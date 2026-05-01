import SwiftUI

extension Color {
    // MARK: - Backgrounds
    static let amgiBackground = Color(red: 0, green: 0, blue: 0)  // watchOS is dark
    static let amgiSurface = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let amgiSurfaceElevated = Color(red: 0.165, green: 0.165, blue: 0.176)
    // MARK: - Text
    static let amgiTextPrimary = Color.white
    static let amgiTextSecondary = Color.white.opacity(0.8)
    static let amgiTextTertiary = Color.white.opacity(0.48)
    // MARK: - Interactive
    static let amgiAccent = Color(red: 0.161, green: 0.592, blue: 1.0)
    static let amgiLink = Color(red: 0.161, green: 0.592, blue: 1.0)
}
// MARK: - Adaptive Color (Watch)
extension Color {
    init(light: Color, dark: Color) {
        self = dark  // watchOS is always dark in this app
    }
}
