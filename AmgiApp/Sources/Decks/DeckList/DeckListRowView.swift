// AmgiApp/Sources/Decks/DeckList/DeckListRowView.swift
//
// Domain row aggregation consumed by `DeckListView`. The actual row +
// list views live in AmgiUI so previews don't link the Anki backend;
// this file owns only the AnkiKit-typed record and the mapper to
// AmgiUI's neutral `DeckRowViewData`.
import AmgiUI
import AnkiKit

/// Flat row record. Built by the container from a top-level
/// `DeckTreeNode` (children are flattened to a count) and mapped to
/// `DeckRowViewData` before reaching AmgiUI.
struct DeckListRow: Identifiable, Equatable, Hashable {
    let id: DeckID
    let name: String           // last segment, e.g. "한국어"
    let fullName: String       // full path, e.g. "Languages::한국어"
    let counts: DeckCounts
    let isFiltered: Bool
    let subdeckCount: Int
}

extension DeckListRow {
    /// Flatten a top-level `DeckTreeNode` into the row record: children
    /// collapse to a count, everything else carries through.
    init(node: DeckTreeNode) {
        self.init(
            id: node.id,
            name: node.name,
            fullName: node.fullName,
            counts: node.counts,
            isFiltered: node.isFiltered,
            subdeckCount: node.children.count
        )
    }

    var asDeckInfo: DeckInfo {
        DeckInfo(id: id, name: fullName, counts: counts, isFiltered: isFiltered)
    }

    var viewData: DeckRowViewData {
        DeckRowViewData(
            id: id.rawValue,
            name: name,
            fullName: fullName,
            newCount: counts.newCount,
            learnCount: counts.learnCount,
            reviewCount: counts.reviewCount,
            isFiltered: isFiltered,
            subdeckCount: subdeckCount
        )
    }
}

extension DeckRowViewData {
    /// Reconstruct the domain `DeckInfo` from a neutral view-data row
    /// handed back through a `LibraryListContent` callback (tap / start
    /// review). The view layer only ever sees `DeckRowViewData`, so the
    /// container maps back here when it needs to navigate.
    var asDeckInfo: DeckInfo {
        DeckInfo(
            id: DeckID(id),
            name: fullName,
            counts: DeckCounts(
                newCount: newCount,
                learnCount: learnCount,
                reviewCount: reviewCount
            ),
            isFiltered: isFiltered
        )
    }
}
