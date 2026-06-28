import Testing
import Foundation

/// Architectural guard: `import AnkiProto` is forbidden outside the
/// `AnkiBackend` and `AnkiProtoBridge` modules. Every other file gets
/// added to `allowlist` only as a pre-existing exception that is
/// expected to be removed during cluster migrations. The allowlist
/// must shrink monotonically — never grow.
@Suite struct ImportAuditTests {
    /// Files that currently import AnkiProto and have not yet been
    /// migrated to the AnkiProtoBridge stack. Each cluster spec lists
    /// which of these it removes.
    static let allowlist: Set<String> = []

    /// Directories scanned for `import AnkiProto`. AnkiBackend and
    /// AnkiProtoBridge are deliberately excluded — they are the
    /// sanctioned bridge points.
    static let scanRoots: [String] = [
        "Sources/AnkiServices",
        "Sources/AnkiClients",
        "Sources/AnkiKit",
        "AmgiApp/Sources",
    ]

    @Test func no_unsanctioned_AnkiProto_imports() throws {
        let repoRoot = try Self.repoRoot()
        var offenders: [String] = []

        for root in Self.scanRoots {
            let rootURL = repoRoot.appendingPathComponent(root)
            let files = try Self.swiftFiles(under: rootURL, repoRoot: repoRoot)
            for relativePath in files {
                let absolute = repoRoot.appendingPathComponent(relativePath)
                let contents = try String(contentsOf: absolute, encoding: .utf8)
                let importsProto = contents
                    .split(separator: "\n")
                    .contains { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        return trimmed == "import AnkiProto"
                            || trimmed == "public import AnkiProto"
                            || trimmed == "package import AnkiProto"
                            || trimmed == "@testable import AnkiProto"
                    }
                if importsProto && !Self.allowlist.contains(relativePath) {
                    offenders.append(relativePath)
                }
            }
        }

        #expect(offenders.sorted() == [], """
        These files import AnkiProto but are not on the allowlist. \
        Either remove the import (preferred — route through AnkiProtoBridge) \
        or add the path to ImportAuditTests.allowlist with a comment explaining why.
        """)
    }

    @Test func allowlist_has_no_stale_entries() throws {
        let repoRoot = try Self.repoRoot()
        var stale: [String] = []
        for path in Self.allowlist {
            let absolute = repoRoot.appendingPathComponent(path)
            guard FileManager.default.fileExists(atPath: absolute.path) else {
                stale.append("\(path) (file missing)")
                continue
            }
            let contents = try String(contentsOf: absolute, encoding: .utf8)
            let stillImports = contents
                .split(separator: "\n")
                .contains { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return trimmed.hasSuffix("import AnkiProto")
                }
            if !stillImports {
                stale.append("\(path) (no longer imports AnkiProto — remove from allowlist)")
            }
        }
        #expect(stale == [], "Allowlist contains entries that should be removed.")
    }

    // MARK: - Helpers

    static func repoRoot() throws -> URL {
        // This file lives at <repo>/AmgiApp/Tests/AmgiAppTests/ImportAuditTests.swift.
        // Walk up four directories to reach the repo root.
        let here = URL(fileURLWithPath: #filePath)
        return here
            .deletingLastPathComponent()  // AmgiAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // AmgiApp
            .deletingLastPathComponent()  // <repo>
    }

    static func swiftFiles(under root: URL, repoRoot: URL) throws -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var results: [String] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }
            let relative = url.path.replacingOccurrences(of: repoRoot.path + "/", with: "")
            results.append(relative)
        }
        return results
    }
}
