import XCTest
import SwiftUI
@testable import AmgiUI
@testable import AmgiTheme

final class AmgiCardTests: XCTestCase {
    func testBackgroundCasesEnumerate() {
        // .surface and .surfaceElevated should be distinct cases.
        let a: AmgiCardBackground = .surface
        let b: AmgiCardBackground = .surfaceElevated
        switch (a, b) {
        case (.surface, .surfaceElevated): break
        default: XCTFail("Expected distinct cases")
        }
    }

    @MainActor
    func testCardWithSurfaceBackgroundBuilds() {
        _ = AmgiCard(background: .surface) {
            Text("hello")
        }
    }

    @MainActor
    func testCardWithGradientBackgroundBuilds() {
        _ = AmgiCard(background: .gradient(start: .blue, end: .purple)) {
            Text("hello")
        }
    }
}
