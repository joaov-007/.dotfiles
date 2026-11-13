//! Read a `ChatGPT` data export from a `.zip`, a `.json`, or a directory.
//!
//! The export is untrusted input: malformed entries are skipped, but a file
//! that is not a conversations file at all is a hard error.

use std::fs::File;
use std::io::Read;
use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::error::{Error, Result};
use crate::model::{Conversation, parse_conversation};

/// One export read: parsed conversations plus the member names that produced
/// them (shown in the ingest summary).
#[derive(Debug, Clone)]
pub struct ExportBatch {
    pub conversations: Vec<Conversation>,
    pub members: Vec<String>,
}

/// Read every `conversations*.json` in the source.
pub fn load_export(source: &Path) -> Result<ExportBatch> {
    if source.is_dir() {
        load_directory(source)
    } else if source
        .extension()
        .and_then(|ext| ext.to_str())
        .is_some_and(|ext| ext.eq_ignore_ascii_case("zip"))
    {
        load_zip(source)
    } else if source
        .extension()
        .and_then(|ext| ext.to_str())
        .is_some_and(|ext| ext.eq_ignore_ascii_case("json"))
    {
        let bytes = std::fs::read(source)?;
        let values = parse_values(&bytes, source)?;
        Ok(batch(&values, vec![file_name(source)]))
    } else {
        Err(Error::usage(format!(
            "esperava .zip, .json ou uma pasta, veio {}",
            source.display()
        )))
    }
}

fn load_directory(source: &Path) -> Result<ExportBatch> {
    let mut files = std::fs::read_dir(source)?
        .filter_map(std::result::Result::ok)
        .map(|entry| entry.path())
        .filter(|path| {
            path.is_file()
                && path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .is_some_and(is_directory_member)
        })
        .collect::<Vec<_>>();
    files.sort();
    if files.is_empty() {
        return Err(Error::usage(format!(
            "nenhum conversations*.json em {}",
            source.display()
        )));
    }

    let mut conversations = Vec::new();
    let mut members = Vec::new();
    for path in files {
        let bytes = std::fs::read(&path)?;
        let values = parse_values(&bytes, &path)?;
        conversations.extend(batch(&values, Vec::new()).conversations);
        members.push(file_name(&path));
    }
    Ok(ExportBatch {
        conversations,
        members,
    })
}

fn load_zip(source: &Path) -> Result<ExportBatch> {
    let file = File::open(source)?;
    let mut archive = zip::ZipArchive::new(file)?;
    let names = archive
        .file_names()
        .filter_map(std::result::Result::ok)
        .filter(|name| is_zip_member(name))
        .map(std::borrow::Cow::into_owned)
        .collect::<Vec<String>>();
    if names.is_empty() {
        return Err(Error::usage(format!(
            "nenhum conversations*.json dentro de {}",
            file_name(source)
        )));
    }

    let mut conversations = Vec::new();
    let mut members = Vec::new();
    for name in names {
        let mut entry = archive.by_name(&name)?;
        let mut bytes = Vec::new();
        entry.read_to_end(&mut bytes)?;
        let values = parse_values(&bytes, Path::new(&name))?;
        conversations.extend(batch(&values, Vec::new()).conversations);
        members.push(file_name(Path::new(&name)));
    }
    Ok(ExportBatch {
        conversations,
        members,
    })
}

fn batch(values: &[Value], members: Vec<String>) -> ExportBatch {
    let conversations = values
        .iter()
        .filter_map(parse_conversation)
        .collect::<Vec<_>>();
    ExportBatch {
        conversations,
        members,
    }
}

fn parse_values(bytes: &[u8], source: &Path) -> Result<Vec<Value>> {
    let data: Value = serde_json::from_slice(bytes).map_err(|error| {
        Error::usage(format!("{} não é JSON válido: {error}", source.display()))
    })?;
    match data {
        Value::Array(items) => Ok(items.into_iter().filter(Value::is_object).collect()),
        Value::Object(mut object) => {
            let Some(Value::Array(items)) = object.remove("conversations") else {
                return Err(Error::usage(format!(
                    "{} não parece um export do ChatGPT (sem lista e sem a chave \
                     `conversations`)",
                    source.display()
                )));
            };
            Ok(items.into_iter().filter(Value::is_object).collect())
        }
        _ => Err(Error::usage(format!(
            "{} não parece um export do ChatGPT",
            source.display()
        ))),
    }
}

