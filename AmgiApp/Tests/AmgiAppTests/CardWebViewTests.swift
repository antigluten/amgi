import XCTest
@testable import AmgiApp

final class CardWebViewTests: XCTestCase {
    // DEFERRED: fork's testMediaBaseTagPointsAtMediaRoot tests CardWebView.mediaBaseTag(for: URL)
    // using file:// URLs. Our codebase uses CardAssetPath.mediaBaseTag() with the amgi-asset://
    // custom URL scheme (no file-path parameter). The method doesn't exist in our CardWebView.
    // See AmgiCardWebTests/CardAssetPathTests.swift for coverage of our mediaBaseTag() variant.

    // DEFERRED: fork's testCardWrapperFileUsesHiddenFileInMediaRoot tests
    // CardWebView.cardWrapperFileURL(in:), which doesn't exist in our codebase.
    // Our architecture loads HTML via webView.loadHTMLString(_:baseURL:) with a custom
    // URL scheme handler (CardAssetScheme) rather than writing an on-disk wrapper file.
}
