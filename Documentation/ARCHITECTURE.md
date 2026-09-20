# Architecture

How Amgi is structured. Two companion documents go deeper:
[RUST_BRIDGE.md](RUST_BRIDGE.md) for the engine seam, and
[DATA_FLOWS.md](DATA_FLOWS.md) for what a user action turns into.

## High-level overview

```
┌─────────────────────────────────────────────────┐
│              SwiftUI feature modules            │
│     (AmgiFeatures/ — *Feature + bare-noun sinks)│
├─────────────────────────────────────────────────┤
│           @DependencyClient structs             │
│                 (AnkiClients)                   │
├─────────────────────────────────────────────────┤
│              Service facades                    │
│                (AnkiServices)                   │
├─────────────────────────────────────────────────┤
│        Typed protobuf request factories         │
│               (AnkiProtoBridge)                 │
├─────────────────────────────────────────────────┤
│          AnkiBackend (Swift wrapper)            │
│    invoke(service:method:request:) → Response   │
├─────────────────────────────────────────────────┤
│              C FFI (4 functions)                │
│      anki_open_backend / anki_run_method /      │
│      anki_free_response / anki_close_backend    │
├─────────────────────────────────────────────────┤
│       Rust dynamic framework (AnkiRustLib)      │
│           ankitects/anki rslib crate            │
│  SQLite · Sync protocol · FSRS · Templates      │
└─────────────────────────────────────────────────┘
```

**Swift owns**: UI, navigation, dependency wiring, charts, keychain, the EPUB
reader and dictionary lookup.
**Rust owns**: the SQLite database, sync protocol, FSRS scheduling, card
template rendering, search, import/export, statistics.

The layers are strictly ordered. Feature code reaches for an `AnkiClients`
client first; where no client wrapper exists it may use an `AnkiServices` facade
directly. Direct `AnkiBackend` use is reserved for the composition roots and for
`backendOffload`, the hop off the main actor for a blocking FFI call.

## Package layout

Four SPM packages plus one xcodegen-generated Xcode project.

### `AnkiBridge` (root `Package.swift`) — the engine surface

| Module | Purpose |
|---|---|
| **AnkiKit** | Pure Swift domain types: `Rating`, `FSRSState`, `DeckInfo`, `EntityID`, … No dependencies. |
| **AnkiProto** | Generated SwiftProtobuf types from the 25 `.proto` service files. Package-internal — only `AnkiBackend` and `AnkiProtoBridge` may import it. |
| **AnkiBackend** | Swift class wrapping the Rust C FFI. Owns the backend pointer, dispatches `Request<R>`, decodes responses, carries the `RPCObserver` hook. |
| **AnkiProtoBridge** | The only sanctioned protobuf ↔ Swift-mirror boundary. Exposes `Request<R>` factories, `ServiceCatalog`, and typed `*Method` dispatch wrappers. |
| **AnkiServices** | High-level facades: `DecksService`, `SchedulerService`, `SyncService`, `StatsService`, `NotesService`, `NotetypesService`, `CardRenderingService`, `ImportExportService`, `CollectionService`. |
| **AnkiClients** | `@DependencyClient` structs plus their live values. The UI's preferred entry point. |
| **AnkiSync** | `KeychainHelper` for sync credentials, scoped per profile. |
| **AmgiCardWeb** | WebKit-based card renderer host. |
| **AnkiRustLib** | `binaryTarget` pointing at `AnkiRustLib.xcframework`. iOS and watchOS only. |

### `AmgiFeatures` (`./AmgiFeatures`) — the app layer

Screen-level modules carry the `*Feature` suffix; reusable sinks are bare nouns
with no prefix (`AppCore`, `AppShared`, `ReviewCore`, `StatsCharts`).

