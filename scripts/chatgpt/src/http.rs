//! HTTP plumbing for the live commands.
//!
//! Two pieces, kept separate so both can be tested without a network:
//!
//! * [`Transport`] does exactly one request and returns one response;
//! * [`HttpClient`] owns pacing, retries, and the retry policy.
//!
//! The pacing rules mirror the Python tool: one request in flight, a widening
//! gap on 429, `Retry-After` honoured whether it is seconds or an HTTP date,
//! and no retry for a POST on a 5xx (the server may have created the resource
//! even though the answer was lost).

use std::io::Read;
use std::time::{Duration, Instant};

use chrono::{DateTime, Utc};

use crate::error::{Error, Result};

/// HTTP verbs the API needs.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Method {
    Get,
    Post,
    Patch,
}

impl Method {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Get => "GET",
            Self::Post => "POST",
            Self::Patch => "PATCH",
        }
    }

    /// A POST may create something; retrying it after a lost response could
    /// create the same Project twice. Every other verb here is idempotent.
    fn is_idempotent(self) -> bool {
        !matches!(self, Self::Post)
    }
}

/// One request, fully described. The client never mutates it.
#[derive(Debug, Clone)]
pub struct Request {
    pub method: Method,
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: Option<String>,
}

impl Request {
    #[must_use]
    pub fn new(method: Method, url: impl Into<String>) -> Self {
        Self {
            method,
            url: url.into(),
            headers: Vec::new(),
            body: None,
        }
    }

    #[must_use]
    pub fn header(mut self, name: impl Into<String>, value: impl Into<String>) -> Self {
        self.headers.push((name.into(), value.into()));
        self
    }

    #[must_use]
    pub fn body(mut self, body: impl Into<String>) -> Self {
        self.body = Some(body.into());
        self
    }
}

/// One response, including the status code, so callers decide what it means.
#[derive(Debug, Clone)]
pub struct Response {
    pub status: u16,
    pub body: String,
    pub retry_after: Option<f64>,
}

impl Response {
    #[must_use]
    pub fn is_success(self) -> bool {
        (200..300).contains(&self.status)
    }

    #[must_use]
    pub fn is_auth_failure(&self) -> bool {
        matches!(self.status, 401 | 403)
    }
}

/// A single round trip. Implementations must not retry or sleep.
pub trait Transport: Send + Sync {
    fn send(&self, request: &Request) -> Result<Response>;
}

/// `ureq`-backed transport used by the real binary.
#[derive(Debug)]
pub struct UreqTransport {
    agent: ureq::Agent,
}

impl UreqTransport {
    /// Build an agent with a connect and an overall timeout.
    #[must_use]
    pub fn new(timeout: Duration) -> Self {
        let agent = ureq::AgentBuilder::new()
            .timeout_connect(timeout)
            .timeout(timeout)
            .build();
        Self { agent }
    }
}

impl Default for UreqTransport {
    fn default() -> Self {
        Self::new(Duration::from_secs(30))
    }
}

impl Transport for UreqTransport {
    fn send(&self, request: &Request) -> Result<Response> {
        let mut pending = self.agent.request(request.method.as_str(), &request.url);
        for (name, value) in &request.headers {
            pending = pending.set(name, value);
        }

        let result = match &request.body {
            Some(body) => pending.send_string(body),
            None => pending.call(),
        };
        let response = match result {
            Ok(response) | Err(ureq::Error::Status(_, response)) => response,
            Err(ureq::Error::Transport(error)) => {
                return Err(Error::Network {
                    url: request.url.clone(),
                    reason: error.to_string(),
                });
            }
        };

        let status = response.status();
        let retry_after = response
            .header("Retry-After")
            .and_then(parse_retry_after)
            .map(|when| when.max(0.0));
        let body = read_body(response);
        Ok(Response {
            status,
            body,
            retry_after,
        })
    }
}

fn read_body(response: ureq::Response) -> String {
    let mut text = String::new();
    // A truncated error body is still useful in a message; do not fail the
    // whole request because the body could not be decoded.
    let _ = response
        .into_reader()
        .take(8 * 1024 * 1024)
        .read_to_string(&mut text);
    text
}

/// `Retry-After` is either delta-seconds or an HTTP-date; both mean "wait".
#[must_use]
#[allow(clippy::cast_precision_loss)]
pub fn parse_retry_after(raw: &str) -> Option<f64> {
    let raw = raw.trim();
    if raw.is_empty() {
        return None;
    }
    if let Ok(seconds) = raw.parse::<f64>() {
        return Some(seconds.max(0.0));
    }
    if let Ok(when) = DateTime::parse_from_rfc2822(raw) {
        return Some((when.with_timezone(&Utc) - Utc::now()).num_milliseconds() as f64 / 1000.0);
    }
    // chrono does not accept the literal `GMT` suffix some servers send.
    let stripped = raw.strip_suffix(" GMT").unwrap_or(raw);
    if let Ok(naive) = chrono::NaiveDateTime::parse_from_str(stripped, "%a, %d %b %Y %H:%M:%S") {
        let when = naive.and_utc();
        return Some((when - Utc::now()).num_milliseconds() as f64 / 1000.0);
    }
    None
}

