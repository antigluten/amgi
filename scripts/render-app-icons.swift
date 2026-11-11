#!/usr/bin/env swift
// Renders the alternate app icons and their Settings previews.
// Run from the repo root: swift scripts/render-app-icons.swift
import CoreGraphics
import CoreText
import CryptoKit
import Foundation

enum Mark {
    case pen(String, size: CGFloat)
    case minimal
    case corner
}

struct AlternateIcon {
    let id: String
    let mark: Mark
    let ground: String
    let ink: String
}

let icons: [AlternateIcon] = [
    .init(id: "Dojang", mark: .pen("암기", size: 64), ground: "#F4EDE1", ink: "#C8372D"),
    .init(id: "DeepTeal", mark: .minimal, ground: "#0F3B4C", ink: "#A8F7F2"),
    .init(id: "Midnight", mark: .minimal, ground: "#1E2A5A", ink: "#FFD27A"),
    .init(id: "Celadon", mark: .corner, ground: "#A9C8B8", ink: "#1F3B36"),
    .init(id: "Persimmon", mark: .pen("기", size: 92), ground: "#E8743B", ink: "#FFF4E6"),
]

let iconsDir = URL(fileURLWithPath: "AmgiApp/Resources/AppIcons")
let previewsDir = URL(fileURLWithPath: "AmgiFeatures/Sources/SettingsFeature/Resources/AppIconPreviews.xcassets")
// Nanum Pen Script (SIL OFL 1.1), fetched rather than vendored.
let fontSource = URL(string: "https://github.com/google/fonts/raw/main/ofl/nanumpenscript/NanumPenScript-Regular.ttf")!
let fontSHA256 = "6f0d1ab29c7894010dc88831fb7a0a51edb79136e450344183de5b1a8b52bd43"
let fontURL = FileManager.default.temporaryDirectory.appendingPathComponent("NanumPenScript-Regular.ttf")

func fetchFont() throws {
    if !FileManager.default.fileExists(atPath: fontURL.path) {
        try Data(contentsOf: fontSource).write(to: fontURL)
    }
    let digest = SHA256.hash(data: try Data(contentsOf: fontURL)).map { String(format: "%02x", $0) }.joined()
    guard digest == fontSHA256 else {
        try? FileManager.default.removeItem(at: fontURL)
        fatalError("\(fontSource) changed: SHA-256 \(digest)")
    }
}

func penFont(size: CGFloat) -> CTFont {
    guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
          let first = descriptors.first else { fatalError("Unreadable font at \(fontURL.path)") }
    return CTFontCreateWithFontDescriptor(first, size, nil)
}

// Glyph outlines in a 100×100 y-down box, centred on their ink bounds:
// the font's em box sits well below the visible strokes.
func penPath(_ text: String, size: CGFloat) -> CGPath {
    let font = penFont(size: size)
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text,
        attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
    ))
    let glyphs = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var ids = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &ids)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        for (glyph, position) in zip(ids, positions) {
            var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: position.x, ty: -position.y)
            if let outline = CTFontCreatePathForGlyph(font, glyph, &flip) { glyphs.addPath(outline) }
        }
    }
    let ink = glyphs.boundingBoxOfPath
    var centre = CGAffineTransform(translationX: 50 - ink.midX, y: 50 - ink.midY)
    return glyphs.copy(using: &centre)!
}

func svgPathData(_ path: CGPath) -> String {
    func point(_ p: CGPoint) -> String { String(format: "%.2f %.2f", p.x, p.y) }
    var commands: [String] = []
    path.applyWithBlock { element in
        let p = element.pointee.points
        switch element.pointee.type {
        case .moveToPoint: commands.append("M\(point(p[0]))")
        case .addLineToPoint: commands.append("L\(point(p[0]))")
        case .addQuadCurveToPoint: commands.append("Q\(point(p[0])) \(point(p[1]))")
        case .addCurveToPoint: commands.append("C\(point(p[0])) \(point(p[1])) \(point(p[2]))")
        case .closeSubpath: commands.append("Z")
        @unknown default: fatalError("Unknown path element")
        }
    }
    return commands.joined(separator: " ")
}

func markElements(_ mark: Mark, ink: String) -> String {
    switch mark {
    case let .pen(text, size):
        // Same 1.5-unit marker weight as the reviewed canvas.
        return #"<path d="\#(svgPathData(penPath(text, size: size)))" fill="\#(ink)" stroke="\#(ink)" stroke-width="1.5" stroke-linejoin="round"/>"#
    case .minimal:
        return #"<path d="M25 29 H55 Q55 58 23 73" fill="none" stroke="\#(ink)" stroke-width="10"/><path d="M72 17 V83" fill="none" stroke="\#(ink)" stroke-width="10"/>"#
    case .corner:
        return #"<path d="M26 32 H68 V74" fill="none" stroke="\#(ink)" stroke-width="13"/>"#
    }
}

func svg(_ body: String) -> String {
    #"<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 100 100">\#(body)</svg>"# + "\n"
}

func srgb(_ hex: String) -> String {
    let value = Int(hex.dropFirst(), radix: 16)!
    let channels = [(value >> 16) & 0xFF, (value >> 8) & 0xFF, value & 0xFF]
        .map { String(format: "%.5f", Double($0) / 255) }
    return "srgb:\(channels.joined(separator: ",")),1.00000"
}

func iconJSON(_ icon: AlternateIcon) -> [String: Any] {
    [
        "fill": ["solid": srgb(icon.ground)],
        "groups": [["layers": [["glass": true, "image-name": "mark.svg", "name": "mark"]]]],
        "supported-platforms": ["squares": "shared"],
    ]
}

func write(_ data: Data, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url)
}

func writeJSON(_ object: Any, to url: URL) throws {
    var data = try JSONSerialization.data(
        withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    data.append(0x0A)
    try write(data, to: url)
}

let xcodeInfo: [String: Any] = ["author": "xcode", "version": 1]

try fetchFont()

for icon in icons {
    let marks = markElements(icon.mark, ink: icon.ink)

    let bundle = iconsDir.appendingPathComponent("\(icon.id).icon")
    try write(Data(svg(marks).utf8), to: bundle.appendingPathComponent("Assets/mark.svg"))
    try writeJSON(iconJSON(icon), to: bundle.appendingPathComponent("icon.json"))

    let imageSet = previewsDir.appendingPathComponent("\(icon.id).imageset")
    let preview = svg(#"<rect width="100" height="100" fill="\#(icon.ground)"/>"# + marks)
    try write(Data(preview.utf8), to: imageSet.appendingPathComponent("\(icon.id).svg"))
    try writeJSON([
        "images": [["filename": "\(icon.id).svg", "idiom": "universal"]],
        "info": xcodeInfo,
        "properties": ["preserves-vector-representation": true],
    ], to: imageSet.appendingPathComponent("Contents.json"))
}
try writeJSON(["info": xcodeInfo], to: previewsDir.appendingPathComponent("Contents.json"))
print("Rendered \(icons.count) alternate icons")
