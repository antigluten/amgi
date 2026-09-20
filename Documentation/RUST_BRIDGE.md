# The Rust bridge

How Swift talks to the Anki engine. The layer map is in
[ARCHITECTURE.md](ARCHITECTURE.md); the step-by-step recipe for surfacing a new
method lives in [`Sources/AGENTS.md`](../Sources/AGENTS.md), beside the code.

## Four C functions

The entire bridge surface, declared in `anki-bridge-rs/src/lib.rs`:

| Function | Purpose |
|---|---|
| `anki_open_backend(path, lang)` | Open a collection at the given path, returns a handle |
| `anki_run_method(handle, service, method, input, input_len, output, output_len)` | Run an RPC method |
| `anki_free_response(ptr, len)` | Free a response buffer allocated by Rust |
| `anki_close_backend(handle)` | Close the collection and free the handle |

Adding a fifth symbol is a last resort — prefer a new service/method pair routed
through `anki_run_method`.

## Protobuf serialization

```
Swift request struct
    │
    ▼  .serializedData()
Raw bytes (Data)
    │
    ▼  C FFI: anki_run_method()
Rust deserializes → executes → serializes response
    │
    ▼  Raw bytes back to Swift
Response struct
    │
    ▼  init(serializedBytes:)
Swift response struct
```

Every call encodes protobuf, passes bytes through C, and decodes protobuf. No
Objective-C, no Swift-Rust interop crates — just C and bytes.

## Service and method dispatch

The backend exposes services identified by numeric IDs, in two layers:

- **Backend services** (odd IDs: 1, 3, 7, 13, 25, 27, 29, 41) handle
  backend-level operations — open collection, sync — and delegate the rest to
  collection services.
- **Collection services** (even IDs) handle collection-level operations: search,
  scheduling, stats.

A backend service prepends its own methods before delegating, so a method's
index differs between the two layers — `getQueuedCards` is method 3 on
`BackendSchedulerService` (13) and method 0 on `CollectionSchedulerService` (12).
Address everything through the backend table. `CollectionService` (2) in
particular is never dispatched over the FFI at all; its methods arrive through
`BackendCollectionService` (3).

`Sources/AnkiProtoBridge/ServiceCatalog.swift` holds every ID this app uses,
mirroring the generated `backend.rs` upstream. It is the source of truth, and
this document deliberately does not copy it — a table of numbers duplicated into
prose goes stale without anything failing.

## App-only RPCs

Service 200 is ours rather than upstream's, for work upstream has no RPC for:
today, finding notes that share a first field. `anki-bridge-rs/src/aux.rs`
dispatches it before a call reaches the engine's own router, and the wire format
is JSON via `serde` rather than protobuf, so there is no `.proto` involved.

## Build pipeline

```
anki-bridge-rs/
├── src/lib.rs          — C FFI exports
├── src/aux.rs          — app-only JSON RPCs (service 200)
├── Cargo.toml          — depends on the vendored anki-upstream/rslib
└── targets:
    aarch64-apple-ios              (device)
    aarch64-apple-ios-sim          (simulator)
    aarch64-apple-watchos-sim      (watch simulator, -Z build-std on nightly)
```

`scripts/build-xcframework.sh` compiles each target, wraps each `cdylib` in an
`AnkiRustLib.framework`, and packages them into `AnkiRustLib.xcframework`, which
SPM consumes as a binary target.

The framework is **dynamic** on purpose. A static archive's symbols are
invisible to XCPreviewAgent's JIT, which broke every package-target SwiftUI
preview that transitively reached `AnkiBackend` with `JITError: Symbols not
found: [_anki_open_backend, …]`. Do not switch `crate-type` back to `staticlib`.

The watchOS slice is arm64-only, so watch builds need `ARCHS=arm64`; the default
multi-arch simulator build fails to link x86_64.

`scripts/generate-protos.sh` runs `protoc --swift_out` against the 25 `.proto`
files under `anki-upstream/proto/anki/` to produce Swift types in
`Sources/AnkiProto/`.

`anki-upstream/` is a submodule pinned to the `26.05` tag. Do not move it
without coordinating: the generated protos and the service/method IDs are tied
to that revision.
