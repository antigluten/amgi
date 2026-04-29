import SwiftUI
import AnkiClients
import AmgiTheme
import Dependencies

// MARK: - EditImageOcclusionNoteView

struct EditImageOcclusionNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Dependency(\.imageOcclusionClient) private var client

    let noteId: Int64
    let onSave: () -> Void
    let embedInNavigationStack: Bool

    @State private var isLoading = true
    @State private var loadError: String?
    @State private var uiImage: UIImage?
    @State private var masks: [IOMask] = []
    @State private var header: String = ""
    @State private var backExtra: String = ""
    @State private var tagsText: String = ""
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showOcclusionEditor = false

    init(noteId: Int64, onSave: @escaping () -> Void, embedInNavigationStack: Bool = true) {
        self.noteId = noteId
        self.onSave = onSave
        self.embedInNavigationStack = embedInNavigationStack
    }

    var body: some View {
        Group {
            if embedInNavigationStack {
                NavigationStack {
                    editorBody
                }
            } else {
                editorBody
            }
        }
    }

    private var editorBody: some View {
        Group {
            Group {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let err = loadError {
                    AmgiStatusMessageView(
                        title: "Error",
                        message: err,
                        systemImage: "exclamationmark.triangle",
                        tone: .warning
                    )
                } else {
                    Form {
                        if let img = uiImage {
                            Section {
                                ImageOcclusionMaskSummaryCard(image: img, masks: masks) {
                                    showOcclusionEditor = true
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                            } header: {
                                Text("Masks")
                            } footer: {
                                Text("Tap and drag to draw a mask. Drag handles to resize.")
                                    .amgiFont(.caption)
                                    .foregroundStyle(palette.textSecondary)
                            }
                        }

                        // MARK: Text fields
                        Section("Content") {
                            TextField("Header", text: $header)
                            TextField("Extra info shown on the back", text: $backExtra)
                        }

                        Section {
                            TextField("Tags", text: $tagsText)
                        } header: {
                            Text("Tags")
                        } footer: {
                            Text("Space-separated")
                                .amgiFont(.caption)
                                .foregroundStyle(palette.textSecondary)
                        }

                        if let err = saveError {
                            Section {
                                Text(err)
                                    .amgiStatusText(.danger, font: .caption)
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(palette.background)
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("Edit Image Occlusion")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if embedInNavigationStack {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    Task { await save() }
                }
                .amgiToolbarTextButton()
                .disabled(isLoading || masks.isEmpty || isSaving)
                .overlay { if isSaving { ProgressView().scaleEffect(0.7) } }
            }
        }
        .fullScreenCover(isPresented: $showOcclusionEditor) {
            if let uiImage {
                NavigationStack {
                    ImageOcclusionWorkspaceView(
                        title: "Edit",
                        image: uiImage,
                        initialMasks: masks
                    ) { updatedMasks in
                        masks = updatedMasks
                    }
                }
            }
        }
        .task { await loadNote() }
    }

    @MainActor
    private func loadNote() async {
        isLoading = true
        loadError = nil
        do {
            let data = try client.getNote(noteId)

            // Decode image
            if let img = UIImage(data: data.imageData) {
                uiImage = img
            }

            // Parse header/backExtra/tags
            header = data.header
            backExtra = data.backExtra
            tagsText = data.tags.joined(separator: " ")

            // Parse occlusion string back to IOMask array
            masks = parseMasks(from: data.occlusions)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func save() async {
        guard !masks.isEmpty else { return }
        isSaving = true
        saveError = nil
        let occlusions = masks.enumerated().map { idx, mask in
            mask.occlusionText(index: idx)
        }.joined(separator: "\n")
        let tags = tagsText.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        do {
            try client.updateNote(noteId, occlusions, header, backExtra, tags)
            onSave()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
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
