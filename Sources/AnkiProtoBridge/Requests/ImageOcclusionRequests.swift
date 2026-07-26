import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - addImageOcclusionNotetype / addImageOcclusionNote / updateImageOcclusionNote

extension Request where Response == Void {
    /// Ensures the image-occlusion notetype exists in the collection.
    /// Safe to call multiple times — Anki skips creation if present.
    public static var addImageOcclusionNotetype: Self {
        .empty(
            serviceId: ServiceID.imageOcclusion,
            methodId: ImageOcclusionMethod.addImageOcclusionNotetype,
            decode: { _ in () }
        )
    }

    /// Creates an image-occlusion note. The backend imports the source
    /// image into media and saves the note into the *current* deck —
    /// callers must `setCurrentDeck` first.
    public static func addImageOcclusionNote(
        imagePath: String,
        occlusions: String,
        header: String,
        backExtra: String,
        tags: [String],
        notetypeId: NotetypeID
    ) -> Self {
        Self(
            serviceId: ServiceID.imageOcclusion,
            methodId: ImageOcclusionMethod.addImageOcclusionNote,
            encode: {
                var proto = Anki_ImageOcclusion_AddImageOcclusionNoteRequest()
                proto.imagePath = imagePath
                proto.occlusions = occlusions
                proto.header = header
                proto.backExtra = backExtra
                proto.tags = tags
                proto.notetypeID = notetypeId.rawValue
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Updates an existing image-occlusion note.
    public static func updateImageOcclusionNote(
        noteId: NoteID,
        occlusions: String,
        header: String,
        backExtra: String,
        tags: [String]
    ) -> Self {
        Self(
            serviceId: ServiceID.imageOcclusion,
            methodId: ImageOcclusionMethod.updateImageOcclusionNote,
            encode: {
                var proto = Anki_ImageOcclusion_UpdateImageOcclusionNoteRequest()
                proto.noteID = noteId.rawValue
                proto.occlusions = occlusions
                proto.header = header
                proto.backExtra = backExtra
                proto.tags = tags
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}

// MARK: - getImageOcclusionNote

extension Request where Response == ImageOcclusionNoteData {
    /// Fetches an existing image-occlusion note for editing. Throws
    /// `BackendError(kind: .notFoundError)` if the backend's response
    /// is the negative variant (`error` field instead of `note`).
    public static func getImageOcclusionNote(noteId: NoteID) -> Self {
        Self(
            serviceId: ServiceID.imageOcclusion,
            methodId: ImageOcclusionMethod.getImageOcclusionNote,
            encode: {
                var proto = Anki_ImageOcclusion_GetImageOcclusionNoteRequest()
                proto.noteID = noteId.rawValue
                return try proto.serializedData()
            },
            decode: { bytes in
                let resp = try Anki_ImageOcclusion_GetImageOcclusionNoteResponse(serializedBytes: bytes)
                guard case .note(let note) = resp.value else {
                    throw BackendError(kind: .notFoundError, message: "Image occlusion note not found")
                }
                return ImageOcclusionNoteData(
                    imageData: note.imageData,
                    imageName: note.imageFileName,
                    occlusions: occlusionsString(note.occlusions),
                    header: note.header,
                    backExtra: note.backExtra,
                    tags: note.tags
                )
            }
        )
    }
}

/// Reconstructs the cloze-syntax occlusion string from the proto's
/// structured shape list, matching the format the editor produces:
/// `{{cN::image-occlusion:<shape>[:k=v:...]}}` per occlusion, joined
/// with newlines.
private func occlusionsString(_ occlusions: [Anki_ImageOcclusion_GetImageOcclusionNoteResponse.ImageOcclusion]) -> String {
    occlusions.enumerated().map { (i, occ) -> String in
        let n = occ.ordinal > 0 ? Int(occ.ordinal) : (i + 1)
        guard let shape = occ.shapes.first else { return "" }
        let propertyTokens = shape.properties.map { "\($0.name)=\($0.value)" }.joined(separator: ":")
        let suffix = propertyTokens.isEmpty ? "" : ":\(propertyTokens)"
        return "{{c\(n)::image-occlusion:\(shape.shape)\(suffix)}}"
    }
    .filter { !$0.isEmpty }
    .joined(separator: "\n")
}
