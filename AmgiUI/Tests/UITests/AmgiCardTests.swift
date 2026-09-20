//
//  AmgiCardTests.swift
//  UITests
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import Testing
import SwiftUI
@testable import UI
@testable import Theme

@Suite("AmgiCard")
struct AmgiCardTests {
    @Test func backgroundCasesEnumerate() {
        // .surface and .surfaceElevated should be distinct cases.
        let a: AmgiCardBackground = .surface
        let b: AmgiCardBackground = .surfaceElevated
        switch (a, b) {
        case (.surface, .surfaceElevated): break
        default: Issue.record("Expected distinct cases")
        }
    }

    @MainActor
    @Test func cardWithSurfaceBackgroundBuilds() {
        _ = AmgiCard(background: .surface) {
            Text("hello")
        }
    }

    @MainActor
    @Test func cardWithGradientBackgroundBuilds() {
        _ = AmgiCard(background: .gradient(start: .blue, end: .purple)) {
            Text("hello")
        }
    }
}
