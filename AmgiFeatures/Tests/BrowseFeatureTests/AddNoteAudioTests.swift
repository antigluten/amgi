import Foundation
import Dependencies
import Testing
@testable import BrowseFeature

@Suite("Add note voice attachments")
@MainActor
struct AddNoteAudioTests {
    private func model() -> AddNoteModel {
        let model = AddNoteModel()
        model.fieldNames = ["Front", "Back"]
        model.fieldValues = ["", ""]
        model.fieldAudio = [[], []]
        return model
    }

    private func recording() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("amgi-voice-\(UUID().uuidString).m4a")
        try Data([1, 2, 3]).write(to: url)
        return url
    }

    @Test("a voice-only note is addable and requires discard confirmation")
    func audioOnlyNote() throws {
        let model = model()
        #expect(!model.canAdd)
        let url = try recording()
        defer { model.discardAudio() }
        model.attachAudio(url, toField: 0)
        #expect(model.canAdd)
        #expect(model.hasUnsavedChanges)
        model.isSaving = true
        #expect(!model.canAdd)
    }

    @Test("saving is blocked while note-type fields are loading")
    func loadingFieldsBlocksSave() async throws {
        let model = model()
        let url = try recording()
        defer { model.discardAudio() }
        model.attachAudio(url, toField: 0)
        model.isLoadingFields = true
        #expect(!model.canAdd)
        let saved = await model.save()
        #expect(!saved)
        model.isLoadingFields = false
        #expect(model.canAdd)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    @Test("removing a clip deletes only that attachment")
    func removeOneClip() throws {
        let model = model()
        let first = try recording()
        let second = try recording()
        defer { model.discardAudio() }
        model.attachAudio(first, toField: 0)
        model.attachAudio(second, toField: 0)
        model.removeAudio(first, fromField: 0)
        #expect(model.fieldAudio[0] == [second])
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test("discard removes temporary files and clears attachments")
    func discardCleansFiles() throws {
        let model = model()
        let url = try recording()
        model.attachAudio(url, toField: 1)
        model.discardAudio()
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!model.hasAudio)
        #expect(!model.canAdd)
    }

    @Test("changing note type keeps named fields and removes dropped recordings")
    func noteTypeChange() throws {
        let model = model()
        let front = try recording()
        let back = try recording()
        defer { model.discardAudio() }
        model.attachAudio(front, toField: 0)
        model.attachAudio(back, toField: 1)
        model.reconcileAudio(with: ["Back", "Extra"])
        #expect(model.fieldAudio == [[back], []])
        #expect(!FileManager.default.fileExists(atPath: front.path))
        #expect(FileManager.default.fileExists(atPath: back.path))
    }

    @Test("an attachment for a missing field is deleted rather than orphaned")
    func staleField() throws {
        let model = model()
        let url = try recording()
        model.attachAudio(url, toField: 5)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!model.hasAudio)
    }

    @Test("media markers target the right fields and retries reuse filenames")
    func markersAndRetries() async throws {
        let url = try recording()
        let writes = MediaWrites()
        try await withDependencies {
            $0.mediaClient.save = { data, filename in
                await writes.append(data: data, filename: filename)
            }
        } operation: {
            let model = model()
            defer { model.discardAudio() }
            model.fieldValues = ["hello", "world"]
            model.attachAudio(url, toField: 1)
            let first = try await model.fieldsWithAudio()
            let retry = try await model.fieldsWithAudio()
            #expect(first == ["hello", "world [sound:\(url.lastPathComponent)]"])
            #expect(retry == first)
            let saved = await writes.filenames
            #expect(saved == [url.lastPathComponent, url.lastPathComponent])
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test("a failed media write keeps the recording for retry")
    func failedWriteRetainsAudio() async throws {
        let url = try recording()
        try await withDependencies {
            $0.mediaClient.save = { _, _ in throw AudioTestFailure.write }
        } operation: {
            let model = model()
            defer { model.discardAudio() }
            model.attachAudio(url, toField: 0)
            await #expect(throws: AudioTestFailure.self) {
                _ = try await model.fieldsWithAudio()
            }
            #expect(model.fieldAudio[0] == [url])
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }
}

private enum AudioTestFailure: Error { case write }

private actor MediaWrites {
    var filenames: [String] = []
    func append(data: Data, filename: String) { filenames.append(filename) }
}
