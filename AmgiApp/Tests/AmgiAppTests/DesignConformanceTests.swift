import Testing
import Foundation

/// Guards the design system against the drift that made R23 invisible:
/// screens that never adopt the palette and quietly render system colors.
///
/// `pendingSweep` shrinks to empty as R29 progresses. Entries may be
/// REMOVED, never added. A new violation in a file not listed here fails.
@Suite("Design-language conformance")
struct DesignConformanceTests {

    /// Screens still awaiting the R29 sweep. Delete entries as they land.
    ///
    /// Seeded from a live scanner run against `develop` on 2026-07-16, AFTER
    /// Tasks 1–3 landed (Stats chart-card migration to AmgiCard, Heatmap
    /// container/ramp rewrite) — NOT from the task-4 brief's original list,
    /// which predates those tasks. See task-4-report.md for the full diff:
    /// 5 brief-listed files are now clean (dropped) and 20 files the brief
    /// never mentioned are genuine violations (added, grouped below).
    private static let pendingSweep: Set<String> = []

    /// Deliberately off-system, with the reason. These never drain.
    private static let permanentlyExempt: [String: String] = [
        "Review/CardWebViewCoordinator.swift":
            "Parses Anki template CSS into UIColor. Card content, not app chrome.",
        "Review/CardWebView.swift":
            "Same — template CSS parsing.",
        "Reader/ReaderThemeColor.swift":
            "Reader's own sepia/dark/light reading themes, deliberately independent of the app palette.",
        "Reader/ReaderTypographyPreferences.swift":
            "Reader content typography — user-controlled, not app chrome.",
        "Reader/ReaderFontOption.swift":
            "Reader content font list.",
        "Reader/EPUBChapterPageController.swift":
            "UIColor.color(fromHex:) parses the reading theme's hex background for the WKWebView " +
            "hosting the book page — reading surface, not chrome, per the same boundary as " +
            "ReaderThemeColor.swift. No SwiftUI/palette-facing chrome lives in this file.",
        "Reader/ReaderBookDetailView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Reader/ReaderCoverImage.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Reader/ChapterReaderView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Reader/Library/AllBooksCell.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Sync/SyncSheet.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Theme/AmgiModifiers.swift":
            "Implements the palette.elevation-driven shadow branch itself (AmgiCard's " +
            "ring-vs-shadow switch) — the mechanism other views delegate to, not a " +
            "screen that should delegate to it. Not in the original brief seed.",
        "Stats/HeatmapChartOptimized.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change " +
            "(R29 is no-layout). The heatmap cell's cornerRadius: 2 (grid squares + legend swatches) " +
            "is not a card and must stay 2, not round to AmgiRadius.control (10).",
        "Browse/ImageOcclusionWorkspaceView.swift":
            "ImageOcclusion UIKit canvas: mask/handle fills are drawing state, not app chrome. " +
            "Chrome radii were fixed; canvas fills are the exempt part.",
        "Settings/AppearanceSettingsView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Settings/CodeEditorSettingsView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Review/ReviewView.swift":
            "64pt display numeral; no AmgiFont role at this size.",
        "Decks/DeckTemplateList/TemplateEditorView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Widgets/LargeWidgetView.swift":
            "Separate target (shares only AmgiTheme + AnkiKit). Renders in the system's context and cannot observe ThemeManager at render time, so palette adoption is a design decision, not a conformance sweep. Tracked separately if widget theming is wanted.",
    ]

