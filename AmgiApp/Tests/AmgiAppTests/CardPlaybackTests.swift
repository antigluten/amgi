// App-hosted: CardWebView loads the production bridge and asset resources from Bundle.main.
import AnkiBackend
import AnkiClients
import AnkiKit
import AnkiServices
import AVFoundation
import Dependencies
import Foundation
import Testing
import UIKit
import WebKit
@testable import ReviewFeature

@MainActor
@Suite(.serialized)
struct CardPlaybackTests {
    @Test(arguments: ["Hello & world!", "<b>Hello</b>&nbsp;&amp; <i>world</i>!"], [false, true])
    func nativeRenderedTTSUsesSpokenText(field: String, autoplay: Bool) async throws {
        let directory = try mediaDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = try AnkiBackend()
        try backend.openCollection(
            collectionPath: directory.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: directory.appendingPathComponent("media").path,
            mediaDbPath: directory.appendingPathComponent("media.db").path
        )
        defer { try? backend.closeCollection() }
        let html = try await withDependencies {
            $0.ankiBackend = backend
        } operation: {
            let client = NotetypesClient.liveValue
            let names = try await client.listAll()
            let basic = try #require(names.first { $0.name == "Basic" })
            var notetype = try await client.get(basic.id)
            notetype.templates[0].config.qFormat = "{{tts en_US voices=MissingVoice speed=0.8:Front}}"
            return try CardRenderingService.liveValue.renderUncommittedCard(
                notetype, 0, [field, "back"]
            ).frontHTML
        }
        #expect(html.contains("[anki:tts"))

        var started = false
        let card = CardWebView(html: html, autoplayEnabled: autoplay, onAudioStateChange: {
            if $0 { started = true }
        })
        let coordinator = card.makeCoordinator()
        let webView = card.makeWebView(coordinator: coordinator)
        let window = try host(webView)
        defer { window.isHidden = true }
        defer { CardWebView.dismantleWebView(webView, coordinator: coordinator) }
        ReviewAudioSession.apply(playInSilent: true)
        defer { ReviewAudioSession.release() }
        card.updateWebView(webView, coordinator: coordinator)
        let loaded = try await wait {
            try await webView.evaluateJavaScript("!!document.querySelector('.tts-btn')") as? Bool == true
        }
        try #require(loaded, "The actual bundled card frame must finish rendering")
        let text = try await webView.evaluateJavaScript("document.querySelector('.tts-btn').dataset.ttsText") as? String
        #expect(text == "Hello & world!")
        let language = try await webView.evaluateJavaScript("document.querySelector('.tts-btn').dataset.ttsLang") as? String
        #expect(language == "en_US")

        if !autoplay {
            _ = try await webView.evaluateJavaScript("document.querySelector('.tts-btn').click()")
        }
        let spoke = try await wait { started }
        #expect(spoke, "The real WK message must start AVSpeechSynthesizer")
    }

    @Test(arguments: [false, true])
    func localSoundPlaysThroughTheActualAssetScheme(autoplay: Bool) async throws {
        let directory = try mediaDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withDependencies {
            $0.mediaClient.folderURL = { directory }
        } operation: {
            var started = false
            let card = CardWebView(
                html: "[sound:先生 space.wav]", autoplayEnabled: autoplay,
                onAudioStateChange: { if $0 { started = true } }
            )
            let coordinator = card.makeCoordinator()
            let webView = card.makeWebView(coordinator: coordinator)
            let window = try host(webView)
            defer { window.isHidden = true }
            defer { CardWebView.dismantleWebView(webView, coordinator: coordinator) }
            ReviewAudioSession.apply(playInSilent: true)
            defer { ReviewAudioSession.release() }
            card.updateWebView(webView, coordinator: coordinator)
            let loaded = try await wait {
                try await webView.evaluateJavaScript("!!document.querySelector('.anki-sound-audio')") as? Bool == true
            }
            try #require(loaded, "The actual bundled card frame must finish rendering")
            if !autoplay {
                _ = try await webView.evaluateJavaScript("document.querySelector('.sound-btn .replay-button').click()")
            }
            let selector = autoplay ? "#amgi-audio-queue-player" : ".anki-sound-audio"
            let ended = try await wait {
                try await webView.evaluateJavaScript("""
                    (() => {
                      const audio = document.querySelector('\(selector)');
                      return !!audio && audio.ended && audio.duration > 0 && audio.currentTime > 0;
                    })()
                    """) as? Bool == true
            }
            #expect(started)
            let diagnostic = try await webView.evaluateJavaScript("""
                (() => {
                  const audio = document.querySelector('\(selector)');
                  return JSON.stringify(audio && {src:audio.src, error:audio.error && audio.error.code,
                    paused:audio.paused, duration:audio.duration, time:audio.currentTime,
                    ready:audio.readyState, network:audio.networkState});
                })()
                """)
            #expect(ended, "WebKit must decode and finish the real WAV: \(String(describing: diagnostic))")
        }
    }

