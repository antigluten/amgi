//
//  RequestProbeCoverageTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import Foundation
import Testing

@Suite("Request factory probe coverage")
struct RequestProbeCoverageTests {

    private static let pendingUnprobed: Set<String> = [
        "fullUploadOrDownload",
        "syncCollection",
        "syncLogin",

        "addImageOcclusionNotetype",
        "addImageOcclusionNote",
        "getImageOcclusionNote",
        "updateImageOcclusionNote",

        "computeFsrsParams",
        "simulateFsrsReview",
        "simulateFsrsWorkload",

        "emptyFilteredDeck",
        "rebuildFilteredDeck",
    ]

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // AnkiProtoBridgeTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root

    private static func swiftFiles(in directory: URL, suffix: String) throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasSuffix(suffix) }
            .map { try String(contentsOf: $0, encoding: .utf8) }
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
    }

    private static func factoryNames() throws -> Set<String> {
        let dir = repoRoot.appendingPathComponent("Sources/AnkiProtoBridge/Requests")
        return Set(try swiftFiles(in: dir, suffix: ".swift")
            .flatMap { matches(#"public static (?:func|var) (\w+)"#, in: $0) })
    }

    private static func probedNames() throws -> Set<String> {
        let dir = repoRoot.appendingPathComponent("Tests/AnkiProtoBridgeTests")
        return Set(try swiftFiles(in: dir, suffix: "LiveTests.swift")
            .flatMap { matches(#"\.(\w+)"#, in: $0) })
    }

    @Test("every Request factory is exercised against a live backend")
    func noUnprobedFactories() throws {
        let unprobed = try Self.factoryNames()
            .subtracting(Self.probedNames())
            .subtracting(Self.pendingUnprobed)
            .sorted()

        #expect(
            unprobed.isEmpty,
            """
            Request factories with no live round-trip:
              \(unprobed.joined(separator: "\n  "))

            Add a `*LiveTests.swift` probe that opens a scratch collection and
            asserts observable state — see CardActionsLiveTests.swift. Do NOT
            add to `pendingUnprobed`; that set only shrinks.
            """
        )
    }

    @Test("pendingUnprobed has no stale entries")
    func pendingHasNoStaleEntries() throws {
        let factories = try Self.factoryNames()
        let probed = try Self.probedNames()

        let gone = Self.pendingUnprobed.subtracting(factories).sorted()
        #expect(gone.isEmpty, "pendingUnprobed names factories that no longer exist: \(gone)")

        let covered = Self.pendingUnprobed.intersection(probed).sorted()
        #expect(covered.isEmpty, "Now probed — delete from pendingUnprobed: \(covered)")
    }

    @Test("the scanner actually resolves both source roots")
    func scannerFindsSources() throws {
        #expect(try Self.factoryNames().count > 50, "factory scan found too few — check repoRoot")
        #expect(try !Self.probedNames().isEmpty, "live-probe scan found nothing — check repoRoot")
    }
}
