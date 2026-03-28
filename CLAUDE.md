# iOS Anki Client — Project Instructions

## Project Overview

An offline-first iOS Anki flashcard client that syncs with AnkiWeb. Uses the official Anki Rust backend (AGPL-3.0) bridged to Swift via C FFI + protobuf serialization.

## Architecture

```
SwiftUI Views (AnkiApp/)
    ↓ @Dependency(\.xxxClient)
@DependencyClient structs (AnkiClients/)
    ↓ AnkiBackend.invoke(service:method:request:)
AnkiBackend Swift wrapper (AnkiBackend/)
    ↓ C FFI (4 functions)
Rust static library (anki-bridge-rs/ → XCFramework)
    ↓ protobuf RPC
ankitects/anki rslib (anki-upstream/)
```

**Rust owns**: SQLite database, AnkiWeb sync, FSRS scheduling, card template rendering
**Swift owns**: SwiftUI views, @DependencyClient wiring, navigation, charts

## Module Map

| Module | Purpose |
|---|---|
| `AnkiKit` | Pure Swift domain types (Rating, FSRSState, DeckInfo, etc.) |
| `AnkiDatabase` | @Table records, migrations, CollectionJSON types |
| `AnkiProto` | Generated Swift protobuf types from 24 .proto files |
| `AnkiBackend` | Swift wrapper around Rust C FFI (AnkiBackend class) |
| `AnkiClients` | @DependencyClient structs + live implementations |
| `AnkiFSRS` | Pure Swift FSRS engine (kept for local calculations) |
| `AnkiCardRenderer` | TemplateEngine for card HTML rendering |
| `AnkiSync` | KeychainHelper for credential storage |

## Build Commands

```bash
# Build Rust XCFramework (required before Xcode build)
./scripts/build-xcframework.sh

# Regenerate Swift protobuf types
./scripts/generate-protos.sh

# Build SPM package (macOS targets only — AnkiBackend needs iOS)
swift build

# Build iOS app
cd AnkiApp && xcodegen generate && cd ..
xcodebuild build -project AnkiApp/AnkiApp.xcodeproj -scheme AnkiApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max'

# Run tests
swift test
```

## Key Patterns

### Dependency Client (struct-closure DI)
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
            fetchDue: { deckId in /* call Rust backend */ },
            answer: { cardId, rating, timeSpent in /* call Rust backend */ }
        )
    }()
}
```

### Calling the Rust Backend
```swift
// Typed RPC: encode request protobuf → C FFI → decode response protobuf
let response: Anki_Decks_DeckTreeNode = try backend.invoke(
    service: AnkiBackend.Service.decks,
    method: AnkiBackend.DecksMethod.getDeckTree,
    request: Anki_Decks_DeckTreeRequest()
)
```

### Service Index Reference
| Service ID | Name | Key Methods |
|---|---|---|
| 1 | BackendSyncService | 3=SyncLogin, 5=SyncCollection, 6=FullUploadOrDownload |
| 3 | BackendCollectionService | 0=OpenCollection, 1=CloseCollection |
| 2 | CollectionService | 0=CheckDatabase |
| 7 | BackendDecksService | 8=GetDeckTree |
| 13 | BackendSchedulerService | 3=GetQueuedCards, 4=AnswerCard, 7=CountsForDeckToday |
| 25 | BackendNotesService | 5=GetNote |
| 29 | BackendSearchService | 0=SearchCards, 1=SearchNotes |

## Import Rules (Swift 6.2 + InternalImportsByDefault)

- `public import` for any module whose types appear in public API signatures
- `import` (internal) for modules used only within the file
- `@Table` structs need `public import StructuredQueries`
- `@DependencyClient` files need `public import Dependencies`
- SwiftProtobuf methods (serializedData, init(serializedBytes:)) need `import SwiftProtobuf`

## Known Issues & Workarounds

- **DeckTree with counts fails on fresh sync**: Use `now=0` to skip counts, fetch per-deck separately
- **SyncCollection returns FULL_DOWNLOAD for empty local DB**: Must auto-download, not just return "complete"
- **SourceKit false positives**: The IDE shows errors that don't exist in actual builds. Trust `swift build` / `xcodebuild`
- **Apple Compression framework has no zstd**: Rust handles zstd internally, no need for Swift-side compression
- **XCFramework is iOS-only**: `swift build` on macOS can't build AnkiBackend. Use `xcodebuild` for full builds
