//
//  AmgiWidget.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import WidgetKit
public import SwiftUI
import Theme

public struct AmgiWidget: Widget {
    let kind = "AmgiWidget"

    public init() {}

    public var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: AmgiWidgetIntent.self,
            provider: WidgetTimelineProvider()
        ) { entry in
            AmgiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Amgi")
        .description("See your cards due today.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct AmgiWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: WidgetEntry

    var body: some View {
        let palette = ThemeManager.shared.palette(for: colorScheme)
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(snapshot: entry.snapshot)
            case .systemMedium:
                MediumWidgetView(snapshot: entry.snapshot)
            case .systemLarge:
                LargeWidgetView(snapshot: entry.snapshot)
            default:
                SmallWidgetView(snapshot: entry.snapshot)
            }
        }
        .containerBackground(palette.surface, for: .widget)
        .environment(\.palette, palette)
    }
}
