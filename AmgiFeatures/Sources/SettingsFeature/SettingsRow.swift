//
//  SettingsRow.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 05.08.2026.
//

import SwiftUI
import Theme
import UI

// MARK: - Tone

/// Icon-tile tint for a settings row.
///
/// The design mock (`amgi-settings.jsx`) spells these as raw hues —
/// `#bf5af2`, `#ff9f0a`, `#30d158`, `#8e8e93`. Every one of them is
/// already a slot the theme JSONs define, so the cases name the palette
/// role rather than the colour: the tiles re-tint with the active theme
/// instead of pinning the default theme's values, which is what keeps
/// mono-light and mono-dark legible.
enum SettingsTone {
    case accent
    case info
    case review
    case learning
    case mature
    case danger
    case neutral
    case link

    func color(_ palette: Palette) -> Color {
        switch self {
        case .accent:   palette.accent             // mock #0a84ff
        case .info:     palette.info               // mock #5ac8fa
        case .review:   palette.cardStateReview    // mock #30d158
        case .learning: palette.cardStateLearning  // mock #ff9f0a
        case .mature:   palette.cardStateMature    // mock #bf5af2
        case .danger:   palette.cardStateRelearn   // mock #ff453a
        case .neutral:  palette.textSecondary      // mock #8e8e93
        case .link:     palette.link               // mock #5e5ce6
        }
    }
}

// MARK: - Icon tile

/// The design's 30pt tinted glyph tile. Shared by every row kind so the
/// icon column lines up whether the row navigates, toggles, or picks.
struct SettingsIconTile: View {
    @Environment(\.palette) private var palette

    let systemImage: String
    let tone: SettingsTone

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(
                tone.color(palette),
                // Mock says 7; `AmgiRadius.small` is 8. Rounding to the token
                // rather than adding a ninth radius for a 1pt difference.
                in: RoundedRectangle(cornerRadius: AmgiRadius.small, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

// MARK: - Row

/// One settings row: tinted 30pt glyph tile, title, optional trailing
/// value, chevron. Mirrors `.row` in the design's `styles.css`
/// (44pt minimum height, 17pt title, value in secondary text).
struct SettingsRowLink<Destination: View>: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let tone: SettingsTone
    var detail: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: AmgiSpacing.md) {
                iconTile
                Text(title)
                    .amgiFont(.body)
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: AmgiSpacing.sm)
                if let detail {
                    Text(detail)
                        .amgiFont(.body)
                        .foregroundStyle(palette.textSecondary)
                        .lineLimit(1)
                }
                chevron
            }
            .padding(.horizontal, AmgiSpacing.lg)
            .padding(.vertical, AmgiSpacing.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressScale)
    }

    private var iconTile: some View {
        SettingsIconTile(systemImage: systemImage, tone: tone)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
    }
}

// MARK: - Group chrome

/// The design's `.inset-group`: an elevated panel holding a run of rows.
/// Radius follows the theme's elevation style — the mock's Minimal palette
/// swaps the 14pt shadowed card for a 12pt hairline ring, which is exactly
/// what `palette.elevation == .ring` already means here.
struct SettingsGroup<Content: View>: View {
    @Environment(\.palette) private var palette

    @ViewBuilder let content: () -> Content

    var body: some View {
        AmgiCard(
            background: .surface,
            cornerRadius: palette.elevation == .ring ? AmgiRadius.inset : AmgiRadius.hero,
            contentInsets: EdgeInsets()
        ) {
            VStack(spacing: 0) { content() }
        }
        .padding(.horizontal, AmgiSpacing.lg)
    }
}

/// Hairline between two rows, inset to the tile's leading edge.
struct SettingsSeparator: View {
    @Environment(\.palette) private var palette

    var body: some View {
        palette.separator
            .frame(height: 0.5)
            .padding(.leading, AmgiSpacing.lg)
    }
}

/// `.section-header` — uppercase, tracked, tertiary. Leading inset lands on
/// the row content (group margin + row padding), not on the screen edge.
struct SettingsSectionHeader: View {
    @Environment(\.palette) private var palette

    let title: String

    var body: some View {
        Text(title)
            .amgiFont(.micro)
            .fontWeight(.semibold)
            .textCase(.uppercase)
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, AmgiSpacing.xxl)
            .padding(.top, AmgiSpacing.xl)
            .padding(.bottom, AmgiSpacing.sm)
    }
}
