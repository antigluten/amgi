//
//  OcclusionCanvasUIView.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

#if canImport(UIKit)
import Theme
import SwiftUI
import UIKit

// MARK: - OcclusionCanvasUIView

final class OcclusionCanvasUIView: UIView {
    enum SelectionHandle: CaseIterable, Hashable {
        case topLeft
        case top
        case topRight
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left
        case rotate
    }

    enum ActiveDrag {
        case move(maskIndices: [Int], start: CGPoint, originals: [Int: IOMask])
        case resize(maskIndex: Int, handle: SelectionHandle, original: IOMask)
        case rotate(maskIndex: Int, pivot: CGPoint, startAngle: CGFloat, original: IOMask)
        case polygonVertex(maskIndex: Int, vertexIndex: Int)
    }

    struct BoxTransform {
        let origin: CGPoint
        let size: CGSize
        let angle: CGFloat
    }

    struct SelectionGeometry {
        let corners: [CGPoint]
        let handleCenters: [SelectionHandle: CGPoint]
        let rotationStemStart: CGPoint
        let rotationStemEnd: CGPoint
        let center: CGPoint
    }

    let selectionOutset: CGFloat = 4
    let handleVisualDiameter: CGFloat = 12
    let handleHitDiameter: CGFloat = 28
    let rotationHandleDistance: CGFloat = 34
    let minimumBoxDimension: CGFloat = 24
    let minimumNormalizedDimension: CGFloat = 0.02
    let minimumTextScale: CGFloat = 0.25

    var image: UIImage {
        // `updateUIView` assigns this on every SwiftUI pass, almost always the
        // same instance — compare identity so the cache survives.
        didSet { if image !== oldValue { scaledImageCache = nil } }
    }
    var masks: [IOMask] = []
    var selectedMaskIndex: Int?
    var shapeType: IOShapeType = .rect
    var highlightedMaskIndices: Set<Int> = []
    var activeSelectionIndices: Set<Int> = []
    var maskOpacity: CGFloat = 0.72
    weak var coordinator: OcclusionCanvasView.Coordinator?

    private var dragStart: CGPoint?
    private var currentDragRect: CGRect?
    private var polygonPoints: [CGPoint] = []
    private var activeDrag: ActiveDrag?

    /// `image` pre-scaled to the rect it's actually drawn at, and the size that
    /// cache is valid for.
    ///
    /// `draw(_:)` runs on every frame of a mask drag, and `image.draw(in:)`
    /// resamples the full source each time — for a photo-library pick that's a
    /// 12 MP resample into a ~380pt rect, per frame. Resampling once per size
    /// change and blitting the result costs one extra display-sized bitmap.
    private var scaledImageCache: UIImage?
    private var scaledImageSize: CGSize = .zero

    /// True while a move/resize/rotate/vertex drag is in flight. During that
    /// window the view mutates `masks` directly and SwiftUI must not overwrite
    /// it; the final value is pushed through the coordinator on gesture end.
    var isDraggingMasks: Bool { activeDrag != nil }

    init(image: UIImage) {
        self.image = image
        super.init(frame: .zero)
        backgroundColor = .clear

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.require(toFail: doubleTap)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError() }

    /// The source image resampled to `size`, cached until the size or the
    /// image itself changes.
    private func scaledImage(at size: CGSize) -> UIImage {
        if let scaledImageCache, scaledImageSize == size { return scaledImageCache }
        let renderer = UIGraphicsImageRenderer(size: size, format: .preferred())
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        scaledImageCache = scaled
        scaledImageSize = size
        return scaled
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let imgRect = imageRect(in: bounds)
        if imgRect.width >= 1, imgRect.height >= 1 {
            scaledImage(at: imgRect.size).draw(at: imgRect.origin)
        }

        let inactiveFill = UIColor(red: 1, green: 0.92, blue: 0.64, alpha: maskOpacity).cgColor
        let inactiveStroke = UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1).cgColor

        for (i, mask) in masks.enumerated() {
            ctx.setFillColor((maskFillColor(for: mask) ?? UIColor(cgColor: inactiveFill)).cgColor)
            let isSelected = i == selectedMaskIndex
            let isHighlighted = highlightedMaskIndices.contains(i)
            ctx.setStrokeColor(((isSelected || isHighlighted) ? UIColor.systemBlue : UIColor(cgColor: inactiveStroke)).cgColor)
            ctx.setLineWidth((isSelected || isHighlighted) ? 2.5 : 1.5)
            drawMask(ctx: ctx, mask: mask, imgRect: imgRect)
            drawOrdinal(ctx: ctx, index: i, mask: mask, imgRect: imgRect)
            if isSelected || isHighlighted {
                drawSelectionOutline(
                    ctx: ctx,
                    mask: mask,
                    imgRect: imgRect,
                    showsHandles: shapeType == .select && isSelected && activeSelectionIndices.count <= 1
                )
            }
        }

