# Contributing to Amgi

Thank you for your interest in contributing. This guide covers how to report issues, suggest features, and submit code changes.

## Reporting Bugs

Open a [GitHub Issue](https://github.com/antigluten/anki-ios/issues/new) with:

- Steps to reproduce
- Expected behavior vs. actual behavior
- iOS version and device/simulator
- Crash logs or screenshots if applicable

## Suggesting Features

Open a [GitHub Issue](https://github.com/antigluten/anki-ios/issues/new) with the `enhancement` label. Describe the use case and why it would benefit Anki users.

## Development Setup

### Prerequisites

- Xcode 16.0+
- Rust stable toolchain (`rustup`)
- `protoc` and `protoc-gen-swift` (`brew install protobuf swift-protobuf`)
- `xcodegen` (`brew install xcodegen`)

### Build

```bash
git clone --recursive https://github.com/antigluten/anki-ios.git
cd anki-ios

# Rust targets for iOS
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios-simulator

# Build Rust XCFramework
./scripts/build-xcframework.sh

# Generate Swift protobuf types
./scripts/generate-protos.sh

# Generate Xcode project and open
cd AnkiApp && xcodegen generate && cd ..
open AnkiApp/AnkiApp.xcodeproj
```

### Running Tests

```bash
# SPM library tests (macOS — does not include AnkiBackend)
swift test

# Full app tests (requires iOS Simulator)
xcodebuild test -project AnkiApp/AnkiApp.xcodeproj -scheme AnkiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'
```

## Code Style

- **Swift 6.2** with strict concurrency (language mode v6)
- **Struct-closure dependency injection** using `@DependencyClient` -- never protocols
- **Value types** everywhere above the database layer
- **`public import`** for modules whose types appear in public API signatures (`InternalImportsByDefault` is enabled)
- **`@Observable @MainActor`** for view-bound mutable state
- Follow Apple's [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

## Branch Strategy

- Feature branches off `main`
- Pull requests required for all changes
- PRs should target `main`

## Commit Messages

Use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add deck statistics view
fix: correct sync error handling for empty collections
refactor: extract card rendering into separate client
docs: update architecture diagram
test: add unit tests for FSRS scheduling
```

## Working with the Rust Bridge

Changes to the Rust FFI layer require both Rust and Swift modifications:

1. **Rust side** (`anki-bridge-rs/`): Modify `src/lib.rs` or `Cargo.toml`
2. **Rebuild XCFramework**: `./scripts/build-xcframework.sh`
3. **Swift side**: Update `AnkiBackend` wrapper or add new service/method constants
4. **Protobuf changes**: If proto files change, regenerate with `./scripts/generate-protos.sh`

The Rust backend is pinned to `anki-upstream/` (tag 25.09.2). Do not update the submodule without coordinating.

## Pull Request Guidelines

- Keep PRs focused -- one feature or fix per PR
- Include a description of what changed and why
- Add tests for new functionality where possible
- Make sure `swift test` passes before submitting
- Screenshots for UI changes

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Questions?

Open a [Discussion](https://github.com/antigluten/anki-ios/discussions) or file an issue. We are happy to help.
