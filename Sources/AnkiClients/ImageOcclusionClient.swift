public import AnkiKit
public import Dependencies
import DependenciesMacros
public import Foundation

@DependencyClient
public struct ImageOcclusionClient: Sendable {
    /// Creates an image occlusion note from the given source image path.
    /// The client is responsible for selecting the target deck/current deck state
    /// before delegating to the backend image-occlusion add flow.
    public var addNote: @Sendable (
        _ imageURL: URL,
        _ occlusions: String,
        _ header: String,
        _ backExtra: String,
        _ tags: [String],
        _ deckID: DeckID,
        _ notetypeID: NotetypeID
    ) throws -> Void

    /// Ensures the image-occlusion notetype exists in the collection.
    /// Safe to call multiple times — Anki skips creation if it already exists.
    public var ensureNotetype: @Sendable () throws -> Void

    /// Fetches an existing image occlusion note for editing.
    /// Returns (imageData, imageName, occlusions, header, backExtra, tags).
    public var getNote: @Sendable (_ noteId: NoteID) throws -> ImageOcclusionNoteData

    /// Updates an existing image occlusion note.
    public var updateNote: @Sendable (
        _ noteId: NoteID,
        _ occlusions: String,
        _ header: String,
        _ backExtra: String,
        _ tags: [String]
    ) throws -> Void
}

extension ImageOcclusionClient: TestDependencyKey {
    public static let testValue = ImageOcclusionClient()
}

extension DependencyValues {
    public var imageOcclusionClient: ImageOcclusionClient {
        get { self[ImageOcclusionClient.self] }
        set { self[ImageOcclusionClient.self] = newValue }
    }
}
