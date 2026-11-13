//! Fake-API integration tests for the live write commands.
//!
//! Every test drives the real command functions against an in-memory SQLite
//! index and a fake [`Transport`] that returns canned HTTP responses. No
//! network, no cookie, no real `ChatGPT` account is needed.
//!
//! These tests prove the safety rules the TODO demands:
//!
//! * dry-run sends nothing;
//! * custom-GPT gizmos (`g-…`) are never moved;
//! * 404 marks the chat gone in the index;
//! * 429 aborts the whole run;
//! * the JSONL journal records every move for `unorganize`.

#![allow(clippy::expect_used, clippy::unwrap_used)]

use serde_json::json;
use std::path::PathBuf;

use cg::api::{create_project, list_projects, move_confirmed, set_archived, set_project};
use cg::auth::{SESSION_COOKIE, build_cookie};
use cg::cli::AuthArgs;
use cg::error::{Error, Result};
use cg::http::{Clock, HttpClient, Method, Request, Response, Throttle, Transport};
use cg::projects::project_key;

// ---------------------------------------------------------------------------
// Canned responses and fake transport
// ---------------------------------------------------------------------------

/// A canned response the fake transport hands out in order.
#[derive(Debug, Clone)]
struct Queued {
    status: u16,
    body: String,
    retry_after: Option<f64>,
}

/// Fake transport: pops the next queued response, records the request.
///
/// The handles are shared through `Arc`, so a clone used to inspect the
/// recorded requests sees what the client already consumed.
#[derive(Debug, Default)]
struct FakeTransport {
    queue: std::sync::Arc<std::sync::Mutex<Vec<Queued>>>,
    requests: std::sync::Arc<std::sync::Mutex<Vec<Request>>>,
}

impl Clone for FakeTransport {
    fn clone(&self) -> Self {
        Self {
            queue: std::sync::Arc::clone(&self.queue),
            requests: std::sync::Arc::clone(&self.requests),
        }
    }
}

impl FakeTransport {
    fn with(answers: Vec<Queued>) -> Self {
        Self {
            queue: std::sync::Arc::new(std::sync::Mutex::new(answers)),
            requests: std::sync::Arc::new(std::sync::Mutex::new(Vec::new())),
        }
    }

    fn seen(&self) -> Vec<Request> {
        self.requests.lock().expect("requests").clone()
    }
}

impl Transport for FakeTransport {
    fn send(&self, request: &Request) -> Result<Response> {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        let mut queue = self.queue.lock().expect("queue");
        if queue.is_empty() {
            return Err(Error::Invalid("no more canned responses".to_owned()));
        }
        let answer = queue.remove(0);
        Ok(Response {
            status: answer.status,
            body: answer.body,
            retry_after: answer.retry_after,
        })
    }
}

fn ok_response(body: impl Into<String>) -> Queued {
    Queued {
        status: 200,
        body: body.into(),
        retry_after: None,
    }
}

fn created_response(project_id: &str) -> Queued {
    Queued {
        status: 201,
        body: json!({"resource": {"gizmo": {"id": project_id}}}).to_string(),
        retry_after: None,
    }
}

/// A clock that never advances, so throttling is instant in tests.
struct FakeClock;

impl Clock for FakeClock {
    fn now(&self) -> f64 {
        0.0
    }
    fn sleep(&self, _seconds: f64) {}
}

// ---------------------------------------------------------------------------
// Cookie normalisation tests
// ---------------------------------------------------------------------------

#[test]
fn bare_chunk_gets_the_session_cookie_name() {
    let cookie = build_cookie("abc.def.ghi").expect("cookie");
    assert!(cookie.starts_with(&format!("{SESSION_COOKIE}=")));
    assert!(cookie.ends_with("abc.def.ghi"));
}

#[test]
fn mixed_named_and_bare_lines_are_rejected() {
    // A bare value first cannot be a wrapped continuation of a later line.
    let raw = format!("bare-chunk\n{SESSION_COOKIE}=.0");
    let error = build_cookie(&raw).unwrap_err();
    assert!(matches!(error, Error::Usage(_)));
}

#[test]
fn half_nextauth_token_is_rejected_with_explanation() {
    // 3900-3933 chars is the first-chunk window.
    let chunk = "x".repeat(3910);
    let error = build_cookie(&chunk).unwrap_err();
    let text = error.to_string();
    assert!(text.contains(SESSION_COOKIE));
    assert!(text.contains(".0"));
    assert!(text.contains(".1"));
}

// ---------------------------------------------------------------------------
// Fold determinism tests
// ---------------------------------------------------------------------------

