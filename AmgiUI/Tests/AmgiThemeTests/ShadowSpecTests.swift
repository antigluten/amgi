import XCTest
@testable import AmgiTheme

final class ShadowSpecTests: XCTestCase {
    func testShadowSpecCodableRoundTrip() throws {
        let original = ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.06)
        let json = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShadowSpec.self, from: json)
        XCTAssertEqual(decoded, original)
    }

    func testShadowSetCodableRoundTrip() throws {
        let original = ShadowSet(
            sm: ShadowSpec(radius: 2, dx: 0, dy: 1, opacity: 0.04),
            md: ShadowSpec(radius: 16, dx: 0, dy: 4, opacity: 0.06)
        )
        let json = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShadowSet.self, from: json)
        XCTAssertEqual(decoded, original)
    }
}
