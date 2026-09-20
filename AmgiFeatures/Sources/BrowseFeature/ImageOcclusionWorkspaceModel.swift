//
//  ImageOcclusionWorkspaceModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

#if canImport(UIKit)
import Theme
import SwiftUI
import UIKit


// MARK: - Supporting types

struct IOMaskSnapshot: Equatable {
    var masks: [IOMask]
    var selectedMaskIndex: Int?
    var selectedMaskIndices: Set<Int>
}

enum IOMaskAlignMode: CaseIterable {
    case left
    case horizontalCenter
    case right
    case top
    case verticalCenter
    case bottom

    var label: String {
        switch self {
        case .left:             return "Align left"
        case .horizontalCenter: return "Center horizontally"
        case .right:            return "Align right"
        case .top:              return "Align top"
        case .verticalCenter:   return "Center vertically"
        case .bottom:           return "Align bottom"
        }
    }
}

enum IOOcclusionMode: CaseIterable {
    case hideAllGuessOne
    case hideOneGuessOne

    var label: String {
        switch self {
        case .hideAllGuessOne: return "Hide all, guess one"
        case .hideOneGuessOne: return "Hide one, guess one"
        }
    }

    var occludesInactive: Bool {
        switch self {
        case .hideAllGuessOne: return true
        case .hideOneGuessOne: return false
        }
    }
}

// MARK: - ImageOcclusionWorkspaceModel

/// Owns the mask document being edited: the masks themselves, the selection,
/// the active tool, and the undo stack. Lifted out of
/// `ImageOcclusionWorkspaceView` so the mutation, grouping, alignment, and
/// snapshot logic is reachable without instantiating a `View`.
///
/// The view keeps only presentation state (which sheet is open, the canvas
/// zoom command) and injects its environment `UndoManager` on appear.
@MainActor
@Observable
final class ImageOcclusionWorkspaceModel {
    let image: UIImage
    let initialMasks: [IOMask]

    var masks: [IOMask]
    var selectedMaskIndex: Int?
    var selectedMaskIndices: Set<Int>
    var shapeType: IOShapeType
    var occlusionMode: IOOcclusionMode

    /// Set by the view from `@Environment(\.undoManager)`; nil in previews and tests.
    var undoManager: UndoManager?

    private var transformStartSnapshot: IOMaskSnapshot?

    init(image: UIImage, initialMasks: [IOMask]) {
        self.image = image
        self.initialMasks = initialMasks
        self.masks = initialMasks
        let initialSelection = initialMasks.indices.first
        self.selectedMaskIndex = initialSelection
        self.selectedMaskIndices = initialSelection.map { Set([$0]) } ?? []
        self.shapeType = initialMasks.isEmpty ? .rect : .select
        self.occlusionMode = initialMasks.contains(where: \.occludesInactive) ? .hideAllGuessOne : .hideOneGuessOne
    }

    // MARK: Derived state

    var activeSelectionIndices: [Int] {
        let filtered = selectedMaskIndices.filter { masks.indices.contains($0) }
        if !filtered.isEmpty {
            return filtered.sorted()
        }

        guard let selectedMaskIndex, masks.indices.contains(selectedMaskIndex) else {
            return []
        }
        return [selectedMaskIndex]
    }

    var highlightedMaskIndices: Set<Int> {
        Set(activeSelectionIndices)
    }

    var allMasksSelected: Bool {
        !masks.isEmpty && highlightedMaskIndices.count == masks.count
    }

    var hasUnsavedChanges: Bool {
        masks != initialMasks
    }

    var canUngroup: Bool {
        let indices = activeSelectionIndices
        return !indices.isEmpty && indices.contains(where: { masks[$0].serializationOrdinal != nil })
    }

    // MARK: Selection

