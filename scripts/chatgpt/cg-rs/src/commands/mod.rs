//! One module per CLI command. Commands are thin: parse, call the domain
//! layer, print. Anything that needs a test lives in the domain modules.

pub mod archive;
pub mod auth;
pub mod ingest;
pub mod login;
pub mod move_batch;
pub mod organize;
pub mod plan;
pub mod projects;
pub mod status;
pub mod sync;
pub mod unarchive;
pub mod unorganize;
