public import Foundation

public struct ShadowSpec: Codable, Sendable, Equatable {
    public let radius: CGFloat
    public let dx: CGFloat
    public let dy: CGFloat
    public let opacity: Double

    public init(radius: CGFloat, dx: CGFloat, dy: CGFloat, opacity: Double) {
        self.radius = radius
        self.dx = dx
        self.dy = dy
        self.opacity = opacity
    }
}

public struct ShadowSet: Codable, Sendable, Equatable {
    public let sm: ShadowSpec
    public let md: ShadowSpec

    public init(sm: ShadowSpec, md: ShadowSpec) {
        self.sm = sm
        self.md = md
    }
}
