//
//  LookupExtractionTests.swift
//  ReaderTests
//
//  Created by Vladimir Gusev on 12.09.2026.
//

import Foundation
import Reader
import Testing
import WebKit

@MainActor
struct LookupExtractionTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let name: String
        let body: String
        let needle: String
        var index = 0
        var scanLength = 16
        let text: String?
        var sentence: String? = nil
        var style = ""

        var testDescription: String { name }
    }

    nonisolated static let cases: [Case] = [
        Case(
            name: "先生 runs forward from the tapped kanji to the delimiter",
            body: "<p>今日は晴れ。先生は学校へ行きます。明日は雨。</p>",
            needle: "先生",
            text: "先生は学校へ行きます",
            sentence: "先生は学校へ行きます。"
        ),
        Case(
            name: "頭 keeps what follows it so the engine can shorten from the end",
            body: "<p>頭が痛い。</p>",
            needle: "頭",
            text: "頭が痛い",
            sentence: "頭が痛い。"
        ),
        Case(
            name: "inflected verb arrives whole for deinflection",
            body: "<p>ご飯を食べました。</p>",
            needle: "食べました",
            text: "食べました"
        ),
        Case(
            name: "tap mid-word inside a phrase starts at the tapped character",
            body: "<p>先生は学校へ行きます。</p>",
            needle: "学校",
            index: 1,
            text: "校へ行きます"
        ),
        Case(
            name: "per-character spans still yield the whole run",
            body: "<p><span class=\"amgi-tok\">先</span><span class=\"amgi-tok\">生</span>は<span>来</span>た。</p>",
            needle: "先",
            text: "先生は来た",
            sentence: "先生は来た。"
        ),
        Case(
            name: "furigana rt text is skipped when walking forward",
            body: "<p><ruby>先生<rt>せんせい</rt></ruby>は<ruby>来<rt>き</rt></ruby>た。</p>",
            needle: "先生",
            text: "先生は来た"
        ),
        Case(
            name: "tapping the furigana itself extracts nothing",
            body: "<p style=\"font-size:40px\"><ruby>先生<rt>せんせい</rt></ruby>は来た。</p>",
            needle: "せんせい",
            index: 1,
            text: nil
        ),
        Case(
            name: "Latin tap mid-word expands back to the word start",
            body: "<p>The quick brown fox.</p>",
            needle: "quick",
            index: 2,
            text: "quick",
            sentence: "The quick brown fox."
        ),
        Case(
            name: "Hangul run is one word",
            body: "<p>나는 학교에 갑니다.</p>",
            needle: "학교에",
            index: 1,
            text: "학교에"
        ),
        Case(
            name: "scan length caps the forward walk",
            body: "<p>あいうえおかきくけこさしすせそたちつてと</p>",
            needle: "あ",
            scanLength: 4,
            text: "あいうえ"
        ),
        Case(
            name: "a delimiter yields nothing",
            body: "<p>先生。学校</p>",
            needle: "。",
            text: nil
        ),
        Case(
            name: "the sentence reaches back across an earlier text node",
            body: "<p><span>今日は晴れ。先生は</span>学校へ行きます。</p>",
            needle: "学校",
            text: "学校へ行きます",
            sentence: "先生は学校へ行きます。"
        ),
        Case(
            name: "text with no block ancestor falls back to the body",
            body: "先生は来た。",
            needle: "先生",
            text: "先生は来た",
            sentence: "先生は来た。"
        ),
        Case(
            name: "先生 runs forward from the tapped kanji under vertical-rl",
            body: "<p>今日は晴れ。先生は学校へ行きます。明日は雨。</p>",
            needle: "先生",
            text: "先生は学校へ行きます",
            sentence: "先生は学校へ行きます。",
            style: "html { writing-mode: vertical-rl; }"
        ),
        Case(
            name: "a Latin word split across inline nodes joins into one word",
            body: "<p>The qu<b>ick</b> brown fox.</p>",
            needle: "qu",
            index: 1,
            text: "quick"
        ),
    ]

    @Test(arguments: cases)
    func extraction(_ testCase: Case) async throws {
        let page = try await LookupTestPage.load(body: testCase.body, style: testCase.style)
        let payload = try await page.tap(testCase.needle, index: testCase.index, scanLength: testCase.scanLength)
        #expect(payload?.text == testCase.text)
        if let sentence = testCase.sentence {
            #expect(payload?.sentence == sentence)
        }
    }

    @Test("highlightMatched covers exactly the matched prefix of the last extraction")
    func highlight() async throws {
        let page = try await LookupTestPage.load(body: "<p>先生は来た。</p>")
        let payload = try await page.tap("先生", index: 0, scanLength: 16)
        #expect(payload?.text == "先生は来た")
        let highlighted = try await page.highlightMatched(utf16Length: 2)
        #expect(highlighted == "先生")
        let cleared = try await page.clearHighlight()
        #expect(cleared == "")
    }

    @Test("an astral-plane character survives extraction and highlights as one character")
    func astralCharacter() async throws {
        let page = try await LookupTestPage.load(body: "<p>𠮷野家で食べた。</p>")
        let payload = try await page.tap("𠮷", index: 0, scanLength: 16)
        #expect(payload?.text == "𠮷野家で食べた")
        let highlighted = try await page.highlightMatched(utf16Length: 2)
        #expect(highlighted == "𠮷")
        let capped = try await page.tap("𠮷", index: 0, scanLength: 1)
        #expect(capped?.text == "𠮷")
    }

    @Test("a tap in the middle of a 60 000-character paragraph extracts the same word")
    func longParagraph() async throws {
        let filler = String(repeating: "あいうえお", count: 6000)
        let page = try await LookupTestPage.load(body: "<p>\(filler)先生は学校へ行きます。\(filler)</p>")
        let payload = try await page.tap("先生", index: 0, scanLength: 16)
        #expect(payload?.text == "先生は学校へ行きます")
    }
}

