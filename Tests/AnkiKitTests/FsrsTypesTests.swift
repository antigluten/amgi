import Testing
@testable import AnkiKit

@Suite struct FsrsWeightsTests {
    @Test func default_init_is_empty() {
        #expect(FsrsWeights().isEmpty)
        #expect(FsrsWeights().count == 0)
    }

    @Test func value_constructor_keeps_order() {
        let w = FsrsWeights([1.0, 2.0, 3.0])
        #expect(w.values == [1.0, 2.0, 3.0])
        #expect(!w.isEmpty)
        #expect(w.count == 3)
    }

    @Test func equality_uses_values() {
        #expect(FsrsWeights([1, 2]) == FsrsWeights([1, 2]))
        #expect(FsrsWeights([1, 2]) != FsrsWeights([2, 1]))
    }
}

@Suite struct FsrsOptimizeResultTests {
    @Test func health_check_can_be_passed_failed_or_nil() {
        let none = FsrsOptimizeResult(weights: FsrsWeights(), trainingItemCount: 0, healthCheck: nil)
        let passed = FsrsOptimizeResult(weights: FsrsWeights(), trainingItemCount: 0, healthCheck: .passed)
        let failed = FsrsOptimizeResult(weights: FsrsWeights(), trainingItemCount: 0, healthCheck: .failed)

        #expect(none.healthCheck == nil)
        #expect(passed.healthCheck == .passed)
        #expect(failed.healthCheck == .failed)
    }
}
