//
//  SmallWidgetView.swift
//  WidgetFeature
//
//  Created by Vladimir Gusev on 07.04.2026.
//

import Foundation
import SwiftUI
import WidgetKit
import Theme
import AppCore

struct SmallWidgetView: View {
    @Environment(\.palette) private var palette
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            StreakLabel(days: snapshot.streak)

            Spacer()

            DueHero(totalDue: snapshot.totalDue)

            Spacer()

            Text(snapshot.deckName)
                .amgiFont(.micro)
                .foregroundStyle(palette.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(AmgiSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(URL(string: "amgi://review?deckId=\(snapshot.deckId)"))
    }
}

#if DEBUG

// Deliberately a plain SwiftUI preview with a hand-set frame — no WidgetKit
// preview API. Anything that marks this as a *widget* preview (`#Preview(as:)`
// or `WidgetPreviewContext`, in either the macro or the PreviewProvider form)
// makes Xcode look for a widget-extension process to host it. A file in a
// package target is previewed by XCPreviewAgent, which is an app, so the
// preview fails with "No candidates found to host preview" — the build graph
// tags the node `(SmallWidgetView.swift, Previews, widget)` and finds no
// candidate. Nothing in the package can supply that host; only moving these
// files back into the AmgiWidget target would.
//
// So: the real view, at the nominal small-widget size, with the widget's
// rounded background faked. Palette falls back to the `\.palette` default
// rather than ThemeManager's live theme.
#Preview {
    WidgetPreviewFrame(width: 170, height: 170) {
        SmallWidgetView(snapshot: .placeholder)
    }
}
#endif
