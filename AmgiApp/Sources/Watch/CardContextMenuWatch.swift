import SwiftUI

/// watchOS doesn't use the card context menu, so we provide an empty view here
/// to satisfy any potential references without including the iOS-specific Menu code.
struct CardContextMenu: View {
    let cardId: Int64
    let noteId: Int64?
    var onSuccess: (() -> Void)? = nil
    var onActionSuccess: ((_ shouldAdvance: Bool) -> Void)? = nil
    var onRequestSetDueDate: ((_ cardId: Int64) -> Void)? = nil

    var body: some View {
        EmptyView()
    }
}
