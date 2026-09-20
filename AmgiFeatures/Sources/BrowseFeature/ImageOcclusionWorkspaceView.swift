//
//  ImageOcclusionWorkspaceView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

#if canImport(UIKit)
import SwiftUI
import UIKit
import Theme
import UI
import SwiftUINavigation

private enum IOMaskFillOption: CaseIterable {
    case `default`
    case yellow
    case red
    case blue
    case green

    var label: String {
        switch self {
        case .default: return "Default"
        case .yellow:  return "Yellow"
        case .red:     return "Red"
        case .blue:    return "Blue"
        case .green:   return "Green"
        }
    }

    var hex: String? {
        switch self {
        case .default: return nil
        case .yellow:  return "FFEBA2CC"
        case .red:     return "FF8E8ECC"
        case .blue:    return "8FB8FFCC"
        case .green:   return "A7E3AECC"
        }
    }
}

// MARK: - ImageOcclusionWorkspaceView

struct ImageOcclusionWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Environment(\.palette) private var palette

    let title: String
    let onSave: ([IOMask]) -> Void

    @State private var model: ImageOcclusionWorkspaceModel
    @State private var destination: ImageOcclusionDestination?
    @State private var zoomCommand: IOCanvasZoomCommand = .fit
    @State private var zoomCommandID = 0

    init(title: String, image: UIImage, initialMasks: [IOMask], onSave: @escaping ([IOMask]) -> Void) {
        self.title = title
        self.onSave = onSave
        _model = State(initialValue: ImageOcclusionWorkspaceModel(image: image, initialMasks: initialMasks))
    }

    var body: some View {
        VStack(spacing: 0) {
            IOToolPalette(
                shapeType: model.shapeType,
                hasSelection: !model.activeSelectionIndices.isEmpty,
                onSelectTool: { model.shapeType = $0 },
                onApplyFill: { model.applyFill($0) },
                onCustomFill: {
                    destination = .fillEditor(IOFillDraft(color: model.fillEditorSeedColor))
                },
                onSelectOcclusionMode: { model.applyOcclusionMode($0) }
            )
            .equatable()

            canvas
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { workspaceToolbar }
        .safeAreaInset(edge: .bottom) { bottomToolbars }
        .modifier(WorkspacePresentations(destination: $destination, model: model, onDiscard: { dismiss() }))
        // The environment UndoManager isn't available at init, so hand it to
        // the model once the view is on screen.
        .onAppear { model.undoManager = undoManager }
        .onChange(of: undoManager) { _, manager in model.undoManager = manager }
    }

    private var canvas: some View {
        ZoomableOcclusionCanvasView(
            image: model.image,
            masks: $model.masks,
            selectedMaskIndex: $model.selectedMaskIndex,
            selectedMaskIndices: model.highlightedMaskIndices,
            highlightedMaskIndices: model.highlightedMaskIndices,
            shapeType: model.shapeType,
            maskOpacity: showsTranslucentMasks ? 0.72 : 0.94,
            zoomCommand: zoomCommand,
            zoomCommandID: zoomCommandID,
            onRequestText: { destination = .textEditor(model.textDraft(insertingAt: $0)) },
            onRequestTextEdit: { index in
                guard let draft = model.textDraft(editing: index) else { return }
                destination = .textEditor(draft)
            },
            onAppend: { model.appendMask($0) },
            onSelectionChange: { model.handleCanvasSelectionChange($0) },
            onTransformDidBegin: { model.handleTransformDidBegin() },
            onTransformDidEnd: { model.handleTransformDidEnd() }
        )
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }

    @State private var showsTranslucentMasks = true

    @ToolbarContentBuilder
    private var workspaceToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { requestDismiss() }
                .amgiToolbarTextButton(tone: .neutral)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { saveWorkspace() }
                .amgiToolbarTextButton()
        }
    }

    private var bottomToolbars: some View {
        VStack(spacing: 8) {
            IOEditingToolbar(
                selectionCount: model.activeSelectionIndices.count,
                hasMasks: !model.masks.isEmpty,
                allMasksSelected: model.allMasksSelected,
                showsTranslucentMasks: showsTranslucentMasks,
                undoManager: undoManager,
                canUndo: undoManager?.canUndo ?? false,
                canRedo: undoManager?.canRedo ?? false,
                onDelete: { model.deleteSelection() },
                onDuplicate: { model.duplicateSelection() },
                onToggleSelectAll: { model.toggleSelectAll() },
                onInvertSelection: { model.invertSelection() },
                onToggleTranslucency: { showsTranslucentMasks.toggle() }
            )
            .equatable()

            IOArrangeToolbar(
                selectionCount: model.activeSelectionIndices.count,
                canUngroup: model.canUngroup,
                onGroup: { model.groupSelection() },
                onUngroup: { model.ungroupSelection() },
                onAlign: { model.alignSelection($0) },
                onZoom: { sendZoomCommand($0) }
            )
            .equatable()
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(palette.surface)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Presentations

/// Split out of `body` so the SwiftUI type-checker doesn't have to solve one
/// long modifier chain, matching `DeckDetailPresentations`.
private struct WorkspacePresentations: ViewModifier {
    @Binding var destination: ImageOcclusionDestination?
    let model: ImageOcclusionWorkspaceModel
    let onDiscard: () -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Discard changes?",
                isPresented: $destination.discardConfirmation,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { onDiscard() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Unsaved changes will be lost.")
            }
            .sheet(item: $destination.textEditor) { $draft in
                IOTextEditorSheet(draft: $draft) { submitted in
                    model.apply(submitted)
                    destination = nil
                } onCancel: {
                    destination = nil
                }
            }
            .sheet(item: $destination.fillEditor) { $draft in
                IOFillEditorSheet(draft: $draft) { color in
                    destination = nil
                    model.applyFill(color)
                } onDefault: {
                    destination = nil
                    model.applyFill(nil as String?)
                } onCancel: {
                    destination = nil
                }
            }
    }
}

private struct IOTextEditorSheet: View {
    @Environment(\.palette) private var palette
    @Binding var draft: IOTextDraft
    let onSave: (IOTextDraft) -> Void
    let onCancel: () -> Void

    private var title: String {
        if case .insert = draft.target { return "Prompt" }
        return "Edit text"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Enter prompt text", text: $draft.text, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Text color") {
                    ColorPicker("Custom", selection: $draft.color, supportsOpacity: true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft) }
                        .amgiToolbarTextButton()
                        .disabled(!draft.isSubmittable)
                }
            }
        }
    }
}

