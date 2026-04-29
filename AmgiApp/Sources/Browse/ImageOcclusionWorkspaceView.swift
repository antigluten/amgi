import SwiftUI
import UIKit
import AmgiTheme

// MARK: - IOShapeType

enum IOShapeType: String, CaseIterable {
    case select, rect, ellipse, polygon, text

    var label: String {
        switch self {
        case .select:  return "Select"
        case .rect:    return "Rectangle"
        case .ellipse: return "Ellipse"
        case .polygon: return "Polygon"
        case .text:    return "Text"
        }
    }

    var systemImage: String {
        switch self {
        case .select:  return "cursorarrow"
        case .rect:    return "rectangle"
        case .ellipse: return "oval"
        case .polygon: return "pentagon"
        case .text:    return "textformat"
        }
    }
}

// MARK: - IOMask model

enum IOMask: Equatable {
    /// left/top/width/height in 0-1 fractions
    case rect(left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, extras: [String: String])
    /// left/top = top-left corner of bounding box; rx/ry = radii, all 0-1 fractions
    case ellipse(left: CGFloat, top: CGFloat, rx: CGFloat, ry: CGFloat, extras: [String: String])
    /// points: normalized (x, y) pairs
    case polygon(points: [CGPoint], extras: [String: String])
    /// left/top = top-left anchor; scale/fs match upstream image-occlusion text props.
    case text(left: CGFloat, top: CGFloat, text: String, scale: CGFloat, fontSize: CGFloat, extras: [String: String])

    func occlusionText(index: Int) -> String {
        let n = serializationOrdinal ?? (index + 1)
        switch self {
        case .rect(let l, let t, let w, let h, let extras):
            return clozeText(
                index: n,
                shape: "rect",
                properties: [("left", f(l)), ("top", f(t)), ("width", f(w)), ("height", f(h))],
                extras: extras,
                reservedKeys: ["left", "top", "width", "height"]
            )
        case .ellipse(let l, let t, let rx, let ry, let extras):
            return clozeText(
                index: n,
                shape: "ellipse",
                properties: [("left", f(l)), ("top", f(t)), ("rx", f(rx)), ("ry", f(ry))],
                extras: extras,
                reservedKeys: ["left", "top", "rx", "ry"]
            )
        case .polygon(let pts, let extras):
            let ptsStr = pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " ")
            return clozeText(
                index: n,
                shape: "polygon",
                properties: [("points", ptsStr)],
                extras: extras,
                reservedKeys: ["points"]
            )
        case .text(let l, let t, let text, let scale, let fontSize, let extras):
            return clozeText(
                index: n,
                shape: "text",
                properties: [("left", f(l)), ("top", f(t)), ("text", text), ("scale", f(scale)), ("fs", f(fontSize))],
                extras: extras,
                reservedKeys: ["left", "top", "text", "scale", "fs"]
            )
        }
    }

    var extras: [String: String] {
        switch self {
        case .rect(_, _, _, _, let extras),
             .ellipse(_, _, _, _, let extras),
             .polygon(_, let extras),
             .text(_, _, _, _, _, let extras):
            return extras
        }
    }

    var serializationOrdinal: Int? {
        guard let raw = extras[Self.internalOrdinalKey], let ordinal = Int(raw) else {
            return nil
        }
        return ordinal > 0 ? ordinal : nil
    }

    var occludesInactive: Bool {
        extras["oi"] == "1"
    }

    func applyingSerializationOrdinal(_ ordinal: Int?) -> IOMask {
        updatingExtras { currentExtras in
            var updatedExtras = currentExtras
            if let ordinal {
                updatedExtras[Self.internalOrdinalKey] = String(ordinal)
            } else {
                updatedExtras.removeValue(forKey: Self.internalOrdinalKey)
            }
            return updatedExtras
        }
    }

    func applyingOccludeInactive(_ enabled: Bool) -> IOMask {
        updatingExtras { currentExtras in
            var updatedExtras = currentExtras
            if enabled {
                updatedExtras["oi"] = "1"
            } else {
                updatedExtras.removeValue(forKey: "oi")
            }
            return updatedExtras
        }
    }

    func updatingText(_ newText: String, fillHex: String?) -> IOMask {
        switch self {
        case .text(let left, let top, _, let scale, let fontSize, let extras):
            var updatedExtras = extras
            if let fillHex, !fillHex.isEmpty {
                updatedExtras["fill"] = fillHex
            } else {
                updatedExtras.removeValue(forKey: "fill")
            }
            return .text(left: left, top: top, text: newText, scale: scale, fontSize: fontSize, extras: updatedExtras)
        default:
            return self
        }
    }

    private func updatingExtras(_ transform: ([String: String]) -> [String: String]) -> IOMask {
        switch self {
        case .rect(let left, let top, let width, let height, let extras):
            return .rect(left: left, top: top, width: width, height: height, extras: transform(extras))
        case .ellipse(let left, let top, let rx, let ry, let extras):
            return .ellipse(left: left, top: top, rx: rx, ry: ry, extras: transform(extras))
        case .polygon(let points, let extras):
            return .polygon(points: points, extras: transform(extras))
        case .text(let left, let top, let text, let scale, let fontSize, let extras):
            return .text(left: left, top: top, text: text, scale: scale, fontSize: fontSize, extras: transform(extras))
        }
    }

    private static let internalKeyPrefix = "_amgi_"
    private static let internalOrdinalKey = "_amgi_ordinal"

    private func clozeText(
        index: Int,
        shape: String,
        properties: [(String, String)],
        extras: [String: String],
        reservedKeys: Set<String>
    ) -> String {
        let extraTokens = extras.keys.sorted().compactMap { key -> String? in
            guard !reservedKeys.contains(key), let value = extras[key], !value.isEmpty else {
                return nil
            }
            guard !key.hasPrefix(Self.internalKeyPrefix) else {
                return nil
            }
            return "\(key)=\(value)"
        }
        let allTokens = properties.map { "\($0)=\($1)" } + extraTokens
        return "{{c\(index)::image-occlusion:\(shape):\(allTokens.joined(separator: ":"))}}"
    }

    private func f(_ v: CGFloat) -> String { String(format: "%.3g", v) }
}

