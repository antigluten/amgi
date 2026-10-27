import AppCore
import Foundation
public import SwiftUI
import Theme
import WidgetKit

public struct WordSpotlightWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        StaticConfiguration(kind: WordSpotlightStore.widgetKind, provider: WordSpotlightProvider()) { entry in
            WordSpotlightWidgetView(entry: entry)
        }
        .configurationDisplayName("Word Spotlight")
        .description("A word from your vocabulary cards, refreshed at your chosen interval.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

private struct WordSpotlightEntry: TimelineEntry {
    var date: Date
    var word: SpotlightWord?
    var profileID: String = ""
    var hasSource = false
}

private struct WordSpotlightProvider: TimelineProvider {
    func placeholder(in context: Context) -> WordSpotlightEntry {
        WordSpotlightEntry(date: .now, word: SpotlightWord(
            noteID: 0, term: "木漏れ日", reading: "こもれび", meaning: "Sunlight filtering through the trees"
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (WordSpotlightEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WordSpotlightEntry>) -> Void) {
        let now = Date()
        let schedule = WordSpotlightStore.read()
        var entries = [current(now: now, schedule: schedule)]
        if let schedule {
            entries += schedule.entries.filter { $0.date > now }.map {
                WordSpotlightEntry(date: $0.date, word: $0.word, profileID: schedule.profileID, hasSource: true)
            }
            // Explicit empty entry: never label the final prepared word as today's forever.
            if let expires = schedule.expiration(), expires > now {
                entries.append(WordSpotlightEntry(date: expires, word: nil, hasSource: true))
            }
        }
        completion(Timeline(entries: entries, policy: .never))
    }

    private func current(now: Date = .now, schedule: WordSpotlightSchedule? = WordSpotlightStore.read()) -> WordSpotlightEntry {
        WordSpotlightEntry(
            date: now, word: schedule?.word(on: now), profileID: schedule?.profileID ?? "",
            hasSource: schedule != nil
        )
    }
}

private struct WordSpotlightWidgetView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    let entry: WordSpotlightEntry

    var body: some View {
        let palette = ThemeManager.shared.palette(for: colorScheme)
        Group {
            if family == .accessoryRectangular {
                VStack(alignment: .leading, spacing: 2) {
                    if let word = entry.word {
                        Text(word.term).amgiFont(.bodyEmphasis).lineLimit(1).minimumScaleFactor(0.8)
                        Text(word.meaning).amgiFont(.caption).foregroundStyle(palette.textSecondary).lineLimit(2)
                    } else {
                        Text("Word Spotlight").amgiFont(.bodyEmphasis)
                        Text("Open Amgi to choose your words.").amgiFont(.caption).lineLimit(2)
                    }
                }
                .privacySensitive()
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                homeScreen
            }
        }
        .containerBackground(palette.surface, for: .widget)
        .widgetURL(entry.word.flatMap {
            WordSpotlightLink(profileID: entry.profileID, noteID: $0.noteID).url
        } ?? URL(string: "amgi://word-settings"))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var homeScreen: some View {
        let palette = ThemeManager.shared.palette(for: colorScheme)
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            if let word = entry.word {
                Group {
                    if family == .systemMedium {
                        HStack(alignment: .center, spacing: 20) {
                            wordHeading(word)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(word.meaning).amgiFont(.body).lineLimit(5)
                                .foregroundStyle(palette.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            wordHeading(word)
                            Text(word.meaning).amgiFont(.caption).lineLimit(3)
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                }
                .privacySensitive()
            } else {
                Text(entry.hasSource ? "Open Amgi to refresh your words." : "Choose a vocabulary deck in Amgi.")
                    .amgiFont(.caption)
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(palette.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func wordHeading(_ word: SpotlightWord) -> some View {
        let palette = ThemeManager.shared.palette(for: colorScheme)
        return VStack(alignment: .leading, spacing: 4) {
            Text(word.term)
                .amgiFont(size: 28, weight: .semibold, relativeTo: .title)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if !word.reading.isEmpty {
                Text(word.reading).amgiFont(.caption).lineLimit(1)
                    .foregroundStyle(palette.textSecondary)
            }
        }
    }
}
