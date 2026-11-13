//! One module per CLI command. Commands are thin: parse, call the domain
//! layer, print. Anything that needs a test lives in the domain modules.

pub mod archive;
pub mod auth;
pub mod completions;
pub mod export;
pub mod ingest;
pub mod log;
pub mod login;
pub mod logout;
pub mod move_batch;
pub mod organize;
pub mod plan;
pub mod projects;
pub mod services;
pub mod status;
pub mod sync;
pub mod unarchive;
pub mod unorganize;
