import AnkiKit
import Testing
@testable import DecksFeature

@MainActor
struct DeckConfigStepsTests {
    private func model() -> DeckConfigModel {
        DeckConfigModel(deckId: DeckID(1), deckName: "Steps")
    }

    @Test func secondsAndExistingUnitsParseAsMinutes() {
        #expect(model().parseSteps("30s 90S 1m 0.5h 0.25d 2") == [0.5, 1.5, 1, 30, 360, 2])
    }

    @Test func openingAndSavingPreservesSyncedFractionalSteps() {
        let model = model()
        let config = DeckConfig(config: .init(
            learnSteps: [0.5, 1.25, 10],
            relearnSteps: [0.25, 2.5]
        ))
        model.apply(config: config, context: .init())

        let saved = model.editedConfig(from: config)
        #expect(saved.config.learnSteps == [0.5, 1.25, 10])
        #expect(saved.config.relearnSteps == [0.25, 2.5])
    }

    @Test func formattingPreservesFloatPrecision() {
        let model = model()
        let steps: [Float] = [1 / 60, 20 / 60, 0.5, 1.5, 10, 0.123, 1 / 120]
        #expect(model.parseSteps(model.formatSteps(steps)) == steps)
        #expect(model.formatSteps([1, 10]) == "1m 10m")
    }

    @Test func formattingUsesTheLargestWholeUnitLikeDesktop() {
        let model = model()
        let steps: [Float] = [0.5, 1.5, 20 / 60, 1, 10, 60, 90, 1440, 1500, 2880]
        #expect(model.formatSteps(steps) == "30s 90s 20s 1m 10m 1h 90m 1d 25h 2d")
        #expect(model.formatSteps([0.123, 0]) == "0.123m 0m")
        #expect(model.formatSteps([2_097_153]) == "2097153m")
    }

    @Test func emptyStepsRemainEmpty() {
        let model = model()
        #expect(model.formatSteps([]).isEmpty)
        #expect(model.parseSteps("").isEmpty)
    }
}
