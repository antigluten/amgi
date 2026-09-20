//
//  ChapterReaderView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 05.05.2026.
//

import Reader
import Theme
import AppCore
import AppShared
import Sharing
import SwiftUI
import WebKit


/// Renders a chapter's HTML content in a WKWebView and tracks vertical
/// scroll progress as a 0..1 fraction of the document. The current
/// progress is captured into a binding on every scroll-end and persisted
/// when the view dismisses.
///
/// First-pass scope: read-only. No tap-to-lookup, no font/theme controls,
/// no pagination. Those layer on later via the ReaderPreferences keys
/// already declared in the Settings module.
struct ChapterReaderView: View {
    let book: ReaderBook
    let chapter: ReaderChapter
    let progress: ReaderProgressCoordinator

    @State private var scrollProgress: Double = 0
    @State private var didRestoreInitialProgress = false
    @State private var initialRestoreProgress: Double?
    @State private var lookupQuery: String?

    @Shared(.appStorage(ReaderPreferences.Keys.fontSize))
    private var fontSize: Double = 17
    @Shared(.appStorage(ReaderPreferences.Keys.lineHeight))
    private var lineHeight: Double = 1.5
    @Shared(.appStorage(ReaderPreferences.Keys.horizontalPadding))
    private var horizontalPadding: Double = 18
    @Shared(.appStorage(ReaderPreferences.Keys.verticalPadding))
    private var verticalPadding: Double = 16
    @Shared(.appStorage(ReaderPreferences.Keys.justifyText))
    private var justifyText: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.themeMode))
    private var themeModeRaw: String = "system"
    @Shared(.appStorage(ReaderPreferences.Keys.selectedFont))
    private var selectedFontRaw: String = ReaderFontOption.defaultValue

    @Shared(.appStorage(ReaderPreferences.Keys.customTextColor))
    private var customTextColorHex: String = "#1F2A26"

    @Shared(.appStorage(ReaderPreferences.Keys.customBackgroundColor))
    private var customBackgroundColorHex: String = "#FAF7F2"
    @Shared(.appStorage(ReaderPreferences.Keys.showTitle))
    private var showTitle: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.showPercentage))
    private var showPercentage: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.tapLookup))
    private var tapLookup: Bool = true

    @Shared(.appStorage(ReaderPreferences.Keys.characterSpacing))
    private var characterSpacing: Double = 0
    @Shared(.appStorage(ReaderPreferences.Keys.avoidPageBreak))
    private var avoidPageBreak: Bool = true
    @Shared(.appStorage(ReaderPreferences.Keys.hideFurigana))
    private var hideFurigana: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.customHintColor))
    private var customHintColorHex: String = "#777777"

    @Shared(.appStorage(ReaderPreferences.Keys.showProgressTop))
    private var showProgressTop: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.verticalLayout))
    private var verticalLayout: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.popupDebugInfoEnabled))
    private var debugInfoEnabled: Bool = false

    @State private var pendingNoteText: String?
    @State private var lastTapPhrase: String?

    /// The wrapped chapter HTML, rebuilt only when the chapter or a
    /// typography preference changes.
    ///
    /// `scrollViewDidScroll` writes `scrollProgress`, and a `@State` write
    /// invalidates unconditionally — so `body` re-runs at scroll-event rate.
    /// Building this in `body` meant interpolating the whole chapter into a
    /// template string (and running `prefersLatinWordLayout`'s two
    /// whole-document regexes) on every scrolled frame, then having
    /// `updateUIView` compare the result against the last one with a
    /// full-string `!=`.
    @State private var renderedHTML: String = ""

    @Environment(\.palette) private var palette

    /// Every input `wrappedHTML` reads. Keys the rebuild task, so a
    /// preference change re-renders and a scroll does not.
    private var renderInputs: ChapterRenderInputs {
        ChapterRenderInputs(
            chapterID: chapter.id,
            fontSize: fontSize,
            lineHeight: lineHeight,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            justifyText: justifyText,
            themeModeRaw: themeModeRaw,
            selectedFontRaw: selectedFontRaw,
            customTextColorHex: customTextColorHex,
            customBackgroundColorHex: customBackgroundColorHex,
            characterSpacing: characterSpacing,
            avoidPageBreak: avoidPageBreak,
            hideFurigana: hideFurigana,
            customHintColorHex: customHintColorHex,
            verticalLayout: verticalLayout,
            language: book.language
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            ChapterWebView(
                html: renderedHTML,
                initialProgress: didRestoreInitialProgress ? nil : initialRestoreProgress,
                progress: $scrollProgress,
                onTapLookup: tapLookup
                    ? { phrase in
                        lastTapPhrase = phrase
                        lookupQuery = phrase
                    }
                    : nil,
                onSelectionForNote: { selected in pendingNoteText = selected }
            )
            if showProgressTop {
                ProgressView(value: scrollProgress)
                    .progressViewStyle(.linear)
                    .tint(palette.accent)
                    .frame(height: 2)
                    .scaleEffect(x: 1, y: 0.6, anchor: .top)
                    .ignoresSafeArea(edges: .horizontal)
            }
            if showPercentage {
                Text("\(Int(scrollProgress * 100))%")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
                    .allowsHitTesting(false)
                    .accessibilityLabel("Reading progress")
            }
            if debugInfoEnabled {
                debugOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .allowsHitTesting(false)
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle(showTitle ? chapter.title : "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    requestSelectionForNote()
                } label: {
                    Image(systemName: "plus.circle")
                }
                .accessibilityLabel("Make note from selection")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    lookupQuery = ""
                } label: {
                    Image(systemName: "character.book.closed")
                }
                .accessibilityLabel("Look up word")
            }
        }
        .sheet(item: Binding(
            get: { lookupQuery.map(LookupQuery.init) },
            set: { lookupQuery = $0?.text }
        )) { wrapped in
            LookupPopupView(initialQuery: wrapped.text, languageHint: book.language) {
                lookupQuery = nil
            }
        }
        .sheet(item: Binding(
            get: { pendingNoteText.map(LookupQuery.init) },
            set: { pendingNoteText = $0?.text }
        )) { wrapped in
            // Reuse the lookup popup with the selection prefilled — the
            // popup's "+" already drives note creation through the user's
            // saved note template, so we don't need a parallel codepath.
            LookupPopupView(initialQuery: wrapped.text, languageHint: book.language) {
                pendingNoteText = nil
            }
        }
        .onAppear {
            didRestoreInitialProgress = false
        }
        .task(id: renderInputs) {
            let inputs = renderInputs
            let content = chapter.content
            renderedHTML = await Task.detached {
                ChapterReaderView.wrappedHTML(content, inputs: inputs)
            }.value
        }
        .task(id: chapter.id) {
            guard let saved = await progress.resolved(bookID: book.id),
                  saved.chapterID == chapter.id else { return }
            initialRestoreProgress = saved.progress
        }
        .onDisappear {
            // Persist whatever the user reached. Save unconditionally —
            // even 0% writes are cheap and keep the chapterID stable so
            // the bookshelf "Resume" hint stays accurate. The coordinator
            // also fires-and-forgets a sync write to the Anki collection.
            progress.save(bookID: book.id, chapterID: chapter.id, progress: scrollProgress)
        }
    }

    /// Bottom-left HUD shown only when `popupDebugInfoEnabled` is on.
    /// Useful when triaging tap-lookup misfires or font/layout issues
    /// without spinning up a debug build. Hit-testing is disabled at the
    /// call site so the overlay never swallows reader taps.
    private var debugOverlay: some View {
        let font = ReaderFontOption.resolved(selectedFontRaw)
        let latin = Self.prefersLatinWordLayout(chapter.content, language: book.language)
        let layout = verticalLayout ? "vertical" : (latin ? "latin" : "cjk")
        let phrase = (lastTapPhrase ?? "—").prefix(40)
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(Int(scrollProgress * 100))% · font: \(font.title)")
            Text("layout: \(layout) · lang: \(book.language ?? "?")")
            Text("last tap: \(phrase)")
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(6)
        .background(palette.textPrimary.opacity(0.55), in: RoundedRectangle(cornerRadius: 4))
        .foregroundStyle(.white)
    }
}

