import Testing
import Dependencies
import AnkiServices

@Suite struct CompareAnswerTests {
    @Test func compareAnswerClosureExists() {
        // Smoke: verify the closure is defined on CardRenderingService.
        // Real backend call requires an open collection; that's a manual test.
        withDependencies {
            $0.cardRenderingService.compareAnswer = { _, _, _ in "diff-html" }
        } operation: {
            // The closure exists on the type; this compiles iff the field is defined.
            @Dependency(\.cardRenderingService) var dep
            let result = try? dep.compareAnswer("a", "b", false)
            #expect(result == "diff-html")
        }
    }
}
