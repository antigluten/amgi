//
//  OcclusionCanvasView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

#if canImport(UIKit)
import Theme
import SwiftUI
import UIKit

// MARK: - OcclusionCanvasView

struct OcclusionCanvasView: UIViewRepresentable {
    let image: UIImage
    @Binding var masks: [IOMask]
    @Binding var selectedMaskIndex: Int?
    let shapeType: IOShapeType
    var highlightedMaskIndices: Set<Int> = []
    var activeSelectionIndices: Set<Int> = []
    var maskOpacity: CGFloat = 0.72
    var onRequestText: ((CGPoint) -> Void)?
    var onRequestTextEdit: ((Int) -> Void)?
    var onAppend: ((IOMask) -> Void)?
    var onSelectionChange: ((IOCanvasSelectionChange) -> Void)?
    var onTransformDidBegin: (() -> Void)?
    var onTransformDidEnd: (() -> Void)?

    enum IOCanvasSelectionChange {
        case replace(Int?)
        case toggle(Int)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            masks: $masks,
            selectedMaskIndex: $selectedMaskIndex,
            onRequestText: onRequestText,
            onRequestTextEdit: onRequestTextEdit,
            onAppend: onAppend,
            onSelectionChange: onSelectionChange,
            onTransformDidBegin: onTransformDidBegin,
            onTransformDidEnd: onTransformDidEnd
        )
    }

    func makeUIView(context: Context) -> OcclusionCanvasUIView {
        let view = OcclusionCanvasUIView(image: image)
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: OcclusionCanvasUIView, context: Context) {
        uiView.image = image
        // While a mask drag is in flight the canvas owns `masks`: it edits its
        // own copy per frame and commits once, on gesture end. Assigning here
        // would clobber the in-progress drag with the pre-drag state on any
        // unrelated SwiftUI update.
        if !uiView.isDraggingMasks {
            uiView.masks = masks
        }
        uiView.selectedMaskIndex = selectedMaskIndex
        uiView.highlightedMaskIndices = highlightedMaskIndices
        uiView.activeSelectionIndices = activeSelectionIndices
        uiView.maskOpacity = maskOpacity
        uiView.shapeType = shapeType
        context.coordinator.onRequestText = onRequestText
        context.coordinator.onRequestTextEdit = onRequestTextEdit
        context.coordinator.onAppend = onAppend
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onTransformDidBegin = onTransformDidBegin
        context.coordinator.onTransformDidEnd = onTransformDidEnd
        uiView.setNeedsDisplay()
    }

    final class Coordinator {
        @Binding var masks: [IOMask]
        @Binding var selectedMaskIndex: Int?
        var onRequestText: ((CGPoint) -> Void)?
        var onRequestTextEdit: ((Int) -> Void)?
        var onAppend: ((IOMask) -> Void)?
        var onSelectionChange: ((IOCanvasSelectionChange) -> Void)?
        var onTransformDidBegin: (() -> Void)?
        var onTransformDidEnd: (() -> Void)?
        var lastZoomCommandID = -1

        init(
            masks: Binding<[IOMask]>,
            selectedMaskIndex: Binding<Int?>,
            onRequestText: ((CGPoint) -> Void)?,
            onRequestTextEdit: ((Int) -> Void)?,
            onAppend: ((IOMask) -> Void)?,
            onSelectionChange: ((IOCanvasSelectionChange) -> Void)?,
            onTransformDidBegin: (() -> Void)?,
            onTransformDidEnd: (() -> Void)?
        ) {
            _masks = masks
            _selectedMaskIndex = selectedMaskIndex
            self.onRequestText = onRequestText
            self.onRequestTextEdit = onRequestTextEdit
            self.onAppend = onAppend
            self.onSelectionChange = onSelectionChange
            self.onTransformDidBegin = onTransformDidBegin
            self.onTransformDidEnd = onTransformDidEnd
        }

        func appendMask(_ mask: IOMask) {
            if let onAppend {
                switch mask {
                case .rect(_, _, let w, let h, _) where w > 0.02 && h > 0.02: onAppend(mask)
                case .ellipse(_, _, let rx, let ry, _) where rx > 0.01 && ry > 0.01: onAppend(mask)
                case .polygon(let pts, _) where pts.count >= 3: onAppend(mask)
                case .text(_, _, let text, _, _, _) where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: onAppend(mask)
                default: break
                }
            } else {
                switch mask {
                case .rect(_, _, let w, let h, _) where w > 0.02 && h > 0.02: masks.append(mask)
                case .ellipse(_, _, let rx, let ry, _) where rx > 0.01 && ry > 0.01: masks.append(mask)
                case .polygon(let pts, _) where pts.count >= 3: masks.append(mask)
                case .text(_, _, let text, _, _, _) where !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty: masks.append(mask)
                default: break
                }
            }
        }

        func selectMask(_ selection: IOCanvasSelectionChange) {
            if case .replace(let index) = selection {
                selectedMaskIndex = index
            }
            onSelectionChange?(selection)
        }

        func requestText(at point: CGPoint) {
            onRequestText?(point)
        }

        func requestTextEdit(at index: Int) {
            onRequestTextEdit?(index)
        }

        /// Push the canvas's own mask array back into SwiftUI. Called once
        /// when a drag ends, not per frame -- see `OcclusionCanvasUIView`'s
        /// drag buffering.
        func commitMasks(_ newMasks: [IOMask]) {
            guard masks != newMasks else { return }
            masks = newMasks
        }

        func beginTransform() {
            onTransformDidBegin?()
        }

        func finishTransform() {
            onTransformDidEnd?()
        }
    }
}
#endif
