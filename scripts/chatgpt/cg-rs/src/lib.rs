//! Organize `ChatGPT` history without deleting anything.
//!
//! The crate is split so the offline core (parse, index, classify, plan) can be
//! tested without a browser, a cookie, or a network connection:
//!
//! * [`export`] reads an official export;
//! * [`model`] parses the visible conversation branch;
//! * [`store`] keeps a SQLite index compatible with the Python version;
//! * [`classify`] and [`plan`] decide what is worth keeping;
//! * [`report`] writes the human- and machine-readable plans.
//!
//! Live commands are layered on top of these and live behind their own modules.

pub mod api;
pub mod app;
pub mod auth;
pub mod classify;
pub mod classify_data;
pub mod cli;
pub mod commands;
pub mod config;
pub mod daemon;  // NEW
pub mod error;
pub mod export;
pub mod http;
pub mod journal;
pub mod live;
pub mod lock;
pub mod model;
pub mod plan;
pub mod projects;
pub mod report;
pub mod store;
pub mod text;

pub use error::{Error, Result};
