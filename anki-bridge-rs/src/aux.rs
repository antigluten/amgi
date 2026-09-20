//! App-only RPCs, dispatched at service 200.
//!
//! Everything below service 46 belongs to upstream and is routed straight to
//! `Backend::run_service_method`. Service 200 is ours: methods that Amgi needs
//! and upstream has no rpc for, implemented here so the work happens next to
//! the collection instead of as N round trips from Swift.
//!
//! The wire format is JSON, not protobuf — an app-only method has no .proto to
//! regenerate, so a field can be added without touching `scripts/generate-protos.sh`.
//! The price is that none of protobuf's compatibility rules apply, which is why
//! every method here must carry a probe in `RequestProbeCoverageTests`.
//!
//! This builds entirely on rslib's **public** surface —
//! `Backend::run_db_command_bytes` and `text::strip_html_preserving_media_filenames`.
//! No fork, and nothing reaches through a `pub(crate)`.

use anki::backend::Backend;
use anki::text::strip_html_preserving_media_filenames;
use prost::Message;
use serde::Deserialize;
use serde::Serialize;
use std::collections::HashMap;

pub const SERVICE: u32 = 200;

const FIND_DUPLICATES: u32 = 0;

/// Routes one aux call. `Ok` is the response body, `Err` a serialized
/// `BackendError` — the same convention `run_service_method` uses, so the
/// Swift side's `0 = ok / 1 = error-protobuf` handling is unchanged.
///
/// `_input` is unused while `findDuplicates` is the only method — it takes no
/// arguments. It stays in the signature because the next method will have some
/// and because it mirrors what `anki_run_method` was handed.
pub fn dispatch(backend: &Backend, method: u32, _input: &[u8]) -> Result<Vec<u8>, Vec<u8>> {
    match method {
        FIND_DUPLICATES => find_duplicates(backend),
        other => Err(error(
            ErrorKind::InvalidInput,
            format!("unknown aux method {other}"),
        )),
    }
}

// MARK: - findDuplicates

#[derive(Serialize)]
struct DuplicateGroup {
    notetype_id: i64,
    value: String,
    note_ids: Vec<i64>,
}

#[derive(Serialize)]
struct FindDuplicatesResponse {
    groups: Vec<DuplicateGroup>,
}

/// Every group of notes that share a first field, across the whole collection.
///
/// Upstream has exact duplicate matching already (`SearchNode::Duplicates`, the
/// `dupe:` operator) but it answers "who else has *this* value", which serves
/// the add-note warning and not the browser's "show me every duplicate group".
/// Finding all groups needs every note's first field, and there is no bulk note
/// fetch — `GetNote` and `BrowserRowForId` are both one-at-a-time. Hence this:
/// one query, grouped in SQLite, instead of N FFI round trips.
///
/// Matches upstream's definition of a duplicate exactly (see
/// `rslib/src/search/sqlwriter.rs`, `write_dupe`): `csum` is a 32-bit prefilter
/// over the HTML-stripped first field, so the SQL narrows to candidates and the
/// comparison below confirms them on the stripped text. Notes whose first field
/// is empty are not duplicates of each other, the same as upstream.
fn find_duplicates(backend: &Backend) -> Result<Vec<u8>, Vec<u8>> {
    // (mid, csum) is what upstream keys duplicate detection on, and `notes` has
    // an index on csum, so the inner grouping does not table-scan the strings.
    let query = serde_json::json!({
        "kind": "query",
        "sql": "select n.id, n.mid, n.flds from notes n \
                join (select mid, csum from notes group by mid, csum having count(*) > 1) d \
                  on n.mid = d.mid and n.csum = d.csum \
                order by n.mid, n.id",
        "args": [],
        "first_row_only": false,
    });
    let request = serde_json::to_vec(&query)
        .map_err(|e| error(ErrorKind::JsonError, format!("aux: encoding query: {e}")))?;

    let rows: Vec<Row> = serde_json::from_slice(&backend.run_db_command_bytes(&request)?)
        .map_err(|e| error(ErrorKind::JsonError, format!("aux: decoding rows: {e}")))?;

    let groups = group_rows(rows);

    serde_json::to_vec(&FindDuplicatesResponse { groups })
        .map_err(|e| error(ErrorKind::JsonError, format!("aux: encoding response: {e}")))
}

