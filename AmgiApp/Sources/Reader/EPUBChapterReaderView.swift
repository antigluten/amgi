import AmgiReader
import AmgiTheme
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var model = EPUBChapterReaderModel()

    @State private var pageIndex: Int = 0
    @State private var pageCount: Int = 1
    @State private var progressFraction: Double = 0
    @State private var pendingRestoreFraction: Double?
    @State private var lookupRequest: LookupRequest?
    @State private var didRequestInitialRestore = false
    @State private var chromeVisible: Bool = true
    @State private var endOfBookToastVisible: Bool = false
    @State private var didShowEndOfBookToast: Bool = false

    @Shared(.appStorage(ReaderPreferences.Keys.verticalLayout))
    private var verticalLayout: Bool = false
    @Shared(.appStorage(ReaderPreferences.Keys.horizontalPadding))
    private var horizontalPadding: Double = 22

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
            tokenUnderlineCSS: theme.tokenUnderlineHex
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
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .task { await model.preloadChapterContents(for: book) }
        .task(id: chapterIndex) { await prepareRestoreIfNeeded() }
        .sheet(isPresented: $typographySheetVisible) {
            ReaderTypographySettingsView()
        }
        .sheet(item: $lookupRequest) { request in
            LookupPopupView(
                initialQuery: request.token,
                languageHint: book.language,
                extraTags: sourceTags(),
                onAddedNote: { handleCardAdded() },
                onDismiss: { lookupRequest = nil }
            )
            .presentationDetents([.fraction(0.45), .large])
        }
        .onDisappear { flushProgress() }
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

    @ViewBuilder
    private var closeCapsule: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: Circle())
                .amgiChromeShadow(Circle())
        }
        .accessibilityLabel("Close")
        .padding(.top, 8)
        .padding(.trailing, 16)
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
    }

    @ViewBuilder
    private var pagesLeftCapsule: some View {
        Text(pagesLeftText)
            .amgiFont(.captionBold)
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(.regularMaterial, in: Capsule())
            .amgiChromeShadow(Capsule())
            .padding(.top, 8)
            .opacity(chromeVisible ? 1 : 0)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var pageNumberCapsule: some View {
        Text("\(pageIndex + 1) of \(pageCount)")
            .font(.system(size: AmgiFont.caption.size, weight: AmgiFont.caption.weight).monospacedDigit())
            .foregroundStyle(palette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .amgiChromeShadow(Capsule())
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
                .background(.regularMaterial, in: Circle())
                .amgiChromeShadow(Circle())
        }
        .accessibilityLabel("Reading Style")
        .opacity(chromeVisible ? 1 : 0)
        .allowsHitTesting(chromeVisible)
    }

    /// Bottom chrome bar: page-counter capsule centred, menu hamburger
    /// on the trailing side. HStack guarantees vertical-center alignment
    /// between the two pills regardless of their individual heights.
    @ViewBuilder
    private var bottomChromeBar: some View {
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
            Text("End of book")
                .amgiFont(.captionBold)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .padding(.bottom, 80)
                .transition(.opacity)
        }
    }

}

private extension EPUBChapterReaderView {
    // MARK: - Actions

    func toggleChrome() {
        let duration = reduceMotion ? 0.1 : 0.2
        withAnimation(.easeInOut(duration: duration)) {
            chromeVisible.toggle()
        }
    }

    func showEndOfBookToast() {
        guard !didShowEndOfBookToast else { return }
        didShowEndOfBookToast = true
        withAnimation(.easeInOut(duration: 0.2)) {
            endOfBookToastVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                endOfBookToastVisible = false
            }
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

    func saveProgress() {
        guard let chapter = currentChapter else { return }
        progressCoordinator.save(
            bookID: book.id,
            chapterID: chapter.id,
            progress: progressFraction
        )
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