// MARK: - Harness

@MainActor
private final class LookupTestPage: NSObject, WKNavigationDelegate {
    struct Payload: Decodable {
        let text: String
        let sentence: String
    }

    private let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
    private var loaded: CheckedContinuation<Void, Never>?

    static func load(body: String, style: String = "") async throws -> LookupTestPage {
        let page = LookupTestPage()
        page.webView.navigationDelegate = page
        let html = """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>body { font-size: 24px; line-height: 1.6; margin: 16px; }</style>
        <style>\(style)</style>
        <script>\(LookupExtractionScript.source)</script>
        <script>
        window.amgiTest = {
          find: function(needle, index) {
            var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            var node;
            while ((node = walker.nextNode())) {
              var at = (node.textContent || '').indexOf(needle);
              if (at < 0) continue;
              var range = document.createRange();
              range.setStart(node, at + index);
              range.setEnd(node, at + index + ((node.textContent.codePointAt(at + index) > 0xFFFF) ? 2 : 1));
              var rect = range.getBoundingClientRect();
              if (rect.top < 0 || rect.bottom > window.innerHeight) {
                window.scrollBy(0, rect.top - window.innerHeight / 2);
                rect = range.getBoundingClientRect();
              }
              return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
            }
            return null;
          },
          tap: function(needle, index, scanLength) {
            var point = this.find(needle, index);
            if (!point) return JSON.stringify({ error: 'needle not found: ' + needle });
            return JSON.stringify(window.amgiLookup.payloadAt(point.x, point.y, scanLength));
          },
          highlighted: function() {
            var highlight = CSS.highlights.get('amgi-lookup');
            if (!highlight) return '';
            return Array.from(highlight).map(function(r) { return r.toString(); }).join('|');
          }
        };
        </script></head><body>\(body)</body></html>
        """
        await withCheckedContinuation { continuation in
            page.loaded = continuation
            page.webView.loadHTMLString(html, baseURL: nil)
        }
        return page
    }

    func tap(_ needle: String, index: Int, scanLength: Int) async throws -> Payload? {
        let json = try await evaluate("window.amgiTest.tap(\(Self.literal(needle)), \(index), \(scanLength))")
        if json == "null" { return nil }
        struct Failure: Decodable { let error: String }
        if let failure = try? JSONDecoder().decode(Failure.self, from: Data(json.utf8)) {
            throw TestError.harness(failure.error)
        }
        return try JSONDecoder().decode(Payload.self, from: Data(json.utf8))
    }

    func highlightMatched(utf16Length: Int) async throws -> String {
        try await evaluate("window.amgiLookup.highlightMatched(\(utf16Length)); window.amgiTest.highlighted()")
    }

    func clearHighlight() async throws -> String {
        try await evaluate("window.amgiLookup.clearHighlight(); window.amgiTest.highlighted()")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loaded?.resume()
        loaded = nil
    }

    private func evaluate(_ script: String) async throws -> String {
        let result = try await webView.evaluateJavaScript(script)
        guard let string = result as? String else { throw TestError.harness("non-string result: \(String(describing: result))") }
        return string
    }

    private static func literal(_ string: String) -> String {
        let data = (try? JSONEncoder().encode([string])) ?? Data()
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }

    enum TestError: Error {
        case harness(String)
    }
}
