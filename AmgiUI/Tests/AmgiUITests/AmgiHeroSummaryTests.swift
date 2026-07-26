import XCTest
import SwiftUI
@testable import AmgiUI
@testable import AmgiTheme

final class AmgiHeroSummaryTests: XCTestCase {
    @MainActor
    func testBuildsWithAllSlots() {
        _ = AmgiHeroSummary(
            eyebrow: "Due today",
            bigNumber: "127",
            subtitle: "cards across 4 decks",
            background: .gradient(start: .blue, end: .purple),
            decoration: { Image(systemName: "chart.line.uptrend.xyaxis") },
            footer: { Button("Start") {} }
        )
    }

    @MainActor
    func testBuildsWithNoEyebrowOrSubtitle() {
        _ = AmgiHeroSummary(
            eyebrow: nil,
            bigNumber: "0",
            subtitle: nil,
            background: .solid(.blue),
            decoration: { EmptyView() },
            footer: { EmptyView() }
        )
    }
}
