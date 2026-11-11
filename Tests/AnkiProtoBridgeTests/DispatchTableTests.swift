//
//  DispatchTableTests.swift
//  AnkiProtoBridgeTests
//
//  Created by Vladimir Gusev on 22.09.2026.
//

import Foundation
import Testing
@testable import AnkiBackend
@testable import AnkiProtoBridge

@Suite("Backend dispatch table")
struct DispatchTableTests {

    private struct Method {
        let service: UInt32
        let index: UInt32
        let rustName: String

        init(_ service: UInt32, _ index: UInt32, _ rustName: String) {
            self.service = service
            self.index = index
            self.rustName = rustName
        }
    }

    private static let services: [(UInt32, String)] = [
        (ServiceID.sync, "backend_sync_service"),
        (ServiceID.collection, "backend_collection_service"),
        (ServiceID.cards, "backend_cards_service"),
        (ServiceID.decks, "backend_decks_service"),
        (ServiceID.config, "backend_config_service"),
        (ServiceID.deckConfig, "backend_deck_config_service"),
        (ServiceID.scheduler, "backend_scheduler_service"),
        (ServiceID.notetypes, "backend_notetypes_service"),
        (ServiceID.notes, "backend_notes_service"),
        (ServiceID.cardRendering, "backend_card_rendering_service"),
        (ServiceID.search, "backend_search_service"),
        (ServiceID.imageOcclusion, "backend_image_occlusion_service"),
        (ServiceID.importExport, "backend_import_export_service"),
        (ServiceID.media, "backend_media_service"),
        (ServiceID.stats, "backend_stats_service"),
        (ServiceID.tags, "backend_tags_service"),
        // AnkiBackend keeps its own copies for the RPCs it makes directly.
        (AnkiBackend.Service.collection, "backend_collection_service"),
        (AnkiBackend.Service.config, "backend_config_service"),
    ]

