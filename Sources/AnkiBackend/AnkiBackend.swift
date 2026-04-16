import AnkiRustLib
import AnkiProto
public import Foundation
public import SwiftProtobuf

public final class AnkiBackend: Sendable {
    private let backendPtr: Int64
    private let lock = NSLock()

    /// Stored collection paths for close/reopen after full sync.
    private nonisolated(unsafe) var collectionPath: String?
    private nonisolated(unsafe) var mediaFolderPath: String?
    private nonisolated(unsafe) var mediaDbPath: String?

    /// Absolute path of the open collection's media folder, or nil if no
    /// collection is currently open. Backed by `nonisolated(unsafe)` storage
    /// that is set during `openCollection` and cleared during `close`. Safe to
    /// read from any thread for the duration of an open collection, but callers
    /// must not assume stability across `close` / `openCollection` cycles.
    public var currentMediaFolderPath: String? { mediaFolderPath }

    public init(preferredLangs: [String] = ["en"]) throws {
        var initMsg = Anki_Backend_BackendInit()
        initMsg.preferredLangs = preferredLangs
        initMsg.server = false

        let initBytes = try initMsg.serializedData()
        var ptr: Int64 = 0

        let result = initBytes.withUnsafeBytes { buf in
            anki_open_backend(
                buf.baseAddress?.assumingMemoryBound(to: UInt8.self),
                buf.count,
                &ptr
            )
        }

        guard result == 0, ptr != 0 else {
            throw BackendError(kind: .ioError, message: "Failed to initialize Anki backend")
        }
        self.backendPtr = ptr
    }

    deinit {
        anki_close_backend(backendPtr)
    }

    // MARK: - Typed RPC (package — use AnkiServices, not these directly)

    package func invoke<Req: SwiftProtobuf.Message, Resp: SwiftProtobuf.Message>(
        service: UInt32, method: UInt32, request: Req
    ) throws -> Resp {
        let responseBytes = try call(service: service, method: method, request: request)
        return try Resp(serializedBytes: responseBytes)
    }

    package func invoke<Resp: SwiftProtobuf.Message>(
        service: UInt32, method: UInt32
    ) throws -> Resp {
        let responseBytes = try callRaw(service: service, method: method, input: Data())
        return try Resp(serializedBytes: responseBytes)
    }

    package func call(
        service: UInt32, method: UInt32,
        request: some SwiftProtobuf.Message
    ) throws -> Data {
        let inputBytes = try request.serializedData()
        return try callRaw(service: service, method: method, input: inputBytes)
    }

    package func call(service: UInt32, method: UInt32) throws -> Data {
        try callRaw(service: service, method: method, input: Data())
    }

    package func callVoid(
        service: UInt32, method: UInt32,
        request: some SwiftProtobuf.Message
    ) throws {
        _ = try call(service: service, method: method, request: request)
    }

    package func callVoid(service: UInt32, method: UInt32) throws {
        _ = try call(service: service, method: method)
    }

    // MARK: - Collection Lifecycle

    public func openCollection(
        collectionPath: String,
        mediaFolderPath: String,
        mediaDbPath: String
    ) throws {
        // Store paths for reopen after full sync
        self.collectionPath = collectionPath
        self.mediaFolderPath = mediaFolderPath
        self.mediaDbPath = mediaDbPath

        var req = Anki_Collection_OpenCollectionRequest()
        req.collectionPath = collectionPath
        req.mediaFolderPath = mediaFolderPath
        req.mediaDbPath = mediaDbPath
        try callVoid(service: Service.collection, method: CollectionMethod.open, request: req)
    }

    /// Reopen the collection after a full sync (which replaces the DB file).
    /// The Rust backend internally reopens, but we call close+open at our layer
    /// to ensure consistency (same pattern as AnkiDroid).
    public func reopenAfterFullSync() throws {
        guard let path = collectionPath,
              let media = mediaFolderPath,
              let mediaDb = mediaDbPath
        else { return }

        // Close our side (Rust may already have reopened internally)
        try? closeCollection()

        // Reopen with the same paths
        try openCollection(
            collectionPath: path,
            mediaFolderPath: media,
            mediaDbPath: mediaDb
        )
    }

    public func closeCollection(downgradeToSchema11: Bool = false) throws {
        var req = Anki_Collection_CloseCollectionRequest()
        req.downgradeToSchema11 = downgradeToSchema11
        try callVoid(service: Service.collection, method: CollectionMethod.close, request: req)
    }

    /// Runs CheckDatabase to repair any inconsistencies (CollectionService 2, method 0).
    public func checkDatabase() throws {
        _ = try callRaw(service: Service.collectionOps, method: CollectionOpsMethod.checkDatabase, input: Data())
    }