| Module | Purpose |
|---|---|
| **AppCore** | The engine-free sink: preferences, `AccountStore`, app-group keys, `WidgetSnapshot`, `StreakCalculator`, `CardFlag`. Must never gain an `AnkiClients` dependency — the widget and watch link it. |
| **AppShared** | The engine-touching, iOS-only half of the sink: `CollectionStore`, `ImportHelper`, share sheet, card context menu, widget snapshot writing. |
| **StatsCharts** | Pure chart and heatmap views over `GraphsSnapshot`. Compiled for watchOS in its entirety. |
| **ReviewCore** | The review state machine (`ReviewSession`) and template render overrides. Shared with the watch, so it stays watchOS-clean. |
| **BrowseFeature** | Note browsing, search, authoring, batch tagging, tag management, and the image-occlusion editor. |
| **TemplatesFeature** | Card-template editor, template source editing, preview, and notetype field management. |
| **ReviewFeature** | The review screen: WebKit card host, native renderer, flip chrome, rating bar, render-mode UI. |
| **DecksFeature** | Deck list, deck detail, deck config with the FSRS simulator, profile picker. |
| **ReaderFeature** | The EPUB and Anki-note readers, the offline dictionary lookup UI, and the Study landing screen. The only module that touches `ReaderDictionary`. |
| **StatsFeature** | The statistics dashboard. |
| **SyncFeature** | Sync coordinator, sync sheet, login, onboarding, sync toast. |
| **SettingsFeature** | The Settings root and every screen it pushes to. The app's fan-in point. |
| **IntentsFeature** | The App Intents surface: study a deck, sync, due count, and their entities. |
| **WidgetFeature** | Everything the iOS widget extension renders, plus its AppIntents configuration and timeline provider. |
| **WatchFeature** | Every screen the watchOS app renders. |
| **RootFeature** | The composition root: `RootView`, the tab bar, startup error UI, and dependency bootstrap. |

Direction of dependency is one-way: nothing in `AmgiFeatures` depends on the app
target, and the sinks never depend on a `*Feature`. Shared code is routed down
into a sink rather than across a feature→feature edge. The rules that enforce
this are in [CODE_STYLE.md](CODE_STYLE.md) and in each package's `AGENTS.md`.

### `AmgiUI` (`./AmgiUI`) and `AmgiReader` (`./AmgiReader`)

| Module | Purpose |
|---|---|
| **Theme** | Palette data, theme tokens, resources. Themes are data (a string id plus `PaletteData`), not enum-bound code. |
| **UI** | Shared SwiftUI components built on `Theme`. |
| **Reader** | Pure-Swift reader domain types. No EPUB or C++ dependencies. |
| **ReaderEPUB** | EPUB parsing on top of the vendored `EPUBKit`. |
| **ReaderDictionary** | C++-interop wrapper around `hoshidicts` (Yomitan-compatible offline dictionaries). Isolated so that importing `Reader` stays C++-free. |

### App project (`AmgiApp/`)

Generated by xcodegen from `AmgiApp/project.yml` and not checked in. Three targets:

- **AmgiApp** (iOS) — links the `RootFeature` and `IntentsFeature` products.
  `AmgiAppApp.swift` is 13 lines: `@main`, an `init` that calls
  `AmgiRoot.bootstrap()`, and a `body` that returns `RootView()`.
- **AmgiWidget** (iOS widget extension) — links `WidgetFeature`; only
  `@main AmgiWidgetBundle` lives in the target.
- **AmgiWatchApp** (watchOS) — links `WatchFeature` plus the engine; only
  `@main WatchApp.swift` lives in the target, holding the collection bootstrap.

## Key design decisions

- **Rust backend over pure Swift**: pure Swift sync hit protocol issues (zstd, redirects, error semantics). The Rust backend is battle-tested by millions of users.
- **AGPL-3.0 license**: required by the ankitects/anki dependency.
- **Struct-closure DI**: Point-Free's `@DependencyClient` pattern — no protocols, no mock classes.
- **Protobuf over direct struct bridging**: the Rust backend already uses protobuf internally. Reusing the same serialization avoids a second translation layer.
- **Rust owns the database**: Swift never reads SQLite directly. All data flows through Rust RPC calls for consistency.
- **A thin app target**: all UI lives in SPM feature modules, so it compiles under the packages' stricter settings (`InternalImportsByDefault`, `AccessLevelOnImport`, `MemberImportVisibility`) and previews independently.
- **Themes as data**: a theme is a string id plus `PaletteData`, not an enum case, so user-created themes can land without a refactor.
