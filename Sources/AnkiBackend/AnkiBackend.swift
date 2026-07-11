import AnkiRustLib
import AnkiProto
public import Foundation
private import SwiftProtobuf

public final class AnkiBackend: Sendable {
    private let backendPtr: Int64
    private let lock = NSLock()

    private nonisolated(unsafe) var mediaFolderPath: String?

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

    private func invoke<Req: SwiftProtobuf.Message, Resp: SwiftProtobuf.Message>(
        service: UInt32, method: UInt32, request: Req
    ) throws -> Resp {
        let responseBytes = try call(service: service, method: method, request: request)
        return try Resp(serializedBytes: responseBytes)
    }

    private func invoke<Resp: SwiftProtobuf.Message>(
        service: UInt32, method: UInt32
    ) throws -> Resp {
        let responseBytes = try callRaw(service: service, method: method, input: Data())
        return try Resp(serializedBytes: responseBytes)
    }

    private func call(
        service: UInt32, method: UInt32,
        request: some SwiftProtobuf.Message
    ) throws -> Data {
        let inputBytes = try request.serializedData()
        return try callRaw(service: service, method: method, input: inputBytes)
    }

    private func call(service: UInt32, method: UInt32) throws -> Data {
        try callRaw(service: service, method: method, input: Data())
    }

    private func callVoid(
        service: UInt32, method: UInt32,
        request: some SwiftProtobuf.Message
    ) throws {
        _ = try call(service: service, method: method, request: request)
    }

    private func callVoid(service: UInt32, method: UInt32) throws {
        _ = try call(service: service, method: method)
    }

    // MARK: - Collection Lifecycle

    public func openCollection(
        collectionPath: String,
        mediaFolderPath: String,
        mediaDbPath: String
    ) throws {
        self.mediaFolderPath = mediaFolderPath

        var req = Anki_Collection_OpenCollectionRequest()
        req.collectionPath = collectionPath
        req.mediaFolderPath = mediaFolderPath
        req.mediaDbPath = mediaDbPath
        try callVoid(service: Service.collection, method: CollectionMethod.open, request: req)
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

    // MARK: - Collection Config (typed JSON helpers)

    /// Fetches a JSON-encoded value from the Anki collection config under
    /// `key` and decodes it as `T`. Returns nil if the key has never been
    /// set (`notFoundError` from the backend).
    public func getConfigJSONValue<T: Decodable>(for key: String) throws -> T? {
        var req = Anki_Generic_String()
        req.val = key
        do {
            let response: Anki_Generic_Json = try invoke(
                service: Service.config,
                method: ConfigMethod.getConfigJson,
                request: req
            )
            return try JSONDecoder().decode(T.self, from: response.json)
        } catch let error as BackendError where error.kind == .notFoundError {
            return nil
        }
    }

    /// Encodes `value` as JSON and writes it under `key` in the collection
    /// config. Uses the no-undo variant — config writes are not part of
    /// the user-visible undo stack.
    public func setConfigJSONValue<T: Encodable>(_ value: T, for key: String) throws {
        var req = Anki_Config_SetConfigJsonRequest()
        req.key = key
        req.valueJson = try JSONEncoder().encode(value)
        req.undoable = false
        try callVoid(
            service: Service.config,
            method: ConfigMethod.setConfigJsonNoUndo,
            request: req
        )
    }

    /// Removes a collection-config key. No-op if the key was never set.
    public func removeConfigValue(for key: String) throws {
        var req = Anki_Generic_String()
        req.val = key
        try callVoid(service: Service.config, method: ConfigMethod.removeConfig, request: req)
    }

    /// Raw `Data?` accessors for the collection-config store. Used by
    /// abstraction layers that want to shuttle opaque JSON bytes without
    /// committing to a specific Codable type at the boundary.
    public func getConfigRawJSON(for key: String) throws -> Data? {
        var req = Anki_Generic_String()
        req.val = key
        do {
            let response: Anki_Generic_Json = try invoke(
                service: Service.config,
                method: ConfigMethod.getConfigJson,
                request: req
            )
            return response.json
        } catch let error as BackendError where error.kind == .notFoundError {
            return nil
        }
    }

    public func setConfigRawJSON(_ json: Data, for key: String) throws {
        var req = Anki_Config_SetConfigJsonRequest()
        req.key = key
        req.valueJson = json
        req.undoable = false
        try callVoid(
            service: Service.config,
            method: ConfigMethod.setConfigJsonNoUndo,
            request: req
        )
    }

    // MARK: - Raw FFI

    private func callRaw(service: UInt32, method: UInt32, input: Data) throws(BackendError) -> Data {
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

    // MARK: - Typed Request invocation (public — preferred entry point)

    public func invoke<R>(_ request: Request<R>) throws(BackendError) -> R {
        switch Self.runInvoke(backend: self, request: request) {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    /// Splits the encode/FFI/decode pipeline out so each step's untyped
    /// throws can be funneled into a single `BackendError` for typed-
    /// throws callers. Encoding and decoding failures map to
    /// `.protoError`; BackendErrors raised explicitly by decoders
    /// (e.g. the `notFoundError` branch in `getImageOcclusionNote`)
    /// pass through unmodified.
    private static func runInvoke<R>(backend: AnkiBackend, request: Request<R>) -> Result<R, BackendError> {
        // Encode
        let input: Data
        do {
            input = try request.encode()
        } catch let backendError as BackendError {
            return .failure(backendError)
        } catch {
            return .failure(BackendError(kind: .protoError, message: "encode failed: \(error)"))
        }
        // FFI dispatch (already typed BackendError)
        let bytes: Data
        do {
            bytes = try backend.callRaw(
                service: request.serviceId,
                method: request.methodId,
                input: input
            )
        } catch {
            return .failure(error)
        }
        // Decode
        do {
            return .success(try request.decode(bytes))
        } catch let backendError as BackendError {
            return .failure(backendError)
        } catch {
            return .failure(BackendError(kind: .protoError, message: "decode failed: \(error)"))
        }
    }

    public func invoke<R>(_ request: Request<R>) async throws(BackendError) -> R {
        do {
            return try await Task.detached(priority: .userInitiated) { [self] in
                try invoke(request)
            }.value
        } catch let error as BackendError {
            throw error
        } catch {
            // Task.detached returns 'any Error'; in practice we only throw
            // BackendError from sync invoke, so this branch is unreachable
            // but the compiler can't prove that.
            throw BackendError(kind: .ioError, message: "Unexpected error: \(error)")
        }
    }
}

// MARK: - Internal service constants
//
// AnkiBackend's *internal* RPCs (openCollection/closeCollection/checkDatabase
// and the config-JSON helpers) keep a small private constant table. The
// canonical, exhaustive service/method ID catalog lives in AnkiProtoBridge.
// Bridge factories are the only sanctioned way for service code to dispatch
// RPCs — every other constant exposure was a drift risk.

extension AnkiBackend {
    fileprivate enum Service {
        static let collectionOps: UInt32 = 2
        static let collection: UInt32 = 3
        static let config: UInt32 = 9
    }

    fileprivate enum CollectionMethod {
        static let open: UInt32 = 0
        static let close: UInt32 = 1
    }

    fileprivate enum CollectionOpsMethod {
        static let checkDatabase: UInt32 = 0
    }

    // BackendConfigService (service 9). Verified against the DreamAfar fork.
    fileprivate enum ConfigMethod {
        static let getConfigJson: UInt32 = 0
        static let setConfigJsonNoUndo: UInt32 = 2
        static let removeConfig: UInt32 = 3
    }
}