/// Time and sleep seams so the throttle can be tested instantly.
pub trait Clock: Send + Sync {
    fn now(&self) -> f64;
    fn sleep(&self, seconds: f64);
}

/// Wall clock and real sleep, used by every command that talks to the API.
#[derive(Debug, Clone, Copy, Default)]
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> f64 {
        // A monotonic reference is enough; it is never compared with epoch time.
        static START: std::sync::OnceLock<Instant> = std::sync::OnceLock::new();
        let start = START.get_or_init(Instant::now);
        start.elapsed().as_secs_f64()
    }

    fn sleep(&self, seconds: f64) {
        if seconds > 0.0 {
            std::thread::sleep(Duration::from_secs_f64(seconds));
        }
    }
}

/// Pacing state. One instance per run, shared by every request.
pub struct Throttle {
    floor: f64,
    interval: f64,
    ceiling: f64,
    next: f64,
    enabled: bool,
    clock: Box<dyn Clock>,
}

impl std::fmt::Debug for Throttle {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Throttle")
            .field("floor", &self.floor)
            .field("interval", &self.interval)
            .field("ceiling", &self.ceiling)
            .field("next", &self.next)
            .field("enabled", &self.enabled)
            .finish_non_exhaustive()
    }
}

impl Throttle {
    /// `interval` is the starting gap; `CG_THROTTLE=0|off|false` disables it.
    #[must_use]
    pub fn new(interval: f64) -> Self {
        Self::with_clock(interval, Box::new(SystemClock))
    }

    #[must_use]
    pub fn with_clock(interval: f64, clock: Box<dyn Clock>) -> Self {
        let interval = interval.max(0.0);
        Self {
            floor: interval,
            interval,
            ceiling: 30.0,
            next: 0.0,
            enabled: throttle_enabled(),
            clock,
        }
    }

    /// The command chooses the pace; a 429 can only make it slower.
    pub fn set_floor(&mut self, interval: f64) {
        self.floor = interval.max(0.0);
        self.interval = self.floor;
        self.next = 0.0;
    }

    /// Sleep until the next slot. Called before every attempt.
    pub fn wait(&mut self) {
        if !self.enabled {
            return;
        }
        let delay = self.next - self.clock.now();
        if delay > 0.0 {
            log::debug!(
                "throttle: esperando {delay:.1}s (intervalo {:.1}s)",
                self.interval
            );
            self.clock.sleep(delay);
        }
    }

    /// Push the next slot at least `seconds` into the future.
    pub fn pause(&mut self, seconds: f64) {
        if self.enabled && seconds > 0.0 {
            self.next = self.next.max(self.clock.now() + seconds);
        }
    }

    /// Update pacing from the response that just arrived.
    pub fn observe(&mut self, status: u16, retry_after: Option<f64>) {
        let now = self.clock.now();
        if status == 429 {
            self.interval = self
                .ceiling
                .min((self.interval * 2.0).max(self.floor * 2.0).max(2.0));
            let pause = retry_after
                .filter(|seconds| *seconds > 0.0)
                .unwrap_or(self.interval);
            self.pause(pause.max(self.interval));
            log::warn!(
                "HTTP 429 — intervalo agora {:.1}s, pausa de {:.1}s",
                self.interval,
                pause.max(self.interval)
            );
            return;
        }
        // Recover slowly (5% per good answer) and never faster than the floor.
        self.interval = self.floor.max(self.interval * 0.95);
        let spread = 0.9 + 0.2 * fastrand::f64();
        self.next = now + self.floor.max(self.interval * spread);
    }

    #[must_use]
    pub fn interval(&self) -> f64 {
        self.interval
    }

    #[must_use]
    pub fn floor(&self) -> f64 {
        self.floor
    }
}

fn throttle_enabled() -> bool {
    match std::env::var("CG_THROTTLE") {
        Ok(raw) => !matches!(
            raw.trim().to_ascii_lowercase().as_str(),
            "0" | "off" | "false"
        ),
        Err(_) => true,
    }
}

/// Pacing plus retry policy around a [`Transport`].
pub struct HttpClient {
    transport: Box<dyn Transport>,
    throttle: Throttle,
    retries: u32,
    timeout: Duration,
}

impl std::fmt::Debug for HttpClient {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HttpClient")
            .field("throttle", &self.throttle)
            .field("retries", &self.retries)
            .field("timeout", &self.timeout)
            .finish_non_exhaustive()
    }
}

