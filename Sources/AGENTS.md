# AnkiBridge

The engine surface, from `@DependencyClient` structs down to the four C FFI
symbols. The Rust engine is a black-box RPC service — every call goes through
the layers in order.

| Module | Role |
|---|---|
| `AnkiKit` | Pure Swift domain types (`Rating`, `FSRSState`, `DeckInfo`, `EntityID`). No deps. |
| `AnkiProto` | Generated SwiftProtobuf types. Package-internal: only `AnkiBackend` and `AnkiProtoBridge` import it. |
| `AnkiBackend` | Wraps the C FFI, owns the backend pointer, dispatches `Request<R>`, carries `RPCObserver` and `backendOffload`. |
| `AnkiProtoBridge` | The one sanctioned protobuf ↔ Swift-mirror boundary: `Request<R>` factories, `ServiceCatalog`, typed `*Method` wrappers. |
| `AnkiServices` | Facades: Decks, Scheduler, Sync, Stats, Notes, Notetypes, CardRendering, ImportExport, Collection. |
| `AnkiClients` | `@DependencyClient` structs + live values. The UI's entry point. |
| `AnkiSync` | `KeychainHelper`, scoped per profile. |
| `AmgiCardWeb` | WebKit card renderer host. |
| `AnkiRustLib` | `binaryTarget` → `AnkiRustLib.xcframework`. iOS and watchOS slices. |

## Service and method IDs

`Sources/AnkiProtoBridge/ServiceCatalog.swift` is the source of truth — read it,
and do not copy its numbers into a doc, where they go stale silently.

Two traps it encodes: backend services (odd IDs) prepend their own methods
before delegating, so a method's index differs between the backend and
collection layers; and `CollectionService (2)` is a collection-only service the
FFI never dispatches, so its methods are addressed through
`BackendCollectionService (3)` instead.

## Adding a method

1. Change a `.proto` under `anki-upstream/proto/anki/` — rare, and only when
   upstream moves or a method is not yet surfaced.
2. `./scripts/generate-protos.sh` → types land in `Sources/AnkiProto/`.
3. Add a `Request<R>` factory in `Sources/AnkiProtoBridge/Requests/`, binding
   service ID, method ID and request/response types. Register the pair in
   `ServiceCatalog.swift` if it is new.
4. Expose it through an `AnkiServices` facade, and a `@DependencyClient` in
   `AnkiClients` if it is user-facing.
5. Rebuild the XCFramework only when `anki-bridge-rs/` or `anki-upstream/`
   changed. Protobuf and Swift changes alone need no rebuild.

```swift
public static func getDeckTree(now: Int64 = 0) -> Request<Anki_Decks_DeckTreeNode> {
    .init(
        service: .decks,
        method: DecksMethod.getDeckTree,
        payload: Anki_Decks_DeckTreeRequest.with { $0.now = now }
    )
}
```

## App-only RPCs skip steps 1–3

Service 200 (`ServiceID.aux`) is ours, not upstream's. `anki-bridge-rs/src/aux.rs`
dispatches it before a call reaches `Backend::run_service_method`, for work
upstream has no RPC for — today `findDuplicates` (method 0), which groups notes
by shared first field. The wire is JSON via `serde`, so there is no `.proto`.

To add one: a case in `aux::dispatch`, a constant in `ServiceCatalog.AuxMethod`,
and a `Request<R>` in `AuxRequests.swift` with its own `Decodable` mirror (see
`FindDuplicatesResponse`). Then step 4 above, plus an XCFramework rebuild. Every
aux method needs a live probe in `RequestProbeCoverageTests`: none of protobuf's
compatibility guarantees cover hand-rolled JSON.

## The FFI surface

`anki_open_backend`, `anki_run_method`, `anki_free_response`,
`anki_close_backend`, declared in `anki-bridge-rs/src/lib.rs`. Route new work
through `anki_run_method` with a new service/method pair; a fifth symbol is a
last resort.

The crate is a `cdylib` shipped as a **dynamic** framework. A static archive's
symbols are invisible to XCPreviewAgent's JIT, which killed every package-target
preview that reached `AnkiBackend` with
`JITError: Symbols not found: [_anki_open_backend, …]`. Keep `crate-type` as is.

## Dependency client shape

```swift
@DependencyClient
public struct CardClient: Sendable {
    public var fetchDue: @Sendable (_ deckId: Int64) throws -> [CardRecord]
    public var answer: @Sendable (_ cardId: Int64, _ rating: Rating, _ timeSpent: Int32) throws -> Void
}

extension CardClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            fetchDue: { deckId in /* ... */ },
            answer: { cardId, rating, timeSpent in /* ... */ }
        )
    }()
}
```
