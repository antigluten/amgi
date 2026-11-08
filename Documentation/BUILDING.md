# Building and testing

The one place setup lives. [README](../README.md) and
[CONTRIBUTING](../CONTRIBUTING.md) link here rather than repeating it.

## Requirements

| Tool | Version |
|------|---------|
| iOS | 18.0+ |
| watchOS | 11.0+ |
| Xcode | 26.0+ (Swift 6.2) |
| Rust | 1.92+ (via rustup), plus nightly with `rust-src` |
| protoc | 3.0+ |
| protoc-gen-swift | latest |
| Tuist | 4.210.0 (pinned in `mise.toml`) |

## Setup

```bash
git clone --recursive https://github.com/antigluten/amgi.git
cd amgi
```

The `--recursive` matters: `anki-upstream/` is a submodule pinned to the `26.05`
tag, and the Rust build needs it.

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim

# watchOS is a tier-3 Rust target: std is not distributed for it, so the watch
# slice is built from source with -Z build-std on nightly.
rustup toolchain install nightly
rustup component add rust-src --toolchain nightly

# Protobuf compiler and Swift plugin, and the Xcode project generator
brew install protobuf swift-protobuf mise
mise install
```

## Build

```bash
./scripts/build-xcframework.sh          # 1. Rust engine → AnkiRustLib.xcframework
./scripts/generate-protos.sh            # 2. Swift protobuf types → Sources/AnkiProto/
mise exec -- tuist install              # 3. resolve dependencies
mise exec -- tuist generate --path AmgiApp --no-open
open AmgiApp/AmgiApp.xcworkspace         # 4. build and run (⌘R)
```

Step 1 cross-compiles for iOS device, iOS simulator and watchOS simulator, then
packages the three slices. The first run takes several minutes; later runs are
incremental.

### When to re-run which

- **`build-xcframework.sh`** — only after changing `anki-bridge-rs/` or moving
  `anki-upstream/`. Swift and protobuf changes do not need it.
- **`generate-protos.sh`** — after changing a `.proto`.
- **`tuist install`** — after changing `Tuist/Package.swift`, which declares
  remote dependencies. Vendored EPUBKit has its own `Libraries/EPUBKit/Project.swift`.
  `Tuist/Package.resolved` pins the dependency revisions used by this workspace.
  Keep both `xctest-dynamic-overlay` and `swift-issue-reporting` pins when
  refreshing it: older Swift manifests use the former, Swift 6.4 uses the latter.
- **`tuist generate --path AmgiApp --no-open`** — after changing
  any local `Project.swift`, `Tuist/ProjectDescriptionHelpers/`, or source files.
  Generated projects and the workspace are gitignored. Run install and generate on a fresh clone;
  edit the manifests rather than Xcode's generated project.

Use `mise exec --` before Tuist commands if mise is not activated in your shell.
Generate with the same Xcode used for builds (`xcode-select` or `DEVELOPER_DIR`).
Tuist reads deployment floors from the selected SDKs, so host macros
use macOS 12.0 with Xcode 27 while older SDKs retain their supported floors.
Regenerate after switching Xcode versions.
The pinned release also resolves package products by their owning package,
avoiding alias cycles when older and current Swift manifests share product names.

Each first-party module group declares its native library and test targets in
its own `Project.swift`; shared settings live in `Tuist/ProjectDescriptionHelpers/`.
Vendored EPUBKit also has a native project; its upstream SwiftPM files are kept
for provenance and are not used by the Amgi build. Tuist also converts external
packages into native Xcode targets.
The generated `Bundle.module` accessors preserve resource access, and
`-package-name` preserves the former packages' visibility boundaries.

## Tests

`AnkiRustLib.xcframework` ships iOS and watchOS slices. **Tests run through the
generated workspace on an iOS simulator destination:**

```bash
xcodebuild test -workspace AmgiApp/AmgiApp.xcworkspace -scheme AmgiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Two things that will otherwise waste your time:

- Do **not** pass `CODE_SIGNING_ALLOWED=NO`. It makes `KeychainProfileScopingTests`
  fail with `saveFailed(-34018)` (`errSecMissingEntitlement`) — that is the flag,
  not your change.
- Boot the simulator first. Tests report as "not run" until one is booted and
  selected as the active destination.

The manual/tag GitHub workflow installs the pinned Tuist version, enforces
`Tuist/Package.resolved`, builds iOS and watchOS, and runs the test plan before
archiving. Its `build-diagnostics` artifact retains build logs and the test
result bundle, including on failure.

## The watch app builds separately

The iOS scheme does **not** build `AmgiWatchApp`. If you touch `Sources/Watch/`,
`WatchFeature`, or any product the watch links (`ReviewCore`, `StatsCharts`,
`AppCore`), build it explicitly:

```bash
xcodebuild build -workspace AmgiApp/AmgiApp.xcworkspace -scheme AmgiWatchApp \
  -destination 'generic/platform=watchOS Simulator' ARCHS=arm64
```

`ARCHS=arm64` is required — the watch slice is arm64-only, so the default
multi-arch simulator build fails to link x86_64.

## Verifying a module move

Run a **clean** build (`xcodebuild clean build`), not an incremental one.
Incremental builds pass on stale cached modules and will tell you a broken
module graph is fine.

Three things break in tandem on a file move, so fix them in the same commit:

- `DesignConformanceTests` keys its allowlist by path *and* asserts there are no
  stale entries, so a move fails it in both directions. Update `permanentlyExempt`.
- Tests using `@testable import AmgiApp` need a second `@testable import <NewModule>`.
- The library modules enable `MemberImportVisibility`; the app target does not. A
  file that borrowed a transitive `import SwiftUI` from the app target has to
  spell it out once it moves.