/// Checks `buckets` with `get_mut` before inserting, so the key clones only
/// when a row starts a brand-new group, not once per row.
fn group_rows(rows: Vec<Row>) -> Vec<DuplicateGroup> {
    // Insertion-ordered so the SQL's `order by` survives into the response;
    // HashMap only decides which bucket a row lands in.
    let mut order: Vec<(i64, String)> = Vec::new();
    let mut buckets: HashMap<(i64, String), Vec<i64>> = HashMap::new();

    for Row(id, notetype_id, fields) in rows {
        let first = fields.split('\u{1f}').next().unwrap_or_default();
        let stripped = strip_html_preserving_media_filenames(first);
        if stripped.trim().is_empty() {
            continue;
        }
        let key = (notetype_id, stripped.into_owned());
        match buckets.get_mut(&key) {
            Some(ids) => ids.push(id),
            None => {
                order.push(key.clone());
                buckets.insert(key, vec![id]);
            }
        }
    }

    order
        .into_iter()
        .filter_map(|key| {
            let note_ids = buckets.remove(&key)?;
            // A csum collision, or two notes that differed only in markup that
            // stripping removed, can leave a candidate group of one.
            (note_ids.len() > 1).then(|| DuplicateGroup {
                notetype_id: key.0,
                value: key.1,
                note_ids,
            })
        })
        .collect()
}

/// One row of `select n.id, n.mid, n.flds`. The DB proxy serializes rows as
/// untagged JSON arrays, so this is a tuple struct rather than a named one.
#[derive(Deserialize)]
struct Row(i64, i64, String);

// MARK: - Errors

type ErrorKind = anki_proto::backend::backend_error::Kind;

fn error(kind: ErrorKind, message: String) -> Vec<u8> {
    anki_proto::backend::BackendError {
        message,
        kind: kind as i32,
        ..Default::default()
    }
    .encode_to_vec()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn row(id: i64, notetype_id: i64, fields: &str) -> Row {
        Row(id, notetype_id, fields.to_string())
    }

    #[test]
    fn groups_preserve_first_appearance_order() {
        let rows = vec![
            row(1, 10, "banana\u{1f}b1"),
            row(2, 10, "apple\u{1f}a1"),
            row(3, 10, "banana\u{1f}b2"),
            row(4, 10, "apple\u{1f}a2"),
        ];

        let groups = group_rows(rows);

        assert_eq!(groups.len(), 2);
        assert_eq!(groups[0].notetype_id, 10);
        assert_eq!(groups[0].value, "banana");
        assert_eq!(groups[0].note_ids, vec![1, 3]);
        assert_eq!(groups[1].value, "apple");
        assert_eq!(groups[1].note_ids, vec![2, 4]);
    }

    #[test]
    fn skips_rows_with_empty_first_field() {
        let rows = vec![
            row(1, 10, "\u{1f}rest"),
            row(2, 10, "\u{1f}rest"),
            row(3, 10, "shared\u{1f}x"),
            row(4, 10, "shared\u{1f}y"),
        ];

        let groups = group_rows(rows);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].value, "shared");
        assert_eq!(groups[0].note_ids, vec![3, 4]);
    }

    #[test]
    fn drops_singleton_groups() {
        let rows = vec![
            row(1, 10, "unique\u{1f}x"),
            row(2, 10, "shared\u{1f}x"),
            row(3, 10, "shared\u{1f}y"),
        ];

        let groups = group_rows(rows);

        assert_eq!(groups.len(), 1);
        assert_eq!(groups[0].value, "shared");
        assert_eq!(groups[0].note_ids, vec![2, 3]);
    }
}
