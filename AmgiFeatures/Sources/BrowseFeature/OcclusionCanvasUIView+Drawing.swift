//
//  OcclusionCanvasUIView+Drawing.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 20.08.2026.
//

#if canImport(UIKit)
import Theme
import SwiftUI
import UIKit

extension OcclusionCanvasUIView {
    // MARK: - Draw helpers

    func drawMask(ctx: CGContext, mask: IOMask, imgRect: CGRect) {
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
                .foregroundColor: UIColor(amgiHex: mask.extras["fill"] ?? "") ?? UIColor.label
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

    func drawOrdinal(ctx: CGContext, index: Int, mask: IOMask, imgRect: CGRect) {
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
}
#endif