    @Test func nativeSoundQueueFinishesTheLocalFile() async throws {
        let directory = try mediaDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        ReviewAudioSession.apply(playInSilent: true)
        defer { ReviewAudioSession.release() }
        let player = NativeCardAudioPlayer()
        defer { player.stop() }
        player.play(files: ["先生 space.wav"], mediaFolder: directory)
        #expect(player.isPlaying)
        let ended = try await wait { !player.isPlaying }
        #expect(ended)
    }

    @Test func mixedSpeechAndSoundQueueFinishesInOrderAndStopsWithoutAdvancing() async throws {
        let directory = try mediaDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withDependencies {
            $0.mediaClient.folderURL = { directory }
        } operation: {
            var playing = false
            let card = CardWebView(
                html: "[anki:tts lang=en_US]Hello[/anki:tts][sound:先生 space.wav][anki:tts lang=en_US]Goodbye[/anki:tts]",
                autoplayEnabled: false, onAudioStateChange: { playing = $0 }
            )
            let coordinator = card.makeCoordinator()
            let webView = card.makeWebView(coordinator: coordinator)
            let window = try host(webView)
            defer { window.isHidden = true; CardWebView.dismantleWebView(webView, coordinator: coordinator) }
            ReviewAudioSession.apply(playInSilent: true)
            defer { ReviewAudioSession.release() }
            card.updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelectorAll('.tts-btn').length === 2") as? Bool == true
            })
            _ = try await webView.evaluateJavaScript("amgiReplayAll('question')")
            try #require(try await wait { playing })
            let oldID = try #require(try await webView.evaluateJavaScript("amgiPendingTts?.requestID") as? String)
            _ = try await webView.evaluateJavaScript("amgiStopAllAudio(); amgiTtsFinished('\(oldID)')")
            try #require(try await wait { !playing })
            #expect(try await webView.evaluateJavaScript("!document.querySelector('#amgi-audio-queue-player').hasAttribute('src')") as? Bool == true)
            _ = try await webView.evaluateJavaScript("""
                window.completedPlayback = [];
                const finish = window.amgiTtsFinished;
                window.amgiTtsFinished = function(id) {
                    window.completedPlayback.push('tts');
                    finish(id);
                };
                document.querySelector('#amgi-audio-queue-player').addEventListener('ended', () => window.completedPlayback.push('sound'));
                amgiReplayAll('question');
                """)
            let finished = try await wait {
                try await webView.evaluateJavaScript("window.completedPlayback.length === 3 && !window.__amgiAudioPlaying") as? Bool == true
            }
            #expect(finished)
            #expect(try await webView.evaluateJavaScript("window.completedPlayback") as? [String] == ["tts", "sound", "tts"])
            #expect(!playing)
            let answerItems = try await webView.evaluateJavaScript("""
                window.__amgiQuestionAudioSrcs = new Set([amgiReplayKey(document.querySelector('.tts-btn'))]);
                collectAudioQueue('answerOnly').map(item => item.matches('.tts-btn') ? item.dataset.ttsText : 'sound');
                """) as? [String]
            #expect(answerItems == ["sound", "Goodbye"])
        }
    }

    private func mediaDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("card-playback-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let format = try #require(AVAudioFormat(
            commonFormat: .pcmFormatInt16, sampleRate: 22_050, channels: 1, interleaved: false
        ))
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 11_025))
        buffer.frameLength = buffer.frameCapacity
        try #require(buffer.int16ChannelData)[0].update(repeating: 0, count: Int(buffer.frameLength))
        let file = try AVAudioFile(
            forWriting: directory.appendingPathComponent("先生 space.wav"), settings: format.settings,
            commonFormat: .pcmFormatInt16, interleaved: false
        )
        try file.write(from: buffer)
        return directory
    }

    private func host(_ webView: WKWebView) throws -> UIWindow {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UIViewController()
        window.rootViewController?.view = webView
        window.isHidden = false
        return window
    }

    private func wait(_ condition: () async throws -> Bool) async throws -> Bool {
        for _ in 0..<100 {
            if try await condition() { return true }
            try await Task.sleep(for: .milliseconds(100))
        }
        return false
    }
}

