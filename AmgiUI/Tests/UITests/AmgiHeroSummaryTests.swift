//
//  AmgiHeroSummaryTests.swift
//  UITests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Testing
import SwiftUI
@testable import UI
@testable import Theme

@MainActor
@Suite("AmgiHeroSummary")
struct AmgiHeroSummaryTests {
    @Test func buildsWithAllSlots() {
        _ = AmgiHeroSummary(
            eyebrow: "Due today",
            bigNumber: "127",
            subtitle: "cards across 4 decks",
            background: .gradient(start: .blue, end: .purple),
            decoration: { Image(systemName: "chart.line.uptrend.xyaxis") },
            footer: { Button("Start") {} }
        )
    }

    @Test func buildsWithNoEyebrowOrSubtitle() {
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
