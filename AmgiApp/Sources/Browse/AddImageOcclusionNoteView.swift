import SwiftUI
import PhotosUI
import AmgiTheme
import AnkiKit
import AnkiClients
import AnkiServices
import Dependencies

// MARK: - AddImageOcclusionNoteView

struct AddImageOcclusionNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette
    @Dependency(\.deckClient) private var deckClient
    @Dependency(\.decksService) private var decksService
    @Dependency(\.imageOcclusionClient) private var client

    @State private var decks: [DeckInfo] = []
    @State private var selectedDeckId: Int64
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var masks: [IOMask] = []
    @State private var header: String = ""
    @State private var backExtra: String = ""
    @State private var tagsText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var imageURL: URL?
    @State private var showOcclusionEditor = false

    let onSave: () -> Void
    let preselectedDeckId: Int64?

    init(onSave: @escaping () -> Void, preselectedDeckId: Int64? = nil) {
        self.onSave = onSave
        self.preselectedDeckId = preselectedDeckId
        _selectedDeckId = State(initialValue: preselectedDeckId ?? 0)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Deck") {
                    Picker("Deck", selection: $selectedDeckId) {
                        ForEach(decks) { deck in
                            Text(deck.name).tag(deck.id)
                        }
                    }
                }

                Section {
                    Text("Add Image Occlusion")
                        .foregroundStyle(palette.textPrimary)
                } header: {
                    Text("Note Type")
                } footer: {
                    Text("Pick an image, draw occlusions over the regions you want to test, then save.")
                        .amgiFont(.caption)
                        .foregroundStyle(palette.textSecondary)
                }

                Section {
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            "Pick image",
                            systemImage: selectedImage == nil ? "photo.on.rectangle.angled" : "photo.badge.plus"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: selectedItem) {
                        Task { await loadImage(from: selectedItem) }
                    }
                } header: {
                    Text("Image")
                }

                if let uiImage = selectedImage {
                    Section {
                        ImageOcclusionMaskSummaryCard(image: uiImage, masks: masks) {
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

                // MARK: Error
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .amgiStatusText(.danger, font: .caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .toolbar(.hidden, for: .tabBar)
            .navigationTitle("Image Occlusion")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadDecks()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .amgiToolbarTextButton()
                    .disabled(!canSave || isSaving)
                    .overlay {
                        if isSaving { ProgressView().scaleEffect(0.7) }
                    }
                }
            }
            .fullScreenCover(isPresented: $showOcclusionEditor) {
                if let selectedImage {
                    NavigationStack {
                        ImageOcclusionWorkspaceView(
                            title: "Edit",
                            image: selectedImage,
                            initialMasks: masks
                        ) { updatedMasks in
                            masks = updatedMasks
                        }
                    }
                }
            }
        }
    }

    // In Anki's IO notetype, occlusions are the first required field; header is a later optional field.
    private var canSave: Bool {
        selectedDeckId != 0 && selectedImage != nil && imageURL != nil && !masks.isEmpty
    }

    @MainActor
    private func loadDecks() async {
        decks = (try? deckClient.fetchAll()) ?? []

        if let preselectedDeckId, decks.contains(where: { $0.id == preselectedDeckId }) {
            selectedDeckId = preselectedDeckId
            return
        }

        if let currentDeckId = try? currentDeckID(), decks.contains(where: { $0.id == currentDeckId }) {
            selectedDeckId = currentDeckId
            return
        }

        if let firstDeck = decks.first {
            selectedDeckId = firstDeck.id
        }
    }

    private func currentDeckID() throws -> Int64 {
        let currentDeck = try decksService.getCurrentDeck()
        return currentDeck.id
    }

    @MainActor
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        self.masks = []

        // Load as UIImage
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            selectedImage = img

            // Write a temporary file for the upload path
            let tempDir = FileManager.default.temporaryDirectory
            let filename = "io_pick_\(Int(Date().timeIntervalSince1970)).jpg"
            let url = tempDir.appendingPathComponent(filename)
            if let jpegData = img.jpegData(compressionQuality: 0.92) {
                try? jpegData.write(to: url)
                imageURL = url
            }
        }
    }

    @MainActor
    private func save() async {
        guard selectedDeckId != 0 else {
            return
        }
        guard let url = imageURL else {
            errorMessage = "Image is missing."
            return
        }
        guard !masks.isEmpty else {
            errorMessage = "Add at least one mask before saving."
            return
        }
        isSaving = true
        errorMessage = nil

        let occlusions = masks.enumerated().map { idx, mask in
            mask.occlusionText(index: idx)
        }.joined(separator: "\n")
        let tags = tagsText.split(separator: " ").map(String.init).filter { !$0.isEmpty }

        do {
            try client.addNote(url, occlusions, header, backExtra, tags, selectedDeckId, 0)
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}
