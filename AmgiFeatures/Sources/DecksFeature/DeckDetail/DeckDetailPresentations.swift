//
//  DeckDetailPresentations.swift
//  DecksFeature
//
//  Created by Vladimir Gusev on 14.05.2026.
//

import SwiftUI
import AnkiKit
import Theme
import SwiftNavigation
import SwiftUINavigation
import ReviewFeature
import UniformTypeIdentifiers  // UTType.data

// Two ViewModifiers split out from `DeckDetailView.body` so the SwiftUI
// type-checker doesn't blow up on a single long modifier chain. AnyView
// wrappers on the closure returns keep the outer body type stable across
// sheet/alert variants.

struct SheetCoverModifier: ViewModifier {
    let destination: Binding<DeckDetailDestination?>
    let deckId: DeckID
    let onReviewDismiss: () -> Void
    let sheetContent: (DeckDetailSheet) -> AnyView

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: destination.review) {
                ReviewView(deckId: deckId) { onReviewDismiss() }
            }
            .sheet(item: destination.sheet) { sheet in
                sheetContent(sheet)
            }
    }
}

struct AlertModifier: ViewModifier {
    let destination: Binding<DeckDetailDestination?>
    let currentAlert: DeckDetailAlert?
    let alertTitle: String
    let alertActions: (DeckDetailAlert) -> AnyView
    let alertMessage: (DeckDetailAlert) -> AnyView

    func body(content: Content) -> some View {
        content
            .alert(
                alertTitle,
                isPresented: Binding(destination.alert),
                presenting: currentAlert
            ) { alert in
                alertActions(alert)
            } message: { alert in
                alertMessage(alert)
            }
    }
}