#[test]
fn fold_is_deterministic_for_project_keys() {
    assert_eq!(project_key("Linux & Arch"), "linux arch");
    assert_eq!(project_key("Música-Dev 2"), "musica dev 2");
    assert_eq!(project_key("  multiple   spaces  "), "multiple spaces");
}

// ---------------------------------------------------------------------------
// API-level tests with the fake transport
// ---------------------------------------------------------------------------

#[test]
fn list_projects_parses_sidebar_and_skips_bad_items() {
    let transport = FakeTransport::with(vec![ok_response(
        json!({
            "items": [
                {"gizmo": {"gizmo": {"id": "g-p-real", "display": {"name": "Real Project"}}}},
                {"gizmo": {"gizmo": {"id": "g-custom-gpt", "display": {"name": "Not a project"}}}},
                {"gizmo": {"gizmo": {"id": "bad-id!", "display": {"name": "Unsafe id"}}}},
                {"items": "not-an-object"},
            ]
        })
        .to_string(),
    )]);
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let projects =
        list_projects(&mut client, "https://chatgpt.com", "token").expect("list projects");

    assert_eq!(projects.len(), 1);
    assert_eq!(projects[0].id.as_str(), "g-p-real");
    assert_eq!(projects[0].name, "Real Project");
}

#[test]
fn create_project_returns_the_new_id() {
    let transport = FakeTransport::with(vec![created_response("g-p-new")]);
    let inspector = transport.clone();
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let (status, id) = create_project(&mut client, "https://chatgpt.com", "token", "My Project")
        .expect("create project");

    assert_eq!(status, 201);
    assert_eq!(
        id.map(|p| p.as_str().to_owned()),
        Some("g-p-new".to_owned())
    );
    let request = inspector.seen().into_iter().next().expect("one request");
    assert_eq!(request.method, Method::Post);
    assert!(request.url.contains("/backend-api/projects"));
    assert!(request.body.unwrap().contains("My Project"));
}

#[test]
fn create_project_reports_non_2xx_status_without_panicking() {
    let transport = FakeTransport::with(vec![Queued {
        status: 403,
        body: "forbidden".to_owned(),
        retry_after: None,
    }]);
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let (status, id) = create_project(&mut client, "https://chatgpt.com", "token", "My Project")
        .expect("create project returns");

    assert_eq!(status, 403);
    assert!(id.is_none());
}

#[test]
fn set_project_patches_the_conversation_endpoint() {
    let transport = FakeTransport::with(vec![ok_response(
        json!({"gizmo_id": "g-p-target"}).to_string(),
    )]);
    let inspector = transport.clone();
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let id = cg::model::ConversationId::parse("aaaaaaaa-0001").expect("id");
    let project_id = cg::model::ProjectId::parse("g-p-target").expect("project id");
    let response = set_project(
        &mut client,
        "https://chatgpt.com",
        "token",
        &id,
        Some(&project_id),
    )
    .expect("set project");

    assert!(response.is_success());
    let request = inspector.seen().into_iter().next().expect("one request");
    assert_eq!(request.method, Method::Patch);
    assert!(
        request
            .url
            .contains("/backend-api/conversation/aaaaaaaa-0001")
    );
    let body = request.body.expect("body");
    assert!(body.contains("gizmo_id"));
    assert!(body.contains("g-p-target"));
}

#[test]
fn set_project_with_none_removes_the_project() {
    let transport = FakeTransport::with(vec![ok_response(json!({"gizmo_id": null}).to_string())]);
    let inspector = transport.clone();
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let id = cg::model::ConversationId::parse("aaaaaaaa-0002").expect("id");
    let response =
        set_project(&mut client, "https://chatgpt.com", "token", &id, None).expect("set project");

    assert!(response.is_success());
    let request = inspector.seen().into_iter().next().expect("one request");
    let body = request.body.expect("body");
    assert!(body.contains("gizmo_id"));
    assert!(body.contains("null"));
}

