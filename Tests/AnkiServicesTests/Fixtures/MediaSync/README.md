# Native media-sync protocol fixture

This is a bounded loopback HTTP fixture, not an Anki server implementation.
The tests call `SyncService.liveValue` with a real isolated Rust backend.
Collection download/upload, zstd decoding, media ZIP extraction, media database
updates, image decoding, and Check Media / Check Database are real.

Nothing here is a pre-built collection. Each test creates a scratch collection
with the repository's compiled Rust backend and adds a Basic note with fields
`["<img src=\"probe.png\">", "media sync"]` to deck 1. The "remote" collection
served for a full download is built separately (`makeRemoteCollection`). The
incremental tests serve a snapshot of their own collection: they read its `mod` /
`scm` back from SQLite and serve them as current-time collection metadata, so
collection sync has no changes while media version 1 still needs fetching.
Native incremental media skips `begin` because collection metadata already
supplies the media USN. No user's collection, account, or media was used.

`probe.png` is the original placeholder app icon resized to 2 × 2 with `sips`.
`media.zip` is a stored ZIP with entry `0` (that PNG) and `_meta`:
`{"0":"probe.png"}`. The PNG's SHA-1 is recorded in `protocol.json`.

`protocol.json` holds the JSON endpoint responses (`begin`, `changes`, `empty`,
`sanity`). The server wraps every payload in a zstd frame of raw blocks at
request time and derives `anki-original-size` from the payload. It requires
collection → begin → changes → ZIP → empty changes → sanity in that order.
Unknown requests are recorded as failures that the tests assert on; no status
is mocked.

The interruption case sends half the zstd-wrapped media ZIP, declares a larger
Content-Length, then closes the connection. It requires a native sync error, no
partially installed PNG, a successful retry with byte-identical media, an
idempotent subsequent sync with no download, and clean Check Media / Check
Database.
