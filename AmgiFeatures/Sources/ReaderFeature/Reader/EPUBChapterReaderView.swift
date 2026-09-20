//
//  EPUBChapterReaderView.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 16.05.2026.
//

import Reader
import Theme
import UI
import AppCore
import AppShared
import Sharing
import SwiftUI

/// Top-level screen for EPUB chapters. Hosts a `UIPageViewController`
/// (`.scroll`, `.horizontal`) via `EPUBPageViewControllerHost`; each
/// chapter is one `WKWebView` whose internal scroll view drives
/// intra-chapter paging. Cross-chapter transitions ride the outer
/// page controller's gesture — one continuous swipe.
///
/// Chrome (top bar + bottom progress strip) is hidden on a tap to an
/// empty area, mirroring Apple Books. Edge-tap zones (left/right 15%)
/// page forward/back without a swipe (`EPUBPageViewControllerHost`
/// routes those internally).
struct EPUBChapterReaderView: View {
    let book: ReaderBook
    /// Index into `book.chapters` of the chapter currently displayed.
    @State var chapterIndex: Int
    let progressCoordinator: ReaderProgressCoordinator

    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = EPUBChapterReaderModel()

    @State private var pageIndex: Int = 0
    @State private var pageCount: Int = 1
    @State private var progressFraction: Double = 0
    @State private var pendingRestoreFraction: Double?
    @State private var lookupRequest: LookupRequest?
    @State private var lookupHighlight = LookupHighlight()
    @State private var didRequestInitialRestore = false
    @State private var chromeVisible: Bool = true
    @State private var endOfBookToastVisible: Bool = false
    @State private var didShowEndOfBookToast: Bool = false
    @State private var endOfBookToastDismiss: Task<Void, Never>?
    /// Coalesces progress writes. Every page turn used to encode into
    /// UserDefaults and fire a detached write into the Anki collection;
    /// swiping through a chapter issued one of each per page.
    @State private var progressSaveDebounce: Task<Void, Never>?

