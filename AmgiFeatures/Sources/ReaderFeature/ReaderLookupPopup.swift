//
//  ReaderLookupPopup.swift
//  ReaderFeature
//
//  Created by Vladimir Gusev on 29.08.2026.
//

import AppShared
package import SwiftUI

/// The concrete `LookupPopupProviding` the app root injects.
///
/// Deliberately has no stored properties: SwiftUI compares environment values
/// field-by-field, so a fieldless struct always compares equal and readers of
/// `\.lookupPopup` never invalidate spuriously. Adding `Equatable` here would
/// be inert — the environment stores the boxed `any LookupPopupProviding`
/// existential, so SwiftUI reflects on that box either way, never on this
/// concrete type's own conformance.
package struct ReaderLookupPopup: LookupPopupProviding {
    package init() {}

    package func popup(query: String, onMatched: @escaping (String) -> Void, onDismiss: @escaping () -> Void) -> AnyView {
        AnyView(LookupPopupView(initialQuery: query, onMatched: onMatched, onDismiss: onDismiss))
    }
}

package struct ReaderDictionarySettings: DictionarySettingsProviding {
    package init() {}

    package func settings() -> AnyView {
        AnyView(ReaderDictionarySettingsView())
    }
}