fn file_name(path: &Path) -> String {
    path.file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("?")
        .to_owned()
}

/// Directory mode accepts the same broad prefix the Python glob used.
fn is_directory_member(name: &str) -> bool {
    let path = Path::new(name);
    let Some(file) = path.file_name().and_then(|n| n.to_str()) else {
        return false;
    };
    file.starts_with("conversations")
        && path
            .extension()
            .is_some_and(|ext| ext.eq_ignore_ascii_case("json"))
}

/// ZIP mode is stricter: `conversations.json` or `conversations-<digits>.json`,
/// anywhere in the archive.
fn is_zip_member(name: &str) -> bool {
    let path = PathBuf::from(name);
    let Some(base) = path.file_name().and_then(|n| n.to_str()) else {
        return false;
    };
    let Some(stem) = base.strip_suffix(".json") else {
        return false;
    };
    match stem.strip_prefix("conversations") {
        Some("") => true,
        Some(rest) => rest
            .strip_prefix('-')
            .is_some_and(|digits| !digits.is_empty() && digits.chars().all(|c| c.is_ascii_digit())),
        None => false,
    }
}

#[cfg(test)]
mod tests {
    use serde_json::json;
    use std::io::Write;

    use super::*;

    fn raw(id: &str) -> Value {
        json!({
            "id": id,
            "title": "A title",
            "create_time": 1_700_000_000.0,
            "mapping": {
                "n": {
                    "id": "n", "parent": null, "children": [],
                    "message": {
                        "author": { "role": "user" },
                        "content": { "content_type": "text", "parts": ["hello"] }
                    }
                }
            },
            "current_node": "n"
        })
    }

    #[test]
    fn zip_member_matching_is_strict() {
        assert!(is_zip_member("conversations.json"));
        assert!(is_zip_member("folder/conversations-2.json"));
        assert!(!is_zip_member("conversations-extra.json"));
        assert!(!is_zip_member("notes.json"));
        assert!(!is_zip_member("conversations.json.bak"));
    }

    #[test]
    fn directory_matching_is_broad() {
        assert!(is_directory_member("conversations.json"));
        assert!(is_directory_member("conversations-10.json"));
        assert!(!is_directory_member("conversations.txt"));
        assert!(!is_directory_member("notes.json"));
    }

    #[test]
    fn reads_a_directory_in_sorted_order() {
        let dir = tempfile::tempdir().expect("tempdir");
        std::fs::write(
            dir.path().join("conversations-2.json"),
            serde_json::to_vec(&json!([raw("id-two-0000")])).expect("json"),
        )
        .expect("write");
        std::fs::write(
            dir.path().join("conversations.json"),
            serde_json::to_vec(&json!({ "conversations": [raw("id-one-0000")] })).expect("json"),
        )
        .expect("write");

        let batch = load_export(dir.path()).expect("load");
        assert_eq!(
            batch.members,
            ["conversations-2.json", "conversations.json"]
        );
        assert_eq!(batch.conversations.len(), 2);
    }

    #[test]
    fn reads_a_zip() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("export.zip");
        let file = File::create(&path).expect("create");
        let mut zip = zip::ZipWriter::new(file);
        let options = zip::write::SimpleFileOptions::default()
            .compression_method(zip::CompressionMethod::Stored);
        zip.start_file("nested/conversations.json", options)
            .expect("start");
        zip.write_all(
            serde_json::to_string(&json!([raw("id-zip-0000")]))
                .expect("json")
                .as_bytes(),
        )
        .expect("write");
        zip.finish().expect("finish");

        let batch = load_export(&path).expect("load");
        assert_eq!(batch.members, ["conversations.json"]);
        assert_eq!(batch.conversations.len(), 1);
    }

    #[test]
    fn foreign_json_is_rejected_with_context() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("conversations.json");
        std::fs::write(&path, br#"{"hello":"world"}"#).expect("write");
        let error = load_export(&path).expect_err("must fail");
        assert!(error.to_string().contains("conversations"));
    }
}
