<h1 align="center">Amgi</h1>

<p align="center">
  <em>암기 (amgi) — Korean for "memorization"</em>
</p>

<p align="center">
  An open-source, offline-first Anki-compatible iOS flashcard client with sync server support.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white" alt="Swift 6.2">
  <img src="https://img.shields.io/badge/iOS-17%2B-000000?logo=apple&logoColor=white" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Rust-FFI-DEA584?logo=rust&logoColor=white" alt="Rust FFI">
  <img src="https://img.shields.io/badge/License-AGPL--3.0-blue" alt="AGPL-3.0">
</p>

---

Amgi wraps the official [ankitects/anki](https://github.com/ankitects/anki) Rust backend via C FFI, giving you a native SwiftUI experience backed by the same battle-tested engine that powers Anki Desktop and AnkiDroid. Sync your decks with any compatible sync server (including self-hosted), study with FSRS scheduling, and keep your review history in perfect sync across all your devices.

## Features

- **Sync Server Support** -- login, sync, full upload/download, bidirectional review sync with any compatible server
- **FSRS Scheduling** -- powered by the official Rust FSRS engine, not a reimplementation
- **Card Rendering** -- Rust template engine renders cards exactly like desktop clients
- **Deck Browser** -- hierarchical deck tree with recursive `DisclosureGroup` expand/collapse, new/learn/review count badges on every node
- **Study Session** -- answer cards with Again/Hard/Good/Easy; next-interval labels shown above each button
- **Note Browser** -- search notes across all decks, deck filter chips (top-level decks auto-include subdecks), lazy-load results (50 per page)
- **Note Editor** -- edit note fields with accurate field names from the Rust notetype RPC
- **Statistics Dashboard** -- full-year review heatmap (auto-scrolls to today), streak counter, retention rate, forecast chart, card count breakdown
- **Offline-First** -- everything works offline; sync when you have a connection
- **Swift 6.2 Strict Concurrency** -- zero data races, fully actor-isolated, `Sendable` throughout

## Screenshots

<p align="center">
    <img src="assets/decks.png" width="300" alt="Decks Screen" />
    <img src="assets/stats.png" width="300" alt="Stats Screen" />
</p>

## Architecture

```
SwiftUI Views
    |
@DependencyClient structs
    |
AnkiBackend (Swift wrapper)
    |
C FFI (4 functions)
    |
Rust static library (ankitects/anki)
```

Swift owns the UI. Rust owns everything else -- database, sync, FSRS scheduling, card templates, statistics.

For the full architecture walkthrough, see **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Requirements

| Tool | Version |
|------|---------|
| iOS | 17.0+ |
| Xcode | 16.0+ |
| Rust | 1.92+ (via rustup) |
| protoc | 3.0+ |
| protoc-gen-swift | latest |
| xcodegen | latest |

## Getting Started

### 1. Clone with submodules

```bash
git clone --recursive https://github.com/antigluten/anki-ios.git
cd anki-ios
```

### 2. Install dependencies

```bash
# Rust toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios-simulator

# Protobuf compiler and Swift plugin
brew install protobuf swift-protobuf

# Xcode project generator
brew install xcodegen
```

### 3. Build the Rust XCFramework

```bash
./scripts/build-xcframework.sh
```

This cross-compiles the Rust bridge for iOS device and simulator, then packages both into `AnkiRust.xcframework`. The first build takes several minutes; incremental builds are fast.

### 4. Generate Swift protobuf types

```bash
./scripts/generate-protos.sh
```

### 5. Open in Xcode

```bash
cd AnkiApp && xcodegen generate && cd ..
open AnkiApp/AnkiApp.xcodeproj
```

### 6. Build and Run

Select an iOS Simulator or device, then build and run (Cmd+R).

## Tech Stack

- **UI**: SwiftUI with strict concurrency (Swift 6.2, language mode v6)
- **Dependency Injection**: [swift-dependencies](https://github.com/pointfreeco/swift-dependencies) (`@DependencyClient` struct-closure pattern)
- **Backend**: [ankitects/anki](https://github.com/ankitects/anki) Rust crate via C FFI
- **Serialization**: Protocol Buffers (24 .proto service definitions)
- **Database**: SQLite (owned by Rust backend)
- **Build**: SPM for library modules, xcodegen for the app target

## License

This project is licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)** because it incorporates [ankitects/anki](https://github.com/ankitects/anki) (copyright Ankitects Pty Ltd), which is also AGPL-3.0. See [LICENSE](LICENSE) for the full license text.

The AGPL requires that if you distribute this software or run it as a network service, you must make the complete source code available under the same license.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines, code style, and the development setup.

## Acknowledgments

- **[Damien Elmes](https://github.com/dae)** and the [ankitects/anki](https://github.com/ankitects/anki) contributors for the Rust backend that powers this app
- **[AnkiDroid](https://github.com/ankidroid/Anki-Android)** for pioneering the Rust backend bridge pattern on mobile
- **[Point-Free](https://www.pointfree.co/)** for [swift-dependencies](https://github.com/pointfreeco/swift-dependencies)
