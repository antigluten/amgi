import AppCore
import AppShared
import AnkiClients
import AnkiKit
import Dependencies
import Foundation
import Testing
@testable import SettingsFeature

@MainActor
@Suite(.serialized)
struct WordSpotlightSettingsTests {
    @Test func retryPreservesTheFailedRotationChoice() async throws {
        let profileID = AccountStore.shared.selectedID
        let keys = ["wordOfDay.\(profileID)", "wordOfDay.rotation.\(profileID)"]
        let saved = keys.map { UserDefaults.standard.data(forKey: $0) }
        let snapshot = WordSpotlightStore.read()
        defer {
            if let snapshot { try? WordSpotlightStore.write(snapshot) }
            else { try? WordSpotlightStore.clear() }
            for (key, value) in zip(keys, saved) { UserDefaults.standard.set(value, forKey: key) }
        }
        var preferences = WordSpotlightPreferences()
        preferences.deckID = 11
        preferences.notetypeID = 12
        preferences.termField = "Front"
        preferences.meaningField = "Back"
        try WordSpotlightStore.save(preferences, profileID: profileID)
        let failing = LockIsolated(true)
        await withDependencies {
            $0.deckClient.fetchAll = {
                if failing.value { throw CocoaError(.fileReadUnknown) }
                return [DeckInfo(id: DeckID(11), name: "Vocabulary")]
            }
            $0.notetypesClient.get = { _ in
                Notetype(id: NotetypeID(12), fields: [.init(name: "Front"), .init(name: "Back")])
            }
            $0.noteClient.searchAll = { _, _ in
                [NoteRecord(id: NoteID(42), guid: "", mid: NotetypeID(12), mod: 0,
                            flds: "cat\u{1f}A cat", sfld: "", csum: 0)]
            }
        } operation: {
            let model = WordSpotlightSettingsModel(controller: WordSpotlightController())
            model.profileID = profileID
            model.savedPreferences = preferences
            model.preferences = preferences
            model.preferences.intervalHours = 3
            await model.saveOptions()
            #expect(model.error != nil)
            #expect(model.preferences.rotationHours == 24)
            #expect(WordSpotlightStore.preferences(profileID: profileID).rotationHours == 24)
            failing.setValue(false)
            await model.retry()
            #expect(model.error == nil)
            #expect(model.preferences.rotationHours == 3)
            #expect(WordSpotlightStore.preferences(profileID: profileID).rotationHours == 3)
        }
    }

    @Test func sourceCanOnlyBeSavedAfterItsCurrentMappingHasAPreview() async {
        await withDependencies {
            $0.deckClient.fetchAll = { [DeckInfo(id: DeckID(11), name: "Vocabulary")] }
            $0.notetypesClient.listAll = { [NotetypeNameId(id: NotetypeID(12), name: "Basic")] }
            $0.notetypesClient.get = { _ in
                Notetype(id: NotetypeID(12), fields: [.init(name: "Front"), .init(name: "Back")])
            }
            $0.noteClient.searchAll = { _, _ in
                [NoteRecord(id: NoteID(42), guid: "", mid: NotetypeID(12), mod: 0,
                            flds: "cat\u{1f}A cat", sfld: "", csum: 0)]
            }
        } operation: {
            let model = WordSpotlightSettingsModel()
            model.profileID = AccountStore.shared.selectedID
            await model.load()
            model.preferences.deckID = 11
            model.preferences.notetypeID = 12
            model.preferences.termField = "Front"
            model.preferences.meaningField = "Back"
            model.preferences.readingField = ""
            #expect(!model.canSaveSource)
            await model.loadPreview()
            #expect(model.canSaveSource)
            model.preferences.meaningField = "Missing"
            #expect(!model.canSaveSource)
            await model.loadPreview()
            #expect(!model.canSaveSource)
            model.preferences.meaningField = "Back"
            await model.loadPreview()
            #expect(model.canSaveSource)
        }
    }

    @Test(arguments: ["decks", "notetypes", "fields"])
    func retryReloadsPickersAfterInitialLoadFails(stage: String) async {
        let failing = LockIsolated(true)
        await withDependencies {
            $0.deckClient.fetchAll = {
                if failing.value && stage == "decks" { throw CocoaError(.fileReadUnknown) }
                return [DeckInfo(id: DeckID(11), name: "Vocabulary")]
            }
            $0.notetypesClient.listAll = {
                if failing.value && stage == "notetypes" { throw CocoaError(.fileReadUnknown) }
                return [NotetypeNameId(id: NotetypeID(12), name: "Basic")]
            }
            $0.notetypesClient.get = { _ in
                if failing.value && stage == "fields" { throw CocoaError(.fileReadUnknown) }
                return Notetype(id: NotetypeID(12), fields: [.init(name: "Front"), .init(name: "Back")])
            }
        } operation: {
            let model = WordSpotlightSettingsModel()
            model.profileID = AccountStore.shared.selectedID
            await model.load()
            #expect(model.error != nil)
            if stage == "decks" {
                model.preferences.notetypeID = 12
                await model.loadFields()
                #expect(model.error != nil)
            }
            failing.setValue(false)
            await model.retry()
            #expect(model.error == nil)
            #expect(model.decks.map(\.name) == ["Vocabulary"])
            #expect(model.notetypes.map(\.name) == ["Basic"])
            #expect(model.fields == ["Front", "Back"])
            #expect(!model.isLoading)
        }
    }
}
