# Amgi

Offline-first, Anki-compatible iOS flashcard client with sync-server support,
plus an EPUB reader with offline dictionary lookup. The Anki engine is the
upstream Rust crate (`anki-upstream/`, AGPL-3.0) compiled into an XCFramework
and called from Swift over C FFI + protobuf.

**Rust owns**: the SQLite collection, sync, FSRS scheduling, card template
rendering, search, import/export.
**Swift owns**: SwiftUI, navigation, charts, keychain, the EPUB reader,
dictionary UI, widgets.

## Where things live

Each module group carries its own `AGENTS.md`. Read it before editing anything under
that path — it holds the rules that path enforces.

| Path | What | Read first |
|---|---|---|
| `Sources/` | `AnkiBridge` modules: the engine surface, down to the Rust FFI | `Sources/AGENTS.md` |
| `AmgiFeatures/` | Every screen, plus the sinks they share | `AmgiFeatures/AGENTS.md` |
| `AmgiUI/` | `Theme` (palettes, tokens) and `UI` (shared components) | `AmgiUI/AGENTS.md` |
| `AmgiReader/` | Reader domain types, EPUB parsing, the C++ dictionary | `AmgiReader/AGENTS.md` |
| `AmgiApp/` | Tuist project: app, widget and watch targets | `AmgiApp/AGENTS.md` |
| `Tuist/` | Shared project settings and remote dependencies | `Tuist/ProjectDescriptionHelpers/` and `Tuist/Package.swift` |
| `anki-bridge-rs/` | The Rust crate exposing the C ABI | `Sources/AGENTS.md` |

`Documentation/` carries the human-facing half: `ARCHITECTURE.md` (layers,
package layout), `RUST_BRIDGE.md` (the C seam and its build pipeline),
`DATA_FLOWS.md` (sync, study, browse, stats, widgets), `BUILDING.md`,
`CODE_STYLE.md` and `FEATURES.md`.

## The layer rule

```
feature code → AnkiClients → AnkiServices → AnkiProtoBridge → AnkiBackend → Rust
```

Reach for an `AnkiClients` client first. Where no client wraps the call, an
`AnkiServices` facade is the sanctioned second tier — adding a pass-through
client just to avoid it is churn. Direct `AnkiBackend` use belongs to the
composition roots and to `backendOffload`, the hop off the main actor for a
blocking FFI call.

## Verify with a build

Builds, tests and previews go through MCP — `mcp__XcodeBuildMCP__*` when it is
connected, otherwise `mcp__xcode__*`. The shell runs the three scripts in
`scripts/`, `tuist install` and `tuist generate`, nothing else.

```bash
./scripts/build-xcframework.sh   # after anki-bridge-rs/ or anki-upstream/ changes
./scripts/generate-protos.sh     # after a .proto changes
tuist install                  # after Tuist/Package.swift changes
tuist generate --path AmgiApp --no-open  # after Project.swift or source membership changes
```

Read `agents/build-and-verify.md` when: picking the MCP branch for the first
time this session, a build fails on signing or a run destination, tests report
"not run", the watch or a library target needs its own build, or a preview
fails to render.

## Swift rules everywhere

The library modules run Swift 6.2 with `InternalImportsByDefault`,
`AccessLevelOnImport` and `MemberImportVisibility`; the app target does not, so
a file moving into a library module spells out imports it used to inherit.
`Tuist/ProjectDescriptionHelpers/AmgiModule+SwiftSettings.swift` configures these flags and
preserves each former package's Swift `package` visibility boundary.

- `public import` for a module whose types appear in public API signatures,
  `package import` for package-wide surface, plain `import` otherwise.
- `@DependencyClient` files need `public import Dependencies`; `@Table` structs
  need `public import StructuredQueries`; `serializedData()` and
  `init(serializedBytes:)` need `import SwiftProtobuf`.

## When it looks like the toolchain, not the code

`agents/known-issues.md` — SourceKit phantom errors, the `libcxxshim` warning,
the empty-collection sync path, deck-tree counts on a fresh sync.

## Moving or extracting a module

`agents/module-extraction.md` — what every lift in this repo has cost, and the
five things to budget for before starting one.
