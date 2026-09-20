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
| xcodegen | latest |

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
brew install protobuf swift-protobuf xcodegen
```

## Build

```bash
./scripts/build-xcframework.sh          # 1. Rust engine → AnkiRustLib.xcframework
./scripts/generate-protos.sh            # 2. Swift protobuf types → Sources/AnkiProto/
cd AmgiApp && xcodegen generate && cd .. # 3. AmgiApp.xcodeproj
open AmgiApp/AmgiApp.xcodeproj           # 4. build and run (⌘R)
```

Step 1 cross-compiles for iOS device, iOS simulator and watchOS simulator, then
packages the three slices. The first run takes several minutes; later runs are
incremental.

### When to re-run which

- **`build-xcframework.sh`** — only after changing `anki-bridge-rs/` or moving
  `anki-upstream/`. Swift and protobuf changes do not need it.
- **`generate-protos.sh`** — after changing a `.proto`.
- **`xcodegen generate`** — after changing `AmgiApp/project.yml`.
  `AmgiApp.xcodeproj` is generated and gitignored, so this is also required on a
  fresh clone. Expect Xcode to rewrite the generated project while it is open;
  `project.yml` is the source.

## Tests

`AnkiRustLib.xcframework` ships iOS and watchOS slices, so `swift test` on the
host cannot link anything that reaches `AnkiBackend`. **Tests run on a simulator
destination:**

```bash
xcodebuild test -project AmgiApp/AmgiApp.xcodeproj -scheme AmgiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Two things that will otherwise waste your time:

- Do **not** pass `CODE_SIGNING_ALLOWED=NO`. It makes `KeychainProfileScopingTests`
  fail with `saveFailed(-34018)` (`errSecMissingEntitlement`) — that is the flag,
  not your change.
- Boot the simulator first. Tests report as "not run" until one is booted and
  selected as the active destination.

## The watch app builds separately

The iOS scheme does **not** build `AmgiWatchApp`. If you touch `Sources/Watch/`,
`WatchFeature`, or any product the watch links (`ReviewCore`, `StatsCharts`,
`AppCore`), build it explicitly:

```bash
xcodebuild build -project AmgiApp/AmgiApp.xcodeproj -scheme AmgiWatchApp \
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
- The SPM packages enable `MemberImportVisibility`; the app target does not. A
  file that borrowed a transitive `import SwiftUI` from the app target has to
  spell it out once it moves.
