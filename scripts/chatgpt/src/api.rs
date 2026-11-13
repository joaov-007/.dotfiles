//! Typed wrappers for the handful of endpoints the web app itself uses.
//!
//! Every function takes the base URL and a validated access token, and returns
//! either a typed value or a status code the command can explain. Nothing here
//! retries: the [`HttpClient`] owns that policy.

use serde_json::{Value, json};

use crate::auth::api_headers;
use crate::error::{Error, Result};
use crate::http::{HttpClient, Method, Request, Response};
use crate::model::{ConversationId, ProjectId};

/// A Project as the sidebar knows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Project {
    pub id: ProjectId,
    pub name: String,
}

/// One page of the conversation list. Bodies are empty here; `deep` fetches
/// them one by one.
#[derive(Debug, Clone)]
pub struct ConversationPage {
    pub items: Vec<Value>,
    pub total: usize,
}

/// Projects are gizmos of type snorlax; the sidebar endpoint lists them.
pub fn list_projects(client: &mut HttpClient, base: &str, token: &str) -> Result<Vec<Project>> {
    let url =
        format!("{base}/backend-api/gizmos/snorlax/sidebar?limit=50&conversations_per_gizmo=0");
    let response = client.send(&authorized(Method::Get, &url, base, token))?;
    if response.is_auth_failure() {
        return Err(Error::SessionExpired(format!(
            "HTTP {} ao listar Projects",
            response.status
        )));
    }
    if response.status != 200 {
        return Err(Error::Http {
            status: response.status,
            url,
            body: snippet(&response.body),
        });
    }
    let data: Value = serde_json::from_str(&response.body)?;
    Ok(projects_from_sidebar(&data))
}

/// Parse sidebar JSON. Malformed entries are skipped, not fatal: one odd item
/// must not hide the other projects.
#[must_use]
pub fn projects_from_sidebar(data: &Value) -> Vec<Project> {
    data.get("items")
        .and_then(Value::as_array)
        .map(|items| {
            items
                .iter()
                .filter_map(|item| item.get("gizmo")?.get("gizmo"))
                .filter_map(|gizmo| {
                    let id = gizmo.get("id").and_then(Value::as_str)?;
                    let id = ProjectId::parse(id)?;
                    let name = gizmo
                        .get("display")
                        .and_then(|display| display.get("name"))
                        .and_then(Value::as_str)
                        .map(str::trim)
                        .filter(|name| !name.is_empty())
                        .unwrap_or_else(|| id.as_str())
                        .to_owned();
                    Some(Project { id, name })
                })
                .collect()
        })
        .unwrap_or_default()
}

/// Create a Project. Returns the HTTP status and the new id when the server
/// answered with one.
pub fn create_project(
    client: &mut HttpClient,
    base: &str,
    token: &str,
    name: &str,
) -> Result<(u16, Option<ProjectId>)> {
    let request = authorized(
        Method::Post,
        &format!("{base}/backend-api/projects"),
        base,
        token,
    )
    .body(json!({"name": name, "instructions": ""}).to_string());
    let response = client.send(&request)?;
    if !matches!(response.status, 200 | 201) {
        return Ok((response.status, None));
    }
    let Ok(data) = serde_json::from_str::<Value>(&response.body) else {
        return Ok((response.status, None));
    };
    let id = data
        .get("resource")
        .and_then(|resource| resource.get("gizmo"))
        .and_then(|gizmo| gizmo.get("id"))
        .and_then(Value::as_str)
        .and_then(ProjectId::parse);
    Ok((response.status, id))
}

/// Move one chat in or out of a project. Never deletes anything.
pub fn set_project(
    client: &mut HttpClient,
    base: &str,
    token: &str,
    conv_id: &ConversationId,
    project_id: Option<&ProjectId>,
) -> Result<Response> {
    let url = format!("{base}/backend-api/conversation/{conv_id}");
    let body = json!({"gizmo_id": project_id.map(ProjectId::as_str)}).to_string();
    client.send(&authorized(Method::Patch, &url, base, token).body(body))
}

/// Archive or restore one chat.
pub fn set_archived(
    client: &mut HttpClient,
    base: &str,
    token: &str,
    conv_id: &ConversationId,
    archived: bool,
) -> Result<Response> {
    let url = format!("{base}/backend-api/conversation/{conv_id}");
    let body = json!({"is_archived": archived}).to_string();
    client.send(&authorized(Method::Patch, &url, base, token).body(body))
}