// MARK: - IOMask fill extension

private extension IOMask {
    func applyingFill(_ hex: String?) -> IOMask {
        var updatedExtras = extras
        if let hex {
            updatedExtras["fill"] = hex
        } else {
            updatedExtras.removeValue(forKey: "fill")
        }

        switch self {
        case .rect(let left, let top, let width, let height, _):
            return .rect(left: left, top: top, width: width, height: height, extras: updatedExtras)
        case .ellipse(let left, let top, let rx, let ry, _):
            return .ellipse(left: left, top: top, rx: rx, ry: ry, extras: updatedExtras)
        case .polygon(let points, _):
            return .polygon(points: points, extras: updatedExtras)
        case .text(let left, let top, let text, let scale, let fontSize, _):
            return .text(left: left, top: top, text: text, scale: scale, fontSize: fontSize, extras: updatedExtras)
        }
    }
}

// MARK: - UIColor hex extension (IO)

private extension UIColor {
    convenience init?(ioHex: String) {
        let sanitized = ioHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6 || sanitized.count == 8,
              let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if sanitized.count == 8 {
            red = CGFloat((value & 0xFF000000) >> 24) / 255
            green = CGFloat((value & 0x00FF0000) >> 16) / 255
            blue = CGFloat((value & 0x0000FF00) >> 8) / 255
            alpha = CGFloat(value & 0x000000FF) / 255
        } else {
            red = CGFloat((value & 0xFF0000) >> 16) / 255
            green = CGFloat((value & 0x00FF00) >> 8) / 255
            blue = CGFloat(value & 0x0000FF) / 255
            alpha = 1
        }

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

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
        uiView.masks = masks
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

        func updateMask(at index: Int, to mask: IOMask) {
            guard masks.indices.contains(index) else { return }
            masks[index] = mask
        }

        func beginTransform() {
            onTransformDidBegin?()
        }

        func finishTransform() {
            onTransformDidEnd?()
        }
    }
}

// MARK: - OcclusionCanvasUIView

final class OcclusionCanvasUIView: UIView {
    private enum SelectionHandle: CaseIterable, Hashable {
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

    private enum ActiveDrag {
        case move(maskIndices: [Int], start: CGPoint, originals: [Int: IOMask])
        case resize(maskIndex: Int, handle: SelectionHandle, original: IOMask)
        case rotate(maskIndex: Int, pivot: CGPoint, startAngle: CGFloat, original: IOMask)
        case polygonVertex(maskIndex: Int, vertexIndex: Int)
    }

    private struct BoxTransform {
        let origin: CGPoint
        let size: CGSize
        let angle: CGFloat
    }

    private struct SelectionGeometry {
        let corners: [CGPoint]
        let handleCenters: [SelectionHandle: CGPoint]
        let rotationStemStart: CGPoint
        let rotationStemEnd: CGPoint
        let center: CGPoint
    }

    private let selectionOutset: CGFloat = 4
    private let handleVisualDiameter: CGFloat = 12
    private let handleHitDiameter: CGFloat = 28
    private let rotationHandleDistance: CGFloat = 34
    private let minimumBoxDimension: CGFloat = 24
    private let minimumNormalizedDimension: CGFloat = 0.02
    private let minimumTextScale: CGFloat = 0.25

    var image: UIImage
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

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let imgRect = imageRect(in: bounds)
        image.draw(in: imgRect)

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

    // MARK: - Draw helpers

