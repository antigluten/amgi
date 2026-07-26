public import SwiftUI

public struct BookCoverPalette: Equatable, Identifiable, Sendable {
    public let id: String
    public let gradientStart: Color
    public let gradientEnd: Color
    public let lineColor: Color

    public init(id: String, gradientStart: Color, gradientEnd: Color, lineColor: Color) {
        self.id = id
        self.gradientStart = gradientStart
        self.gradientEnd = gradientEnd
        self.lineColor = lineColor
    }

    public static let presets: [BookCoverPalette] = [
        BookCoverPalette(
            id: "slate",
            gradientStart: Color(red: 0.70, green: 0.78, blue: 0.86),
            gradientEnd:   Color(red: 0.45, green: 0.55, blue: 0.66),
            lineColor:     Color(red: 0.96, green: 0.74, blue: 0.27)
        ),
        BookCoverPalette(
            id: "navy",
            gradientStart: Color(red: 0.18, green: 0.22, blue: 0.30),
            gradientEnd:   Color(red: 0.08, green: 0.10, blue: 0.16),
            lineColor:     Color(red: 0.96, green: 0.62, blue: 0.20)
        ),
        BookCoverPalette(
            id: "brick",
            gradientStart: Color(red: 0.78, green: 0.30, blue: 0.20),
            gradientEnd:   Color(red: 0.55, green: 0.16, blue: 0.10),
            lineColor:     Color.white.opacity(0.85)
        ),
        BookCoverPalette(
            id: "violet",
            gradientStart: Color(red: 0.55, green: 0.20, blue: 0.78),
            gradientEnd:   Color(red: 0.25, green: 0.08, blue: 0.36),
            lineColor:     Color.white.opacity(0.85)
        ),
        BookCoverPalette(
            id: "teal",
            gradientStart: Color(red: 0.30, green: 0.62, blue: 0.66),
            gradientEnd:   Color(red: 0.14, green: 0.38, blue: 0.46),
            lineColor:     Color(red: 0.96, green: 0.78, blue: 0.30)
        ),
    ]

    public static func resolve(seed: String) -> BookCoverPalette {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        let index = Int(hash % UInt64(presets.count))
        return presets[index]
    }
}
