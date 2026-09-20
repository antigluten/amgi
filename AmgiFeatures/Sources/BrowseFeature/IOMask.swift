//
//  IOMask.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

import SwiftUI

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

    private static let internalKeyPrefix = "_amgi_"
    private static let internalOrdinalKey = "_amgi_ordinal"
}

// MARK: - IOMask fill extension

private extension IOMask {
    func updatingExtras(_ transform: ([String: String]) -> [String: String]) -> IOMask {
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

    func clozeText(
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

    func f(_ v: CGFloat) -> String { String(format: "%.3g", v) }
}

extension IOMask {
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