    private func drawMask(ctx: CGContext, mask: IOMask, imgRect: CGRect) {
        switch mask {
        case .rect:
            guard let box = boxTransform(for: mask, imgRect: imgRect) else { return }
            ctx.saveGState()
            ctx.translateBy(x: box.origin.x, y: box.origin.y)
            if box.angle != 0 { ctx.rotate(by: box.angle) }
            ctx.addRect(CGRect(origin: .zero, size: box.size))
            ctx.drawPath(using: .fillStroke)
            ctx.restoreGState()
        case .ellipse:
            guard let box = boxTransform(for: mask, imgRect: imgRect) else { return }
            ctx.saveGState()
            ctx.translateBy(x: box.origin.x, y: box.origin.y)
            if box.angle != 0 { ctx.rotate(by: box.angle) }
            ctx.addEllipse(in: CGRect(origin: .zero, size: box.size))
            ctx.drawPath(using: .fillStroke)
            ctx.restoreGState()
        case .polygon(let pts, _):
            guard let first = pts.first else { return }
            let abs = { (p: CGPoint) -> CGPoint in
                CGPoint(x: imgRect.minX + p.x * imgRect.width,
                        y: imgRect.minY + p.y * imgRect.height)
            }
            ctx.move(to: abs(first))
            for pt in pts.dropFirst() { ctx.addLine(to: abs(pt)) }
            ctx.closePath()
            ctx.drawPath(using: .fillStroke)
        case .text(let left, let top, let text, let scale, let fontSize, _):
            let frame = textFrame(
                for: text,
                left: left,
                top: top,
                scale: scale,
                fontSize: fontSize,
                imgRect: imgRect
            )
            let angle = angleRadians(for: mask)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: textFont(scale: scale, fontSize: fontSize, imgRect: imgRect),
                .foregroundColor: UIColor(ioHex: mask.extras["fill"] ?? "") ?? UIColor.label
            ]

            ctx.saveGState()
            ctx.translateBy(x: frame.origin.x, y: frame.origin.y)
            if angle != 0 { ctx.rotate(by: angle) }

            let localFrame = CGRect(origin: .zero, size: frame.size)
            let backgroundPath = UIBezierPath(roundedRect: localFrame, cornerRadius: 8)
            ctx.addPath(backgroundPath.cgPath)
            ctx.setFillColor(UIColor(white: 1, alpha: 0.88).cgColor)
            ctx.drawPath(using: .fillStroke)

            UIGraphicsPushContext(ctx)
            (text as NSString).draw(at: CGPoint(x: 10, y: 6), withAttributes: attrs)
            UIGraphicsPopContext()
            ctx.restoreGState()
        }
    }