impl HttpClient {
    #[must_use]
    pub fn new(transport: Box<dyn Transport>, throttle: Throttle, retries: u32) -> Self {
        Self {
            transport,
            throttle,
            retries,
            timeout: Duration::from_secs(30),
        }
    }

    /// Real network client with the default timeouts.
    #[must_use]
    pub fn live(sleep: f64, retries: u32) -> Self {
        Self::new(
            Box::new(UreqTransport::default()),
            Throttle::new(sleep),
            retries,
        )
    }

    pub fn set_sleep(&mut self, seconds: f64) {
        self.throttle.set_floor(seconds);
    }

    #[must_use]
    pub fn throttle(&self) -> &Throttle {
        &self.throttle
    }

    #[must_use]
    pub fn timeout(&self) -> Duration {
        self.timeout
    }

    /// Send one request, retrying only when the policy allows it.
    pub fn send(&mut self, request: &Request) -> Result<Response> {
        validate_url(&request.url)?;
        Self::validate_headers(request)?;

        for attempt in 0..=self.retries {
            self.throttle.wait();
            let started = Instant::now();
            let response = self.transport.send(request)?;
            log::debug!(
                "{} {} -> {} ({} ms)",
                request.method.as_str(),
                request.url,
                response.status,
                started.elapsed().as_millis()
            );
            self.throttle.observe(response.status, response.retry_after);

            let retryable = is_retryable(response.status);
            let allowed = request.method.is_idempotent() || response.status == 429;
            if !retryable || !allowed || attempt == self.retries {
                return Ok(response);
            }

            let backoff =
                self.throttle.interval() * 2_f64.powi(i32::try_from(attempt).unwrap_or(0));
            let wait = backoff.max(response.retry_after.unwrap_or(0.0));
            self.throttle.pause(wait);
            log::warn!(
                "{} {} -> HTTP {}; tentando de novo em {:.0}s ({}/{})",
                request.method.as_str(),
                request.url,
                response.status,
                wait,
                attempt + 1,
                self.retries
            );
        }

        // The loop always returns; this keeps the compiler honest without a
        // panic on a path that cannot happen.
        Err(Error::Invalid("pedido HTTP sem resposta".to_owned()))
    }

    fn validate_headers(request: &Request) -> Result<()> {
        for (name, value) in &request.headers {
            if name.is_empty()
                || value.contains('\r')
                || value.contains('\n')
                || value.contains('\0')
            {
                return Err(Error::Invalid(format!("cabeçalho HTTP inválido: {name:?}")));
            }
        }
        Ok(())
    }
}

fn is_retryable(status: u16) -> bool {
    matches!(status, 429 | 500 | 502 | 503)
}