    @Shared(.appStorage(ReaderPreferences.Keys.verticalLayout))
    private var verticalLayout: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.horizontalPadding))
    private var horizontalPadding: Double = 22
    @Shared(.appStorage(ReaderPreferences.Keys.dictionaryScanLength))
    private var dictionaryScanLength: Int = 16

    // Typography sheet preferences. These supersede the legacy per-book
    // colour pickers — once the user picks a theme it drives fg/bg
    // directly. Font family / size / line-height / page-margin / justify
    // come from the Apple Books-style sheet.
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.fontFamily))
    private var typoFontFamilyRaw: String = ReaderTypographyPreferences.FontFamily.system.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.fontSize))
    private var typoFontSize: Int = 17
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.lineHeight))
    private var typoLineHeight: Double = 1.55
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.pageMargin))
    private var typoPageMarginRaw: String = ReaderTypographyPreferences.PageMargin.defaultMargin.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.theme))
    private var typoThemeRaw: String = ReaderTypographyPreferences.Theme.default.rawValue
    @Shared(.appStorage(ReaderTypographyPreferences.Keys.justify))
    private var typoJustify: Bool = true

    @State private var typographySheetVisible: Bool = false

    private var currentChapter: ReaderChapter? {
        guard chapterIndex >= 0, chapterIndex < book.chapters.count else { return nil }
        return book.chapters[chapterIndex]
    }

    private var typoTheme: ReaderTypographyPreferences.Theme {
        ReaderTypographyPreferences.Theme(rawValue: typoThemeRaw) ?? .default
    }

    private var typoFontFamily: ReaderTypographyPreferences.FontFamily {
        ReaderTypographyPreferences.FontFamily(rawValue: typoFontFamilyRaw) ?? .system
    }

    private var typoPageMargin: ReaderTypographyPreferences.PageMargin {
        ReaderTypographyPreferences.PageMargin(rawValue: typoPageMarginRaw) ?? .defaultMargin
    }

    private var styleTokens: EPUBReaderStyleTokens {
        let theme = typoTheme
        return EPUBReaderStyleTokens(
            foreground: theme.foregroundHex,
            background: theme.backgroundHex,
            fontSizePx: typoFontSize,
            lineHeight: typoLineHeight,
            paddingPx: Int(horizontalPadding),
            verticalMode: verticalLayout,
            fontFamilyCSS: typoFontFamily.cssStack,
            pageMarginPx: typoPageMargin.pixels,
            textAlign: typoJustify ? "justify" : "left",
            tokenUnderlineCSS: theme.tokenUnderlineHex,
            scanLength: dictionaryScanLength
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor.ignoresSafeArea()
            pagerLayer
            endOfBookToast
        }
        .overlay(alignment: .topTrailing) { closeCapsule }
        .overlay(alignment: .top) { pagesLeftCapsule }
        .overlay(alignment: .bottom) { bottomChromeBar }
        .navigationBarBackButtonHidden(true)
        .toolbarVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(.hidden, for: .tabBar)
        .task { await model.preloadChapterContents(for: book) }
        .task(id: chapterIndex) { await prepareRestoreIfNeeded() }
        .sheet(isPresented: $typographySheetVisible) {
            ReaderTypographySettingsView()
        }
        .sheet(item: $lookupRequest, onDismiss: { lookupHighlight.clear() }) { request in
            LookupPopupView(
                initialQuery: request.token,
                languageHint: book.language,
                extraTags: sourceTags(),
                sentence: request.sentence,
                onAddedNote: { handleCardAdded() },
                onMatched: { lookupHighlight.show(matched: $0) },
                onDismiss: { lookupRequest = nil }
            )
            .presentationDetents([.fraction(0.45), .large])
        }
        .sensoryFeedback(trigger: endOfBookToastVisible) { _, visible in
            visible ? .success : nil
        }
        .onDisappear {
            endOfBookToastDismiss?.cancel()
            progressSaveDebounce?.cancel()
            flushProgress()
        }
    }

    // MARK: - Subviews

    private var backgroundColor: Color {
        typoTheme.backgroundColor
    }

    @ViewBuilder
    private var pagerLayer: some View {
        if !model.chapterContents.isEmpty {
            EPUBPageViewControllerHost(
                book: book,
                chapterContents: model.chapterContents,
                chapterIndex: $chapterIndex,
                styleTokens: styleTokens,
                pendingRestoreFraction: pendingRestoreFraction,
                pagingEnabled: lookupRequest == nil,
                lookupHighlight: lookupHighlight,
                onPageInfo: { idx, count in
                    pageIndex = idx
                    pageCount = max(count, 1)
                    pendingRestoreFraction = nil
                },
                onProgress: { fraction, idx in
                    pageIndex = idx
                    progressFraction = fraction
                    saveProgress()
                },
                onWordTap: { token, sentence in
                    lookupRequest = LookupRequest(token: token, sentence: sentence)
                },
                onTapEmpty: { _ in toggleChrome() },
                onReachedEnd: { showEndOfBookToast() }
            )
//            .ignoresSafeArea(.all, edges: [.top, .bottom])
        } else {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var pagesLeftInChapter: Int {
        max(0, pageCount - 1 - pageIndex)
    }

    private var pagesLeftText: String {
        let remaining = pagesLeftInChapter
        if remaining == 0 { return "Last page of chapter" }
        if remaining == 1 { return "1 page left in chapter" }
        return "\(remaining) pages left in chapter"
    }

    /// Both top capsules are removed from the tree when the chrome is hidden
    /// rather than faded to `opacity(0)`. They are translucent material — and
    /// on iOS 26, Liquid Glass — floating over a live WKWebView, so a
    /// zero-opacity layer that stays in the render tree is a backdrop sample
    /// per frame for something the reader can't see. They live in their own
    /// `.overlay`s and share layout with nothing, so removal costs no
    /// alignment; `.transition(.opacity)` keeps the fade `toggleChrome`
    /// animates.
    @ViewBuilder
    private var closeCapsule: some View {
        if chromeVisible {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .amgiMaterial(.regular, in: Circle(), interactive: true)
                    .amgiMaterialElevation(Circle())
            }
            .accessibilityLabel("Close")
            .padding(.top, 8)
            .padding(.trailing, 16)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var pagesLeftCapsule: some View {
        if chromeVisible {
            Text(pagesLeftText)
                .amgiFont(.captionBold)
                .foregroundStyle(palette.textSecondary)
                .contentTransition(.numericText())
                .animation(AmgiMotion.quick, value: pageIndex)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .amgiMaterial(.regular, in: Capsule())
                .amgiMaterialElevation(Capsule())
                .padding(.top, 8)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var pageNumberCapsule: some View {
        Text("\(pageIndex + 1) of \(pageCount)")
            .amgiFont(.caption, .monospacedDigits)
            .foregroundStyle(palette.textSecondary)
            .contentTransition(.numericText())
            .animation(AmgiMotion.quick, value: pageIndex)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .amgiMaterial(.regular, in: Capsule())
            .amgiMaterialElevation(Capsule())
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var menuCapsule: some View {
        Button {
            typographySheetVisible = true
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(width: 44, height: 44)
                .amgiMaterial(.regular, in: Circle(), interactive: true)
                .amgiMaterialElevation(Circle())
        }
        .accessibilityLabel("Reading Style")
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
    }

    /// Bottom chrome bar: page-counter capsule centred, menu hamburger
    /// on the trailing side. HStack guarantees vertical-center alignment
    /// between the two pills regardless of their individual heights.
    /// The two bottom pills are the only pair of glass surfaces in this screen
    /// that share a row, so they get a `GlassEffectContainer`: inside one,
    /// glass samples the backdrop once for the group and neighbours blend as
    /// they approach instead of each drawing its own isolated lens. The top
    /// pair (`closeCapsule`, `pagesLeftCapsule`) sit in separate overlays at
    /// opposite ends and never approach, so they don't need one.
    ///
    /// The `#available` branch swaps view structure, but availability is fixed
    /// for the life of the process — unlike Reduce Transparency it can't flip
    /// under a running view, so no identity is lost.
    @ViewBuilder
    private var bottomChromeBar: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 16) { bottomChromePills }
        } else {
            bottomChromePills
        }
    }

    @ViewBuilder
    private var bottomChromePills: some View {
        HStack(alignment: .center) {
            // Leading spacer keeps the page-counter visually centred even
            // though the trailing menuCapsule is wider than nothing.
            Color.clear.frame(width: 44, height: 44)
            Spacer(minLength: 0)
            pageNumberCapsule
            Spacer(minLength: 0)
            menuCapsule
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var endOfBookToast: some View {
        if endOfBookToastVisible {
            Button(action: dismissEndOfBookToast) {
                Text("End of book")
                    .amgiFont(.captionBold)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .amgiMaterial(.light, in: Capsule())
            }
            .buttonStyle(.pressScale)
            .accessibilityHint("Dismisses this message")
            .padding(.bottom, 80)
            .transition(AmgiMotion.slide(from: .bottom))
        }
    }

}

private extension EPUBChapterReaderView {
    // MARK: - Actions

    func toggleChrome() {
        // `AmgiMotion` already collapses to a cross-fade under Reduce Motion,
        // so this no longer branches on `reduceMotion` itself.
        withAnimation(AmgiMotion.standard) {
            chromeVisible.toggle()
        }
    }

    func showEndOfBookToast() {
        guard !didShowEndOfBookToast else { return }
        didShowEndOfBookToast = true
        withAnimation(AmgiMotion.momentum) {
            endOfBookToastVisible = true
        }
        endOfBookToastDismiss = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            dismissEndOfBookToast()
        }
    }

    /// Also called by a tap on the toast — a timed message the user has
    /// already read shouldn't make them wait out its timer.
    func dismissEndOfBookToast() {
        endOfBookToastDismiss?.cancel()
        endOfBookToastDismiss = nil
        withAnimation(AmgiMotion.standard) {
            endOfBookToastVisible = false
        }
    }

    func prepareRestoreIfNeeded() async {
        guard let chapter = currentChapter else { return }
        if !didRequestInitialRestore,
           let saved = await progressCoordinator.resolved(bookID: book.id),
           saved.chapterID == chapter.id,
           saved.progress > 0.01 {
            pendingRestoreFraction = saved.progress
        }
        didRequestInitialRestore = true
    }

    /// Debounced: `flushProgress` reads `progressFraction` when it fires, so a
    /// run of page turns collapses into one write of the position the reader
    /// actually settled on. `onDisappear` cancels this and flushes directly,
    /// so leaving mid-debounce still persists.
    func saveProgress() {
        progressSaveDebounce?.cancel()
        progressSaveDebounce = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            flushProgress()
        }
    }

    func flushProgress() {
        guard let chapter = currentChapter else { return }
        progressCoordinator.save(
            bookID: book.id,
            chapterID: chapter.id,
            progress: progressFraction
        )
    }

    func sourceTags() -> [String] {
        ["amgi::book::\(book.id)", "amgi::book::\(book.id)::ch::\(chapterIndex)"]
    }

    func handleCardAdded() {
        guard let chapter = currentChapter else { return }
        NotificationCenter.default.post(
            name: .amgiReaderCardAdded,
            object: nil,
            userInfo: [
                "bookID": book.id,
                "chapterID": chapter.id
            ]
        )
    }
}

extension Notification.Name {
    /// Posted by the EPUB reader after `LookupPopupView` confirms a
    /// successful `addNote`. The detail screen listens and refreshes its
    /// per-chapter "N cards added" counts.
    static let amgiReaderCardAdded = Notification.Name("amgiReaderCardAdded")
}

/// One tap-to-lookup request. Identifiable so `.sheet(item:)` treats
/// every tap as a fresh presentation even when the same word is tapped
/// twice in a row.
struct LookupRequest: Identifiable {
    let id = UUID()
    let token: String
    let sentence: String
}
