import Testing
import Foundation
@testable import AmgiCardWeb

@Suite struct CardAssetPathTests {
    let mediaRoot = "/tmp/amgi-media"
    let bundleRoot = "/tmp/amgi-bundle"

    @Test func resolvesMediaFile() {
        let url = URL(string: "amgi-asset://media/hello.mp3")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == "/tmp/amgi-media/hello.mp3")
    }

    @Test func resolvesBundleAsset() {
        let url = URL(string: "amgi-asset://assets/mathjax/tex-svg.js")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == "/tmp/amgi-bundle/mathjax/tex-svg.js")
    }

    @Test func percentDecodesFilename() {
        let url = URL(string: "amgi-asset://media/my%20sound.mp3")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == "/tmp/amgi-media/my sound.mp3")
    }

    @Test func rejectsPathTraversalInMedia() {
        let url = URL(string: "amgi-asset://media/../../etc/passwd")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == nil)
    }

    @Test func rejectsPathTraversalInAssets() {
        let url = URL(string: "amgi-asset://assets/mathjax/../../../etc/passwd")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == nil)
    }

    @Test func rejectsUnknownHost() {
        let url = URL(string: "amgi-asset://other/x.txt")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == nil)
    }

    @Test func assetsRequireMathjaxPrefix() {
        let url = URL(string: "amgi-asset://assets/other/x.js")!
        let resolved = CardAssetPath.resolve(url: url, mediaRoot: mediaRoot, bundleRoot: bundleRoot)
        #expect(resolved == nil)
    }

    @Test func rejectsSymlinkEscapingMediaRoot() throws {
        let fm = FileManager.default
        let tempBase = fm.temporaryDirectory.appendingPathComponent("amgi-symlink-test-\(UUID().uuidString)")
        let mediaDir = tempBase.appendingPathComponent("media")
        let outsideDir = tempBase.appendingPathComponent("outside")
        try fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: outsideDir, withIntermediateDirectories: true)
        let secretFile = outsideDir.appendingPathComponent("secret.txt")
        try Data("secret".utf8).write(to: secretFile)
        let link = mediaDir.appendingPathComponent("escape")
        try fm.createSymbolicLink(at: link, withDestinationURL: outsideDir)

        defer { try? fm.removeItem(at: tempBase) }

        let url = URL(string: "amgi-asset://media/escape/secret.txt")!
        let resolved = CardAssetPath.resolve(
            url: url,
            mediaRoot: mediaDir.path,
            bundleRoot: "/tmp/irrelevant"
        )
        #expect(resolved == nil, "Symlink escape should be rejected after resolvingSymlinksInPath")
    }
}

@Suite struct CardAssetMimeTests {
    @Test func mp3() { #expect(CardAssetPath.mimeType(for: "a.mp3") == "audio/mpeg") }
    @Test func mp4() { #expect(CardAssetPath.mimeType(for: "a.mp4") == "video/mp4") }
    @Test func wav() { #expect(CardAssetPath.mimeType(for: "a.wav") == "audio/wav") }
    @Test func ogg() { #expect(CardAssetPath.mimeType(for: "a.ogg") == "audio/ogg") }
    @Test func jpg() { #expect(CardAssetPath.mimeType(for: "a.jpg") == "image/jpeg") }
    @Test func jpeg() { #expect(CardAssetPath.mimeType(for: "a.jpeg") == "image/jpeg") }
    @Test func png() { #expect(CardAssetPath.mimeType(for: "a.png") == "image/png") }
    @Test func gif() { #expect(CardAssetPath.mimeType(for: "a.gif") == "image/gif") }
    @Test func svg() { #expect(CardAssetPath.mimeType(for: "a.svg") == "image/svg+xml") }
    @Test func js() { #expect(CardAssetPath.mimeType(for: "a.js") == "application/javascript") }
    @Test func flac() { #expect(CardAssetPath.mimeType(for: "a.flac") == "audio/flac") }
    @Test func opus() { #expect(CardAssetPath.mimeType(for: "a.opus") == "audio/ogg") }
    @Test func aac() { #expect(CardAssetPath.mimeType(for: "a.aac") == "audio/aac") }
    @Test func bmp() { #expect(CardAssetPath.mimeType(for: "a.bmp") == "image/bmp") }
    @Test func heic() { #expect(CardAssetPath.mimeType(for: "a.heic") == "image/heic") }
    @Test func tiff() { #expect(CardAssetPath.mimeType(for: "a.tiff") == "image/tiff") }
    @Test func tif() { #expect(CardAssetPath.mimeType(for: "a.tif") == "image/tiff") }
    @Test func unknown() { #expect(CardAssetPath.mimeType(for: "a.xyz") == "application/octet-stream") }
    @Test func noExtension() { #expect(CardAssetPath.mimeType(for: "noext") == "application/octet-stream") }
}