extension ChapterReaderView {
    /// Toolbar "+" handler: ask the WebView for the user's current
    /// selection. The WebView responds via the `onSelectionForNote`
    /// callback, which seeds `pendingNoteText` and triggers the sheet.
    func requestSelectionForNote() {
        NotificationCenter.default.post(
            name: .amgiReaderRequestSelection,
            object: nil
        )
    }

    /// Decides whether `book.language` (or, as a fallback, the chapter
    /// content) is Latin-script-dominant. Drives `overflow-wrap` and
    /// `hyphens` rules — Latin text wraps on word boundaries and hyphenates,
    /// CJK wraps anywhere.
    nonisolated static func prefersLatinWordLayout(_ content: String, language: String?) -> Bool {
        if let hint = language?.lowercased() {
            if hint.hasPrefix("en") || hint.hasPrefix("de") || hint.hasPrefix("fr") ||
               hint.hasPrefix("es") || hint.hasPrefix("it") || hint.hasPrefix("pt") ||
               hint.hasPrefix("ru") || hint == "eng" {
                return true
            }
            if hint.hasPrefix("ja") || hint.hasPrefix("ko") || hint.hasPrefix("zh") ||
               hint == "jpn" || hint == "kor" || hint == "chi" {
                return false
            }
        }
        let plain = content
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&[A-Za-z0-9#]+;", with: " ", options: .regularExpression)
        let latin = plain.unicodeScalars.lazy.filter {
            CharacterSet.letters.contains($0) && $0.value < 128
        }.count
        let cjk = plain.unicodeScalars.lazy.filter {
            (0x3040...0x30FF).contains(Int($0.value)) ||  // Japanese kana
            (0x3400...0x9FFF).contains(Int($0.value)) ||  // CJK ideographs
            (0xAC00...0xD7AF).contains(Int($0.value))     // Hangul
        }.count
        return latin >= 40 && latin > cjk * 2
    }

    /// Wrap the raw note HTML in a tiny shell that gives us a readable
    /// default style and a known body width. Without a viewport meta
    /// tag, WKWebView can pick wildly different scales depending on the
    /// content and progress math gets noisy.
    ///
    /// CSS pulls in user prefs: font size, line height, padding, justify,
    /// theme. Theme `system` defers to the OS via prefers-color-scheme;
    /// fixed modes hardcode foreground/background. Sepia matches Anki
    /// desktop's reader-tone (#f4ecd8 / #5b4636).
    /// Pure and `static` so the caller can run it off the main actor. The
    /// body is a whole-chapter string interpolation plus two full-document
    /// regex passes; it used to run on the main thread on chapter open and
    /// on every typography-preference change.
    nonisolated static func wrappedHTML(_ content: String, inputs: ChapterRenderInputs) -> String {
        let mode = ReaderThemeMode(rawValue: inputs.themeModeRaw) ?? .system
        let theme = themeCSS(for: mode, customTextColorHex: inputs.customTextColorHex, customBackgroundColorHex: inputs.customBackgroundColorHex)
        let fontFamily = ReaderFontOption.resolved(inputs.selectedFontRaw).cssFontFamily
        let letterSpacingEm = String(format: "%.3f", inputs.characterSpacing / 100)
        let pageBreakRule = inputs.avoidPageBreak
            ? "p { break-inside: avoid; -webkit-column-break-inside: avoid; }"
            : ""
        let hintColor = ReaderThemeColor.cssHex(inputs.customHintColorHex, default: "#777777")
        let rubyRule = inputs.hideFurigana
            ? "ruby rt { display: none; }"
            : "ruby rt { color: \(hintColor); font-size: 0.55em; }"

        // Latin-dominant text wants word-boundary wrapping + hyphenation;
        // CJK wants `overflow-wrap: anywhere`. Vertical mode ignores
        // alignment (`text-align: start` is the only sensible value).
        let latinLayout = prefersLatinWordLayout(content, language: inputs.language)
        let wrappingRule = latinLayout
            ? "overflow-wrap: break-word; word-break: normal;"
            : "overflow-wrap: anywhere;"
        let hyphenRule = latinLayout ? "hyphens: auto; -webkit-hyphens: auto;" : ""
        let alignment = inputs.verticalLayout
            ? "start"
            : (inputs.justifyText && !latinLayout ? "justify" : (inputs.justifyText ? "justify" : "left"))
        let writingMode = inputs.verticalLayout ? "vertical-rl" : "horizontal-tb"
        let bodyWidthRule = inputs.verticalLayout
            ? "width: max-content; min-width: 100%;"
            : "max-width: 100%;"

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
        <style>
        :root { color-scheme: light dark; }
        html, body {
          margin: 0;
          -webkit-text-size-adjust: 100%;
          text-size-adjust: 100%;
          \(wrappingRule)
        }
        body {
          font-family: \(fontFamily);
          font-size: \(Int(inputs.fontSize))px;
          line-height: \(String(format: "%.2f", inputs.lineHeight));
          letter-spacing: \(letterSpacingEm)em;
          padding: \(Int(inputs.verticalPadding))px \(Int(inputs.horizontalPadding))px \(Int(inputs.verticalPadding) + 48)px \(Int(inputs.horizontalPadding))px;
          text-align: \(alignment);
          writing-mode: \(writingMode);
          text-orientation: mixed;
          \(bodyWidthRule)
          \(hyphenRule)
          \(theme)
        }
        p { margin: 0 0 1em 0; }
        \(pageBreakRule)
        \(rubyRule)
        ::highlight(amgi-reader-selection) {
          background-color: rgba(160, 160, 160, 0.4);
          color: inherit;
        }
        img { max-width: 100%; height: auto; }
        </style>
        </head>
        <body>\(content)</body>
        </html>
        """
    }

    /// CSS palette per theme mode. `system` defers to the OS via the
    /// `-apple-system-*` semantic colors; `eyeCare` is a low-contrast
    /// dark-on-cream palette tuned for long sessions; `sepia` matches
    /// Anki desktop; `custom` stays system until the user wires up the
    /// custom-color preference UI in a follow-up chunk.
    nonisolated static func themeCSS(
        for mode: ReaderThemeMode,
        customTextColorHex: String,
        customBackgroundColorHex: String
    ) -> String {
        switch mode {
        case .system:
            return "color: -apple-system-label; background: -apple-system-systemBackground;"
        case .custom:
            let text = ReaderThemeColor.cssHex(customTextColorHex, default: "#1F2A26")
            let bg = ReaderThemeColor.cssHex(customBackgroundColorHex, default: "#FAF7F2")
            return "color: \(text); background: \(bg);"
        case .eyeCare:
            return "color: #1f2a26; background: #e8f0e3;"
        case .sepia:
            return "color: #5b4636; background: #f4ecd8;"
        }
    }
}

extension Notification.Name {
    /// Toolbar → WebView ping that asks for the user's current text
    /// selection. The coordinator answers via `onSelectionForNote`.
    static let amgiReaderRequestSelection = Notification.Name("amgiReaderRequestSelection")
}

/// The full input set `ChapterReaderView.wrappedHTML` reads, so the rebuild
/// can be keyed on it. Deliberately excludes `scrollProgress` and the chapter
/// body itself — the chapter is identified by `chapterID`, and progress
/// doesn't affect the rendered HTML.
/// Internal rather than private: `ChapterWebView` moved to its own file and
/// `wrappedHTML` takes this as a parameter, and `private` is file-scoped.
struct ChapterRenderInputs: Equatable, Sendable {
    let chapterID: Int64
    let fontSize: Double
    let lineHeight: Double
    let horizontalPadding: Double
    let verticalPadding: Double
    let justifyText: Bool
    let themeModeRaw: String
    let selectedFontRaw: String
    let customTextColorHex: String
    let customBackgroundColorHex: String
    let characterSpacing: Double
    let avoidPageBreak: Bool
    let hideFurigana: Bool
    let customHintColorHex: String
    let verticalLayout: Bool
    let language: String?
}

/// Wrapper so an empty-string query is still presentable via .sheet(item:);
/// `.sheet(item:)` requires `Identifiable` and treats nil as "dismissed".
private struct LookupQuery: Identifiable {
    let id = UUID()
    let text: String
}
