//
//  SettingsControls.swift
//  SettingsFeature
//
//  Created by Vladimir Gusev on 05.08.2026.
//

import SwiftUI
import Theme

// MARK: - Page scaffold

/// Chrome shared by every settings sub-page: palette background, scrolling
/// column of grouped panels. Sub-pages keep the system navigation bar (the
/// design's back pill) so the back button and the interactive pop gesture
/// stay free; only the content adopts the design's grouped layout.
struct SettingsPage<Content: View>: View {
    @Environment(\.palette) private var palette

    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.bottom, AmgiSpacing.xl)
        }
        .background(palette.background)
    }
}

/// `SettingsSectionHeader`'s type treatment for screens that stayed on
/// `List` (those needing `swipeActions` or `onDelete`). List supplies its
/// own header insets, so this is the text styling only.
struct SettingsListHeader: View {
    @Environment(\.palette) private var palette

    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .amgiFont(.micro)
            .fontWeight(.semibold)
            // A custom header view opts out of List's own uppercasing, so
            // it has to be applied here to match `SettingsSectionHeader`.
            .textCase(.uppercase)
            .foregroundStyle(palette.textTertiary)
    }
}

/// Explanatory text under a group — the design's equivalent of a `Form`
/// section footer. Inset to the group's text column, like the header.
struct SettingsFootnote: View {
    @Environment(\.palette) private var palette

    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .amgiFont(.caption)
            .foregroundStyle(palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, AmgiSpacing.xxl)
            .padding(.top, AmgiSpacing.sm)
    }
}

// MARK: - Rows

/// A row whose trailing control is a switch. The label stays on the
/// `Toggle` (hidden, not removed) so VoiceOver still announces what the
/// switch controls.
struct SettingsToggleRow: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let tone: SettingsTone
    @Binding var isOn: Bool

    var body: some View {
        SettingsRowLayout(title: title, systemImage: systemImage, tone: tone) {
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(palette.positive)
        }
    }
}

/// A row whose trailing control is a menu of choices, showing the current
/// one inline — the design's value-plus-chevron row with a picker behind it.
struct SettingsPickerRow<Value: Hashable, Options: View>: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let tone: SettingsTone
    @Binding var selection: Value
    @ViewBuilder let options: () -> Options

    var body: some View {
        SettingsRowLayout(title: title, systemImage: systemImage, tone: tone) {
            Picker(title, selection: $selection) { options() }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(palette.textSecondary)
        }
    }
}

/// A row that performs an action rather than navigating. `tone` tints the
/// tile; `isDestructive` also tints the title, so the warning doesn't rest
/// on colour in the icon alone.
struct SettingsButtonRow: View {
    @Environment(\.palette) private var palette
    // Explicit foreground colours mean a disabled Button no longer greys
    // itself, so the dimming is applied here instead.
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let systemImage: String
    let tone: SettingsTone
    var isDestructive: Bool = false
    var isBusy: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AmgiSpacing.md) {
                SettingsIconTile(systemImage: systemImage, tone: tone)
                Text(title)
                    .amgiFont(.body)
                    .foregroundStyle(isDestructive ? palette.danger : palette.textPrimary)
                Spacer(minLength: AmgiSpacing.sm)
                if isBusy { ProgressView() }
            }
            .padding(.horizontal, AmgiSpacing.lg)
            .padding(.vertical, AmgiSpacing.md)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.pressScale)
    }
}

/// A row whose trailing control steps a number, with the current value
/// rendered by `format` beside the stepper.
struct SettingsStepperRow<Value: Strideable>: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let tone: SettingsTone
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride
    let format: (Value) -> String

    var body: some View {
        SettingsRowLayout(title: title, systemImage: systemImage, tone: tone) {
            HStack(spacing: AmgiSpacing.sm) {
                // `fixedSize` is load-bearing: without it the value loses the
                // width fight with the stepper and wraps mid-word ("17p / t").
                // The title wraps instead, which is what should give.
                Text(format(value))
                    .amgiFont(.body, .monospacedDigits)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .accessibilityHidden(true)
                Stepper(title, value: $value, in: range, step: step)
                    .labelsHidden()
                    .accessibilityValue(format(value))
            }
        }
    }
}

/// A row whose trailing control is a colour well.
struct SettingsColorRow: View {
    let title: String
    let systemImage: String
    let tone: SettingsTone
    @Binding var color: Color

    var body: some View {
        SettingsRowLayout(title: title, systemImage: systemImage, tone: tone) {
            ColorPicker(title, selection: $color, supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// A read-only row: title on the left, value on the right. No chevron —
/// nothing to tap.
struct SettingsValueRow: View {
    @Environment(\.palette) private var palette

    let title: String
    let value: String
    let systemImage: String
    let tone: SettingsTone
    /// URLs and paths read better clipped in the middle than at the tail.
    var truncation: Text.TruncationMode = .tail
    var isMuted: Bool = false

    var body: some View {
        SettingsRowLayout(title: title, systemImage: systemImage, tone: tone) {
            Text(value)
                .amgiFont(.body)
                .foregroundStyle(isMuted ? palette.textTertiary : palette.textSecondary)
                .multilineTextAlignment(.trailing)
                .truncationMode(truncation)
                .lineLimit(truncation == .middle ? 1 : nil)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared layout

/// Tile, title, trailing accessory — the row geometry every non-navigating
/// row shares with `SettingsRowLink` (44pt minimum, 16pt gutters, 12pt
/// icon column).
private struct SettingsRowLayout<Accessory: View>: View {
    @Environment(\.palette) private var palette

    let title: String
    let systemImage: String
    let tone: SettingsTone
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        HStack(spacing: AmgiSpacing.md) {
            SettingsIconTile(systemImage: systemImage, tone: tone)
            Text(title)
                .amgiFont(.body)
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: AmgiSpacing.sm)
            accessory()
        }
        .padding(.horizontal, AmgiSpacing.lg)
        .padding(.vertical, AmgiSpacing.md)
        .frame(minHeight: 44)
    }
}
