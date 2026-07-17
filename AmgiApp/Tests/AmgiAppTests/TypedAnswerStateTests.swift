import XCTest
import AnkiKit

final class TypedAnswerStateTests: XCTestCase {
    func testEquality() {
        let a = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        let b = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        XCTAssertEqual(a, b)
    }

    func testInequalityOnExpected() {
        let a = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        let b = TypedAnswerState(placeholder: "[[typeans]]", expected: "犬", combining: false, fontName: "Arial", fontSize: 20)
        XCTAssertNotEqual(a, b)
    }
}