/// Only http(s) URLs are accepted; a file: URL must never reach the transport.
pub fn validate_url(url: &str) -> Result<()> {
    let trimmed = url.trim();
    let rest = trimmed
        .strip_prefix("https://")
        .or_else(|| trimmed.strip_prefix("http://"));
    match rest {
        Some(rest) if !rest.is_empty() && !rest.starts_with('/') => Ok(()),
        _ => Err(Error::usage(format!("URL recusada (só http/https): {url}"))),
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Mutex;

    use super::*;

    #[derive(Debug, Default)]
    struct FakeClock {
        now: Mutex<f64>,
        sleeps: Mutex<Vec<f64>>,
    }

    impl Clock for FakeClock {
        fn now(&self) -> f64 {
            *self.now.lock().expect("clock")
        }

        fn sleep(&self, seconds: f64) {
            self.sleeps.lock().expect("sleeps").push(seconds);
            *self.now.lock().expect("clock") += seconds;
        }
    }

    #[derive(Debug)]
    struct FakeTransport {
        answers: Mutex<Vec<Response>>,
        requests: Mutex<Vec<Request>>,
    }

    impl FakeTransport {
        fn new(answers: Vec<Response>) -> Self {
            Self {
                answers: Mutex::new(answers),
                requests: Mutex::new(Vec::new()),
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
            let mut answers = self.answers.lock().expect("answers");
            if answers.is_empty() {
                return Err(Error::Invalid("sem resposta enfileirada".to_owned()));
            }
            Ok(answers.remove(0))
        }
    }

    fn response(status: u16) -> Response {
        Response {
            status,
            body: String::new(),
            retry_after: None,
        }
    }

    fn client<T: Transport + 'static>(transport: T, retries: u32) -> HttpClient {
        let clock = FakeClock::default();
        HttpClient::new(
            Box::new(transport),
            Throttle::with_clock(0.0, Box::new(clock)),
            retries,
        )
    }

    #[test]
    fn retry_after_accepts_seconds_and_dates() {
        assert_eq!(parse_retry_after("12"), Some(12.0));
        assert_eq!(parse_retry_after(" 0 "), Some(0.0));
        assert_eq!(parse_retry_after(""), None);
        assert_eq!(parse_retry_after("nonsense"), None);

        let future = (Utc::now() + chrono::Duration::seconds(60))
            .format("%a, %d %b %Y %H:%M:%S GMT")
            .to_string();
        let seconds = parse_retry_after(&future).expect("date");
        assert!((55.0..=65.0).contains(&seconds), "{seconds}");
    }

    #[test]
    fn a_429_is_retried_for_any_method() {
        let transport = FakeTransport::new(vec![response(429), response(200)]);
        let mut client = client(transport, 2);
        let request = Request::new(Method::Post, "https://example.test/api");
        let response = client.send(&request).expect("send");
        assert_eq!(response.status, 200);
    }

    struct SharedTransport(std::sync::Arc<FakeTransport>);

    impl Transport for SharedTransport {
        fn send(&self, request: &Request) -> Result<Response> {
            self.0.send(request)
        }
    }

    struct SharedClock(std::sync::Arc<FakeClock>);

    impl Clock for SharedClock {
        fn now(&self) -> f64 {
            self.0.now()
        }

        fn sleep(&self, seconds: f64) {
            self.0.sleep(seconds);
        }
    }

    #[test]
    fn a_post_5xx_is_not_retried() {
        let transport = std::sync::Arc::new(FakeTransport::new(vec![response(503)]));
        let mut client = client(SharedTransport(transport.clone()), 3);
        let request = Request::new(Method::Post, "https://example.test/api");
        let response = client.send(&request).expect("send");
        assert_eq!(response.status, 503);
        assert_eq!(transport.seen().len(), 1, "a POST must be attempted once");
    }

    #[test]
    fn a_get_5xx_is_retried_until_the_budget_is_gone() {
        let transport = std::sync::Arc::new(FakeTransport::new(vec![
            response(503),
            response(503),
            response(200),
        ]));
        let mut client = client(SharedTransport(transport.clone()), 3);
        let request = Request::new(Method::Get, "https://example.test/api");
        let response = client.send(&request).expect("send");
        assert_eq!(response.status, 200);
        assert_eq!(transport.seen().len(), 3);
    }

    #[test]
    fn network_failures_are_not_retried() {
        let transport = FakeTransport::new(Vec::new());
        let mut client = client(transport, 3);
        let request = Request::new(Method::Get, "https://example.test/api");
        let error = client.send(&request).expect_err("must fail");
        assert!(matches!(error, Error::Invalid(_)));
    }

    #[test]
    fn non_http_urls_are_refused_before_the_transport() {
        let transport = FakeTransport::new(vec![response(200)]);
        let mut client = client(transport, 0);
        let request = Request::new(Method::Get, "file:///etc/passwd");
        let error = client.send(&request).expect_err("must fail");
        assert!(matches!(error, Error::Usage(_)));
    }

    #[test]
    fn header_injection_is_refused() {
        let transport = FakeTransport::new(vec![response(200)]);
        let mut client = client(transport, 0);
        let request = Request::new(Method::Get, "https://example.test/api")
            .header("X-Test", "value\r\nInjected: yes");
        assert!(client.send(&request).is_err());
    }

    #[test]
    fn throttle_never_goes_faster_than_the_floor() {
        let clock = std::sync::Arc::new(FakeClock::default());
        let mut throttle = Throttle::with_clock(1.5, Box::new(SharedClock(clock.clone())));
        for _ in 0..5 {
            throttle.observe(200, None);
        }
        assert!(throttle.interval() >= 1.5);
    }

    #[test]
    fn a_429_widens_the_interval_and_backs_off() {
        let clock = std::sync::Arc::new(FakeClock::default());
        let mut throttle = Throttle::with_clock(1.0, Box::new(SharedClock(clock.clone())));
        throttle.observe(429, Some(7.0));
        assert!(throttle.interval() >= 2.0);
        throttle.wait();
        let slept = clock.sleeps.lock().expect("sleeps").clone();
        assert_eq!(slept.len(), 1);
        assert!(slept[0] >= 7.0, "{slept:?}");
    }

    #[test]
    fn requests_are_logged_in_order() {
        let transport = std::sync::Arc::new(FakeTransport::new(vec![response(200), response(404)]));
        let mut client = client(SharedTransport(transport.clone()), 0);
        let _ = client
            .send(&Request::new(Method::Get, "https://example.test/one"))
            .expect("one");
        let _ = client
            .send(&Request::new(Method::Get, "https://example.test/two"))
            .expect("two");
        let seen = transport.seen();
        assert_eq!(seen.len(), 2);
        assert!(seen[0].url.ends_with("/one"));
        assert!(seen[1].url.ends_with("/two"));
    }
}
