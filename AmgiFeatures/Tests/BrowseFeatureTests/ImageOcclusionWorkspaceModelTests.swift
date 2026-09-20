//
//  ImageOcclusionWorkspaceModelTests.swift
//  BrowseFeatureTests
//
//  Created by Vladimir Gusev on 15.08.2026.
//

import Testing
import SwiftUI
import UIKit
@testable import BrowseFeature

/// The mask document logic used to live in a private extension on
/// `ImageOcclusionWorkspaceView`, where none of it was reachable without a
/// `View`. These tests pin the behaviour that moved into the model — in
/// particular the text-draft path, whose five loose `pendingText*` vars
/// collapsed into `IOTextDraft.Target`.
@Suite("ImageOcclusionWorkspaceModel")
@MainActor
struct ImageOcclusionWorkspaceModelTests {

    private func image() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in }
    }

    private func rect(_ left: CGFloat, ordinal: Int? = nil) -> IOMask {
        let mask = IOMask.rect(left: left, top: 0.1, width: 0.2, height: 0.2, extras: [:])
        return ordinal.map { mask.applyingSerializationOrdinal($0) } ?? mask
    }

    private func model(_ masks: [IOMask] = []) -> ImageOcclusionWorkspaceModel {
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: masks)
        model.undoManager = UndoManager()
        return model
    }

    // MARK: Initial state

    @Test("empty document starts on the rect tool with nothing selected")
    func emptyDocumentStartsOnRectTool() {
        let model = model()
        #expect(model.shapeType == .rect)
        #expect(model.activeSelectionIndices.isEmpty)
        #expect(!model.hasUnsavedChanges)
    }

    @Test("existing document starts on the select tool with the first mask selected")
    func existingDocumentStartsOnSelectTool() {
        let model = model([rect(0.1), rect(0.4)])
        #expect(model.shapeType == .select)
        #expect(model.activeSelectionIndices == [0])
    }

    @Test("occlusion mode is inferred from the loaded masks")
    func occlusionModeInferredFromMasks() {
        #expect(model([rect(0.1)]).occlusionMode == .hideOneGuessOne)

        let hidden = rect(0.1).applyingOccludeInactive(true)
        #expect(model([hidden]).occlusionMode == .hideAllGuessOne)
    }

    // MARK: Text drafts

    @Test("insert draft appends a new text mask")
    func insertDraftAppendsMask() {
        let model = model()
        var draft = model.textDraft(insertingAt: CGPoint(x: 0.25, y: 0.5))
        draft.text = "hello"
        model.apply(draft)

        #expect(model.masks.count == 1)
        guard case .text(let left, let top, let text, _, _, _) = model.masks[0] else {
            Issue.record("expected a text mask, got \(model.masks[0])")
            return
        }
        #expect(text == "hello")
        #expect(left == 0.25)
        #expect(top == 0.5)
    }

    @Test("edit draft updates in place instead of appending")
    func editDraftUpdatesInPlace() {
        let model = model()
        var insert = model.textDraft(insertingAt: CGPoint(x: 0.1, y: 0.1))
        insert.text = "before"
        model.apply(insert)

        guard var edit = model.textDraft(editing: 0) else {
            Issue.record("expected an editable text draft at index 0")
            return
        }
        #expect(edit.text == "before")
        edit.text = "after"
        model.apply(edit)

        #expect(model.masks.count == 1)
        guard case .text(_, _, let text, _, _, _) = model.masks[0] else {
            Issue.record("expected a text mask")
            return
        }
        #expect(text == "after")
    }

    @Test("a blank draft is rejected and never reaches the document")
    func blankDraftIsRejected() {
        let model = model()
        var draft = model.textDraft(insertingAt: .zero)
        draft.text = "   \n "
        #expect(!draft.isSubmittable)
        model.apply(draft)
        #expect(model.masks.isEmpty)
    }

    @Test("editing a non-text mask yields no draft")
    func editingNonTextMaskYieldsNoDraft() {
        let model = model([rect(0.1)])
        #expect(model.textDraft(editing: 0) == nil)
        #expect(model.textDraft(editing: 99) == nil)
    }

    // MARK: Selection and grouping

    @Test("selecting one mask of a group selects the whole group")
    func selectingGroupedMaskSelectsGroup() {
        let model = model([rect(0.1, ordinal: 3), rect(0.4), rect(0.7, ordinal: 3)])
        model.handleCanvasSelectionChange(.replace(1))
        #expect(model.activeSelectionIndices == [1])

        model.handleCanvasSelectionChange(.replace(0))
        #expect(model.activeSelectionIndices == [0, 2])
    }

    @Test("grouping assigns the lowest existing ordinal to the whole selection")
    func groupingAssignsLowestOrdinal() {
        let model = model([rect(0.1, ordinal: 5), rect(0.4, ordinal: 2)])
        model.selectedMaskIndices = [0, 1]
        model.groupSelection()

        #expect(model.masks[0].serializationOrdinal == 2)
        #expect(model.masks[1].serializationOrdinal == 2)
    }

    @Test("ungrouping clears the ordinal on the selection")
    func ungroupingClearsOrdinal() {
        let model = model([rect(0.1, ordinal: 2), rect(0.4, ordinal: 2)])
        model.selectedMaskIndices = [0, 1]
        #expect(model.canUngroup)
        model.ungroupSelection()

        #expect(model.masks.allSatisfy { $0.serializationOrdinal == nil })
        #expect(!model.canUngroup)
    }

    @Test("select all toggles between everything and nothing")
    func selectAllToggles() {
        let model = model([rect(0.1), rect(0.4), rect(0.7)])
        model.toggleSelectAll()
        #expect(model.allMasksSelected)
        model.toggleSelectAll()
        #expect(model.activeSelectionIndices.isEmpty)
    }

    @Test("invert selection swaps selected for unselected")
    func invertSelectionSwaps() {
        let model = model([rect(0.1), rect(0.4), rect(0.7)])
        model.selectedMaskIndices = [0]
        model.invertSelection()
        #expect(model.activeSelectionIndices == [1, 2])
    }

    // MARK: Mutation

    @Test("delete removes the selection and reselects what remains")
    func deleteRemovesSelection() {
        let model = model([rect(0.1), rect(0.4), rect(0.7)])
        model.selectedMaskIndices = [0, 2]
        model.deleteSelection()

        #expect(model.masks.count == 1)
        #expect(model.activeSelectionIndices == [0])
    }

    @Test("duplicate offsets the copy and gives a grouped copy a fresh ordinal")
    func duplicateOffsetsAndRemapsOrdinal() {
        let model = model([rect(0.1, ordinal: 1)])
        model.selectedMaskIndices = [0]
        model.duplicateSelection()

        #expect(model.masks.count == 2)
        guard case .rect(let left, _, _, _, _) = model.masks[1] else {
            Issue.record("expected a rect duplicate")
            return
        }
        #expect(abs(left - 0.13) < 0.0001)
        // The duplicate is its own group, not a member of the original's.
        #expect(model.masks[1].serializationOrdinal != model.masks[0].serializationOrdinal)
    }

    @Test("align left pins every selected mask to the canvas edge")
    func alignLeftPinsToEdge() {
        let model = model([rect(0.3), rect(0.6)])
        model.selectedMaskIndices = [0, 1]
        model.alignSelection(.left)

        for mask in model.masks {
            guard case .rect(let left, _, _, _, _) = mask else {
                Issue.record("expected rects")
                return
            }
            #expect(abs(left) < 0.0001)
        }
    }

    @Test("occlusion mode is written through to every mask")
    func occlusionModeWritesThrough() {
        let model = model([rect(0.1), rect(0.4)])
        model.applyOcclusionMode(.hideAllGuessOne)
        #expect(model.masks.allSatisfy { $0.occludesInactive })

        model.applyOcclusionMode(.hideOneGuessOne)
        #expect(model.masks.allSatisfy { !$0.occludesInactive })
    }

    @Test("fill applies to the selection only")
    func fillAppliesToSelectionOnly() {
        let model = model([rect(0.1), rect(0.4)])
        model.selectedMaskIndices = [1]
        model.applyFill("FFEBA2CC")

        #expect(model.masks[0].extras["fill"] == nil)
        #expect(model.masks[1].extras["fill"] == "FFEBA2CC")
    }

    // MARK: Undo

    @Test("undo restores the document, redo reapplies it")
    func undoRestoresDocument() {
        let undoManager = UndoManager()
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: [rect(0.1)])
        model.undoManager = undoManager

        model.selectedMaskIndices = [0]
        model.deleteSelection()
        #expect(model.masks.isEmpty)
        #expect(model.hasUnsavedChanges)

        undoManager.undo()
        #expect(model.masks.count == 1)
        #expect(!model.hasUnsavedChanges)

        undoManager.redo()
        #expect(model.masks.isEmpty)
    }

    @Test("a transform that changes nothing registers no undo step")
    func noopTransformRegistersNoUndo() {
        let undoManager = UndoManager()
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: [rect(0.1)])
        model.undoManager = undoManager

        model.handleTransformDidBegin()
        model.handleTransformDidEnd()
        #expect(!undoManager.canUndo)
    }

    @Test("a transform that moves a mask registers one undo step")
    func transformRegistersUndo() {
        let undoManager = UndoManager()
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: [rect(0.1)])
        model.undoManager = undoManager

        model.handleTransformDidBegin()
        // The canvas commits the dragged masks through its binding before it
        // reports the gesture end -- see `canvasCommitsMasksBeforeReportingEnd`.
        model.masks = [rect(0.5)]
        model.handleTransformDidEnd()

        #expect(undoManager.canUndo)
        undoManager.undo()
        guard case .rect(let left, _, _, _, _) = model.masks[0] else {
            Issue.record("expected a rect")
            return
        }
        #expect(abs(left - 0.1) < 0.0001)
    }

    /// `OcclusionCanvasUIView` buffers a drag in its own `masks` and pushes the
    /// result through `Coordinator.commitMasks` once, on gesture end. That
    /// commit has to land *before* `finishTransform()`, because the model
    /// snapshots `masks` inside it to decide whether an undo step is warranted.
    /// Swapping the two lines loses every drag from the undo stack silently, so
    /// this pins the order the canvas calls them in.
    @Test("the canvas commits dragged masks before it reports the gesture end")
    func canvasCommitsMasksBeforeReportingEnd() {
        let undoManager = UndoManager()
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: [rect(0.1)])
        model.undoManager = undoManager

        let coordinator = OcclusionCanvasView.Coordinator(
            masks: Binding(get: { model.masks }, set: { model.masks = $0 }),
            selectedMaskIndex: Binding(get: { model.selectedMaskIndex }, set: { model.selectedMaskIndex = $0 }),
            onRequestText: nil,
            onRequestTextEdit: nil,
            onAppend: nil,
            onSelectionChange: nil,
            onTransformDidBegin: { model.handleTransformDidBegin() },
            onTransformDidEnd: { model.handleTransformDidEnd() }
        )

        // One drag, in the order `handlePan` performs it.
        coordinator.beginTransform()
        coordinator.commitMasks([rect(0.5)])
        coordinator.finishTransform()

        #expect(undoManager.canUndo)
        undoManager.undo()
        guard case .rect(let restored, _, _, _, _) = model.masks[0] else {
            Issue.record("expected a rect")
            return
        }
        #expect(abs(restored - 0.1) < 0.0001)
    }

    @Test("committing an unchanged mask array does not touch the document")
    func noopCommitDoesNotWriteBack() {
        let model = ImageOcclusionWorkspaceModel(image: image(), initialMasks: [rect(0.1)])
        var writes = 0
        let coordinator = OcclusionCanvasView.Coordinator(
            masks: Binding(get: { model.masks }, set: { writes += 1; model.masks = $0 }),
            selectedMaskIndex: .constant(nil),
            onRequestText: nil,
            onRequestTextEdit: nil,
            onAppend: nil,
            onSelectionChange: nil,
            onTransformDidBegin: nil,
            onTransformDidEnd: nil
        )

        coordinator.commitMasks([rect(0.1)])
        #expect(writes == 0)

        coordinator.commitMasks([rect(0.5)])
        #expect(writes == 1)
    }
}
