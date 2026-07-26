import Testing
import AmgiTheme
@testable import AmgiUI

@Suite("HeatmapCardData")
struct HeatmapCardDataTests {

    @Test("empty fixture has no counts and maxCount of 1")
    func emptyFixture() {
        let data = HeatmapCardData.empty
        #expect(data.counts.isEmpty)
        #expect(data.maxCount == 1)
    }

    @Test("maxCount clamps to 1 when zero is passed")
    func maxCountClampZero() {
        let data = HeatmapCardData(counts: [-1: 5], maxCount: 0)
        #expect(data.maxCount == 1)
    }

    @Test("maxCount clamps to 1 when negative is passed")
    func maxCountClampNegative() {
        let data = HeatmapCardData(counts: [-1: 5], maxCount: -3)
        #expect(data.maxCount == 1)
    }

    @Test("counts round-trips through init")
    func countsRoundTrip() {
        let data = HeatmapCardData(counts: [-1: 5, -3: 12], maxCount: 12)
        #expect(data.counts[-1] == 5)
        #expect(data.counts[-3] == 12)
        #expect(data.counts[-2] == nil)
    }
}

@Suite("HeatmapColorRamp")
struct HeatmapColorRampTests {

    @Test("legendColors returns exactly 5 entries")
    func legendColorCount() {
        #expect(HeatmapColorRamp.legendColors(palette: .vividLight).count == 5)
    }

    @Test("same inputs produce same color — deterministic")
    func deterministic() {
        let c1 = HeatmapColorRamp.color(count: 10, maxCount: 20, palette: .vividLight)
        let c2 = HeatmapColorRamp.color(count: 10, maxCount: 20, palette: .vividLight)
        #expect(c1 == c2)
    }

    @Test("count 0 returns separator color")
    func zeroCountReturnsSeparator() {
        let empty = HeatmapColorRamp.color(count: 0, maxCount: 20, palette: .vividLight)
        let separator = Palette.vividLight.separator
        #expect(empty == separator)
    }

    @Test("negative maxCount falls back to 1 — no crash")
    func negativeMaxCountNoCrash() {
        // Should not crash; behaviour defined by max(maxCount, 1) inside helper.
        let c = HeatmapColorRamp.color(count: 5, maxCount: -1, palette: .mutedDark)
        let reference = HeatmapColorRamp.color(count: 5, maxCount: 1, palette: .mutedDark)
        #expect(c == reference)
    }
}