    private static let methods: [Method] = [
        // backend_collection_service (3)
        Method(ServiceID.collection, CollectionOpsMethod.checkDatabase, "check_database"),
        Method(ServiceID.collection, CollectionOpsMethod.getUndoStatus, "get_undo_status"),
        Method(ServiceID.collection, CollectionOpsMethod.undo, "undo"),
        // backend_cards_service (5)
        Method(ServiceID.cards, CardsMethod.getCard, "get_card"),
        Method(ServiceID.cards, CardsMethod.removeCards, "remove_cards"),
        Method(ServiceID.cards, CardsMethod.setFlag, "set_flag"),
        // backend_decks_service (7)
        Method(ServiceID.decks, DecksMethod.newDeck, "new_deck"),
        Method(ServiceID.decks, DecksMethod.addDeck, "add_deck"),
        Method(ServiceID.decks, DecksMethod.addOrUpdateDeckLegacy, "add_or_update_deck_legacy"),
        // Named `deck_tree` upstream; the Swift constant reads `getDeckTree`
        // to match its request factory. Same index — an alias, not drift.
        Method(ServiceID.decks, DecksMethod.getDeckTree, "deck_tree"),
        Method(ServiceID.decks, DecksMethod.getDeck, "get_deck"),
        Method(ServiceID.decks, DecksMethod.getDeckNames, "get_deck_names"),
        Method(ServiceID.decks, DecksMethod.removeDecks, "remove_decks"),
        Method(ServiceID.decks, DecksMethod.renameDeck, "rename_deck"),
        Method(ServiceID.decks, DecksMethod.setCurrentDeck, "set_current_deck"),
        Method(ServiceID.decks, DecksMethod.getCurrentDeck, "get_current_deck"),
        // backend_scheduler_service (13)
        Method(ServiceID.scheduler, SchedulerMethod.getQueuedCards, "get_queued_cards"),
        Method(ServiceID.scheduler, SchedulerMethod.answerCard, "answer_card"),
        Method(ServiceID.scheduler, SchedulerMethod.extendLimits, "extend_limits"),
        Method(ServiceID.scheduler, SchedulerMethod.buryOrSuspendCards, "bury_or_suspend_cards"),
        Method(ServiceID.scheduler, SchedulerMethod.emptyFilteredDeck, "empty_filtered_deck"),
        Method(ServiceID.scheduler, SchedulerMethod.rebuildFilteredDeck, "rebuild_filtered_deck"),
        Method(ServiceID.scheduler, SchedulerMethod.scheduleCardsAsNew, "schedule_cards_as_new"),
        Method(ServiceID.scheduler, SchedulerMethod.setDueDate, "set_due_date"),
        Method(ServiceID.scheduler, SchedulerMethod.computeFsrsParams, "compute_fsrs_params"),
        Method(ServiceID.scheduler, SchedulerMethod.simulateFsrsReview, "simulate_fsrs_review"),
        Method(ServiceID.scheduler, SchedulerMethod.simulateFsrsWorkload, "simulate_fsrs_workload"),
        // backend_deck_config_service (11)
        Method(ServiceID.deckConfig, DeckConfigMethod.getDeckConfig, "get_deck_config"),
        Method(ServiceID.deckConfig, DeckConfigMethod.getDeckConfigsForUpdate, "get_deck_configs_for_update"),
        Method(ServiceID.deckConfig, DeckConfigMethod.updateDeckConfigs, "update_deck_configs"),
        Method(ServiceID.deckConfig, DeckConfigMethod.getRetentionWorkload, "get_retention_workload"),
        // backend_notetypes_service (23)
        Method(ServiceID.notetypes, NotetypesMethod.updateNotetype, "update_notetype"),
        Method(ServiceID.notetypes, NotetypesMethod.getNotetype, "get_notetype"),
        Method(ServiceID.notetypes, NotetypesMethod.getNotetypeNames, "get_notetype_names"),
        Method(ServiceID.notetypes, NotetypesMethod.removeNotetype, "remove_notetype"),
        // backend_stats_service (43)
        Method(ServiceID.stats, StatsMethod.cardStats, "card_stats"),
        Method(ServiceID.stats, StatsMethod.graphs, "graphs"),
        // backend_import_export_service (39)
        Method(ServiceID.importExport, ImportExportMethod.importCollectionPackage, "import_collection_package"),
        Method(ServiceID.importExport, ImportExportMethod.exportCollectionPackage, "export_collection_package"),
        Method(ServiceID.importExport, ImportExportMethod.importAnkiPackage, "import_anki_package"),
        Method(ServiceID.importExport, ImportExportMethod.exportAnkiPackage, "export_anki_package"),
        // backend_notes_service (25)
        Method(ServiceID.notes, NotesMethod.newNote, "new_note"),
        Method(ServiceID.notes, NotesMethod.addNote, "add_note"),
        Method(ServiceID.notes, NotesMethod.updateNotes, "update_notes"),
        Method(ServiceID.notes, NotesMethod.getNote, "get_note"),
        Method(ServiceID.notes, NotesMethod.removeNotes, "remove_notes"),
        Method(ServiceID.notes, NotesMethod.fieldNamesForNotes, "field_names_for_notes"),
        Method(ServiceID.notes, NotesMethod.cardsOfNote, "cards_of_note"),
        // backend_search_service (29)
        Method(ServiceID.search, SearchMethod.searchCards, "search_cards"),
        Method(ServiceID.search, SearchMethod.searchNotes, "search_notes"),
        Method(ServiceID.search, SearchMethod.findAndReplace, "find_and_replace"),
        // backend_sync_service (1)
        Method(ServiceID.sync, SyncMethod.syncMedia, "sync_media"),
        Method(ServiceID.sync, SyncMethod.abortMediaSync, "abort_media_sync"),
        Method(ServiceID.sync, SyncMethod.mediaSyncStatus, "media_sync_status"),
        Method(ServiceID.sync, SyncMethod.syncLogin, "sync_login"),
        Method(ServiceID.sync, SyncMethod.syncStatus, "sync_status"),
        Method(ServiceID.sync, SyncMethod.syncCollection, "sync_collection"),
        Method(ServiceID.sync, SyncMethod.fullUploadOrDownload, "full_upload_or_download"),
        Method(ServiceID.sync, SyncMethod.abortSync, "abort_sync"),
        // backend_tags_service (45)
        Method(ServiceID.tags, TagsMethod.clearUnusedTags, "clear_unused_tags"),
        Method(ServiceID.tags, TagsMethod.allTags, "all_tags"),
        Method(ServiceID.tags, TagsMethod.removeTags, "remove_tags"),
        Method(ServiceID.tags, TagsMethod.setTagCollapsed, "set_tag_collapsed"),
        Method(ServiceID.tags, TagsMethod.tagTree, "tag_tree"),
        Method(ServiceID.tags, TagsMethod.reparentTags, "reparent_tags"),
        Method(ServiceID.tags, TagsMethod.renameTags, "rename_tags"),
        Method(ServiceID.tags, TagsMethod.addNoteTags, "add_note_tags"),
        Method(ServiceID.tags, TagsMethod.removeNoteTags, "remove_note_tags"),
        Method(ServiceID.tags, TagsMethod.findAndReplaceTag, "find_and_replace_tag"),
        Method(ServiceID.tags, TagsMethod.completeTag, "complete_tag"),
        // backend_image_occlusion_service (37)
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.getImageForOcclusion, "get_image_for_occlusion"),
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.getImageOcclusionNote, "get_image_occlusion_note"),
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.getImageOcclusionFields, "get_image_occlusion_fields"),
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.addImageOcclusionNotetype, "add_image_occlusion_notetype"),
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.addImageOcclusionNote, "add_image_occlusion_note"),
        Method(ServiceID.imageOcclusion, ImageOcclusionMethod.updateImageOcclusionNote, "update_image_occlusion_note"),
        // backend_media_service (41)
        Method(ServiceID.media, MediaMethod.checkMedia, "check_media"),
        Method(ServiceID.media, MediaMethod.addMediaFile, "add_media_file"),
        Method(ServiceID.media, MediaMethod.trashMediaFiles, "trash_media_files"),
        Method(ServiceID.media, MediaMethod.emptyTrash, "empty_trash"),
        Method(ServiceID.media, MediaMethod.restoreTrash, "restore_trash"),
        // backend_card_rendering_service (27)
        Method(ServiceID.cardRendering, CardRenderingMethod.getEmptyCards, "get_empty_cards"),
        Method(ServiceID.cardRendering, CardRenderingMethod.renderExistingCard, "render_existing_card"),
        Method(ServiceID.cardRendering, CardRenderingMethod.renderUncommittedCard, "render_uncommitted_card"),
        Method(ServiceID.cardRendering, CardRenderingMethod.compareAnswer, "compare_answer"),
        Method(ServiceID.cardRendering, CardRenderingMethod.extractClozeForTyping, "extract_cloze_for_typing"),
        // AnkiBackend's own RPCs, which no bridge factory covers.
        Method(AnkiBackend.Service.collection, AnkiBackend.CollectionMethod.open, "open_collection"),
        Method(AnkiBackend.Service.collection, AnkiBackend.CollectionMethod.close, "close_collection"),
        Method(AnkiBackend.Service.config, AnkiBackend.ConfigMethod.getConfigJson, "get_config_json"),
        Method(AnkiBackend.Service.config, AnkiBackend.ConfigMethod.setConfigJsonNoUndo, "set_config_json_no_undo"),
        Method(AnkiBackend.Service.config, AnkiBackend.ConfigMethod.removeConfig, "remove_config"),
    ]

    // MARK: - Ground truth

    private static let sourceRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // AnkiProtoBridgeTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root

    private static func loadFixture() throws -> (
        methods: [Pair: String], services: [UInt32: String]
    ) {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/dispatch-table.tsv")
        let text = try String(contentsOf: url, encoding: .utf8)

        var methods: [Pair: String] = [:]
        var services: [UInt32: String] = [:]
        for line in text.split(separator: "\n") {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count == 4,
                  let service = UInt32(cols[0]),
                  let method = UInt32(cols[2])
            else { continue }
            services[service] = String(cols[1])
            methods[Pair(service, method)] = String(cols[3])
        }
        return (methods, services)
    }

    private struct Pair: Hashable {
        let service: UInt32
        let method: UInt32
        init(_ service: UInt32, _ method: UInt32) {
            self.service = service
            self.method = method
        }
    }

    // MARK: - Tests

    @Test("every service index resolves to the service we think it is")
    func servicesMatchTheEngine() throws {
        let fixture = try Self.loadFixture()
        #expect(!fixture.services.isEmpty, "fixture failed to load")

        for (index, expected) in Self.services {
            #expect(
                fixture.services[index] == expected,
                "service \(index) is \(fixture.services[index] ?? "absent") upstream, not \(expected)"
            )
        }
    }

    @Test("every method index resolves to the method we think it is")
    func methodsMatchTheEngine() throws {
        let fixture = try Self.loadFixture()
        #expect(!fixture.methods.isEmpty, "fixture failed to load")

        for row in Self.methods {
            let actual = fixture.methods[Pair(row.service, row.index)]
            #expect(
                actual == row.rustName,
                """
                service \(row.service) method \(row.index) dispatches to \
                '\(actual ?? "nothing")' upstream, but we call it '\(row.rustName)'
                """
            )
        }
    }

    @Test("no dispatch constant is left unpinned")
    func everyConstantIsPinned() throws {
        // `ServiceID.aux` and `AuxMethod.findDuplicates` are ours, not
        // upstream's: service 200 never reaches `run_service_method`.
        let auxConstants = 2

        let catalog = try Self.constantCount(
            in: "Sources/AnkiProtoBridge/ServiceCatalog.swift"
        )
        let backend = try Self.constantCount(
            in: "Sources/AnkiBackend/AnkiBackend.swift"
        )

        // A duplicated row would otherwise balance an unpinned constant.
        let uniqueRows = Set(Self.methods.map { Pair($0.service, $0.index) })
        #expect(uniqueRows.count == Self.methods.count, "duplicate (service, index) row")

        let pinned = Self.services.count + Self.methods.count
        #expect(
            catalog + backend == pinned + auxConstants,
            """
            \(catalog + backend) dispatch constants in source, \(pinned) pinned \
            (+\(auxConstants) aux). A new one needs a row in `services` or `methods`.
            """
        )
    }

    private static func constantCount(in path: String) throws -> Int {
        let text = try String(
            contentsOf: sourceRoot.appendingPathComponent(path), encoding: .utf8
        )
        let pattern = #"static let \w+: UInt32 = \d+"#
        let regex = try NSRegularExpression(pattern: pattern)
        return regex.numberOfMatches(
            in: text, range: NSRange(text.startIndex..., in: text)
        )
    }
}
