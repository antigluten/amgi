//
//  ImageOcclusionMaskSummaryCard.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 15.08.2026.
//

#if canImport(UIKit)
import SwiftUI
import UIKit
import Theme
import UI

// MARK: - imageOcclusionPreviewHeight

@MainActor
func imageOcclusionPreviewHeight(for image: UIImage, width: CGFloat) -> CGFloat {
    let ratio = image.size.height / max(image.size.width, 1)
    let idealHeight = width * ratio
    return min(max(idealHeight, 180), 260)
}

// MARK: - ImageOcclusionMaskSummaryCard

struct ImageOcclusionMaskSummaryCard: View {
    @Environment(\.palette) private var palette
    let image: UIImage
    let masks: [IOMask]
    let action: () -> Void
    @State private var canvasWidth: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OcclusionCanvasView(
                image: image,
                masks: .constant(masks),
                selectedMaskIndex: .constant(nil),
                shapeType: .select
            )
            .frame(height: imageOcclusionPreviewHeight(for: image, width: canvasWidth))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { canvasWidth = $0 }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(false)

            HStack(spacing: 12) {
                Text(masks.isEmpty ? "No masks yet" : "\(masks.count) masks")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: action) {
                    Text("Edit")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: AmgiRadius.pill, style: .continuous))
    }
}
#endif