        // In-progress drag (rect or ellipse)
        if let dr = currentDragRect {
            ctx.setFillColor(UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 0.5).cgColor)
            ctx.setStrokeColor(UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.8).cgColor)
            ctx.setLineWidth(1.5)
            if shapeType == .ellipse {
                ctx.addEllipse(in: dr)
            } else {
                ctx.addRect(dr)
            }
            ctx.drawPath(using: .fillStroke)
        }

        // In-progress polygon
        if !polygonPoints.isEmpty {
            ctx.setFillColor(UIColor(red: 1, green: 0.55, blue: 0.55, alpha: 0.3).cgColor)
            ctx.setStrokeColor(UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.9).cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: polygonPoints[0])
            for pt in polygonPoints.dropFirst() { ctx.addLine(to: pt) }
            ctx.drawPath(using: .fillStroke)
            for pt in polygonPoints {
                ctx.setFillColor(UIColor.systemRed.cgColor)
                ctx.fillEllipse(in: CGRect(x: pt.x - 4, y: pt.y - 4, width: 8, height: 8))
            }
        }
    }

    // MARK: - Gestures
    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        let loc = g.location(in: self)
        let imgRect = imageRect(in: bounds)
        switch g.state {
        case .began:
            if let drag = beginMaskDrag(at: loc, imgRect: imgRect) {
                coordinator?.beginTransform()
                activeDrag = drag
                return
            }
            guard shapeType == .rect || shapeType == .ellipse else { return }
            dragStart = loc
            currentDragRect = nil
        case .changed:
            if let activeDrag {
                updateMaskDrag(activeDrag, location: loc, imgRect: imgRect)
                return
            }
            guard shapeType == .rect || shapeType == .ellipse else { return }
            guard let start = dragStart else { return }
            currentDragRect = makeRect(from: start, to: loc)
            setNeedsDisplay()
        case .ended:
            if activeDrag != nil {
                // Clear the drag first so `updateUIView` stops guarding, then
                // commit -- the model snapshots `masks` inside
                // `finishTransform()`, so the write has to land before it.
                activeDrag = nil
                coordinator?.commitMasks(masks)
                coordinator?.finishTransform()
                setNeedsDisplay()
                return
            }
            guard shapeType == .rect || shapeType == .ellipse else { return }
            guard let start = dragStart else { return }
            let r = makeRect(from: start, to: loc)
            let mask = normalizedMask(from: r, in: imgRect)
            coordinator?.appendMask(mask)
            dragStart = nil
            currentDragRect = nil
            setNeedsDisplay()
        default:
            if activeDrag != nil {
                activeDrag = nil
                coordinator?.commitMasks(masks)
                coordinator?.finishTransform()
            }
            activeDrag = nil
            dragStart = nil
            currentDragRect = nil
            setNeedsDisplay()
        }
    }

    @objc private func handleTap(_ g: UITapGestureRecognizer) {
        let location = g.location(in: self)
        let imgRect = imageRect(in: bounds)
        if shapeType == .polygon {
            polygonPoints.append(location)
            setNeedsDisplay()
            return
        }
        if shapeType == .text {
            guard imgRect.contains(location) else { return }
            let normalizedPoint = CGPoint(
                x: max(0, min(1, (location.x - imgRect.minX) / imgRect.width)),
                y: max(0, min(1, (location.y - imgRect.minY) / imgRect.height))
            )
            coordinator?.requestText(at: normalizedPoint)
            return
        }

        let selected = hitTestMaskIndex(at: location, imgRect: imgRect)
        if shapeType == .select, let selected {
            coordinator?.selectMask(.toggle(selected))
        } else {
            selectedMaskIndex = selected
            coordinator?.selectMask(.replace(selected))
        }
        setNeedsDisplay()
    }

    @objc private func handleDoubleTap(_ g: UITapGestureRecognizer) {
        if shapeType == .select {
            let location = g.location(in: self)
            let imgRect = imageRect(in: bounds)
            if let hitIndex = hitTestMaskIndex(at: location, imgRect: imgRect),
               case .text = masks[hitIndex] {
                coordinator?.requestTextEdit(at: hitIndex)
            }
            return
        }

        guard shapeType == .polygon else { return }
        if polygonPoints.count >= 3 {
            let imgRect = imageRect(in: bounds)
            let pts = polygonPoints.map { pt -> CGPoint in
                CGPoint(
                    x: max(0, min(1, (pt.x - imgRect.minX) / imgRect.width)),
                    y: max(0, min(1, (pt.y - imgRect.minY) / imgRect.height))
                )
            }
            coordinator?.appendMask(.polygon(points: pts, extras: [:]))
        }
        polygonPoints.removeAll()
        setNeedsDisplay()
    }

}
#endif
