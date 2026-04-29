// AmgiApp/Sources/Widgets/AmgiWidget.swift
import WidgetKit
import SwiftUI
import AmgiTheme

struct AmgiWidget: Widget {
    let kind = "AmgiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: AmgiWidgetIntent.self,
            provider: WidgetTimelineProvider()
        ) { entry in
            AmgiWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
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
        .environment(\.palette, ThemeManager.shared.palette(for: colorScheme))
    }
}