    func handleCanvasSelectionChange(_ selection: OcclusionCanvasView.IOCanvasSelectionChange) {
        switch selection {
        case .replace(let index):
            guard let index, masks.indices.contains(index) else {
                selectedMaskIndex = nil
                selectedMaskIndices = []
                return
            }
            let group = groupedSelectionIndices(for: index)
            selectedMaskIndex = index
            selectedMaskIndices = group
        case .toggle(let index):
            guard masks.indices.contains(index) else { return }
            let group = groupedSelectionIndices(for: index)
            if group.isSubset(of: selectedMaskIndices) {
                selectedMaskIndices.subtract(group)
                if selectedMaskIndices.isEmpty {
                    selectedMaskIndex = nil
                } else if let selectedMaskIndex, !selectedMaskIndices.contains(selectedMaskIndex) {
                    self.selectedMaskIndex = selectedMaskIndices.sorted().first
                }
            } else {
                selectedMaskIndices.formUnion(group)
                selectedMaskIndex = index
            }
        }
    }

    func toggleSelectAll() {
        guard !masks.isEmpty else { return }
        if allMasksSelected {
            selectedMaskIndices = []
            selectedMaskIndex = nil
        } else {
            selectedMaskIndices = Set(masks.indices)
            selectedMaskIndex = masks.indices.first
        }
    }

    func invertSelection() {
        guard !masks.isEmpty else { return }
        let inverted = Set(masks.indices).subtracting(selectedMaskIndices)
        selectedMaskIndices = inverted
        if let selectedMaskIndex, inverted.contains(selectedMaskIndex) {
            return
        }
        self.selectedMaskIndex = inverted.sorted().first
    }

    // MARK: Text masks

    /// Draft for inserting a new text mask at a canvas point.
    func textDraft(insertingAt point: CGPoint) -> IOTextDraft {
        IOTextDraft(target: .insert(at: point), text: "", color: .black)
    }

    /// Draft for editing an existing text mask, or nil if the index isn't a text mask.
    func textDraft(editing maskIndex: Int) -> IOTextDraft? {
        guard masks.indices.contains(maskIndex),
              case .text(_, _, let text, _, _, let extras) = masks[maskIndex] else {
            return nil
        }
        return IOTextDraft(
            target: .edit(maskIndex: maskIndex),
            text: text,
            color: color(from: extras["fill"], fallback: .black)
        )
    }

    func apply(_ draft: IOTextDraft) {
        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let fillHex = hexString(for: draft.color)

        switch draft.target {
        case .edit(let maskIndex):
            guard masks.indices.contains(maskIndex) else { return }
            var updatedMasks = masks
            updatedMasks[maskIndex] = updatedMasks[maskIndex].updatingText(text, fillHex: fillHex)
            commitSnapshot(
                IOMaskSnapshot(
                    masks: updatedMasks,
                    selectedMaskIndex: maskIndex,
                    selectedMaskIndices: groupedSelectionIndices(for: maskIndex, in: updatedMasks)
                )
            )
        case .insert(let point):
            appendMask(
                .text(
                    left: point.x,
                    top: point.y,
                    text: text,
                    scale: 1,
                    fontSize: 0.055,
                    extras: ["fill": fillHex]
                )
            )
        }
    }

    // MARK: Mask mutation

