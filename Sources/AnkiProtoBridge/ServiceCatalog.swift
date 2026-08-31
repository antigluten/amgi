import Foundation

/// Typed wrappers for backend service/method dispatch. Internal to
/// AnkiProtoBridge — service code never sees raw `UInt32` constants.
enum ServiceID {
    static let sync: UInt32 = 1
    static let collection: UInt32 = 3
    static let cards: UInt32 = 5
    static let decks: UInt32 = 7
    static let scheduler: UInt32 = 13
    static let notetypes: UInt32 = 23
    static let notes: UInt32 = 25
    static let config: UInt32 = 9
    static let deckConfig: UInt32 = 11
    static let cardRendering: UInt32 = 27
    static let search: UInt32 = 29
    static let imageOcclusion: UInt32 = 37
    static let importExport: UInt32 = 39
    static let media: UInt32 = 41
    static let stats: UInt32 = 43
    static let tags: UInt32 = 45
}

/// Collection methods delegated onto BackendCollectionService (3).
/// `CollectionService` (2) is a collection-only service the FFI never
/// dispatches, so these must be addressed through the backend service: its
/// six backend-native methods precede the delegated ones.
enum CollectionOpsMethod {
    static let checkDatabase: UInt32 = 6
    static let getUndoStatus: UInt32 = 7
    static let undo: UInt32 = 8
}

/// BackendCardsService (5).
enum CardsMethod {
    static let getCard: UInt32 = 0
    static let removeCards: UInt32 = 2
    static let setFlag: UInt32 = 4
}

enum DecksMethod {
    static let newDeck: UInt32 = 0
    static let addDeck: UInt32 = 1
    static let addOrUpdateDeckLegacy: UInt32 = 3
    static let getDeckTree: UInt32 = 4
    static let getDeck: UInt32 = 8
    static let getDeckNames: UInt32 = 13
    static let removeDecks: UInt32 = 16
    static let renameDeck: UInt32 = 18
    static let setCurrentDeck: UInt32 = 22
    static let getCurrentDeck: UInt32 = 23
}

/// Method IDs for the scheduler service. The values mirror
/// `AnkiBackend.SchedulerMethod` but are kept here so service code
/// never names the raw `UInt32` constants directly.
enum SchedulerMethod {
    static let getQueuedCards: UInt32 = 3
    static let answerCard: UInt32 = 4
    static let extendLimits: UInt32 = 9
    static let buryOrSuspendCards: UInt32 = 14
    static let emptyFilteredDeck: UInt32 = 15
    static let rebuildFilteredDeck: UInt32 = 16
    static let scheduleCardsAsNew: UInt32 = 17
    static let computeFsrsParams: UInt32 = 30
    static let simulateFsrsReview: UInt32 = 33
    static let simulateFsrsWorkload: UInt32 = 34
}

enum DeckConfigMethod {
    static let getDeckConfig: UInt32 = 1
    static let getDeckConfigsForUpdate: UInt32 = 6
    static let updateDeckConfigs: UInt32 = 7
    static let getRetentionWorkload: UInt32 = 9
}

enum NotetypesMethod {
    static let updateNotetype: UInt32 = 1
    static let getNotetype: UInt32 = 6
    static let getNotetypeNames: UInt32 = 8
    static let removeNotetype: UInt32 = 11
}

enum StatsMethod {
    static let cardStats: UInt32 = 0
    static let graphs: UInt32 = 2
}

/// Method IDs for the import/export service. Backend offsets +2 from
/// the Collection-level indices match the same pattern as the other
/// services in this file.
enum ImportExportMethod {
    static let importCollectionPackage: UInt32 = 0
    static let exportCollectionPackage: UInt32 = 1
    static let importAnkiPackage: UInt32 = 2
    static let exportAnkiPackage: UInt32 = 4
}

enum NotesMethod {
    static let newNote: UInt32 = 0
    static let addNote: UInt32 = 1
    static let removeNotes: UInt32 = 7
    static let updateNotes: UInt32 = 5
    static let getNote: UInt32 = 6
    static let cardsOfNote: UInt32 = 12
}

enum SearchMethod {
    static let searchCards: UInt32 = 1
    static let searchNotes: UInt32 = 2
}

/// BackendSyncService (1). syncMedia=0, abortMediaSync=1,
/// mediaSyncStatus=2, syncLogin=3, syncStatus=4, syncCollection=5,
/// fullUploadOrDownload=6.
///
/// No `syncMedia` constant: media syncs are started by
/// `syncCollection(syncMedia: true)`, which spawns the engine's background
/// media task before it returns. Nothing needs to kick one off on its own.
enum SyncMethod {
    static let abortMediaSync: UInt32 = 1
    static let mediaSyncStatus: UInt32 = 2
    static let syncLogin: UInt32 = 3
    static let syncStatus: UInt32 = 4
    static let syncCollection: UInt32 = 5
    static let fullUploadOrDownload: UInt32 = 6
}

/// BackendTagsService (45).
enum TagsMethod {
    static let clearUnusedTags: UInt32 = 0
    static let allTags: UInt32 = 1
    static let removeTags: UInt32 = 2
    static let setTagCollapsed: UInt32 = 3
    static let tagTree: UInt32 = 4
    static let reparentTags: UInt32 = 5
    static let renameTags: UInt32 = 6
    static let addNoteTags: UInt32 = 7
    static let removeNoteTags: UInt32 = 8
    static let findAndReplaceTag: UInt32 = 9
    static let completeTag: UInt32 = 10
}

/// BackendImageOcclusionService (37).
enum ImageOcclusionMethod {
    static let getImageForOcclusion: UInt32 = 0
    static let getImageOcclusionNote: UInt32 = 1
    static let getImageOcclusionFields: UInt32 = 2
    static let addImageOcclusionNotetype: UInt32 = 3
    static let addImageOcclusionNote: UInt32 = 4
    static let updateImageOcclusionNote: UInt32 = 5
}

/// BackendMediaService (41).
enum MediaMethod {
    static let checkMedia: UInt32 = 0
    static let addMediaFile: UInt32 = 1
    static let trashMediaFiles: UInt32 = 2
    static let emptyTrash: UInt32 = 3
    static let restoreTrash: UInt32 = 4
}

/// BackendCardRenderingService (27). The collection-level service
/// prefixes 6 backend-only methods; renderExistingCard is index 6.
enum CardRenderingMethod {
    static let getEmptyCards: UInt32 = 5
    static let renderExistingCard: UInt32 = 6
    static let renderUncommittedCard: UInt32 = 7
    static let compareAnswer: UInt32 = 15
    static let extractClozeForTyping: UInt32 = 16
}
