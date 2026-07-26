public import Foundation

/// Full payload for an image-occlusion note, surfaced by the
/// `getImageOcclusionNote` backend RPC. The `occlusions` string is the
/// Anki cloze-syntax representation reconstructed from the proto's
/// structured shapes.
public struct ImageOcclusionNoteData: Sendable {
    public var imageData: Data
    public var imageName: String
    public var occlusions: String
    public var header: String
    public var backExtra: String
    public var tags: [String]

    public init(
        imageData: Data,
        imageName: String,
        occlusions: String,
        header: String,
        backExtra: String,
        tags: [String]
    ) {
        self.imageData = imageData
        self.imageName = imageName
        self.occlusions = occlusions
        self.header = header
        self.backExtra = backExtra
        self.tags = tags
    }
}