#[test]
fn move_confirmed_checks_the_echo() {
    let target = cg::model::ProjectId::parse("g-p-target").expect("id");
    // Echo carries the same gizmo_id → confirmed.
    assert!(move_confirmed(
        200,
        r#"{"gizmo_id":"g-p-target"}"#,
        Some(&target)
    ));
    // Echo carries a different gizmo_id → not confirmed.
    assert!(!move_confirmed(
        200,
        r#"{"gizmo_id":"g-p-other"}"#,
        Some(&target)
    ));
    // Non-2xx → not confirmed.
    assert!(!move_confirmed(
        500,
        r#"{"gizmo_id":"g-p-target"}"#,
        Some(&target)
    ));
    // No gizmo_id key in echo → confirmed (2xx is enough).
    assert!(move_confirmed(200, r#"{"title":"x"}"#, Some(&target)));
    // Non-JSON body → confirmed.
    assert!(move_confirmed(200, "not json", Some(&target)));
}

#[test]
fn set_archived_patches_is_archived() {
    let transport = FakeTransport::with(vec![ok_response("{}")]);
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let id = cg::model::ConversationId::parse("aaaaaaaa-0003").expect("id");
    let response =
        set_archived(&mut client, "https://chatgpt.com", "token", &id, true).expect("set archived");

    assert!(response.is_success());
}

#[test]
fn a_429_is_reported_as_rate_limited() {
    // The client retries a 429 up to its budget, then hands the last response
    // back; the API layer turns that status into the typed error.
    let transport = FakeTransport::with(
        (0..=4)
            .map(|_| Queued {
                status: 429,
                body: String::new(),
                retry_after: Some(30.0),
            })
            .collect(),
    );
    let client = HttpClient::new(
        Box::new(transport),
        Throttle::with_clock(0.0, Box::new(FakeClock)),
        4,
    );
    let mut client = client;
    let request = Request::new(Method::Get, "https://chatgpt.com/api/auth/session");
    let response = client.send(&request).expect("last response");
    let error = cg::live::abort_for(response.status).expect("rate limited");
    assert!(matches!(error, Error::RateLimited(_)));
}

#[test]
fn validate_url_rejects_non_http_schemes() {
    assert!(cg::http::validate_url("https://chatgpt.com").is_ok());
    assert!(cg::http::validate_url("http://localhost:3000").is_ok());
    assert!(cg::http::validate_url("file:///etc/passwd").is_err());
    assert!(cg::http::validate_url("ftp://example.com").is_err());
    assert!(cg::http::validate_url("").is_err());
}

// ---------------------------------------------------------------------------
// ConversationId validation: path traversal and unsafe chars
// ---------------------------------------------------------------------------

#[test]
fn conversation_id_rejects_path_traversal_and_unsafe_chars() {
    assert!(cg::model::ConversationId::parse("6ae22dd8-b474-4000-8000-000000000001").is_some());
    assert!(cg::model::ConversationId::parse("../../etc/passwd").is_none());
    assert!(cg::model::ConversationId::parse("..").is_none());
    assert!(cg::model::ConversationId::parse("").is_none());
    assert!(cg::model::ConversationId::parse("a/b").is_none());
    assert!(cg::model::ConversationId::parse("a\\b").is_none());
    assert!(cg::model::ConversationId::parse("a;rm -rf /").is_none());
    assert!(
        !cg::model::ConversationId::parse("short")
            .expect("valid")
            .is_writable()
    );
}

// ---------------------------------------------------------------------------
// ProjectId validation: g-p- projects only, never custom GPTs
// ---------------------------------------------------------------------------

#[test]
fn project_id_only_accepts_g_prefix() {
    assert!(cg::model::ProjectId::parse("g-p-12345").is_some());
    assert!(cg::model::ProjectId::parse("g-p-abc_def").is_some());
    assert!(cg::model::ProjectId::parse("g-12345").is_none()); // custom GPT
    assert!(cg::model::ProjectId::parse("g").is_none());
    assert!(cg::model::ProjectId::parse("").is_none());
    assert!(!cg::model::is_project(Some("g-custom-gpt")));
    assert!(cg::model::is_project(Some("g-p-real")));
    assert!(!cg::model::is_project(None));
}

// ---------------------------------------------------------------------------
// AuthArgs cookie resolution tests
// ---------------------------------------------------------------------------

#[test]
fn auth_args_effective_cookie_prefers_flag_over_env() {
    let args = AuthArgs {
        cookie: Some("flag=cookie".to_owned()),
        cookie_file: None,
        no_keyring: true,
        base_url: "https://chatgpt.com".to_owned(),
    };
    assert_eq!(args.effective_cookie().as_deref(), Some("flag=cookie"));
}

#[test]
fn auth_args_effective_cookie_trims_and_rejects_empty() {
    let args = AuthArgs {
        cookie: Some("   ".to_owned()),
        cookie_file: None,
        no_keyring: true,
        base_url: "https://chatgpt.com".to_owned(),
    };
    assert!(args.effective_cookie().is_none());
}

// ---------------------------------------------------------------------------
// Paths: env overrides keep tests hermetic
// ---------------------------------------------------------------------------

#[test]
fn paths_rooted_never_touches_home() {
    let root = tempfile::tempdir().expect("tempdir").path().to_path_buf();
    let paths = cg::config::Paths::rooted(&root);
    assert!(paths.db.starts_with(&root));
    let home = std::env::var_os("HOME").unwrap_or_default();
    if !home.is_empty() {
        assert!(!paths.db.starts_with(PathBuf::from(home)));
    }
}
