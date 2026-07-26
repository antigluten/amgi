public import Dependencies
import AnkiBackend
import AnkiKit
import AnkiProtoBridge
import DependenciesMacros
import Foundation
import Logging

private let logger = Logger(label: "com.amgiapp.reader.cardcount")

@DependencyClient
public struct ReaderCardCountClient: Sendable {
    /// Counts notes carrying the given Anki tag. Returns 0 on any backend
    /// error — UI treats the count as best-effort.
    public var cardsAdded: @Sendable (_ tag: String) throws -> Int
}

extension ReaderCardCountClient: TestDependencyKey {
    public static let testValue = ReaderCardCountClient()
}

extension DependencyValues {
    public var readerCardCountClient: ReaderCardCountClient {
        get { self[ReaderCardCountClient.self] }
        set { self[ReaderCardCountClient.self] = newValue }
    }
}

extension ReaderCardCountClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend
        return Self(
            cardsAdded: { tag in
                let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return 0 }
                do {
                    let ids = try backend.invoke(.searchNoteIds(query: "tag:\(trimmed)"))
                    return ids.count
                } catch {
                    logger.debug("cardsAdded(\(trimmed)) failed: \(error)")
                    return 0
                }
            }
        )
    }()
}
