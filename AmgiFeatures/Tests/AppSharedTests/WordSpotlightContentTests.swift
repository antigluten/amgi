import AppCore
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import Testing
@testable import AppShared

@MainActor
@Suite(.serialized) struct WordSpotlightContentTests {
    private func note(_ fields: String) -> NoteRecord {
        NoteRecord(id: NoteID(42), guid: "", mid: NotetypeID(1), mod: 0, flds: fields, sfld: "", csum: 0)
    }

    private var preferences: WordSpotlightPreferences {
        var preferences = WordSpotlightPreferences()
        preferences.deckID = 1
        preferences.notetypeID = 1
        preferences.termField = "Expression"
        preferences.readingField = "Reading"
        preferences.meaningField = "Definition"
        return preferences
    }

    @Test func usesMappedFieldsAndStripsMarkupAndMedia() {
        let word = WordSpotlightSource.word(
            from: note("<b>猫</b>[sound:cat.mp3]\u{1f}ねこ\u{1f}<p>A cat</p><p>A feline</p><script>bad()</script>"),
            fields: ["Expression", "Reading", "Definition"], preferences: preferences
        )
        #expect(word?.term == "猫")
        #expect(word?.reading == "ねこ")
        #expect(word?.meaning == "A cat\nA feline")
    }