    // MARK: - Raw FFI

    private func callRaw(service: UInt32, method: UInt32, input: Data) throws -> Data {
        lock.lock()
        defer { lock.unlock() }

        var outPtr: UnsafeMutablePointer<UInt8>? = nil
        var outLen: Int = 0

        let status: Int32
        if input.isEmpty {
            status = anki_run_method(backendPtr, service, method, nil, 0, &outPtr, &outLen)
        } else {
            status = input.withUnsafeBytes { buf in
                anki_run_method(
                    backendPtr, service, method,
                    buf.baseAddress?.assumingMemoryBound(to: UInt8.self), buf.count,
                    &outPtr, &outLen
                )
            }
        }

        defer {
            if let outPtr { anki_free_response(outPtr, outLen) }
        }

        let responseData: Data
        if let outPtr, outLen > 0 {
            responseData = Data(bytes: outPtr, count: outLen)
        } else {
            responseData = Data()
        }

        switch status {
        case 0: return responseData
        case 1: throw BackendError(errorBytes: responseData)
        default: throw BackendError(kind: .ioError, message: "FFI error (status \(status))")
        }
    }
}

// MARK: - Service Constants (package — implementation detail of AnkiServices)

extension AnkiBackend {
    package enum Service {
        package static let sync: UInt32 = 1
        package static let collectionOps: UInt32 = 2
        package static let collection: UInt32 = 3
        package static let cards: UInt32 = 5
        package static let decks: UInt32 = 7
        package static let scheduler: UInt32 = 13
        package static let notetypes: UInt32 = 23
        package static let notes: UInt32 = 25
        package static let cardRendering: UInt32 = 27
        package static let search: UInt32 = 29
        package static let importExport: UInt32 = 37
        package static let stats: UInt32 = 41
        package static let tags: UInt32 = 43
    }

    package enum CollectionOpsMethod {
        package static let checkDatabase: UInt32 = 0
        package static let getUndoStatus: UInt32 = 1
        package static let undo: UInt32 = 2
    }

    package enum CollectionMethod {
        package static let open: UInt32 = 0
        package static let close: UInt32 = 1
        package static let latestProgress: UInt32 = 4
    }

    package enum SyncMethod {
        package static let syncMedia: UInt32 = 0
        package static let syncLogin: UInt32 = 3
        package static let syncStatus: UInt32 = 4
        package static let syncCollection: UInt32 = 5
        package static let fullUploadOrDownload: UInt32 = 6
    }

    // Method indices from BackendSchedulerService (service 13) dispatch table.
    // Backend-level has 3 extra methods at start (computeFsrsParams, benchmark, exportDataset)
    // so Collection-level indices are offset by +3.
    package enum SchedulerMethod {
        package static let getQueuedCards: UInt32 = 3
        package static let answerCard: UInt32 = 4
        package static let schedTimingToday: UInt32 = 5
        package static let countsForDeckToday: UInt32 = 10
        package static let congratsInfo: UInt32 = 11
    }

    package enum NotesMethod {
        package static let newNote: UInt32 = 0
        package static let addNote: UInt32 = 1
        package static let removeNotes: UInt32 = 3  // verified dispatch index
        package static let updateNotes: UInt32 = 5
        package static let getNote: UInt32 = 6
    }

    package enum DecksMethod {
        package static let newDeck: UInt32 = 0
        package static let addDeck: UInt32 = 1
        package static let addOrUpdateDeckLegacy: UInt32 = 3
        package static let getDeckTree: UInt32 = 4
        package static let getDeck: UInt32 = 8
        package static let getDeckNames: UInt32 = 13
        package static let removeDecks: UInt32 = 16
        package static let renameDeck: UInt32 = 18
        package static let setCurrentDeck: UInt32 = 22
        package static let getCurrentDeck: UInt32 = 23
    }

    package enum SearchMethod {
        package static let searchCards: UInt32 = 1
        package static let searchNotes: UInt32 = 2
    }

    // BackendCardRenderingService (27) has 6 extra methods before renderExistingCard
    package enum CardRenderingMethod {
        package static let renderExistingCard: UInt32 = 6
    }

    package enum NotetypesMethod {
        package static let getNotetype: UInt32 = 6
        package static let getNotetypeNames: UInt32 = 8
    }

    package enum ImportExportMethod {
        package static let importCollectionPackage: UInt32 = 0
        package static let exportCollectionPackage: UInt32 = 1
        package static let importAnkiPackage: UInt32 = 2
    }

    package enum StatsMethod {
        package static let cardStats: UInt32 = 0
        package static let graphs: UInt32 = 2
    }
}
