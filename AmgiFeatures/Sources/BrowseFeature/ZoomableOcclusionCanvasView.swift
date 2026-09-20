//
//  ZoomableOcclusionCanvasView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - IOCanvasZoomCommand

enum IOCanvasZoomCommand {
    case zoomIn
    case zoomOut
    case fit
}

// MARK: - ZoomableOcclusionCanvasView

struct ZoomableOcclusionCanvasView: UIViewRepresentable {
    let image: UIImage
    @Binding var masks: [IOMask]
    @Binding var selectedMaskIndex: Int?
    let selectedMaskIndices: Set<Int>
    let highlightedMaskIndices: Set<Int>
    let shapeType: IOShapeType
    let maskOpacity: CGFloat
    let zoomCommand: IOCanvasZoomCommand
    let zoomCommandID: Int
    var onRequestText: ((CGPoint) -> Void)?
    var onRequestTextEdit: ((Int) -> Void)?
    var onAppend: ((IOMask) -> Void)?
    var onSelectionChange: ((OcclusionCanvasView.IOCanvasSelectionChange) -> Void)?
    var onTransformDidBegin: (() -> Void)?
    var onTransformDidEnd: (() -> Void)?

    func makeCoordinator() -> OcclusionCanvasView.Coordinator {
        OcclusionCanvasView.Coordinator(
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

    func makeUIView(context: Context) -> ZoomableOcclusionCanvasContainer {
        let view = ZoomableOcclusionCanvasContainer(image: image)
        view.canvasView.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: ZoomableOcclusionCanvasContainer, context: Context) {
        uiView.updateImage(image)
        uiView.canvasView.image = image
        // See `OcclusionCanvasView.updateUIView`: the canvas owns `masks` for
        // the duration of a drag.
        if !uiView.canvasView.isDraggingMasks {
            uiView.canvasView.masks = masks
        }
        uiView.canvasView.selectedMaskIndex = selectedMaskIndex
        uiView.canvasView.activeSelectionIndices = selectedMaskIndices
        uiView.canvasView.highlightedMaskIndices = highlightedMaskIndices
        uiView.canvasView.shapeType = shapeType
        uiView.canvasView.maskOpacity = maskOpacity
        context.coordinator.onRequestText = onRequestText
        context.coordinator.onRequestTextEdit = onRequestTextEdit
        context.coordinator.onAppend = onAppend
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onTransformDidBegin = onTransformDidBegin
        context.coordinator.onTransformDidEnd = onTransformDidEnd

        if context.coordinator.lastZoomCommandID != zoomCommandID {
            context.coordinator.lastZoomCommandID = zoomCommandID
            uiView.apply(zoomCommand)
        }

        uiView.canvasView.setNeedsDisplay()
    }
}

// MARK: - ZoomableOcclusionCanvasContainer

final class ZoomableOcclusionCanvasContainer: UIScrollView, UIScrollViewDelegate {
    let canvasView: OcclusionCanvasUIView
    private var lastBoundsSize: CGSize = .zero
    private var imageSize: CGSize

    init(image: UIImage) {
        self.canvasView = OcclusionCanvasUIView(image: image)
        self.imageSize = image.size
        super.init(frame: .zero)

        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        bouncesZoom = true
        minimumZoomScale = 1
        maximumZoomScale = 5
        // Use a neutral surface color; palette not accessible from UIKit init
        backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1)
        layer.cornerRadius = 24
        addSubview(canvasView)
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            relayoutCanvas(resetZoom: false)
        }
        centerCanvas()
    }

    func updateImage(_ image: UIImage) {
        canvasView.image = image
        if image.size != imageSize {
            imageSize = image.size
            relayoutCanvas(resetZoom: true)
        }
    }

    func apply(_ command: IOCanvasZoomCommand) {
        switch command {
        case .zoomIn:
            setZoomScale(min(maximumZoomScale, zoomScale * 1.2), animated: true)
        case .zoomOut:
            setZoomScale(max(minimumZoomScale, zoomScale / 1.2), animated: true)
        case .fit:
            layoutIfNeeded()
            relayoutCanvas(resetZoom: true)
        }
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        canvasView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerCanvas()
    }
}

private extension ZoomableOcclusionCanvasContainer {
    func relayoutCanvas(resetZoom: Bool) {
        let fittedSize = fittedCanvasSize(for: bounds.size)
        canvasView.frame = CGRect(origin: .zero, size: fittedSize)
        contentSize = fittedSize
        minimumZoomScale = 1
        maximumZoomScale = 5
        if resetZoom || zoomScale < minimumZoomScale {
            zoomScale = minimumZoomScale
        }
        centerCanvas()
    }

    func fittedCanvasSize(for boundsSize: CGSize) -> CGSize {
        let availableWidth = max(boundsSize.width - 8, 1)
        let availableHeight = max(boundsSize.height - 8, 1)
        let scale = min(availableWidth / max(imageSize.width, 1), availableHeight / max(imageSize.height, 1))
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    func centerCanvas() {
        var frame = canvasView.frame
        frame.origin.x = frame.width < bounds.width ? (bounds.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < bounds.height ? (bounds.height - frame.height) / 2 : 0
        canvasView.frame = frame
    }
}
#endif
