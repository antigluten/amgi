# Build and verify

Builds, tests and previews go through MCP. The shell runs the three scripts in
`scripts/` and `xcodegen`; a hand-rolled `xcodebuild` or `swift build` is not
the ground truth for "it builds", with the two exceptions named below.

## Branch A — XcodeBuildMCP connected (`mcp__XcodeBuildMCP__*`), preferred

- `session_show_defaults` once per session, then `build_sim` / `test_sim`.
  Headless, and immune to the run-destination trap below.
- Simulator: `install_app_sim`, `launch_app_sim`, then drive the UI with
  `snapshot_ui` → `tap` / `batch` / `type_text`. Use the accessibility snapshot
  rather than osascript, which lands clicks on the wrong window.
- IDE-only tools go through `xcode_ide_call_tool` (`RenderPreview`,
  `DocumentationSearch`, `GetBuildLog`, `XcodeListNavigatorIssues`). The first
  bridge call after Xcode starts may time out; retry with
  `xcode_ide_list_tools({refresh: true})`.

## Branch B — only the built-in Xcode MCP (`mcp__xcode__*`)

1. If `AmgiApp/project.yml` changed: `cd AmgiApp && xcodegen generate`.
2. `XcodeListWindows` for the `tabIdentifier` (open the project in Xcode first).
3. `BuildProject` — ground truth.
4. On failure `GetBuildLog`; previews via `RenderPreview`; tests via
   `RunSomeTests`, with suite names from `GetTestList`.

**After `xcodegen generate` the run destination resets**, and `BuildProject`
then fails with a signing error about a development team — this repo configures
none and builds for the simulator. Re-select a simulator in the toolbar, or:

```bash
osascript -e 'tell application "Xcode"
  set ws to first workspace document
  repeat with d in run destinations of ws
    if (name of d) is "iPhone 17 Pro" then set active run destination of ws to d
  end repeat
end tell'
```

`RunSomeTests` reports "not run" until a simulator is booted *and* the active
run destination is set. A freshly added test file may still show "No result" —
confirm with `xcodebuild test -only-testing:`.

## Tests

Every suite needs a simulator destination. `AnkiRustLib` ships iOS and watchOS
slices, so the host cannot link the engine and plain `swift test` fails on
anything reaching `AnkiBackend`.

Run the iOS suite **without** `CODE_SIGNING_ALLOWED=NO`. That flag makes
`KeychainProfileScopingTests` fail with `saveFailed(-34018)`
(`errSecMissingEntitlement`) — the flag, not the code.

## The watch builds separately

The iOS scheme does not build `AmgiWatchApp`. Changes to `Sources/Watch/`, to
`ReviewCore` / `StatsCharts` / `AppCore`, or to target wiring need:

```bash
xcodebuild build -project AmgiApp/AmgiApp.xcodeproj -scheme AmgiWatchApp \
  -destination 'generic/platform=watchOS Simulator' ARCHS=arm64
```

`ARCHS=arm64` is required: the watch slice is arm64-only, so a default
multi-arch simulator build fails to link x86_64 with a wall of "found
architecture 'arm64', required architecture 'x86_64'". That is a packaging gap
in `scripts/build-xcframework.sh`, not a regression.

## Compiling one module quickly

```bash
swift build --package-path AmgiFeatures --target <T> -j 6
```

Useful for a fast type-check of a single feature module. Anything user-facing
still goes through `build_sim` / `BuildProject`.

## Clean, not incremental, for a module move

Verify a module move with `xcodebuild clean build`. An incremental build passes
on stale cached modules and has produced a wrong conclusion about Cxx settings
at least once; the clean build caught it.

## Previews

Package-target previews render against the live collection: `AnkiRustLib` ships
as a dynamic framework, so XCPreviewAgent's JIT resolves the `anki_*` symbols.
A preview failing with `JITError: Symbols not found` means something switched
the crate back to a static archive.

No WidgetKit preview API works from a package target — a widget preview needs an
extension process to host it, and XCPreviewAgent is an app. Both `#Preview(as:)`
and `previewContext(WidgetPreviewContext(family:))` fail the same way, on
`WidgetPreviewContext` rather than on the macro.