    func appendMask(_ mask: IOMask) {
        var updatedMasks = masks
        updatedMasks.append(mask.applyingOccludeInactive(occlusionMode.occludesInactive))
        let newIndex = updatedMasks.count - 1
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: newIndex,
                selectedMaskIndices: [newIndex]
            )
        )
    }

    func deleteSelection() {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }
        let indexSet = Set(indices)
        let updatedMasks = masks.enumerated().compactMap { index, mask in
            indexSet.contains(index) ? nil : mask
        }
        let newSelection = updatedMasks.indices.first.map { Set([$0]) } ?? []
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: newSelection.sorted().first,
                selectedMaskIndices: newSelection
            )
        )
    }

    func duplicateSelection() {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }

        var updatedMasks = masks
        updatedMasks.reserveCapacity(masks.count + indices.count)
        var duplicatedIndices = Set<Int>(minimumCapacity: indices.count)
        var ordinalMapping = [Int: Int](minimumCapacity: indices.count)

        for index in indices {
            var duplicate = offset(mask: masks[index], dx: 0.03, dy: 0.03).applyingSerializationOrdinal(nil)
            if let ordinal = masks[index].serializationOrdinal {
                let mappedOrdinal = ordinalMapping[ordinal] ?? nextAvailableOrdinal(in: updatedMasks, reserved: Set(ordinalMapping.values))
                ordinalMapping[ordinal] = mappedOrdinal
                duplicate = duplicate.applyingSerializationOrdinal(mappedOrdinal)
            }
            updatedMasks.append(duplicate)
            duplicatedIndices.insert(updatedMasks.count - 1)
        }

        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: duplicatedIndices.sorted().first,
                selectedMaskIndices: duplicatedIndices
            )
        )
    }

    // MARK: Fill and occlusion mode

    /// Colour to seed the custom-fill editor with, taken from the first selected mask.
    var fillEditorSeedColor: Color {
        color(from: activeSelectionIndices.first.flatMap { masks[$0].extras["fill"] }, fallback: .yellow)
    }

    func applyFill(_ hex: String?) {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }

        var updatedMasks = masks
        for index in indices {
            updatedMasks[index] = updatedMasks[index].applyingFill(hex)
        }
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: selectedMaskIndex,
                selectedMaskIndices: Set(indices)
            )
        )
    }

    func applyFill(_ color: Color) {
        applyFill(hexString(for: color))
    }

    func applyOcclusionMode(_ mode: IOOcclusionMode) {
        occlusionMode = mode
        guard !masks.isEmpty else { return }

        let updatedMasks = masks.map { $0.applyingOccludeInactive(mode.occludesInactive) }
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: selectedMaskIndex,
                selectedMaskIndices: Set(activeSelectionIndices)
            )
        )
    }

    // MARK: Grouping and alignment

    func groupSelection() {
        let indices = activeSelectionIndices
        guard indices.count >= 2 else { return }
        let targetOrdinal = indices.compactMap { masks[$0].serializationOrdinal }.min()
            ?? nextAvailableOrdinal(in: masks)
        var updatedMasks = masks
        for index in indices {
            updatedMasks[index] = updatedMasks[index].applyingSerializationOrdinal(targetOrdinal)
        }
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: selectedMaskIndex,
                selectedMaskIndices: Set(indices)
            )
        )
    }

    func ungroupSelection() {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }
        var updatedMasks = masks
        for index in indices {
            updatedMasks[index] = updatedMasks[index].applyingSerializationOrdinal(nil)
        }
        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: selectedMaskIndex,
                selectedMaskIndices: Set(indices)
            )
        )
    }

    func alignSelection(_ mode: IOMaskAlignMode) {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }

        let canvasBounds = CGRect(x: 0, y: 0, width: 1, height: 1)
        var updatedMasks = masks
        for index in indices {
            let maskBounds = normalizedBounds(for: updatedMasks[index])
            let delta: CGPoint
            switch mode {
            case .left:
                delta = CGPoint(x: canvasBounds.minX - maskBounds.minX, y: 0)
            case .horizontalCenter:
                delta = CGPoint(x: canvasBounds.midX - maskBounds.midX, y: 0)
            case .right:
                delta = CGPoint(x: canvasBounds.maxX - maskBounds.maxX, y: 0)
            case .top:
                delta = CGPoint(x: 0, y: canvasBounds.minY - maskBounds.minY)
            case .verticalCenter:
                delta = CGPoint(x: 0, y: canvasBounds.midY - maskBounds.midY)
            case .bottom:
                delta = CGPoint(x: 0, y: canvasBounds.maxY - maskBounds.maxY)
            }
            updatedMasks[index] = offset(mask: updatedMasks[index], dx: delta.x, dy: delta.y)
        }

        commitSnapshot(
            IOMaskSnapshot(
                masks: updatedMasks,
                selectedMaskIndex: selectedMaskIndex,
                selectedMaskIndices: Set(indices)
            )
        )
    }

    // MARK: Canvas transform undo grouping

    func handleTransformDidBegin() {
        if transformStartSnapshot == nil {
            transformStartSnapshot = currentSnapshot()
        }
    }

    func handleTransformDidEnd() {
        guard let previousSnapshot = transformStartSnapshot else { return }
        transformStartSnapshot = nil
        let current = currentSnapshot()
        guard current != previousSnapshot else { return }
        registerUndo(previous: previousSnapshot, current: current)
    }
}
#endif