extension CardPlaybackTests {
    @Test(arguments: [false, true])
    func kaishiMP3StopsOnFlipNextStopAndUnmount(autoplay: Bool) async throws {
        let directory = try mediaDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fixture = try #require(Bundle(for: MP3Fixture.self).url(forResource: "kaishi-probe", withExtension: "mp3"))
        for name in ["先生 space.mp3", "sentence.mp3"] {
            try FileManager.default.copyItem(at: fixture, to: directory.appendingPathComponent(name))
        }
        let backend = try AnkiBackend()
        try backend.openCollection(collectionPath: directory.appendingPathComponent("collection.anki2").path,
                                   mediaFolderPath: directory.appendingPathComponent("media").path,
                                   mediaDbPath: directory.appendingPathComponent("media.db").path)
        defer { try? backend.closeCollection() }
        try await withDependencies {
            $0.ankiBackend = backend
            $0.mediaClient.folderURL = { directory }
        } operation: {
            let client = NotetypesClient.liveValue
            let basic = try #require(try await client.listAll().first { $0.name == "Basic" })
            var notetype = try await client.get(basic.id)
            notetype.fields[0].name = "Word"
            notetype.fields[1].name = "Sentence"
            notetype.fields += [Notetype.Field(name: "Word Audio"), Notetype.Field(name: "Sentence Audio")]
            // Minimal Word/Sentence/audio layout from donkuri/Kaishi's documented templates.
            notetype.templates[0].config.qFormat = "<div lang=\"ja\">{{Word}}<div style='font-size:20px;'>{{Sentence}}</div></div>"
            notetype.templates[0].config.aFormat = "<div lang=\"ja\">{{Word}}<div style='font-size:25px;'>{{Sentence}}</div>{{Word Audio}}{{Sentence Audio}}</div>"
            try await client.update(notetype)
            notetype = try await client.get(basic.id)
            let rendered = try CardRenderingService.liveValue.renderUncommittedCard(
                notetype, 0, ["先生", "<b>先生</b>は来た。", "[sound:先生 space.mp3]", "[sound:sentence.mp3]"]
            )
            var playing = false
            let onState: (Bool) -> Void = { playing = $0 }
            @MainActor func makeAnswerCard(stop: Int = 0, replay: Int = 0) -> CardWebView {
                CardWebView(html: rendered.backHTML, autoplayEnabled: autoplay, isAnswerSide: true,
                            replayRequestID: replay, stopAudioRequestID: stop, replayMode: .answerOnly,
                            onAudioStateChange: onState)
            }
            let question = CardWebView(html: rendered.frontHTML, autoplayEnabled: false, onAudioStateChange: onState)
            let coordinator = question.makeCoordinator()
            let webView = question.makeWebView(coordinator: coordinator)
            let window = try host(webView)
            defer { window.isHidden = true; CardWebView.dismantleWebView(webView, coordinator: coordinator) }
            ReviewAudioSession.apply(playInSilent: true)
            defer { ReviewAudioSession.release() }
            question.updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelector('#qa')?.textContent.includes('先生')") as? Bool == true
            })
            #expect(try await webView.evaluateJavaScript("document.querySelectorAll('.anki-sound-audio').length") as? Int == 0)
            makeAnswerCard().updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelectorAll('.anki-sound-audio').length === 2") as? Bool == true
            })
            if !autoplay {
                _ = try await webView.evaluateJavaScript("document.querySelector('.sound-btn .replay-button').click()")
            }
            try #require(try await wait { playing })
            let selector = autoplay ? "#amgi-audio-queue-player" : ".anki-sound-audio"
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelector('\(selector)').duration >= 3.9 && document.querySelector('\(selector)').currentTime > 0") as? Bool == true
            })
            // Flip back while the previous audio element remains retained for the assertion.
            _ = try await webView.evaluateJavaScript("void(window.retiredAudio = document.querySelector('\(selector)'))")
            question.updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("window.retiredAudio.paused && !amgiCardState().isAnswerSide") as? Bool == true
            })
            makeAnswerCard().updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelectorAll('.anki-sound-audio').length === 2") as? Bool == true
            })
            _ = try await webView.evaluateJavaScript("document.querySelector('.sound-btn .replay-button').click()")
            try #require(try await wait { playing })
            makeAnswerCard(stop: 1).updateWebView(webView, coordinator: coordinator)
            try #require(try await wait { !playing })
            #expect(try await webView.evaluateJavaScript("Array.from(document.querySelectorAll('audio')).every(a => a.paused)") as? Bool == true)
            makeAnswerCard(stop: 1, replay: 1).updateWebView(webView, coordinator: coordinator)
            try #require(try await wait { playing })
            CardWebView(html: "<p>Next card</p>", autoplayEnabled: false, cardOrdinal: 1,
                        replayRequestID: 1, stopAudioRequestID: 1, onAudioStateChange: onState)
                .updateWebView(webView, coordinator: coordinator)
            try #require(try await wait { !playing })
            makeAnswerCard(stop: 1, replay: 1).updateWebView(webView, coordinator: coordinator)
            try #require(try await wait {
                try await webView.evaluateJavaScript("document.querySelectorAll('.anki-sound-audio').length === 2") as? Bool == true
            })
            _ = try await webView.evaluateJavaScript("document.querySelector('.sound-btn .replay-button').click()")
            try #require(try await wait { playing })
            CardWebView.dismantleWebView(webView, coordinator: coordinator)
            let stopped = try await wait {
                try await webView.evaluateJavaScript("Array.from(document.querySelectorAll('audio')).every(a => a.paused && a.currentTime === 0)") as? Bool == true
            }
            #expect(stopped, "Unmount must stop the real MP3 even while WebKit is retained")
            _ = try await webView.evaluateJavaScript("window.amgiStopAllAudio()")
        }
    }
}

private final class MP3Fixture: NSObject {}
