//
//  DesignConformanceTests.swift
//  AmgiAppTests
//
//  Created by Vladimir Gusev on 16.07.2026.
//

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
        "ReviewFeature/CardWebViewCoordinator.swift":
            "Parses Anki template CSS into UIColor. Card content, not app chrome.",
        "ReviewFeature/CardWebView.swift":
            "Same — template CSS parsing.",
        "ReviewFeature/CardHTMLBuilder.swift":
            "Same — template CSS parsing. Split out of CardWebView.swift.",
        "AppShared/ReaderThemeColor.swift":
            "Reader's own sepia/dark/light reading themes, deliberately independent of the app palette.",
        "ReaderFeature/Reader/ReaderTypographyPreferences.swift":
            "Reader content typography — user-controlled, not app chrome.",
        "AppCore/ReaderFontOption.swift":
            "Reader content font list.",
        "ReaderFeature/Reader/EPUBChapterPageController.swift":
            "UIColor.color(fromHex:) parses the reading theme's hex background for the WKWebView " +
            "hosting the book page — reading surface, not chrome, per the same boundary as " +
            "ReaderThemeColor.swift. No SwiftUI/palette-facing chrome lives in this file.",
        "ReaderFeature/Reader/ChapterReaderView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "StatsCharts/HeatmapChartOptimized.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change " +
            "(R29 is no-layout). The heatmap cell's cornerRadius: 2 (grid squares + legend swatches) " +
            "is not a card and must stay 2, not round to AmgiRadius.control (10).",
        // The four below carry what used to be exempted as a single
        // BrowseFeature/ImageOcclusionWorkspaceView.swift entry, before that file was
        // split up.
        "BrowseFeature/ImageOcclusionWorkspaceView.swift":
            "Selected tool-palette chip labels are Color.white on palette.accent. " +
            "Palette has no on-accent text role, so there is no token to use here; " +
            "drop this entry once one exists.",
        "BrowseFeature/OcclusionCanvasView.swift":
            "ImageOcclusion UIKit canvas: mask/handle fills are drawing state, not app chrome. " +
            "Chrome radii were fixed; canvas fills are the exempt part.",
        "BrowseFeature/OcclusionCanvasUIView.swift":
            "ImageOcclusion UIKit canvas: mask/handle fills are drawing state, not app chrome. " +
            "Chrome radii were fixed; canvas fills are the exempt part.",
        "BrowseFeature/OcclusionCanvasUIView+Drawing.swift":
            "ImageOcclusion UIKit canvas: mask/handle fills are drawing state, not app chrome. " +
            "Chrome radii were fixed; canvas fills are the exempt part.",
        "BrowseFeature/OcclusionCanvasUIView+Geometry.swift":
            "ImageOcclusion UIKit canvas: mask/handle fills are drawing state, not app chrome. " +
            "Chrome radii were fixed; canvas fills are the exempt part.",
        "BrowseFeature/ZoomableOcclusionCanvasView.swift":
            "ImageOcclusion canvas scroll container: the neutral backing colour is set from a " +
            "UIKit init where the SwiftUI palette isn't reachable.",
        "BrowseFeature/ImageOcclusionMaskSummaryCard.swift":
            "Preview thumbnail clip radius matches the canvas it mirrors, not a card radius.",
        "SettingsFeature/AppearanceSettingsView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "SettingsFeature/CodeEditorSettingsView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "TemplatesFeature/TemplateEditorView.swift":
            "Radius literals with no AmgiRadius equivalent; changing them would be a layout change (R29 is no-layout).",
        "Watch/WatchApp.swift": watchExemptReason,
        "WatchFeature/WatchContentView.swift": watchExemptReason,
        "WatchFeature/WatchDeckDetailView.swift": watchExemptReason,
        "WatchFeature/WatchDeckListView.swift": watchExemptReason,
        "WatchFeature/WatchLoginView.swift": watchExemptReason,
        "WatchFeature/WatchReviewView.swift": watchExemptReason,
        "WatchFeature/WatchStatsView.swift": watchExemptReason,
    ]

    /// watchOS target (PR #14): the palette/ThemeManager pipeline is iOS-scoped;
    /// the watch app ships its own compact HIG styling inline.
    /// Palette adoption on watchOS is a design decision, not a conformance sweep.
    private static let watchExemptReason =
        "watchOS target — palette/ThemeManager is iOS-scoped; watch styles inline."
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
        ("raw system font style", #"\.font\(\s*\.(largeTitle|title|title2|title3|headline|subheadline|body|callout|footnote|caption|caption2)\b"#),
        // A literal point size on a `Text` opts it out of Dynamic Type.
        // `amgiFont(size:weight:relativeTo:)` takes the same numbers and
        // scales them. Scoped to `Text(...)` directly followed by the font
        // line: an `Image(systemName:)` glyph inside a fixed tile is *meant*
        // to stay put, and a `@ScaledMetric` variable or user-set reader size
        // isn't a digit literal, so neither matches.
        ("fixed-size Text (use amgiFont(size:))", #"Text\([^\n]*\n\s*\.font\(\s*\.system\(size:\s*\d"#),
        // Motion is a design token like colour and radius. A curve spelled at
        // a call site can't be interrupted, doesn't inherit velocity, and —
        // the reason this is a *test* and not a style note — silently ignores
        // Reduce Motion, which `AmgiMotion` handles for every role at once.
        (
            "raw animation curve (use AmgiMotion)",
            #"(withAnimation|\.animation)\(\s*\.(easeInOut|easeIn|easeOut|linear|default|spring|smooth|snappy|bouncy|interactiveSpring)\b"#
        ),
        // `withAnimation { }` with no argument resolves to SwiftUI's default
        // curve, which is the same problem spelled implicitly.
        ("argument-less withAnimation (use AmgiMotion)", #"withAnimation\s*\{"#),
        // Translucent chrome must route through `amgiMaterial(_:in:)` so it
        // has a Reduce Transparency fallback. A bare material over card or
        // book content is unreadable for the users that setting exists for.
        ("raw material (use amgiMaterial)", #"\.(ultraThin|thin|regular|thick|ultraThick)Material\b"#),
        // Liquid Glass is translucent chrome by another name, so it routes
        // through the same seam for the same reason: `amgiMaterial(_:in:)`
        // owns the Reduce Transparency fallback AND the iOS 26 availability
        // branch. A `.glassEffect(` spelled at a call site has neither — it
        // silently drops back to nothing on iOS 18 and ignores the setting.
        // `GlassEffectContainer` and `glassEffectID` are deliberately NOT
        // banned: they arrange and animate glass, they don't draw the surface.
        ("raw glass effect (use amgiMaterial)", #"\.glassEffect\("#),
    ]

    /// Roots the scanner walks. Paths in `pendingSweep` / `permanentlyExempt`
    /// are relative to whichever root contains the file, so a file that moves
    /// from AmgiApp/Sources/Stats to AmgiFeatures/Sources/StatsCharts changes
    /// key from "Stats/X.swift" to "StatsCharts/X.swift".
    private static let sourceRoots: [URL] = {
        let repo = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // AmgiAppTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // AmgiApp
            .deletingLastPathComponent()   // repo root
        return [
            repo.appendingPathComponent("AmgiApp/Sources"),
            repo.appendingPathComponent("AmgiFeatures/Sources"),
        ]
    }()

    /// Every .swift under the scanned roots, keyed by path relative to
    /// whichever root contains it.
    private static func swiftFiles() throws -> [(relative: String, contents: String)] {
        var out: [(String, String)] = []
        for root in sourceRoots {
            guard let walker = FileManager.default.enumerator(
                at: root, includingPropertiesForKeys: nil
            ) else { continue }

            for case let url as URL in walker where url.pathExtension == "swift" {
                let relative = url.path.replacingOccurrences(of: root.path + "/", with: "")
                out.append((relative, try String(contentsOf: url, encoding: .utf8)))
            }
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
        #expect(files.count > 150, "Expected #filePath-derived sourceRoots to resolve and find many files, found \(files.count). sourceRoots=\(Self.sourceRoots.map(\.path))")
    }
}