    private func drawOrdinal(ctx: CGContext, index: Int, mask: IOMask, imgRect: CGRect) {
        let center = maskCenter(for: mask, imgRect: imgRect)
        let label = "\(mask.serializationOrdinal ?? (index + 1))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.darkText
        ]
        let size = label.size(withAttributes: attrs)
        label.draw(
            at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2),
            withAttributes: attrs
        )
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
                activeDrag = nil
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

    // MARK: - Helpers

    private func makeRect(from a: CGPoint, to b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
               width: Swift.abs(b.x - a.x), height: Swift.abs(b.y - a.y))
    }

    private func imageRect(in bounds: CGRect) -> CGRect {
        let s = image.size
        let scale = min(bounds.width / s.width, bounds.height / s.height)
        let w = s.width * scale, h = s.height * scale
        return CGRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h)
    }

    private func normalizedMask(from r: CGRect, in imgRect: CGRect) -> IOMask {
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

    private func maskFillColor(for mask: IOMask) -> UIColor? {
        guard let fill = mask.extras["fill"] else { return nil }
        guard let color = UIColor(ioHex: fill) else { return nil }
        return color.withAlphaComponent(maskOpacity)
    }

    private func textFrame(
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

    private func textFont(scale: CGFloat, fontSize: CGFloat, imgRect: CGRect) -> UIFont {
        let resolvedSize = max(14, imgRect.height * max(fontSize, 0.02) * max(scale, 1))
        return UIFont.systemFont(ofSize: resolvedSize, weight: .semibold)
    }

    private func drawSelectionOutline(ctx: CGContext, mask: IOMask, imgRect: CGRect, showsHandles: Bool) {
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

    private func maskBounds(for mask: IOMask, imgRect: CGRect) -> CGRect {
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

    private func hitTestMaskIndex(at point: CGPoint, imgRect: CGRect) -> Int? {
        for index in masks.indices.reversed() {
            if maskContainsPoint(masks[index], point: point, imgRect: imgRect) {
                return index
            }
        }
        return nil
    }

    private func maskContainsPoint(_ mask: IOMask, point: CGPoint, imgRect: CGRect) -> Bool {
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

    private func beginMaskDrag(at location: CGPoint, imgRect: CGRect) -> ActiveDrag? {
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

    private func updateMaskDrag(_ drag: ActiveDrag, location: CGPoint, imgRect: CGRect) {
        switch drag {
        case .move(let maskIndices, let start, let originals):
            let delta = CGPoint(x: location.x - start.x, y: location.y - start.y)
            for maskIndex in maskIndices {
                guard let original = originals[maskIndex],
                      let updated = movedMask(original, delta: delta, imgRect: imgRect) else {
                    continue
                }
                coordinator?.updateMask(at: maskIndex, to: updated)
            }
        case .resize(let maskIndex, let handle, let original):
            guard let updated = resizedMask(original, handle: handle, location: location, imgRect: imgRect) else { return }
            coordinator?.updateMask(at: maskIndex, to: updated)
        case .rotate(let maskIndex, let pivot, let startAngle, let original):
            let currentAngle = atan2(location.y - pivot.y, location.x - pivot.x)
            guard let updated = rotatedMask(original, delta: currentAngle - startAngle, imgRect: imgRect) else { return }
            coordinator?.updateMask(at: maskIndex, to: updated)
        case .polygonVertex(let maskIndex, let vertexIndex):
            guard case .polygon(let points, let extras) = masks[maskIndex] else { return }
            var updatedPoints = points
            updatedPoints[vertexIndex] = CGPoint(
                x: max(0, min(1, (location.x - imgRect.minX) / imgRect.width)),
                y: max(0, min(1, (location.y - imgRect.minY) / imgRect.height))
            )
            coordinator?.updateMask(at: maskIndex, to: .polygon(points: updatedPoints, extras: extras))
        }
        setNeedsDisplay()
    }

    private func movedMask(_ mask: IOMask, delta: CGPoint, imgRect: CGRect) -> IOMask? {
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
        case .text(let left, let top, let text, let scale, let fontSize, let extras):
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

    private func handleRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - handleHitDiameter / 2,
            y: center.y - handleHitDiameter / 2,
            width: handleHitDiameter,
            height: handleHitDiameter
        )
    }

    private func visualHandleRect(center: CGPoint) -> CGRect {
        CGRect(
            x: center.x - handleVisualDiameter / 2,
            y: center.y - handleVisualDiameter / 2,
            width: handleVisualDiameter,
            height: handleVisualDiameter
        )
    }

    private func resolvedSelectionIndices() -> [Int] {
        let indices = activeSelectionIndices.filter { masks.indices.contains($0) }.sorted()
        if !indices.isEmpty {
            return indices
        }
        guard let selectedMaskIndex, masks.indices.contains(selectedMaskIndex) else {
            return []
        }
        return [selectedMaskIndex]
    }

    private func originalMasks(for indices: [Int]) -> [Int: IOMask] {
        Dictionary(uniqueKeysWithValues: indices.compactMap { index in
            guard masks.indices.contains(index) else { return nil }
            return (index, masks[index])
        })
    }

    private func polygonVertexIndex(near point: CGPoint, points: [CGPoint], imgRect: CGRect) -> Int? {
        for (index, polygonPoint) in points.enumerated() {
            let absolute = CGPoint(x: imgRect.minX + polygonPoint.x * imgRect.width, y: imgRect.minY + polygonPoint.y * imgRect.height)
            if handleRect(center: absolute).contains(point) {
                return index
            }
        }
        return nil
    }

    private func boxTransform(for mask: IOMask, imgRect: CGRect) -> BoxTransform? {
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

    private func maskCenter(for mask: IOMask, imgRect: CGRect) -> CGPoint {
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

    private func rotationPivot(for mask: IOMask, imgRect: CGRect) -> CGPoint {
        selectionGeometry(for: mask, imgRect: imgRect).center
    }

    private func boxCorners(origin: CGPoint, size: CGSize, angle: CGFloat, outset: CGFloat) -> [CGPoint] {
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

    private func rotatedMask(_ mask: IOMask, delta: CGFloat, imgRect: CGRect) -> IOMask? {
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

    private func updatedBoxMask(_ mask: IOMask, origin: CGPoint, size: CGSize, angle: CGFloat, imgRect: CGRect) -> IOMask? {
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

    private func angleRadians(for mask: IOMask) -> CGFloat {
        guard let rawValue = mask.extras["angle"], let degrees = Double(rawValue) else {
            return 0
        }
        return CGFloat(degrees) * .pi / 180
    }

    private func extrasSettingAngle(_ extras: [String: String], radians: CGFloat) -> [String: String] {
        var updated = extras
        let degrees = normalizedDegrees(radians * 180 / .pi)
        if Swift.abs(degrees) < 0.1 {
            updated.removeValue(forKey: "angle")
        } else {
            updated["angle"] = String(format: "%.3g", degrees)
        }
        return updated
    }

    private func normalizedDegrees(_ degrees: CGFloat) -> CGFloat {
        var wrapped = degrees.truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { wrapped -= 360 }
        if wrapped <= -180 { wrapped += 360 }
        return wrapped
    }

    private func transformedPoint(_ point: CGPoint, origin: CGPoint, angle: CGFloat) -> CGPoint {
        let rotated = rotate(point, by: angle)
        return CGPoint(
            x: origin.x + rotated.x,
            y: origin.y + rotated.y
        )
    }

    private func absolutePoint(for point: CGPoint, imgRect: CGRect) -> CGPoint {
        CGPoint(x: imgRect.minX + point.x * imgRect.width, y: imgRect.minY + point.y * imgRect.height)
    }

    private func normalizedPoint(for point: CGPoint, imgRect: CGRect) -> CGPoint {
        CGPoint(
            x: max(0, min(1, (point.x - imgRect.minX) / imgRect.width)),
            y: max(0, min(1, (point.y - imgRect.minY) / imgRect.height))
        )
    }

    private func midpoint(_ lhs: CGPoint, _ rhs: CGPoint) -> CGPoint {
        CGPoint(x: (lhs.x + rhs.x) / 2, y: (lhs.y + rhs.y) / 2)
    }

    private func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(sqrt(dx * dx + dy * dy), .leastNonzeroMagnitude)
        return CGPoint(x: dx / length, y: dy / length)
    }

    private func boundingRect(of points: [CGPoint]) -> CGRect {
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

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        CGPoint(
            x: point.x * cos(angle) - point.y * sin(angle),
            y: point.x * sin(angle) + point.y * cos(angle)
        )
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat, around pivot: CGPoint) -> CGPoint {
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

// MARK: - Workspace private types

private struct IOMaskSnapshot: Equatable {
    var masks: [IOMask]
    var selectedMaskIndex: Int?
    var selectedMaskIndices: Set<Int>
}

enum IOCanvasZoomCommand {
    case zoomIn
    case zoomOut
    case fit
}

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

private enum IOMaskAlignMode: CaseIterable {
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

private enum IOOcclusionMode: CaseIterable {
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

// MARK: - imageOcclusionPreviewHeight

func imageOcclusionPreviewHeight(for image: UIImage) -> CGFloat {
    let screenBounds = UIScreen.main.bounds
    let screenWidth = screenBounds.width - 32
    let ratio = image.size.height / max(image.size.width, 1)
    let idealHeight = screenWidth * ratio
    return min(max(idealHeight, 180), 260)
}

// MARK: - ImageOcclusionMaskSummaryCard

struct ImageOcclusionMaskSummaryCard: View {
    @Environment(\.palette) private var palette
    let image: UIImage
    let masks: [IOMask]
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OcclusionCanvasView(
                image: image,
                masks: .constant(masks),
                selectedMaskIndex: .constant(nil),
                shapeType: .select
            )
            .frame(height: imageOcclusionPreviewHeight(for: image))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                Text(masks.isEmpty ? "No masks yet" : "\(masks.count) masks")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                Spacer()
                Button(action: action) {
                    Text("Edit")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
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
        uiView.canvasView.masks = masks
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

    private func relayoutCanvas(resetZoom: Bool) {
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

    private func fittedCanvasSize(for boundsSize: CGSize) -> CGSize {
        let availableWidth = max(boundsSize.width - 8, 1)
        let availableHeight = max(boundsSize.height - 8, 1)
        let scale = min(availableWidth / max(imageSize.width, 1), availableHeight / max(imageSize.height, 1))
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func centerCanvas() {
        var frame = canvasView.frame
        frame.origin.x = frame.width < bounds.width ? (bounds.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < bounds.height ? (bounds.height - frame.height) / 2 : 0
        canvasView.frame = frame
    }
}

// MARK: - ImageOcclusionWorkspaceView

struct ImageOcclusionWorkspaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.undoManager) private var undoManager
    @Environment(\.palette) private var palette

    let title: String
    let image: UIImage
    let initialMasks: [IOMask]
    let onSave: ([IOMask]) -> Void

    @State private var masks: [IOMask]
    @State private var selectedMaskIndex: Int?
    @State private var selectedMaskIndices: Set<Int>
    @State private var shapeType: IOShapeType
    @State private var pendingTextPoint: CGPoint?
    @State private var pendingTextValue = ""
    @State private var pendingTextMaskIndex: Int?
    @State private var pendingTextColor = Color.black
    @State private var showTextEditor = false
    @State private var showFillEditor = false
    @State private var fillEditorColor = Color.yellow
    @State private var showDiscardConfirmation = false
    @State private var showsTranslucentMasks = true
    @State private var occlusionMode: IOOcclusionMode
    @State private var transformStartSnapshot: IOMaskSnapshot?
    @State private var zoomCommand: IOCanvasZoomCommand = .fit
    @State private var zoomCommandID = 0

    init(title: String, image: UIImage, initialMasks: [IOMask], onSave: @escaping ([IOMask]) -> Void) {
        self.title = title
        self.image = image
        self.initialMasks = initialMasks
        self.onSave = onSave
        _masks = State(initialValue: initialMasks)
        let initialSelection = initialMasks.indices.first
        _selectedMaskIndex = State(initialValue: initialSelection)
        _selectedMaskIndices = State(initialValue: initialSelection.map { Set([$0]) } ?? [])
        _shapeType = State(initialValue: initialMasks.isEmpty ? .rect : .select)
        _occlusionMode = State(initialValue: initialMasks.contains(where: \.occludesInactive) ? .hideAllGuessOne : .hideOneGuessOne)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolPalette

            ZoomableOcclusionCanvasView(
                image: image,
                masks: $masks,
                selectedMaskIndex: $selectedMaskIndex,
                selectedMaskIndices: highlightedMaskIndices,
                highlightedMaskIndices: highlightedMaskIndices,
                shapeType: shapeType,
                maskOpacity: showsTranslucentMasks ? 0.72 : 0.94,
                zoomCommand: zoomCommand,
                zoomCommandID: zoomCommandID,
                onRequestText: beginTextInsertion(at:),
                onRequestTextEdit: beginTextEditing(maskIndex:),
                onAppend: appendMask(_:),
                onSelectionChange: handleCanvasSelectionChange(_:),
                onTransformDidBegin: handleTransformDidBegin,
                onTransformDidEnd: handleTransformDidEnd
            )
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.background)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { requestDismiss() }
                    .amgiToolbarTextButton(tone: .neutral)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveWorkspace() }
                .amgiToolbarTextButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomToolbars
        }
        .confirmationDialog("Discard changes?", isPresented: $showDiscardConfirmation, titleVisibility: .visible) {
            Button("Discard", role: .destructive) {
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unsaved changes will be lost.")
        }
        .sheet(isPresented: $showTextEditor) {
            textEditorSheet
        }
        .sheet(isPresented: $showFillEditor) {
            fillEditorSheet
        }
    }

    private var activeSelectionIndices: [Int] {
        let filtered = selectedMaskIndices.filter { masks.indices.contains($0) }
        if !filtered.isEmpty {
            return filtered.sorted()
        }

        guard let selectedMaskIndex, masks.indices.contains(selectedMaskIndex) else {
            return []
        }
        return [selectedMaskIndex]
    }

    private var highlightedMaskIndices: Set<Int> {
        Set(activeSelectionIndices)
    }

    private var allMasksSelected: Bool {
        !masks.isEmpty && highlightedMaskIndices.count == masks.count
    }

    private var hasUnsavedChanges: Bool {
        masks != initialMasks
    }

    private var textEditorTitle: String {
        pendingTextMaskIndex == nil ? "Prompt" : "Edit text"
    }

    private var toolPalette: some View {
        HStack(spacing: 4) {
            ForEach(IOShapeType.allCases, id: \.self) { tool in
                ioPaletteButton(
                    title: tool.label,
                    systemImage: tool.systemImage,
                    isSelected: shapeType == tool
                ) {
                    shapeType = tool
                }
                .frame(maxWidth: .infinity)
            }

            Menu {
                ForEach(IOMaskFillOption.allCases, id: \.self) { option in
                    Button(option.label) {
                        applyFill(option.hex)
                    }
                }
                Divider()
                Button("Custom") {
                    openFillEditor()
                }
                Button("Default") {
                    applyFill(nil)
                }
            } label: {
                ioPaletteChip(
                    title: "Fill",
                    systemImage: "paintpalette",
                    isSelected: false
                )
            }
            .frame(maxWidth: .infinity)
            .disabled(activeSelectionIndices.isEmpty)

            Menu {
                ForEach(IOOcclusionMode.allCases, id: \.self) { mode in
                    Button(mode.label) {
                        applyOcclusionMode(mode)
                    }
                }
            } label: {
                ioPaletteChip(
                    title: "Mode",
                    systemImage: "square.stack.3d.up",
                    isSelected: false
                )
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(palette.surface)
    }

    private var bottomToolbars: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    toolbarIconButton(systemImage: "arrow.uturn.backward") {
                        undoManager?.undo()
                    }
                    .disabled(!(undoManager?.canUndo ?? false))

                    toolbarIconButton(systemImage: "arrow.uturn.forward") {
                        undoManager?.redo()
                    }
                    .disabled(!(undoManager?.canRedo ?? false))

                    toolbarIconButton(systemImage: "trash") {
                        deleteSelection()
                    }
                    .disabled(activeSelectionIndices.isEmpty)

                    toolbarIconButton(systemImage: "plus.square.on.square") {
                        duplicateSelection()
                    }
                    .disabled(activeSelectionIndices.isEmpty)

                    toolbarIconButton(systemImage: allMasksSelected ? "checkmark.circle.fill" : "checkmark.circle") {
                        toggleSelectAll()
                    }
                    .disabled(masks.isEmpty)

                    toolbarIconButton(systemImage: "arrow.left.arrow.right") {
                        invertSelection()
                    }
                    .disabled(masks.isEmpty)

                    toolbarIconButton(systemImage: showsTranslucentMasks ? "circle.lefthalf.filled" : "circle") {
                        showsTranslucentMasks.toggle()
                    }
                    .disabled(masks.isEmpty)
                }
                .padding(.horizontal, 16)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    toolbarIconButton(systemImage: "link") {
                        groupSelection()
                    }
                    .disabled(activeSelectionIndices.count < 2)

                    toolbarIconButton(systemImage: "link.slash", fallbackSystemImage: "scissors") {
                        ungroupSelection()
                    }
                    .disabled(activeSelectionIndices.isEmpty || !activeSelectionIndices.contains(where: { masks[$0].serializationOrdinal != nil }))

                    Menu {
                        ForEach(IOMaskAlignMode.allCases, id: \.self) { mode in
                            Button(mode.label) {
                                alignSelection(mode)
                            }
                        }
                    } label: {
                        toolbarIcon(systemImage: "align.horizontal.left")
                    }
                    .disabled(activeSelectionIndices.isEmpty)

                    toolbarIconButton(systemImage: "plus.magnifyingglass") {
                        sendZoomCommand(.zoomIn)
                    }

                    toolbarIconButton(systemImage: "minus.magnifyingglass") {
                        sendZoomCommand(.zoomOut)
                    }

                    toolbarIconButton(systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                        sendZoomCommand(.fit)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
        .background(palette.surface)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var textEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Prompt") {
                    TextField("Enter prompt text", text: $pendingTextValue, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Text color") {
                    ColorPicker("Custom", selection: $pendingTextColor, supportsOpacity: true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle(textEditorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        closeTextEditor()
                    }
                    .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        insertOrUpdateTextMask()
                    }
                    .amgiToolbarTextButton()
                    .disabled(pendingTextValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var fillEditorSheet: some View {
        NavigationStack {
            Form {
                Section("Custom") {
                    ColorPicker("Custom", selection: $fillEditorColor, supportsOpacity: true)
                }
            }
            .scrollContentBackground(.hidden)
            .background(palette.background)
            .navigationTitle("Custom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showFillEditor = false
                    }
                    .amgiToolbarTextButton(tone: .neutral)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Default") {
                        showFillEditor = false
                        applyFill(nil)
                    }
                    .amgiToolbarTextButton(tone: .neutral)

                    Button("Save") {
                        showFillEditor = false
                        applyFill(hexString(for: fillEditorColor))
                    }
                    .amgiToolbarTextButton()
                }
            }
        }
    }

    @ViewBuilder
    private func ioPaletteButton(
        title: String,
        systemImage: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ioPaletteChip(title: title, systemImage: systemImage, isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func ioPaletteChip(
        title: String,
        systemImage: String,
        isSelected: Bool
    ) -> some View {
        VStack(spacing: 3) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .frame(maxWidth: .infinity, minHeight: 42)
        .padding(.horizontal, 2)
        .background(isSelected ? palette.accent : palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func toolbarIconButton(systemImage: String, fallbackSystemImage: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarIcon(systemImage: systemImage, fallbackSystemImage: fallbackSystemImage)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func toolbarIcon(systemImage: String, fallbackSystemImage: String? = nil) -> some View {
        let resolvedSymbol = if UIImage(systemName: systemImage) != nil {
            systemImage
        } else {
            fallbackSystemImage ?? "questionmark"
        }

        Image(systemName: resolvedSymbol)
            .font(.system(size: 13, weight: .semibold))
            .amgiToolbarIconButton(size: 30)
    }

    private func handleCanvasSelectionChange(_ selection: OcclusionCanvasView.IOCanvasSelectionChange) {
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

    private func beginTextInsertion(at point: CGPoint) {
        pendingTextPoint = point
        pendingTextMaskIndex = nil
        pendingTextValue = ""
        pendingTextColor = .black
        showTextEditor = true
    }

    private func beginTextEditing(maskIndex: Int) {
        guard masks.indices.contains(maskIndex),
              case .text(_, _, let text, _, _, let extras) = masks[maskIndex] else {
            return
        }
        pendingTextPoint = nil
        pendingTextMaskIndex = maskIndex
        pendingTextValue = text
        pendingTextColor = color(from: extras["fill"], fallback: .black)
        showTextEditor = true
    }

    private func closeTextEditor() {
        pendingTextPoint = nil
        pendingTextMaskIndex = nil
        pendingTextValue = ""
        showTextEditor = false
    }

    private func insertOrUpdateTextMask() {
        let text = pendingTextValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let fillHex = hexString(for: pendingTextColor)

        if let pendingTextMaskIndex, masks.indices.contains(pendingTextMaskIndex) {
            var updatedMasks = masks
            updatedMasks[pendingTextMaskIndex] = updatedMasks[pendingTextMaskIndex].updatingText(text, fillHex: fillHex)
            commitSnapshot(
                IOMaskSnapshot(
                    masks: updatedMasks,
                    selectedMaskIndex: pendingTextMaskIndex,
                    selectedMaskIndices: groupedSelectionIndices(for: pendingTextMaskIndex, in: updatedMasks)
                )
            )
        } else if let pendingTextPoint {
            appendMask(
                .text(
                    left: pendingTextPoint.x,
                    top: pendingTextPoint.y,
                    text: text,
                    scale: 1,
                    fontSize: 0.055,
                    extras: ["fill": fillHex]
                )
            )
        }

        closeTextEditor()
    }

    private func appendMask(_ mask: IOMask) {
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

    private func deleteSelection() {
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

    private func duplicateSelection() {
        let indices = activeSelectionIndices
        guard !indices.isEmpty else { return }

        var updatedMasks = masks
        var duplicatedIndices: Set<Int> = []
        var ordinalMapping: [Int: Int] = [:]

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

    private func toggleSelectAll() {
        guard !masks.isEmpty else { return }
        if allMasksSelected {
            selectedMaskIndices = []
            selectedMaskIndex = nil
        } else {
            selectedMaskIndices = Set(masks.indices)
            selectedMaskIndex = masks.indices.first
        }
    }

    private func invertSelection() {
        guard !masks.isEmpty else { return }
        let inverted = Set(masks.indices).subtracting(selectedMaskIndices)
        selectedMaskIndices = inverted
        if let selectedMaskIndex, inverted.contains(selectedMaskIndex) {
            return
        }
        self.selectedMaskIndex = inverted.sorted().first
    }

    private func openFillEditor() {
        fillEditorColor = color(from: activeSelectionIndices.first.flatMap { masks[$0].extras["fill"] }, fallback: .yellow)
        showFillEditor = true
    }

    private func applyFill(_ hex: String?) {
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

    private func applyOcclusionMode(_ mode: IOOcclusionMode) {
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

    private func groupSelection() {
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

    private func ungroupSelection() {
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

    private func alignSelection(_ mode: IOMaskAlignMode) {
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

    private func requestDismiss() {
        if hasUnsavedChanges {
            showDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func saveWorkspace() {
        onSave(masks)
        dismiss()
    }

    private func handleTransformDidBegin() {
        if transformStartSnapshot == nil {
            transformStartSnapshot = currentSnapshot()
        }
    }

    private func handleTransformDidEnd() {
        guard let previousSnapshot = transformStartSnapshot else { return }
        transformStartSnapshot = nil
        let current = currentSnapshot()
        guard current != previousSnapshot else { return }
        registerUndo(previous: previousSnapshot, current: current)
    }

    private func sendZoomCommand(_ command: IOCanvasZoomCommand) {
        zoomCommand = command
        zoomCommandID += 1
    }

    private func groupedSelectionIndices(for index: Int, in masks: [IOMask]? = nil) -> Set<Int> {
        let resolvedMasks = masks ?? self.masks
        guard resolvedMasks.indices.contains(index) else { return [] }
        guard let ordinal = resolvedMasks[index].serializationOrdinal else {
            return [index]
        }
        return Set(resolvedMasks.indices.filter { resolvedMasks[$0].serializationOrdinal == ordinal })
    }

    private func nextAvailableOrdinal(in masks: [IOMask], reserved: Set<Int> = []) -> Int {
        let currentMax = masks.compactMap(\.serializationOrdinal).max() ?? 0
        var candidate = currentMax + 1
        while reserved.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    private func color(from hex: String?, fallback: Color) -> Color {
        guard let hex, let color = workspaceUIColor(ioHex: hex) else {
            return fallback
        }
        return Color(uiColor: color)
    }

    private func hexString(for color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02X%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255)),
            Int(round(alpha * 255))
        )
    }

    private func workspaceUIColor(ioHex: String) -> UIColor? {
        let sanitized = ioHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6 || sanitized.count == 8,
              let value = UInt64(sanitized, radix: 16) else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat

        if sanitized.count == 8 {
            red = CGFloat((value & 0xFF000000) >> 24) / 255
            green = CGFloat((value & 0x00FF0000) >> 16) / 255
            blue = CGFloat((value & 0x0000FF00) >> 8) / 255
            alpha = CGFloat(value & 0x000000FF) / 255
        } else {
            red = CGFloat((value & 0xFF0000) >> 16) / 255
            green = CGFloat((value & 0x00FF00) >> 8) / 255
            blue = CGFloat(value & 0x0000FF) / 255
            alpha = 1
        }

        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func currentSnapshot() -> IOMaskSnapshot {
        IOMaskSnapshot(
            masks: masks,
            selectedMaskIndex: selectedMaskIndex,
            selectedMaskIndices: Set(activeSelectionIndices)
        )
    }

    private func commitSnapshot(_ snapshot: IOMaskSnapshot) {
        let previous = currentSnapshot()
        applySnapshot(snapshot)
        registerUndo(previous: previous, current: snapshot)
    }

    private func registerUndo(previous: IOMaskSnapshot, current: IOMaskSnapshot) {
        undoManager?.registerUndo(withTarget: UIApplication.shared) { _ in
            self.restoreSnapshot(previous, redo: current)
        }
    }

    private func restoreSnapshot(_ snapshot: IOMaskSnapshot, redo: IOMaskSnapshot) {
        applySnapshot(snapshot)
        registerUndo(previous: redo, current: snapshot)
    }

    private func applySnapshot(_ snapshot: IOMaskSnapshot) {
        masks = snapshot.masks
        selectedMaskIndices = snapshot.selectedMaskIndices.filter { snapshot.masks.indices.contains($0) }
        if let selectedMaskIndex = snapshot.selectedMaskIndex, snapshot.masks.indices.contains(selectedMaskIndex) {
            self.selectedMaskIndex = selectedMaskIndex
        } else {
            self.selectedMaskIndex = selectedMaskIndices.sorted().first
        }
        occlusionMode = snapshot.masks.contains(where: \.occludesInactive) ? .hideAllGuessOne : .hideOneGuessOne
    }

    private func normalizedBounds(for mask: IOMask) -> CGRect {
        switch mask {
        case .rect(let left, let top, let width, let height, _):
            return CGRect(x: left, y: top, width: width, height: height)
        case .ellipse(let left, let top, let rx, let ry, _):
            return CGRect(x: left, y: top, width: rx * 2, height: ry * 2)
        case .polygon(let points, _):
            let xs = points.map(\.x)
            let ys = points.map(\.y)
            return CGRect(
                x: xs.min() ?? 0,
                y: ys.min() ?? 0,
                width: (xs.max() ?? 0) - (xs.min() ?? 0),
                height: (ys.max() ?? 0) - (ys.min() ?? 0)
            )
        case .text(let left, let top, let text, let scale, let fontSize, _):
            return CGRect(origin: CGPoint(x: left, y: top), size: normalizedTextSize(text: text, scale: scale, fontSize: fontSize))
        }
    }

    private func normalizedTextSize(text: String, scale: CGFloat, fontSize: CGFloat) -> CGSize {
        let resolvedSize = max(14, image.size.height * max(fontSize, 0.02) * max(scale, 1))
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: resolvedSize, weight: .semibold)]
        let textSize = (text as NSString).size(withAttributes: attrs)
        return CGSize(
            width: min(1, (textSize.width + 20) / max(image.size.width, 1)),
            height: min(1, (textSize.height + 12) / max(image.size.height, 1))
        )
    }

    private func offset(mask: IOMask, dx: CGFloat, dy: CGFloat) -> IOMask {
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
            let size = normalizedTextSize(text: text, scale: scale, fontSize: fontSize)
            return .text(
                left: max(0, min(1 - size.width, left + dx)),
                top: max(0, min(1 - size.height, top + dy)),
                text: text,
                scale: scale,
                fontSize: fontSize,
                extras: extras
            )
        }
    }
}
