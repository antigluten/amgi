import Testing
import AnkiKit

@Suite struct TypedAnswerStateTests {
    @Test func equality() {
        let a = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        let b = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        #expect(a == b)
    }

    @Test func inequalityOnExpected() {
        let a = TypedAnswerState(placeholder: "[[typeans]]", expected: "猫", combining: false, fontName: "Arial", fontSize: 20)
        let b = TypedAnswerState(placeholder: "[[typeans]]", expected: "犬", combining: false, fontName: "Arial", fontSize: 20)
        #expect(a != b)
    }
}
