import AnkiBackend
import AnkiKit
import AnkiProtoBridge
public import Dependencies
import Foundation

extension ImageOcclusionClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            addNote: { imageURL, occlusions, header, backExtra, tags, deckID, notetypeID in
                // 1. Ensure the notetype exists.
                try backend.invoke(.addImageOcclusionNotetype)

                // 2. IO note creation saves into the backend's current deck.
                try backend.invoke(.setCurrentDeck(deckId: deckID))

                // 3. Let the backend import the selected source file into media.
                try backend.invoke(.addImageOcclusionNote(
                    imagePath: imageURL.path,
                    occlusions: occlusions,
                    header: header,
                    backExtra: backExtra,
                    tags: tags,
                    notetypeId: notetypeID
                ))
            },

            ensureNotetype: {
                try backend.invoke(.addImageOcclusionNotetype)
            },

            getNote: { noteId in
                try backend.invoke(.getImageOcclusionNote(noteId: noteId))
            },

            updateNote: { noteId, occlusions, header, backExtra, tags in
                try backend.invoke(.updateImageOcclusionNote(
                    noteId: noteId,
                    occlusions: occlusions,
                    header: header,
                    backExtra: backExtra,
                    tags: tags
                ))
            }
        )
    }()
}