private struct IOFillEditorSheet: View {
    @Environment(\.palette) private var palette
    @Binding var draft: IOFillDraft
    let onSave: (Color) -> Void
    let onDefault: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom") {
                    ColorPicker("Custom", selection: $draft.color, supportsOpacity: true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Default") { onDefault() }
                        .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(draft.color) }
                        .amgiToolbarTextButton()
                }
            }
        }
    }
}

// MARK: - Chrome

private extension ImageOcclusionWorkspaceView {
    func requestDismiss() {
        if model.hasUnsavedChanges {
            destination = .discardConfirmation
        } else {
            dismiss()
        }
    }

    func saveWorkspace() {
        onSave(model.masks)
        dismiss()
    }

    func sendZoomCommand(_ command: IOCanvasZoomCommand) {
        zoomCommand = command
        zoomCommandID += 1
    }
}

// MARK: - Chrome components

/// The palette and the two bottom toolbars are separate `View` types rather
/// than computed properties on the workspace so a `masks` mutation — which
/// the canvas performs on every frame of a drag, via the `$model.masks`
/// binding — re-evaluates only the canvas. As computed properties they shared
/// the workspace's invalidation boundary, so every drag frame also rebuilt
/// three `ForEach`es, four `Menu`s and ~13 buttons, each of which resolves its
/// SF Symbol through `UIImage(systemName:)`.
///
/// The `Equatable` conformances compare only the value inputs. The action
/// closures are freshly allocated on each parent body pass and would otherwise
/// always compare unequal, which would defeat the skip entirely.
private struct IOToolPalette: View, Equatable {
    @Environment(\.palette) private var palette

    let shapeType: IOShapeType
    let hasSelection: Bool
    let onSelectTool: (IOShapeType) -> Void
    let onApplyFill: (String?) -> Void
    let onCustomFill: () -> Void
    let onSelectOcclusionMode: (IOOcclusionMode) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.shapeType == rhs.shapeType && lhs.hasSelection == rhs.hasSelection
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(IOShapeType.allCases, id: \.self) { tool in
                Button {
                    onSelectTool(tool)
                } label: {
                    IOPaletteChip(
                        title: tool.label,
                        systemImage: tool.systemImage,
                        isSelected: shapeType == tool
                    )
                }
                .buttonStyle(.pressScale)
                .frame(maxWidth: .infinity)
            }

            Menu {
                ForEach(IOMaskFillOption.allCases, id: \.self) { option in
                    Button(option.label) { onApplyFill(option.hex) }
                }
                Divider()
                Button("Custom") { onCustomFill() }
                Button("Default") { onApplyFill(nil) }
            } label: {
                IOPaletteChip(title: "Fill", systemImage: "paintpalette", isSelected: false)
            }
            .frame(maxWidth: .infinity)
            .disabled(!hasSelection)

            Menu {
                ForEach(IOOcclusionMode.allCases, id: \.self) { mode in
                    Button(mode.label) { onSelectOcclusionMode(mode) }
                }
            } label: {
                IOPaletteChip(title: "Mode", systemImage: "square.stack.3d.up", isSelected: false)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(palette.surface)
    }
}