/// One page of the account list.
pub fn conversations_page(
    client: &mut HttpClient,
    base: &str,
    token: &str,
    offset: usize,
    limit: usize,
) -> Result<ConversationPage> {
    let url = format!(
        "{base}/backend-api/conversations?offset={offset}&limit={limit}\
         &order=updated&hide_snorlax=false"
    );
    let response = client.send(&authorized(Method::Get, &url, base, token))?;
    if response.is_auth_failure() {
        return Err(Error::SessionExpired(format!(
            "HTTP {} no endpoint de lista — sessão expirada",
            response.status
        )));
    }
    if response.status == 429 {
        return Err(Error::RateLimited(
            "limite de requisições no endpoint de lista".to_owned(),
        ));
    }
    if response.status != 200 {
        return Err(Error::Http {
            status: response.status,
            url,
            body: snippet(&response.body),
        });
    }
    let data: Value = serde_json::from_str(&response.body)?;
    let items = data
        .get("items")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let total = data
        .get("total")
        .and_then(Value::as_u64)
        .and_then(|total| usize::try_from(total).ok())
        .unwrap_or(items.len());
    Ok(ConversationPage { items, total })
}

/// Fetch one full conversation, bodies included.
pub fn conversation(
    client: &mut HttpClient,
    base: &str,
    token: &str,
    conv_id: &ConversationId,
) -> Result<Response> {
    let url = format!("{base}/backend-api/conversation/{conv_id}");
    client.send(&authorized(Method::Get, &url, base, token))
}

/// A 2xx is not enough: the PATCH echoes the conversation, so read it back.
///
/// Some moves answer 200 while leaving the chat where it was. Recording that as
/// done would make `unorganize` restore a state that never existed, so the echo
/// wins whenever it carries `gizmo_id`.
#[must_use]
pub fn move_confirmed(status: u16, body: &str, project_id: Option<&ProjectId>) -> bool {
    if !(200..300).contains(&status) {
        return false;
    }
    let Ok(echoed) = serde_json::from_str::<Value>(body) else {
        return true;
    };
    if !echoed.is_object()
        || !echoed
            .as_object()
            .is_some_and(|map| map.contains_key("gizmo_id"))
    {
        return true;
    }
    let echoed_id = echoed
        .get("gizmo_id")
        .and_then(Value::as_str)
        .filter(|raw| !raw.is_empty());
    echoed_id == project_id.map(ProjectId::as_str)
}

fn authorized(method: Method, url: &str, base: &str, token: &str) -> Request {
    let mut request = Request::new(method, url);
    for (name, value) in api_headers(token, base) {
        request = request.header(name, value);
    }
    request
}

fn snippet(body: &str) -> String {
    body.chars().take(200).collect()
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn sidebar_projects_are_parsed_and_flattened() {
        let data = json!({
            "items": [
                {"gizmo": {"gizmo": {"id": "g-p-111", "display": {"name": "Linux"}}}},
                {"gizmo": {"gizmo": {"id": "g-p-222", "display": {"name": "  "}}}},
                {"gizmo": {"gizmo": {"id": "g-custom", "display": {"name": "GPT"}}}},
                {"noise": true}
            ]
        });
        let projects = projects_from_sidebar(&data);
        assert_eq!(projects.len(), 2);
        assert_eq!(projects[0].id.as_str(), "g-p-111");
        assert_eq!(projects[0].name, "Linux");
        // An unnamed project falls back to its id rather than an empty line.
        assert_eq!(projects[1].name, "g-p-222");
    }

    #[test]
    fn a_missing_items_array_is_empty() {
        assert_eq!(projects_from_sidebar(&json!({"items": null})).len(), 0);
        assert_eq!(projects_from_sidebar(&json!({})).len(), 0);
    }

    #[test]
    fn a_move_needs_the_echo_to_agree() {
        let target = ProjectId::parse("g-p-111").expect("id");
        assert!(move_confirmed(
            200,
            r#"{"gizmo_id":"g-p-111"}"#,
            Some(&target)
        ));
        assert!(!move_confirmed(
            200,
            r#"{"gizmo_id":"g-p-999"}"#,
            Some(&target)
        ));
        // No echo: trust the status.
        assert!(move_confirmed(204, "", Some(&target)));
        assert!(move_confirmed(200, r#"{"title":"x"}"#, Some(&target)));
        // Not a success.
        assert!(!move_confirmed(
            500,
            r#"{"gizmo_id":"g-p-111"}"#,
            Some(&target)
        ));
    }

    #[test]
    fn moving_out_of_a_project_matches_a_null_echo() {
        assert!(move_confirmed(200, r#"{"gizmo_id":null}"#, None));
        assert!(move_confirmed(200, r#"{"gizmo_id":""}"#, None));
        let target = ProjectId::parse("g-p-111").expect("id");
        assert!(!move_confirmed(200, r#"{"gizmo_id":null}"#, Some(&target)));
    }
}
