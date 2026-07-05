import AnkiKit
import AnkiClients
import Dependencies
import Foundation
import UIKit

/// Load/save state for editing an existing image-occlusion note. The View
/// owns the modal chrome and the occlusion-editor cover; the model owns the
/// note fetch, occlusion-string parsing, and the update write.
@Observable
@MainActor
final class EditImageOcclusionModel {
    var isLoading = true
    var loadError: String?
    var uiImage: UIImage?
    var masks: [IOMask] = []
    var header: String = ""
    var backExtra: String = ""
    var tagsText: String = ""
    var isSaving = false
    var saveError: String?

    @ObservationIgnored @Dependency(\.imageOcclusionClient) private var client
    @ObservationIgnored private let noteId: NoteID

    init(noteId: NoteID) {
        self.noteId = noteId
    }

    var canSave: Bool {
        !isLoading && !masks.isEmpty && !isSaving
    }

    func loadNote() async {
        isLoading = true
        loadError = nil
        do {
            let data = try await client.getNote(noteId)

            if let img = UIImage(data: data.imageData) {
                uiImage = img
            }

            header = data.header
            backExtra = data.backExtra
            tagsText = data.tags.joined(separator: " ")
            masks = parseMasks(from: data.occlusions)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    /// Persist the edited occlusions/fields/tags. Returns whether the write
    /// succeeded; on failure `saveError` carries the reason.
    func save() async -> Bool {
        guard !masks.isEmpty else { return false }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        let occlusions = masks.enumerated().map { idx, mask in
            mask.occlusionText(index: idx)
        }.joined(separator: "\n")
        let tags = tagsText.split(separator: " ").map(String.init).filter { !$0.isEmpty }

        do {
            try await client.updateNote(noteId, occlusions, header, backExtra, tags)
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }
}

// MARK: - Occlusion string parser

/// Parses "{{c1::image-occlusion:rect:left=X:top=Y:width=W:height=H}}" etc. → [IOMask]
private func parseMasks(from occlusions: String) -> [IOMask] {
    let lines = occlusions.components(separatedBy: "\n")
    var result: [IOMask] = []
    for line in lines {
        guard let payload = extractClozePayload(line) else { continue }
        let parts = payload.body.components(separatedBy: ":")
        guard parts.count >= 2, parts[0] == "image-occlusion" else { continue }
        let shapeName = parts[1]
        let stringProps = parseIOProperties(from: parts.dropFirst(2).joined(separator: ":"))
        switch shapeName {
        case "rect":
            if let l = ioCGFloat(stringProps["left"]), let t = ioCGFloat(stringProps["top"]),
               let w = ioCGFloat(stringProps["width"]), let h = ioCGFloat(stringProps["height"]) {
                result.append(
                    .rect(left: l, top: t, width: w, height: h, extras: ioExtras(from: stringProps, excluding: ["left", "top", "width", "height"]))
                        .applyingSerializationOrdinal(payload.ordinal)
                )
            }
        case "ellipse":
            if let l = ioCGFloat(stringProps["left"]), let t = ioCGFloat(stringProps["top"]),
               let rx = ioCGFloat(stringProps["rx"]), let ry = ioCGFloat(stringProps["ry"]) {
                result.append(
                    .ellipse(left: l, top: t, rx: rx, ry: ry, extras: ioExtras(from: stringProps, excluding: ["left", "top", "rx", "ry"]))
                        .applyingSerializationOrdinal(payload.ordinal)
                )
            }
        case "polygon":
            if let raw = stringProps["points"] {
                let coords = raw.components(separatedBy: CharacterSet(charactersIn: ", "))
                    .compactMap { Double($0) }
                var pts: [CGPoint] = []
                var i = 0
                while i + 1 < coords.count {
                    pts.append(CGPoint(x: coords[i], y: coords[i + 1]))
                    i += 2
                }
                if pts.count >= 3 {
                    result.append(
                        .polygon(points: pts, extras: ioExtras(from: stringProps, excluding: ["points"]))
                            .applyingSerializationOrdinal(payload.ordinal)
                    )
                }
            }
        case "text":
            if let l = ioCGFloat(stringProps["left"]),
               let t = ioCGFloat(stringProps["top"]),
               let text = stringProps["text"],
               !text.isEmpty {
                let scale = ioCGFloat(stringProps["scale"]) ?? 1
                let fontSize = ioCGFloat(stringProps["fs"]) ?? 0.055
                result.append(
                    .text(
                        left: l,
                        top: t,
                        text: text,
                        scale: scale,
                        fontSize: fontSize,
                        extras: ioExtras(from: stringProps, excluding: ["left", "top", "text", "scale", "fs"])
                    )
                    .applyingSerializationOrdinal(payload.ordinal)
                )
            }
        default:
            break
        }
    }
    return result
}

private func parseIOProperties(from source: String) -> [String: String] {
    guard !source.isEmpty,
          let regex = try? NSRegularExpression(pattern: "([A-Za-z]+)=") else {
        return [:]
    }

    let nsSource = source as NSString
    let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
    guard !matches.isEmpty else { return [:] }

    var properties: [String: String] = [:]
    for (index, match) in matches.enumerated() {
        let key = nsSource.substring(with: match.range(at: 1))
        let valueStart = match.range.location + match.range.length
        let valueEnd = index + 1 < matches.count ? matches[index + 1].range.location - 1 : nsSource.length
        guard valueEnd >= valueStart else { continue }
        let value = nsSource.substring(with: NSRange(location: valueStart, length: valueEnd - valueStart))
        properties[key] = value
    }
    return properties
}

private func ioCGFloat(_ value: String?) -> CGFloat? {
    guard let value, let numeric = Double(value) else { return nil }
    return CGFloat(numeric)
}

private func ioExtras(from properties: [String: String], excluding keys: Set<String>) -> [String: String] {
    properties.filter { !keys.contains($0.key) }
}

private struct IOClozePayload {
    let ordinal: Int?
    let body: String
}

private func extractClozePayload(_ cloze: String) -> IOClozePayload? {
    // "{{c1::image-occlusion:...}}" → ordinal=1, body="image-occlusion:..."
    guard cloze.hasPrefix("{{"), cloze.hasSuffix("}}") else { return nil }
    let inner = String(cloze.dropFirst(2).dropLast(2))
    guard let colonIdx = inner.range(of: "::") else { return nil }
    let ordinalText = inner[..<colonIdx.lowerBound]
        .drop { $0 == "c" || $0 == "C" }
    let ordinal = Int(ordinalText)
    return IOClozePayload(ordinal: ordinal, body: String(inner[colonIdx.upperBound...]))
}