    private static let bannedPatterns: [(name: String, regex: String)] = [
        ("Color.accentColor", #"Color\.accentColor|\.accentColor\b"#),
        ("system semantic color", #"Color\(\.(system|secondarySystem|tertiarySystem)"#),
        ("raw UIColor literal", #"UIColor\(red:"#),
        ("hardcoded role color", #"\.(foregroundStyle|foregroundColor|tint|fill)\(\s*\.(red|green|orange|blue|purple|cyan|yellow|gray|secondary|primary)\s*\)"#),
        // Catches the fully-qualified `Color.<role>` spelling, which the shorthand
        // `.(foregroundStyle|...)( .role )` pattern above misses entirely — both when
        // it's used outside those 4 modifiers (.background, .opacity, dictionary
        // literals, @State initializers, ternaries) and when it's spelled out instead
        // of shortened. `Color.accentColor` is intentionally excluded — already
        // reported by the "Color.accentColor" pattern above; don't double-count it.
        ("hardcoded role color (Color.<role> form)", #"\bColor\.(red|green|orange|blue|purple|cyan|yellow|gray|grey|secondary|primary|white|black)\b"#),
        // Catches a system hue passed as a labeled argument — `statBadge(..., color: .green)` —
        // which the modifier-chain and `Color.<role>` patterns above both miss because there's
        // no `.foregroundStyle(...)`/`Color.` spelling at all, just a bare `.role` literal handed
        // to a `color:`/`tint:`/`fill:` parameter. Scoped to those three labels (not e.g.
        // `background:`) and to the same known system-hue name list used above, so it can't
        // false-positive on an unrelated non-Color argument that happens to end in "color:".
        ("hardcoded role color (argument-label form)", #"\b(color|tint|fill):\s*\.(red|green|orange|blue|purple|cyan|yellow|gray|grey|pink|mint|teal|indigo|brown|primary|secondary)\b"#),
        ("raw corner radius", #"cornerRadius:\s*\d"#),
        ("shadow", #"\.shadow\("#),
    ]

    private static var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)          // …/AmgiApp/Tests/AmgiAppTests/This.swift
            .deletingLastPathComponent()          // AmgiAppTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // AmgiApp
            .appendingPathComponent("Sources")
    }

    /// Every .swift under AmgiApp/Sources, keyed by path relative to Sources/.
    private static func swiftFiles() throws -> [(relative: String, contents: String)] {
        let root = sourceRoot
        guard let walker = FileManager.default.enumerator(
            at: root, includingPropertiesForKeys: nil
        ) else { return [] }

        var out: [(String, String)] = []
        for case let url as URL in walker where url.pathExtension == "swift" {
            let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
            out.append((relative, try String(contentsOf: url, encoding: .utf8)))
        }
        return out
    }

    @Test("no screen outside the allowlist uses off-system colors, radii, or shadows")
    func noNewViolations() throws {
        let exempt = Self.pendingSweep.union(Self.permanentlyExempt.keys)
        var offenders: [String] = []

        for (path, contents) in try Self.swiftFiles() where !exempt.contains(path) {
            for (name, pattern) in Self.bannedPatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(contents.startIndex..., in: contents)
                guard let match = regex.firstMatch(in: contents, range: range),
                      let matchRange = Range(match.range, in: contents) else { continue }
                let line = contents[contents.startIndex..<matchRange.lowerBound]
                    .filter(\.isNewline).count + 1
                offenders.append("\(path):\(line) — \(name)")
            }
        }

        #expect(
            offenders.isEmpty,
            """
            Off-system design usage found. Use the palette, AmgiFont, and AmgiRadius:
              \(offenders.joined(separator: "\n  "))

            If a usage is genuinely justified, add it to `permanentlyExempt` WITH a reason.
            Do not add to `pendingSweep` — that set only shrinks.
            """
        )
    }

    @Test("allowlisted paths still exist")
    func allowlistHasNoStaleEntries() throws {
        let known = Set(try Self.swiftFiles().map(\.relative))
        let listed = Self.pendingSweep.union(Self.permanentlyExempt.keys)
        let stale = listed.subtracting(known).sorted()
        #expect(stale.isEmpty, "Allowlist names files that no longer exist: \(stale)")
    }

    @Test("scanner actually walks a non-zero number of source files")
    func scannerFindsFiles() throws {
        let files = try Self.swiftFiles()
        #expect(files.count > 100, "Expected #filePath-derived sourceRoot to resolve to AmgiApp/Sources and find many files, found \(files.count). sourceRoot=\(Self.sourceRoot.path)")
    }
}
