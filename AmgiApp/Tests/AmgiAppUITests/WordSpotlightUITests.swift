import Foundation
import XCTest

@MainActor
final class WordSpotlightUITests: XCTestCase {
    func testSettingsEntryRequiresConfirmedSource() {
        let app = launchApp()
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        let spotlight = app.buttons["settings.wordSpotlight"]
        for _ in 0..<6 {
            if spotlight.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(spotlight.isHittable)
        spotlight.tap()
        let deck = app.buttons["wordSpotlight.deck"]
        XCTAssertTrue(deck.waitForExistence(timeout: 10))
        deck.tap()
        let noDeck = app.buttons["Choose a deck"].firstMatch
        XCTAssertTrue(noDeck.waitForExistence(timeout: 5))
        noDeck.tap()
        let save = app.buttons["wordSpotlight.saveSource"]
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled)
    }

    func testWidgetSettingsLinkOpensAndDismissesSettings() {
        let app = launchApp()
        app.open(URL(string: "amgi://word-settings")!)
        XCTAssertTrue(app.buttons["wordSpotlight.deck"].waitForExistence(timeout: 10))
        let done = app.buttons["wordSpotlight.dismiss"]
        XCTAssertTrue(done.exists)
        done.tap()
        XCTAssertTrue(app.navigationBars["Word Spotlight"].waitForNonExistence(timeout: 5))
    }

    func testForeignProfileWordLinkShowsUnavailableState() {
        let app = launchApp()
        let foreignProfile = UUID().uuidString
        app.open(URL(string: "amgi://word?profile=\(foreignProfile)&note=42")!)
        XCTAssertTrue(app.staticTexts["Word unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Next word"].exists)
        XCTAssertTrue(app.buttons["wordSpotlight.dismiss"].exists)
    }

    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["-onboardingCompleted", "YES", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }
}