    @Test func skipsMediaOnlyClozeAndMissingFields() {
        for content in ["<img src='cat.png'>\u{1f}ねこ\u{1f}cat", "{{c1::cat}}\u{1f}\u{1f}cat", "cat"] {
            #expect(WordSpotlightSource.word(
                from: note(content), fields: ["Expression", "Reading", "Definition"], preferences: preferences
            ) == nil)
        }
    }

    @Test func previewUsesDraftMappingWithoutEnablingIt() async throws {
        let profileID = AccountStore.shared.selectedID
        let saved = WordSpotlightStore.preferences(profileID: profileID)
        let snapshot = WordSpotlightStore.read()?.word(on: .now)
        let sample = note("猫\u{1f}ねこ\u{1f}A cat")
        let notetype = Notetype(id: NotetypeID(1), fields: [
            .init(name: "Expression"), .init(name: "Reading"), .init(name: "Definition"),
        ])
        try await withDependencies {
            $0.deckClient.fetchAll = { [DeckInfo(id: DeckID(1), name: "Vocabulary")] }
            $0.notetypesClient.get = { _ in notetype }
            $0.noteClient.searchAll = { query, limit in
                #expect(query == #"deck:"Vocabulary" mid:1 -is:suspended -is:buried"#)
                #expect(limit == 500)
                return [sample]
            }
        } operation: {
            let controller = WordSpotlightController()
            let words = try await controller.preview(preferences, profileID: profileID)
            #expect(words.first?.term == "猫")
            #expect(controller.currentWord == nil)
            #expect(WordSpotlightStore.preferences(profileID: profileID) == saved)
            #expect(WordSpotlightStore.read()?.word(on: .now) == snapshot)
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func failedAdvancePreservesWordAndWidgetSnapshot() async throws {
        let profileID = AccountStore.shared.selectedID
        let defaults = UserDefaults.standard
        let keys = ["wordOfDay.\(profileID)", "wordOfDay.rotation.\(profileID)"]
        let saved = keys.map { defaults.data(forKey: $0) }
        let snapshot = WordSpotlightStore.read()
        defer {
            if let snapshot { try? WordSpotlightStore.write(snapshot) } else { try? WordSpotlightStore.clear() }
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        try WordSpotlightStore.save(preferences, profileID: profileID)
        let sample = note("猫\u{1f}ねこ\u{1f}A cat")
        let notetype = Notetype(id: NotetypeID(1), fields: [
            .init(name: "Expression"), .init(name: "Reading"), .init(name: "Definition"),
        ])
        try await withDependencies {
            $0.deckClient.fetchAll = { [DeckInfo(id: DeckID(1), name: "Vocabulary")] }
            $0.notetypesClient.get = { _ in notetype }
            $0.noteClient.searchAll = { _, _ in [sample] }
        } operation: {
            let controller = WordSpotlightController()
            #expect(await controller.refresh())
            let original = controller.currentWord
            #expect(original?.noteID == 42)
            #expect(!controller.canAdvance)
            let requests = AsyncStream<Void>.makeStream()
            defer { requests.continuation.finish() }
            try await withDependencies {
                $0.noteClient.searchAll = { _, _ in
                    requests.continuation.yield()
                    try await Task.sleep(for: .milliseconds(50))
                    return [sample]
                }
            } operation: {
                let save = Task { await controller.save(preferences, profileID: profileID) }
                var iterator = requests.stream.makeAsyncIterator()
                await iterator.next()
                let foreground = Task { await controller.refresh() }
                let saved = await save.value
                #expect(saved)
                #expect(await foreground.value)
            }
            await withDependencies {
                $0.noteClient.searchAll = { _, _ in throw CocoaError(.fileReadUnknown) }
            } operation: {
                #expect(await controller.refresh(advance: true) == false)
                #expect(controller.currentWord == original)
                #expect(WordSpotlightStore.read()?.word(on: .now) == original)
                #expect(controller.error != nil)
            }
        }
    }

    @Test(arguments: [false, true])
    func reminderPrivacySavesWhenSourceIsUnavailable(keepNotifications: Bool) async throws {
        let profileID = AccountStore.shared.selectedID
        let key = "wordOfDay.\(profileID)"
        let original = UserDefaults.standard.data(forKey: key)
        defer { UserDefaults.standard.set(original, forKey: key) }
        var saved = preferences
        saved.notifications = true
        try WordSpotlightStore.save(saved, profileID: profileID)
        var updated = saved
        updated.notifications = keepNotifications
        updated.showWord = false

        try await withDependencies {
            $0.deckClient.fetchAll = { throw CocoaError(.fileReadUnknown) }
        } operation: {
            let controller = WordSpotlightController()
            #expect(await controller.save(updated, profileID: profileID))
            let persisted = WordSpotlightStore.preferences(profileID: profileID)
            #expect(persisted.notifications == keepNotifications)
            #expect(!persisted.showWord)
            #expect(persisted.sourceID == saved.sourceID)
        }
    }

    @Test func failedSourceSaveRestoresPreferences() async throws {
        try await preservingStoredState { profileID in
            try WordSpotlightStore.save(preferences, profileID: profileID)
            var changed = preferences
            changed.notetypeID = 99
            await withDependencies {
                $0.deckClient.fetchAll = { throw CocoaError(.fileReadUnknown) }
            } operation: {
                let controller = WordSpotlightController()
                #expect(await controller.save(changed, profileID: profileID) == false)
                #expect(WordSpotlightStore.preferences(profileID: profileID) == preferences)
                #expect(controller.error != nil)
            }
        }
    }

    @Test(.timeLimit(.minutes(1)))
    func profileSwitchRejectsASuspendedRefreshAndRetainsItsRotationAnchor() async throws {
        try await preservingStoredState { profileID in
            try WordSpotlightStore.save(preferences, profileID: profileID)
            let word = SpotlightWord(noteID: 42, term: "cat", reading: "", meaning: "A cat")
            try WordSpotlightStore.write(WordSpotlightSchedule.make(
                profileID: profileID, source: preferences.sourceID, words: [word], previous: nil
            ))
            let started = AsyncStream<Void>.makeStream()
            let release = AsyncStream<Void>.makeStream()
            defer {
                started.continuation.finish()
                release.continuation.finish()
            }
            let sample = note("cat\u{1f}cat\u{1f}A cat")
            await withDependencies {
                $0.deckClient.fetchAll = { [DeckInfo(id: DeckID(1), name: "Vocabulary")] }
                $0.notetypesClient.get = { _ in
                    Notetype(id: NotetypeID(1), fields: [
                        .init(name: "Expression"), .init(name: "Reading"), .init(name: "Definition"),
                    ])
                }
                $0.noteClient.searchAll = { _, _ in
                    started.continuation.yield()
                    var iterator = release.stream.makeAsyncIterator()
                    await iterator.next()
                    return [sample]
                }
            } operation: {
                let controller = WordSpotlightController()
                let refresh = Task { await controller.refresh() }
                var iterator = started.stream.makeAsyncIterator()
                await iterator.next()
                controller.beginProfileSwitch()
                release.continuation.yield()
                #expect(await refresh.value == false)
                #expect(controller.currentWord == nil)
                #expect(WordSpotlightStore.read() == nil)
                #expect(WordSpotlightStore.rotation(profileID: profileID)?.word(on: .now)?.noteID == 42)
            }
        }
    }

    @Test func foreignProfileLinksAreRejectedBeforeFetchingNotes() async {
        let controller = WordSpotlightController()
        let link = WordSpotlightLink(profileID: UUID().uuidString, noteID: 42)
        await #expect(throws: WordSpotlightError.self) {
            try await controller.loadWord(link)
        }
    }

    private func preservingStoredState(_ operation: (String) async throws -> Void) async rethrows {
        let profileID = AccountStore.shared.selectedID
        let defaults = UserDefaults.standard
        let keys = ["wordOfDay.\(profileID)", "wordOfDay.rotation.\(profileID)"]
        let saved = keys.map { defaults.data(forKey: $0) }
        let snapshot = WordSpotlightStore.read()
        defer {
            if let snapshot { try? WordSpotlightStore.write(snapshot) }
            else { try? WordSpotlightStore.clear() }
            for (key, value) in zip(keys, saved) { defaults.set(value, forKey: key) }
        }
        try await operation(profileID)
    }
}
