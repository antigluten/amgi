import Testing
import CoreGraphics
@testable import AmgiTheme

@Suite("AmgiRadius tokens")
struct AmgiRadiusTests {
    @Test func tokenValuesMatchMinimalDesignLanguage() {
        #expect(AmgiRadius.inset == 12)
        #expect(AmgiRadius.hero == 14)
        #expect(AmgiRadius.control == 10)
        #expect(AmgiRadius.pill == 28)
    }

    @Test func displayHeroTrackingTightened() {
        #expect(AmgiFont.displayHero.tracking == -0.6)
    }
}