private struct IOEditingToolbar: View, Equatable {
    let selectionCount: Int
    let hasMasks: Bool
    let allMasksSelected: Bool
    let showsTranslucentMasks: Bool
    /// Held as the manager rather than as `onUndo`/`onRedo` closures: when
    /// `==` returns true SwiftUI keeps the *old* view value, closures and all,
    /// so a captured manager would outlive an `undoManager` swap that left
    /// `canUndo`/`canRedo` unchanged. Identity is part of the comparison.
    let undoManager: UndoManager?
    let canUndo: Bool
    let canRedo: Bool
    let onDelete: () -> Void
    let onDuplicate: () -> Void
    let onToggleSelectAll: () -> Void
    let onInvertSelection: () -> Void
    let onToggleTranslucency: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectionCount == rhs.selectionCount
            && lhs.hasMasks == rhs.hasMasks
            && lhs.allMasksSelected == rhs.allMasksSelected
            && lhs.showsTranslucentMasks == rhs.showsTranslucentMasks
            && lhs.undoManager === rhs.undoManager
            && lhs.canUndo == rhs.canUndo
            && lhs.canRedo == rhs.canRedo
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                IOToolbarIconButton(systemImage: "arrow.uturn.backward") { undoManager?.undo() }
                    .disabled(!canUndo)

                IOToolbarIconButton(systemImage: "arrow.uturn.forward") { undoManager?.redo() }
                    .disabled(!canRedo)

                IOToolbarIconButton(systemImage: "trash", action: onDelete)
                    .disabled(selectionCount == 0)

                IOToolbarIconButton(systemImage: "plus.square.on.square", action: onDuplicate)
                    .disabled(selectionCount == 0)

                IOToolbarIconButton(
                    systemImage: allMasksSelected ? "checkmark.circle.fill" : "checkmark.circle",
                    action: onToggleSelectAll
                )
                .disabled(!hasMasks)

                IOToolbarIconButton(systemImage: "arrow.left.arrow.right", action: onInvertSelection)
                    .disabled(!hasMasks)

                IOToolbarIconButton(
                    systemImage: showsTranslucentMasks ? "circle.lefthalf.filled" : "circle",
                    action: onToggleTranslucency
                )
                .disabled(!hasMasks)
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct IOArrangeToolbar: View, Equatable {
    let selectionCount: Int
    let canUngroup: Bool
    let onGroup: () -> Void
    let onUngroup: () -> Void
    let onAlign: (IOMaskAlignMode) -> Void
    let onZoom: (IOCanvasZoomCommand) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.selectionCount == rhs.selectionCount && lhs.canUngroup == rhs.canUngroup
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                IOToolbarIconButton(systemImage: "link", action: onGroup)
                    .disabled(selectionCount < 2)

                IOToolbarIconButton(
                    systemImage: "link.slash",
                    fallbackSystemImage: "scissors",
                    action: onUngroup
                )
                .disabled(!canUngroup)

                Menu {
                    ForEach(IOMaskAlignMode.allCases, id: \.self) { mode in
                        Button(mode.label) { onAlign(mode) }
                    }
                } label: {
                    IOToolbarIcon(systemImage: "align.horizontal.left")
                }
                .disabled(selectionCount == 0)

                IOToolbarIconButton(systemImage: "plus.magnifyingglass") { onZoom(.zoomIn) }
                IOToolbarIconButton(systemImage: "minus.magnifyingglass") { onZoom(.zoomOut) }
                IOToolbarIconButton(
                    systemImage: "arrow.up.left.and.down.right.magnifyingglass"
                ) { onZoom(.fit) }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct IOPaletteChip: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .amgiFont(size: 10, weight: .medium, relativeTo: .caption2)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isSelected ? Color.white : palette.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 2)
        .background(
            isSelected ? palette.accent : palette.surfaceElevated,
            in: RoundedRectangle(cornerRadius: AmgiRadius.inset, style: .continuous)
        )
    }
}

private struct IOToolbarIconButton: View {
    let systemImage: String
    var fallbackSystemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            IOToolbarIcon(systemImage: systemImage, fallbackSystemImage: fallbackSystemImage)
        }
        .buttonStyle(.pressScale)
    }
}

private struct IOToolbarIcon: View {
    let systemImage: String
    var fallbackSystemImage: String? = nil

    var body: some View {
        // Only the one caller that passes a fallback pays for the lookup;
        // probing `UIImage(systemName:)` for the rest just discards the result.
        let resolvedSymbol = if let fallbackSystemImage, UIImage(systemName: systemImage) == nil {
            fallbackSystemImage
        } else {
            systemImage
        }

        Image(systemName: resolvedSymbol)
            .font(.system(size: 13, weight: .semibold))
            .amgiToolbarIconButton(size: 30)
    }
}
#endif
