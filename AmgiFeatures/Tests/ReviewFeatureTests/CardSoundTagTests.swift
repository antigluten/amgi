import Testing
@testable import ReviewFeature

@MainActor
struct CardSoundTagTests {
    @Test(arguments: ["sound", "Sound", "SOUND"], [false, true])
    func supportedMarkersCreateAudio(marker: String, replayButtons: Bool) {
        let input = "[\(marker):hello.mp3]"
        let output = CardWebView.expandSoundTags(
            input, isDarkMode: false, showReplayButtons: replayButtons
        )
        #expect(output.contains("<audio class=\"anki-sound-audio\" src=\"hello.mp3\""))
        #expect(!output.contains(input))
    }
}
