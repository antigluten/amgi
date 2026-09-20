//
//  BookCoverPlaceholder.swift
//  UI
//
//  Created by Vladimir Gusev on 17.05.2026.
//

public import SwiftUI

/// Stylized fallback cover. Gradient background (from
/// `BookCoverPalette.resolve(seed:)`), serif title at the top, palette
/// divider + uppercase surname near the bottom.
public struct BookCoverPlaceholder: View {
    public let title: String
    public let surname: String?
    public let seed: String

    public init(title: String, surname: String?, seed: String) {
        self.title = title
        self.surname = surname
        self.seed = seed
    }

    public var body: some View {
        let palette = BookCoverPalette.resolve(seed: seed)
        ZStack {
            LinearGradient(
                colors: [palette.gradientEnd, palette.gradientStart],
                startPoint: .top,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if let surname, !surname.isEmpty {
                    Rectangle()
                        .fill(palette.lineColor)
                        .frame(width: 28, height: 2)
                        .padding(.bottom, 8)
                    Text(surname.uppercased())
                        .font(.caption.weight(.medium))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

#if DEBUG

#Preview("All palettes") {
    HStack(spacing: 8) {
        BookCoverPlaceholder(title: "어린 왕자", surname: "Saint-Exupéry", seed: "slate-seed-1")
            .frame(width: 120, height: 163)
        BookCoverPlaceholder(title: "Norwegian Wood", surname: "Murakami", seed: "navy-seed-2")
            .frame(width: 120, height: 163)
        BookCoverPlaceholder(title: "Don Quijote", surname: "Cervantes", seed: "brick-seed-3")
            .frame(width: 120, height: 163)
    }
    .padding()
}
#endif
