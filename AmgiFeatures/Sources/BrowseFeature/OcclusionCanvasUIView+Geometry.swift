//
//  OcclusionCanvasUIView+Geometry.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 29.04.2026.
//

#if canImport(UIKit)
import Theme
import SwiftUI
import UIKit

extension OcclusionCanvasUIView {
    // MARK: - Helpers

    func makeRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: Swift.abs(b.x - a.x), height: Swift.abs(b.y - a.y))
    }

    func imageRect(in bounds: CGRect) -> CGRect {
        // Guard the divisors the way the sibling canvases already do. A
        // zero-sized image (first layout pass, or a decode failure) made
        // this Inf/NaN, which then propagated into mask coordinates through
        // the unclamped conversions below.
        let s = image.size
        guard s.width > 0, s.height > 0 else { return .zero }
        let scale = min(bounds.width / s.width, bounds.height / s.height)
        let w = s.width * scale, h = s.height * scale
        return CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }

    func normalizedMask(from r: CGRect, in imgRect: CGRect) -> IOMask {
        let l = max(0, min(1, (r.minX - imgRect.minX) / imgRect.width))
        let t = max(0, min(1, (r.minY - imgRect.minY) / imgRect.height))
        let w = max(0, min(1 - l, r.width / imgRect.width))
        let h = max(0, min(1 - t, r.height / imgRect.height))
        if shapeType == .ellipse {
            return .ellipse(left: l, top: t, rx: w / 2, ry: h / 2, extras: [:])
        } else {
            return .rect(left: l, top: t, width: w, height: h, extras: [:])
        }
    }

    func maskFillColor(for mask: IOMask) -> UIColor? {
        guard let fill = mask.extras["fill"] else { return nil }
        guard let color = UIColor(amgiHex: fill) else { return nil }
        return color.withAlphaComponent(maskOpacity)
    }

    func textFrame(
        for text: String,
        left: CGFloat,
        top: CGFloat,
        scale: CGFloat,
        fontSize: CGFloat,
        imgRect: CGRect
    ) -> CGRect {
        let font = textFont(scale: scale, fontSize: fontSize, imgRect: imgRect)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let padding = CGSize(width: 20, height: 12)
        let origin = CGPoint(
            x: imgRect.minX + left * imgRect.width,
            y: imgRect.minY + top * imgRect.height
        )
        return CGRect(origin: origin, size: CGSize(width: textSize.width + padding.width, height: textSize.height + padding.height))
    }

    func textFont(scale: CGFloat, fontSize: CGFloat, imgRect: CGRect) -> UIFont {
        let resolvedSize = max(14, imgRect.height * max(fontSize, 0.02) * max(scale, 1))
        return UIFont.systemFont(ofSize: resolvedSize, weight: .semibold)
    }

    func drawSelectionOutline(ctx: CGContext, mask: IOMask, imgRect: CGRect, showsHandles: Bool) {
        let geometry = selectionGeometry(for: mask, imgRect: imgRect)
        ctx.saveGState()
        ctx.setStrokeColor(UIColor.systemBlue.cgColor)
        ctx.setLineWidth(2)

        ctx.beginPath()
        ctx.move(to: geometry.corners[0])
        for corner in geometry.corners.dropFirst() { ctx.addLine(to: corner) }
        ctx.closePath()
        ctx.strokePath()

        guard showsHandles else {
            ctx.restoreGState()
            return
        }

        ctx.beginPath()
        ctx.move(to: geometry.rotationStemStart)
        ctx.addLine(to: geometry.rotationStemEnd)
        ctx.strokePath()

        let handleFill = UIColor(red: 0.73, green: 0.82, blue: 1, alpha: 1)
        ctx.setFillColor(handleFill.cgColor)
        for handle in SelectionHandle.allCases {
            guard let center = geometry.handleCenters[handle] else { continue }
            let rect = visualHandleRect(center: center).insetBy(dx: 0.5, dy: 0.5)
            ctx.fillEllipse(in: rect)
            ctx.strokeEllipse(in: rect)
        }

        ctx.restoreGState()
    }

    func maskBounds(for mask: IOMask, imgRect: CGRect) -> CGRect {
        if let box = boxTransform(for: mask, imgRect: imgRect) {
            return boundingRect(of: boxCorners(origin: box.origin, size: box.size, angle: box.angle, outset: 0))
        }

        switch mask {
        case .polygon(let pts, _):
            let absolutePoints = pts.map {
                CGPoint(x: imgRect.minX + $0.x * imgRect.width, y: imgRect.minY + $0.y * imgRect.height)
            }
            let xs = absolutePoints.map(\.x)
            let ys = absolutePoints.map(\.y)
            return CGRect(
                x: xs.min() ?? imgRect.minX,
                y: ys.min() ?? imgRect.minY,
                width: (xs.max() ?? imgRect.minX) - (xs.min() ?? imgRect.minX),
                height: (ys.max() ?? imgRect.minY) - (ys.min() ?? imgRect.minY)
            )
        default:
            return .zero
        }
    }

    func hitTestMaskIndex(at point: CGPoint, imgRect: CGRect) -> Int? {
        for index in masks.indices.reversed() {
            if maskContainsPoint(masks[index], point: point, imgRect: imgRect) {
                return index
            }
        }
        return nil
    }

    func maskContainsPoint(_ mask: IOMask, point: CGPoint, imgRect: CGRect) -> Bool {
        switch mask {
        case .rect, .text:
            guard let box = boxTransform(for: mask, imgRect: imgRect) else { return false }
            let translated = CGPoint(
                x: point.x - box.origin.x,
                y: point.y - box.origin.y
            )
            let local = rotate(translated, by: -box.angle)
            return CGRect(origin: .zero, size: box.size).contains(local)
        case .ellipse:
            guard let box = boxTransform(for: mask, imgRect: imgRect),
                  box.size.width > 0,
                  box.size.height > 0 else { return false }
            let translated = CGPoint(
                x: point.x - box.origin.x,
                y: point.y - box.origin.y
            )
            let local = rotate(translated, by: -box.angle)
            let center = CGPoint(x: box.size.width / 2, y: box.size.height / 2)
            let normalizedX = (local.x - center.x) / (box.size.width / 2)
            let normalizedY = (local.y - center.y) / (box.size.height / 2)
            return normalizedX * normalizedX + normalizedY * normalizedY <= 1
        case .polygon(let pts, _):
            let path = UIBezierPath()
            guard let first = pts.first else { return false }
            path.move(to: CGPoint(
                x: imgRect.minX + first.x * imgRect.width,
                y: imgRect.minY + first.y * imgRect.height
            ))
            for pt in pts.dropFirst() {
                path.addLine(to: CGPoint(
                    x: imgRect.minX + pt.x * imgRect.width,
                    y: imgRect.minY + pt.y * imgRect.height
                ))
            }
            path.close()
            return path.contains(point)
        }
    }

    func beginMaskDrag(at location: CGPoint, imgRect: CGRect) -> ActiveDrag? {
        let selectionIndices = resolvedSelectionIndices()
        if shapeType == .select,
           let selectedMaskIndex,
           masks.indices.contains(selectedMaskIndex) {
            let selectedMask = masks[selectedMaskIndex]
            if selectionIndices.count <= 1,
               let handle = selectionHandle(at: location, mask: selectedMask, imgRect: imgRect) {
                if handle == .rotate {
                    let pivot = rotationPivot(for: selectedMask, imgRect: imgRect)
                    return .rotate(
                        maskIndex: selectedMaskIndex,
                        pivot: pivot,
                        startAngle: atan2(location.y - pivot.y, location.x - pivot.x),
                        original: selectedMask
                    )
                }
                return .resize(maskIndex: selectedMaskIndex, handle: handle, original: selectedMask)
            }
            if selectionIndices.count > 1,
               selectionIndices.contains(where: { maskContainsPoint(masks[$0], point: location, imgRect: imgRect) }) {
                return .move(maskIndices: selectionIndices, start: location, originals: originalMasks(for: selectionIndices))
            }
            if maskContainsPoint(selectedMask, point: location, imgRect: imgRect) {
                return .move(maskIndices: [selectedMaskIndex], start: location, originals: originalMasks(for: [selectedMaskIndex]))
            }
        }

        if shapeType == .polygon,
           let selectedMaskIndex,
           masks.indices.contains(selectedMaskIndex) {
            let selectedMask = masks[selectedMaskIndex]
            if case .polygon(let points, _) = selectedMask,
               let vertexIndex = polygonVertexIndex(near: location, points: points, imgRect: imgRect) {
                return .polygonVertex(maskIndex: selectedMaskIndex, vertexIndex: vertexIndex)
            }
        }

        guard shapeType == .select else {
            return nil
        }

        if let selectedMaskIndex,
           masks.indices.contains(selectedMaskIndex) {
            let selectedMask = masks[selectedMaskIndex]
            if maskContainsPoint(selectedMask, point: location, imgRect: imgRect) {
                return .move(
                    maskIndices: [selectedMaskIndex],
                    start: location,
                    originals: originalMasks(for: [selectedMaskIndex])
                )
            }
        }

        guard let hitIndex = hitTestMaskIndex(at: location, imgRect: imgRect),
              masks.indices.contains(hitIndex) else {
            return nil
        }
        let hitMask = masks[hitIndex]
        selectedMaskIndex = hitIndex
        coordinator?.selectMask(.replace(hitIndex))
        return .move(maskIndices: [hitIndex], start: location, originals: [hitIndex: hitMask])
    }

    /// Apply one frame of a drag to the canvas's own `masks`. Deliberately
    /// does *not* write through the coordinator's binding: doing that per frame
    /// round-tripped every drag through SwiftUI state.
    private func setMaskDuringDrag(at index: Int, to mask: IOMask) {
        guard masks.indices.contains(index) else { return }
        masks[index] = mask
    }

    func updateMaskDrag(_ drag: ActiveDrag, location: CGPoint, imgRect: CGRect) {
        switch drag {
        case .move(let maskIndices, let start, let originals):
            let delta = CGPoint(x: location.x - start.x, y: location.y - start.y)
            for maskIndex in maskIndices {
                guard let original = originals[maskIndex],
                      let updated = movedMask(original, delta: delta, imgRect: imgRect) else {
                    continue
                }
                setMaskDuringDrag(at: maskIndex, to: updated)
            }
        case .resize(let maskIndex, let handle, let original):
            guard let updated = resizedMask(original, handle: handle, location: location, imgRect: imgRect) else { return }
            setMaskDuringDrag(at: maskIndex, to: updated)
        case .rotate(let maskIndex, let pivot, let startAngle, let original):
            let currentAngle = atan2(location.y - pivot.y, location.x - pivot.x)
            guard let updated = rotatedMask(original, delta: currentAngle - startAngle, imgRect: imgRect) else { return }
            setMaskDuringDrag(at: maskIndex, to: updated)
        case .polygonVertex(let maskIndex, let vertexIndex):
            guard case .polygon(let points, let extras) = masks[maskIndex] else { return }
            var updatedPoints = points
            updatedPoints[vertexIndex] = CGPoint(
                x: max(0, min(1, (location.x - imgRect.minX) / imgRect.width)),
                y: max(0, min(1, (location.y - imgRect.minY) / imgRect.height))
            )
            setMaskDuringDrag(at: maskIndex, to: .polygon(points: updatedPoints, extras: extras))
        }
        setNeedsDisplay()
    }

    func movedMask(_ mask: IOMask, delta: CGPoint, imgRect: CGRect) -> IOMask? {
        // Unlike the clamped conversions elsewhere in this file, dx/dy flow
        // straight into mask coordinates — so a zero-sized imgRect would put
        // NaN in the note and sync it.
        guard imgRect.width > 0, imgRect.height > 0 else { return nil }
        let dx = delta.x / imgRect.width
        let dy = delta.y / imgRect.height
        switch mask {
        case .rect(let left, let top, let width, let height, let extras):
            return .rect(
                left: max(0, min(1 - width, left + dx)),
                top: max(0, min(1 - height, top + dy)),
                width: width,
                height: height,
                extras: extras
            )
        case .ellipse(let left, let top, let rx, let ry, let extras):
            return .ellipse(
                left: max(0, min(1 - rx * 2, left + dx)),
                top: max(0, min(1 - ry * 2, top + dy)),
                rx: rx,
                ry: ry,
                extras: extras
            )
        case .polygon(let points, let extras):
            let minX = points.map(\.x).min() ?? 0
            let maxX = points.map(\.x).max() ?? 1
            let minY = points.map(\.y).min() ?? 0
            let maxY = points.map(\.y).max() ?? 1
            let clampedDX = max(-minX, min(1 - maxX, dx))
            let clampedDY = max(-minY, min(1 - maxY, dy))
            let shifted = points.map {
                CGPoint(x: $0.x + clampedDX, y: $0.y + clampedDY)
            }
            return .polygon(points: shifted, extras: extras)
        case .text(let left, let top, let text, let scale, let fontSize, let extras):
            let frame = textFrame(for: text, left: left, top: top, scale: scale, fontSize: fontSize, imgRect: imgRect)
            let normalizedWidth = frame.width / imgRect.width
            let normalizedHeight = frame.height / imgRect.height
            return .text(
                left: max(0, min(1 - normalizedWidth, left + dx)),
                top: max(0, min(1 - normalizedHeight, top + dy)),
                text: text,
                scale: scale,
                fontSize: fontSize,
                extras: extras
            )
        }
    }

    private func resizedMask(_ mask: IOMask, handle: SelectionHandle, location: CGPoint, imgRect: CGRect) -> IOMask? {
        switch mask {
        case .polygon(let points, let extras):
            let originalBounds = maskBounds(for: mask, imgRect: imgRect)
            guard originalBounds.width > 0, originalBounds.height > 0,
                  let resizedBounds = resizedFrame(
                    originalBounds,
                    handle: handle,
                    location: location,
                    angle: 0,
                    minimumSize: CGSize(width: minimumBoxDimension, height: minimumBoxDimension)
                  ) else {
                return nil
            }

            let updatedPoints = points.map { point -> CGPoint in
                let absolute = absolutePoint(for: point, imgRect: imgRect)
                let relativeX = originalBounds.width > 0 ? (absolute.x - originalBounds.minX) / originalBounds.width : 0.5
                let relativeY = originalBounds.height > 0 ? (absolute.y - originalBounds.minY) / originalBounds.height : 0.5
                let resizedAbsolute = CGPoint(
                    x: resizedBounds.minX + relativeX * resizedBounds.width,
                    y: resizedBounds.minY + relativeY * resizedBounds.height
                )
                return normalizedPoint(for: resizedAbsolute, imgRect: imgRect)
            }
            return .polygon(points: updatedPoints, extras: extras)
        case .text(_, _, let text, let scale, let fontSize, let extras):
            guard let box = boxTransform(for: mask, imgRect: imgRect),
                  let resizedFrame = resizedFrame(
                    CGRect(origin: rotate(box.origin, by: -box.angle), size: box.size),
                    handle: handle,
                    location: location,
                    angle: box.angle,
                    minimumSize: CGSize(width: minimumBoxDimension, height: minimumBoxDimension)
                  ) else {
                return nil
            }

            let safeScale = max(scale, minimumTextScale)
            let widthRatio = resizedFrame.width / max(box.size.width, 1)
            let heightRatio = resizedFrame.height / max(box.size.height, 1)
            let scaleFactor: CGFloat
            switch handle {
            case .left, .right:
                scaleFactor = widthRatio
            case .top, .bottom:
                scaleFactor = heightRatio
            default:
                scaleFactor = max(widthRatio, heightRatio)
            }

            let newScale = max(minimumTextScale, safeScale * scaleFactor)
            let actualScaleRatio = newScale / safeScale
            let actualSize = CGSize(width: box.size.width * actualScaleRatio, height: box.size.height * actualScaleRatio)
            let actualFrame = anchoredFrame(for: resizedFrame, size: actualSize, handle: handle)
            let newOrigin = rotate(actualFrame.origin, by: box.angle)
            let normalizedWidth = min(1, actualSize.width / imgRect.width)
            let normalizedHeight = min(1, actualSize.height / imgRect.height)
            let clampedLeft = max(0, min(1 - normalizedWidth, (newOrigin.x - imgRect.minX) / imgRect.width))
            let clampedTop = max(0, min(1 - normalizedHeight, (newOrigin.y - imgRect.minY) / imgRect.height))
            return .text(
                left: clampedLeft,
                top: clampedTop,
                text: text,
                scale: newScale,
                fontSize: fontSize,
                extras: extrasSettingAngle(extras, radians: box.angle)
            )
        case .rect, .ellipse:
            guard let box = boxTransform(for: mask, imgRect: imgRect),
                  let resizedFrame = resizedFrame(
                    CGRect(origin: rotate(box.origin, by: -box.angle), size: box.size),
                    handle: handle,
                    location: location,
                    angle: box.angle,
                    minimumSize: CGSize(width: minimumBoxDimension, height: minimumBoxDimension)
                  ) else {
                return nil
            }
            let newOrigin = rotate(resizedFrame.origin, by: box.angle)
            return updatedBoxMask(mask, origin: newOrigin, size: resizedFrame.size, angle: box.angle, imgRect: imgRect)
        }
    }

    func handleRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - handleHitDiameter / 2,
            y: center.y - handleHitDiameter / 2,
            width: handleHitDiameter,
            height: handleHitDiameter
        )
    }

    func visualHandleRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - handleVisualDiameter / 2,
            y: center.y - handleVisualDiameter / 2,
            width: handleVisualDiameter,
            height: handleVisualDiameter
        )
    }

    func resolvedSelectionIndices() -> [Int] {
        let indices = activeSelectionIndices.filter { masks.indices.contains($0) }.sorted()
        if !indices.isEmpty {
            return indices
        }
        guard let selectedMaskIndex, masks.indices.contains(selectedMaskIndex) else {
            return []
        }
        return [selectedMaskIndex]
    }

    func originalMasks(for indices: [Int]) -> [Int: IOMask] {
        Dictionary(uniqueKeysWithValues: indices.compactMap { index in
            guard masks.indices.contains(index) else { return nil }
            return (index, masks[index])
        })
    }

    func polygonVertexIndex(near point: CGPoint, points: [CGPoint], imgRect: CGRect) -> Int? {
        for (index, polygonPoint) in points.enumerated() {
            let absolute = CGPoint(x: imgRect.minX + polygonPoint.x * imgRect.width, y: imgRect.minY + polygonPoint.y * imgRect.height)
            if handleRect(center: absolute).contains(point) {
                return index
            }
        }
        return nil
    }

    // Internal rather than private: the drawing extension lives in its
    // own file now.
    func boxTransform(for mask: IOMask, imgRect: CGRect) -> BoxTransform? {
        switch mask {
        case .rect(let left, let top, let width, let height, _):
            return BoxTransform(
                origin: CGPoint(x: imgRect.minX + left * imgRect.width, y: imgRect.minY + top * imgRect.height),
                size: CGSize(width: width * imgRect.width, height: height * imgRect.height),
                angle: angleRadians(for: mask)
            )
        case .ellipse(let left, let top, let rx, let ry, _):
            return BoxTransform(
                origin: CGPoint(x: imgRect.minX + left * imgRect.width, y: imgRect.minY + top * imgRect.height),
                size: CGSize(width: rx * imgRect.width * 2, height: ry * imgRect.height * 2),
                angle: angleRadians(for: mask)
            )
        case .text(let left, let top, let text, let scale, let fontSize, _):
            let frame = textFrame(for: text, left: left, top: top, scale: scale, fontSize: fontSize, imgRect: imgRect)
            return BoxTransform(origin: frame.origin, size: frame.size, angle: angleRadians(for: mask))
        case .polygon:
            return nil
        }
    }

    private func selectionGeometry(for mask: IOMask, imgRect: CGRect) -> SelectionGeometry {
        if let box = boxTransform(for: mask, imgRect: imgRect) {
            let corners = boxCorners(origin: box.origin, size: box.size, angle: box.angle, outset: selectionOutset)
            let topCenter = midpoint(corners[0], corners[1])
            let rightCenter = midpoint(corners[1], corners[2])
            let bottomCenter = midpoint(corners[2], corners[3])
            let leftCenter = midpoint(corners[3], corners[0])
            let tangent = normalizedVector(from: corners[0], to: corners[1])
            let outwardNormal = CGPoint(x: tangent.y, y: -tangent.x)
            let rotationHandle = CGPoint(
                x: topCenter.x + outwardNormal.x * rotationHandleDistance,
                y: topCenter.y + outwardNormal.y * rotationHandleDistance
            )
            return SelectionGeometry(
                corners: corners,
                handleCenters: [
                    .topLeft: corners[0],
                    .top: topCenter,
                    .topRight: corners[1],
                    .right: rightCenter,
                    .bottomRight: corners[2],
                    .bottom: bottomCenter,
                    .bottomLeft: corners[3],
                    .left: leftCenter,
                    .rotate: rotationHandle
                ],
                rotationStemStart: topCenter,
                rotationStemEnd: rotationHandle,
                center: maskCenter(for: mask, imgRect: imgRect)
            )
        }

        let paddedBounds = maskBounds(for: mask, imgRect: imgRect).insetBy(dx: -selectionOutset, dy: -selectionOutset)
        let corners = [
            CGPoint(x: paddedBounds.minX, y: paddedBounds.minY),
            CGPoint(x: paddedBounds.maxX, y: paddedBounds.minY),
            CGPoint(x: paddedBounds.maxX, y: paddedBounds.maxY),
            CGPoint(x: paddedBounds.minX, y: paddedBounds.maxY)
        ]
        let topCenter = CGPoint(x: paddedBounds.midX, y: paddedBounds.minY)
        let rightCenter = CGPoint(x: paddedBounds.maxX, y: paddedBounds.midY)
        let bottomCenter = CGPoint(x: paddedBounds.midX, y: paddedBounds.maxY)
        let leftCenter = CGPoint(x: paddedBounds.minX, y: paddedBounds.midY)
        let rotationHandle = CGPoint(x: paddedBounds.midX, y: paddedBounds.minY - rotationHandleDistance)
        return SelectionGeometry(
            corners: corners,
            handleCenters: [
                .topLeft: corners[0],
                .top: topCenter,
                .topRight: corners[1],
                .right: rightCenter,
                .bottomRight: corners[2],
                .bottom: bottomCenter,
                .bottomLeft: corners[3],
                .left: leftCenter,
                .rotate: rotationHandle
            ],
            rotationStemStart: topCenter,
            rotationStemEnd: rotationHandle,
            center: CGPoint(x: paddedBounds.midX, y: paddedBounds.midY)
        )
    }

    private func selectionHandle(at point: CGPoint, mask: IOMask, imgRect: CGRect) -> SelectionHandle? {
        let geometry = selectionGeometry(for: mask, imgRect: imgRect)
        let orderedHandles: [SelectionHandle] = [.rotate, .topLeft, .top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left]
        for handle in orderedHandles {
            if let center = geometry.handleCenters[handle], handleRect(center: center).contains(point) {
                return handle
            }
        }
        return nil
    }

    func maskCenter(for mask: IOMask, imgRect: CGRect) -> CGPoint {
        if let box = boxTransform(for: mask, imgRect: imgRect) {
            return transformedPoint(CGPoint(x: box.size.width / 2, y: box.size.height / 2), origin: box.origin, angle: box.angle)
        }

        if case .polygon(let points, _) = mask, !points.isEmpty {
            let centerX = points.map(\.x).reduce(0, +) / CGFloat(points.count)
            let centerY = points.map(\.y).reduce(0, +) / CGFloat(points.count)
            return absolutePoint(for: CGPoint(x: centerX, y: centerY), imgRect: imgRect)
        }

        return .zero
    }

    func rotationPivot(for mask: IOMask, imgRect: CGRect) -> CGPoint {
        selectionGeometry(for: mask, imgRect: imgRect).center
    }

    func boxCorners(origin: CGPoint, size: CGSize, angle: CGFloat, outset: CGFloat) -> [CGPoint] {
        let localCorners = [
            CGPoint(x: -outset, y: -outset),
            CGPoint(x: size.width + outset, y: -outset),
            CGPoint(x: size.width + outset, y: size.height + outset),
            CGPoint(x: -outset, y: size.height + outset)
        ]
        return localCorners.map { transformedPoint($0, origin: origin, angle: angle) }
    }

    private func resizedFrame(
        _ originalFrame: CGRect,
        handle: SelectionHandle,
        location: CGPoint,
        angle: CGFloat,
        minimumSize: CGSize
    ) -> CGRect? {
        guard handle != .rotate else { return nil }

        let rotatedLocation = rotate(location, by: -angle)
        var minX = originalFrame.minX
        var maxX = originalFrame.maxX
        var minY = originalFrame.minY
        var maxY = originalFrame.maxY

        switch handle {
        case .topLeft:
            minX = min(rotatedLocation.x, maxX - minimumSize.width)
            minY = min(rotatedLocation.y, maxY - minimumSize.height)
        case .top:
            minY = min(rotatedLocation.y, maxY - minimumSize.height)
        case .topRight:
            maxX = max(rotatedLocation.x, minX + minimumSize.width)
            minY = min(rotatedLocation.y, maxY - minimumSize.height)
        case .right:
            maxX = max(rotatedLocation.x, minX + minimumSize.width)
        case .bottomRight:
            maxX = max(rotatedLocation.x, minX + minimumSize.width)
            maxY = max(rotatedLocation.y, minY + minimumSize.height)
        case .bottom:
            maxY = max(rotatedLocation.y, minY + minimumSize.height)
        case .bottomLeft:
            minX = min(rotatedLocation.x, maxX - minimumSize.width)
            maxY = max(rotatedLocation.y, minY + minimumSize.height)
        case .left:
            minX = min(rotatedLocation.x, maxX - minimumSize.width)
        case .rotate:
            return nil
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func anchoredFrame(for targetFrame: CGRect, size: CGSize, handle: SelectionHandle) -> CGRect {
        switch handle {
        case .topLeft:
            return CGRect(x: targetFrame.maxX - size.width, y: targetFrame.maxY - size.height, width: size.width, height: size.height)
        case .top:
            return CGRect(x: targetFrame.midX - size.width / 2, y: targetFrame.maxY - size.height, width: size.width, height: size.height)
        case .topRight:
            return CGRect(x: targetFrame.minX, y: targetFrame.maxY - size.height, width: size.width, height: size.height)
        case .right:
            return CGRect(x: targetFrame.minX, y: targetFrame.midY - size.height / 2, width: size.width, height: size.height)
        case .bottomRight:
            return CGRect(x: targetFrame.minX, y: targetFrame.minY, width: size.width, height: size.height)
        case .bottom:
            return CGRect(x: targetFrame.midX - size.width / 2, y: targetFrame.minY, width: size.width, height: size.height)
        case .bottomLeft:
            return CGRect(x: targetFrame.maxX - size.width, y: targetFrame.minY, width: size.width, height: size.height)
        case .left:
            return CGRect(x: targetFrame.maxX - size.width, y: targetFrame.midY - size.height / 2, width: size.width, height: size.height)
        case .rotate:
            return CGRect(origin: targetFrame.origin, size: size)
        }
    }

    func rotatedMask(_ mask: IOMask, delta: CGFloat, imgRect: CGRect) -> IOMask? {
        switch mask {
        case .polygon(let points, let extras):
            let pivot = rotationPivot(for: mask, imgRect: imgRect)
            let updatedPoints = points.map { point in
                let absolute = absolutePoint(for: point, imgRect: imgRect)
                return normalizedPoint(for: rotate(absolute, by: delta, around: pivot), imgRect: imgRect)
            }
            return .polygon(points: updatedPoints, extras: extras)
        case .rect, .ellipse, .text:
            guard let box = boxTransform(for: mask, imgRect: imgRect) else { return nil }
            let center = maskCenter(for: mask, imgRect: imgRect)
            let newAngle = box.angle + delta
            let rotatedHalfSize = rotate(CGPoint(x: box.size.width / 2, y: box.size.height / 2), by: newAngle)
            let newOrigin = CGPoint(x: center.x - rotatedHalfSize.x, y: center.y - rotatedHalfSize.y)
            return updatedBoxMask(mask, origin: newOrigin, size: box.size, angle: newAngle, imgRect: imgRect)
        }
    }

    func updatedBoxMask(_ mask: IOMask, origin: CGPoint, size: CGSize, angle: CGFloat, imgRect: CGRect) -> IOMask? {
        switch mask {
        case .rect(_, _, _, _, let extras):
            let normalizedWidth = max(minimumNormalizedDimension, min(1, size.width / imgRect.width))
            let normalizedHeight = max(minimumNormalizedDimension, min(1, size.height / imgRect.height))
            let left = max(0, min(1 - normalizedWidth, (origin.x - imgRect.minX) / imgRect.width))
            let top = max(0, min(1 - normalizedHeight, (origin.y - imgRect.minY) / imgRect.height))
            return .rect(
                left: left,
                top: top,
                width: normalizedWidth,
                height: normalizedHeight,
                extras: extrasSettingAngle(extras, radians: angle)
            )
        case .ellipse(_, _, _, _, let extras):
            let normalizedWidth = max(minimumNormalizedDimension, min(1, size.width / imgRect.width))
            let normalizedHeight = max(minimumNormalizedDimension, min(1, size.height / imgRect.height))
            let left = max(0, min(1 - normalizedWidth, (origin.x - imgRect.minX) / imgRect.width))
            let top = max(0, min(1 - normalizedHeight, (origin.y - imgRect.minY) / imgRect.height))
            return .ellipse(
                left: left,
                top: top,
                rx: normalizedWidth / 2,
                ry: normalizedHeight / 2,
                extras: extrasSettingAngle(extras, radians: angle)
            )
        case .text(_, _, let text, let scale, let fontSize, let extras):
            let normalizedWidth = min(1, size.width / imgRect.width)
            let normalizedHeight = min(1, size.height / imgRect.height)
            let left = max(0, min(1 - normalizedWidth, (origin.x - imgRect.minX) / imgRect.width))
            let top = max(0, min(1 - normalizedHeight, (origin.y - imgRect.minY) / imgRect.height))
            return .text(
                left: left,
                top: top,
                text: text,
                scale: scale,
                fontSize: fontSize,
                extras: extrasSettingAngle(extras, radians: angle)
            )
        case .polygon:
            return nil
        }
    }

    func angleRadians(for mask: IOMask) -> CGFloat {
        guard let rawValue = mask.extras["angle"], let degrees = Double(rawValue) else {
            return 0
        }
        return CGFloat(degrees) * .pi / 180
    }

    func extrasSettingAngle(_ extras: [String: String], radians: CGFloat) -> [String: String] {
        var updated = extras
        let degrees = normalizedDegrees(radians * 180 / .pi)
        if Swift.abs(degrees) < 0.1 {
            updated.removeValue(forKey: "angle")
        } else {
            updated["angle"] = String(format: "%.3g", degrees)
        }
        return updated
    }

    func normalizedDegrees(_ degrees: CGFloat) -> CGFloat {
        var wrapped = degrees.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { wrapped -= 360 }
        if wrapped <= -180 { wrapped += 360 }
        return wrapped
    }

    func transformedPoint(_ point: CGPoint, origin: CGPoint, angle: CGFloat) -> CGPoint {
        let rotated = rotate(point, by: angle)
        return CGPoint(
            x: origin.x + rotated.x,
            y: origin.y + rotated.y
        )
    }

    func absolutePoint(for point: CGPoint, imgRect: CGRect) -> CGPoint {
        CGPoint(x: imgRect.minX + point.x * imgRect.width, y: imgRect.minY + point.y * imgRect.height)
    }

    func normalizedPoint(for point: CGPoint, imgRect: CGRect) -> CGPoint {
        CGPoint(
            x: max(0, min(1, (point.x - imgRect.minX) / imgRect.width)),
            y: max(0, min(1, (point.y - imgRect.minY) / imgRect.height))
        )
    }

    func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(sqrt(dx * dx + dy * dy), .leastNonzeroMagnitude)
        return CGPoint(x: dx / length, y: dy / length)
    }

    func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x * cos(angle) - point.y * sin(angle),
            y: point.x * sin(angle) + point.y * cos(angle)
        )
    }

    func rotate(_ point: CGPoint, by angle: CGFloat, around pivot: CGPoint) -> CGPoint {
        let translated = CGPoint(
            x: point.x - pivot.x,
            y: point.y - pivot.y
        )
        let rotated = rotate(translated, by: angle)
        return CGPoint(
            x: rotated.x + pivot.x,
            y: rotated.y + pivot.y
        )
    }
}
#endif
