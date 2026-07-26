import AmgiReader
import SwiftUI
import UIKit

/// `UIViewControllerRepresentable` wrapping a `UIPageViewController`
/// (`.scroll`, `.horizontal`). The outer controller animates chapter
/// transitions; each chapter VC owns one `WKWebView` whose internal
/// scroll view handles intra-chapter paging via `isPagingEnabled`.
///
/// Cross-chapter handoff relies on default UIKit gesture arbitration:
/// the inner scroll view yields its pan once at maxOffset, the outer
/// page controller's recogniser takes over for the chapter swipe.
struct EPUBPageViewControllerHost: UIViewControllerRepresentable {
    let book: ReaderBook
    /// Resolved content URLs keyed by chapter index. Pre-fetched on the
    /// SwiftUI side (one async call per chapter) so the page controller
    /// data source can vend adjacent VCs synchronously.
    let chapterContents: [Int: EPUBChapterContent]
    @Binding var chapterIndex: Int
    let styleTokens: EPUBReaderStyleTokens
    /// 0..1 fraction to scroll to on the first chapter load only.
    /// Consumed by the inner VC; cleared by the host once handed off.
    let pendingRestoreFraction: Double?
    /// Suppresses the page controller's dataSource so dictionary sheets
    /// can absorb horizontal gestures (UX spec edge case).
    let pagingEnabled: Bool

    let onPageInfo: (Int, Int) -> Void
    let onProgress: (Double, Int) -> Void
    let onWordTap: (String, String) -> Void
    let onTapEmpty: (CGFloat) -> Void
    let onReachedEnd: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(host: self)
    }

    @MainActor
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        pageVC.view.backgroundColor = .clear

        let initial = context.coordinator.makeChapterVC(at: chapterIndex, restoreFraction: pendingRestoreFraction)
        if let initial {
            pageVC.setViewControllers([initial], direction: .forward, animated: false)
            context.coordinator.didInstallInitial = true
        }
        return pageVC
    }

    @MainActor
    func updateUIViewController(_ uiViewController: UIPageViewController, context: Context) {
        context.coordinator.host = self
        context.coordinator.applyStyleTokensToVisibleChapters(in: uiViewController)
        // If the host's chapterIndex Binding diverged from what the page
        // controller currently shows (programmatic jump), re-seed.
        if let current = uiViewController.viewControllers?.first as? EPUBChapterPageController,
           current.chapterIndex != chapterIndex {
            if let next = context.coordinator.makeChapterVC(at: chapterIndex, restoreFraction: pendingRestoreFraction) {
                let direction: UIPageViewController.NavigationDirection =
                    chapterIndex > current.chapterIndex ? .forward : .reverse
                uiViewController.setViewControllers([next], direction: direction, animated: true)
            }
        }
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource,
                             UIPageViewControllerDelegate, EPUBChapterPageControllerDelegate {
        var host: EPUBPageViewControllerHost
        var didInstallInitial = false

        init(host: EPUBPageViewControllerHost) {
            self.host = host
        }

        func makeChapterVC(at index: Int, restoreFraction: Double?) -> EPUBChapterPageController? {
            guard index >= 0, index < host.book.chapters.count else { return nil }
            guard let content = host.chapterContents[index] else { return nil }
            let vc = EPUBChapterPageController(
                chapterIndex: index,
                content: content,
                styleTokens: host.styleTokens,
                pendingRestoreFraction: restoreFraction
            )
            vc.pageDelegate = self
            return vc
        }

        func applyStyleTokensToVisibleChapters(in pageVC: UIPageViewController) {
            for vc in pageVC.viewControllers ?? [] {
                if let chapter = vc as? EPUBChapterPageController, chapter.styleTokens != host.styleTokens {
                    chapter.update(styleTokens: host.styleTokens)
                }
            }
        }

        // MARK: UIPageViewControllerDataSource

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard host.pagingEnabled else { return nil }
            guard let current = viewController as? EPUBChapterPageController else { return nil }
            return makeChapterVC(at: current.chapterIndex - 1, restoreFraction: nil)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard host.pagingEnabled else { return nil }
            guard let current = viewController as? EPUBChapterPageController else { return nil }
            return makeChapterVC(at: current.chapterIndex + 1, restoreFraction: nil)
        }

        // MARK: UIPageViewControllerDelegate

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let current = pageViewController.viewControllers?.first as? EPUBChapterPageController
            else { return }
            if host.chapterIndex != current.chapterIndex {
                host.chapterIndex = current.chapterIndex
            }
        }

        // MARK: EPUBChapterPageControllerDelegate

        func epubChapter(
            _ controller: EPUBChapterPageController,
            didReportPageInfoIndex pageIndex: Int,
            pageCount: Int
        ) {
            // Only forward updates from the currently-visible chapter so
            // background prefetched VCs don't clobber the page strip.
            guard controller.chapterIndex == host.chapterIndex else { return }
            host.onPageInfo(pageIndex, pageCount)
        }

        func epubChapter(
            _ controller: EPUBChapterPageController,
            didReportProgressFraction fraction: Double,
            pageIndex: Int
        ) {
            guard controller.chapterIndex == host.chapterIndex else { return }
            host.onProgress(fraction, pageIndex)
        }

        func epubChapter(
            _ controller: EPUBChapterPageController,
            didTapWord token: String,
            sentence: String
        ) {
            host.onWordTap(token, sentence)
        }

        func epubChapterDidTapEmptySpace(
            _ controller: EPUBChapterPageController,
            atRelativeX relativeX: CGFloat
        ) {
            // Edge-tap zones: left/right 15% drive intra-chapter paging
            // directly without waiting for a swipe. Outside that, toggle
            // chrome via the SwiftUI callback.
            let leftEdge: CGFloat = 0.15
            let rightEdge: CGFloat = 0.85
            if relativeX <= leftEdge {
                // At first page of first chapter — no-op (bounce isn't
                // available from a tap; UX spec says no toast either).
                if controller.isAtFirstPage && controller.chapterIndex == 0 {
                    host.onTapEmpty(relativeX)
                    return
                }
                if controller.isAtFirstPage {
                    // Hop to previous chapter's last page.
                    if let pageVC = controller.parent as? UIPageViewController,
                       let prev = makeChapterVC(at: controller.chapterIndex - 1, restoreFraction: nil) {
                        pageVC.setViewControllers([prev], direction: .reverse, animated: true) { _ in
                            self.host.chapterIndex = prev.chapterIndex
                        }
                    }
                } else {
                    controller.paginate(direction: .backward)
                }
            } else if relativeX >= rightEdge {
                if controller.isAtLastPage && controller.chapterIndex == host.book.chapters.count - 1 {
                    host.onReachedEnd()
                    return
                }
                if controller.isAtLastPage {
                    if let pageVC = controller.parent as? UIPageViewController,
                       let next = makeChapterVC(at: controller.chapterIndex + 1, restoreFraction: nil) {
                        pageVC.setViewControllers([next], direction: .forward, animated: true) { _ in
                            self.host.chapterIndex = next.chapterIndex
                        }
                    }
                } else {
                    controller.paginate(direction: .forward)
                }
            } else {
                host.onTapEmpty(relativeX)
            }
        }
    }
}
