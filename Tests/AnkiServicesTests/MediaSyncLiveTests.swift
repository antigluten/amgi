import AnkiKit
import AnkiServices
import Dependencies
import Foundation
import ImageIO
import Network
import SQLite3
import Testing
import AnkiBackend
import AnkiProtoBridge

@Suite(.timeLimit(.minutes(1)))
struct IncrementalMediaSyncLiveTests {
    @Test(arguments: [false, true])
    func incrementalMediaSyncRetriesWithoutPartialFiles(interrupted: Bool) async throws {
        try await withScratchCollection("incremental-media-sync") { backend, directory in
            try await addProbeNote(backend)
            let collection = try closedSnapshot(backend, directory)
            let server = try MediaSyncFixtureServer(
                mediaReplies(collection, direction: nil, interrupted: interrupted)
            )
            try await server.start()
            defer { server.stop() }
            try await withDependencies {
                $0.ankiBackend = backend
            } operation: {
                let service = SyncService.liveValue
                if interrupted {
                    _ = try await service.sync(server.endpoint, "fixture-key")
                    do {
                        try await waitForMedia(service)
                        Issue.record("Truncated HTTP download must report a media-sync error")
                    } catch {
                        #expect(error is SyncError, "Expected a native media transfer error, not a test timeout: \(error)")
                        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("media/probe.png").path))
                    }
                }
                _ = try await service.sync(server.endpoint, "fixture-key")
                try await waitForMedia(service)
                let image = try Data(contentsOf: directory.appendingPathComponent("media/probe.png"))
                #expect(try image == fixtureData("probe.png"))
                // A second collection sync must not re-fetch already committed media.
                _ = try await service.sync(server.endpoint, "fixture-key")
                try await waitForMedia(service)
                #expect(server.consumedAllResponses)
                #expect(server.failures.isEmpty, "\(server.failures)")
                #expect(try await backend.invoke(.checkMedia).missing.isEmpty)
                #expect(try await backend.invoke(.checkDatabase).isEmpty)
            }
        }
    }
}

@Suite(.timeLimit(.minutes(1)))
struct MediaSyncLiveTests {
    @Test(arguments: [SyncDirection.download, .upload])
    func fullSyncFetchesRemoteImageWithoutAKnownMediaVersion(direction: SyncDirection) async throws {
        let remote = try await makeRemoteCollection()
        try await withScratchCollection("full-media-sync") { backend, directory in
            try await addProbeNote(backend)
            #expect(try await backend.invoke(.checkMedia).missing == ["probe.png"])

            let server = try MediaSyncFixtureServer(
                mediaReplies(remote, direction: direction, interrupted: false)
            )
            try await server.start()
            defer { server.stop() }
            try await withDependencies {
                $0.ankiBackend = backend
            } operation: {
                let service = SyncService.liveValue
                try await service.fullSync(server.endpoint, "fixture-key", direction, true)
                try await waitForMedia(service)
            }
            #expect(server.consumedAllResponses)
            #expect(server.failures.isEmpty, "\(server.failures)")

            let imageURL = directory.appendingPathComponent("media/probe.png")
            #expect(FileManager.default.fileExists(atPath: imageURL.path))
            #expect(try await backend.invoke(.checkMedia).missing.isEmpty)
            #expect(try await backend.invoke(.checkDatabase).isEmpty)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                let image = try Data(contentsOf: imageURL)
                #expect(try image == fixtureData("probe.png"))
                let source = try #require(CGImageSourceCreateWithData(image as CFData, nil))
                #expect(CGImageSourceCreateImageAtIndex(source, 0, nil) != nil)
            }
        }
    }
}

private func waitForMedia(_ service: SyncService) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while try await service.mediaSyncStatus().active {
        try #require(ContinuousClock.now < deadline, "Media sync did not finish")
        try await Task.sleep(for: .milliseconds(20))
    }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/MediaSync/\(name)")
    return try Data(contentsOf: url)
}

private func addProbeNote(_ backend: AnkiBackend) async throws {
    let basic = try #require(try await backend.invoke(.notetypeNames).first { $0.name == "Basic" })
    var note = try await backend.invoke(.newNote(notetypeId: basic.id))
    note.fields = ["<img src=\"probe.png\">", "media sync"]
    try await backend.invoke(.addNote(template: note, deckId: DeckID(1)))
}

private struct CollectionSnapshot {
    let data: Data
    let mod: Int64
    let scm: Int64
}

/// Closes the collection to read its file and `mod` / `scm`, then reopens it.
private func closedSnapshot(_ backend: AnkiBackend, _ directory: URL) throws -> CollectionSnapshot {
    try backend.closeCollection()
    let snapshot = try readSnapshot(directory.appendingPathComponent("collection.anki2"))
    try backend.reopenCollection()
    return snapshot
}

private func readSnapshot(_ path: URL) throws -> CollectionSnapshot {
    var uri = URLComponents()
    uri.scheme = "file"
    uri.path = path.path
    uri.queryItems = [URLQueryItem(name: "immutable", value: "1")]
    var db: OpaquePointer?
    try #require(sqlite3_open_v2(uri.string!, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil) == SQLITE_OK)
    defer { sqlite3_close(db) }
    var statement: OpaquePointer?
    try #require(sqlite3_prepare_v2(db, "SELECT mod, scm FROM col", -1, &statement, nil) == SQLITE_OK,
                 "\(String(cString: sqlite3_errmsg(db)))")
    defer { sqlite3_finalize(statement) }
    try #require(sqlite3_step(statement) == SQLITE_ROW)
    return CollectionSnapshot(
        data: try Data(contentsOf: path),
        mod: sqlite3_column_int64(statement, 0),
        scm: sqlite3_column_int64(statement, 1)
    )
}

/// The collection a server would hold: the probe note, with the image still missing.
private func makeRemoteCollection() async throws -> CollectionSnapshot {
    try await withScratchCollection("media-sync-remote") { backend, directory in
        try await addProbeNote(backend)
        #expect(try await backend.invoke(.checkDatabase).isEmpty)
        return try closedSnapshot(backend, directory)
    }
}

private struct Reply {
    let path: String
    let payload: Data
    var truncated = false
}

private func mediaReplies(
    _ collection: CollectionSnapshot, direction: SyncDirection?, interrupted: Bool
) throws -> [Reply] {
    let protocolFile = try #require(
        try JSONSerialization.jsonObject(with: fixtureData("protocol.json")) as? [String: Any]
    )
    func json(_ key: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: #require(protocolFile[key]))
    }
    let zip = try fixtureData("media.zip")
    let changes = Reply(path: "/msync/mediaChanges", payload: try json("changes"))
    let finish = [
        Reply(path: "/msync/downloadFiles", payload: zip),
        Reply(path: "/msync/mediaChanges", payload: try json("empty")),
        Reply(path: "/msync/mediaSanity", payload: try json("sanity")),
    ]
    if let direction {
        let transfer = direction == .download
            ? Reply(path: "/sync/download", payload: collection.data)
            : Reply(path: "/sync/upload", payload: Data("OK".utf8))
        return [transfer, Reply(path: "/msync/begin", payload: try json("begin")), changes] + finish
    }
    let meta: [String: Any] = [
        "mod": collection.mod, "scm": collection.scm, "usn": 0,
        "ts": Int(Date().timeIntervalSince1970), "msg": "", "cont": true,
        "hostNum": 0, "empty": false, "media_usn": 1,
    ]
    let metaReply = Reply(path: "/sync/meta", payload: try JSONSerialization.data(withJSONObject: meta))
    let attempt = [metaReply, changes]
    let truncated = Reply(path: "/msync/downloadFiles", payload: zip, truncated: true)
    return (interrupted ? attempt + [truncated] : []) + attempt + finish + [metaReply]
}

/// Wraps `data` in a single-segment zstd frame of raw (uncompressed) blocks.
private func rawZstdFrame(_ data: Data) -> Data {
    var frame = Data([0x28, 0xb5, 0x2f, 0xfd, 0xa0])
    withUnsafeBytes(of: UInt32(data.count).littleEndian) { frame.append(contentsOf: $0) }
    var offset = 0
    repeat {
        let size = min(131_072, data.count - offset)
        let header = (size << 3) | (offset + size == data.count ? 1 : 0)
        frame.append(contentsOf: [UInt8(header & 255), UInt8((header >> 8) & 255), UInt8(header >> 16)])
        frame.append(data.subdata(in: offset..<(offset + size)))
        offset += size
    } while offset < data.count
    return frame
}

private func httpResponse(for reply: Reply) -> Data {
    let body = rawZstdFrame(reply.payload)
    let sent = reply.truncated ? Data(body.prefix(body.count / 2)) : body
    let declaredSize = reply.truncated ? sent.count * 2 + 1 : sent.count
    let head = "HTTP/1.1 200 OK\r\nContent-Length: \(declaredSize)\r\n"
        + "anki-original-size: \(reply.payload.count)\r\nConnection: close\r\n\r\n"
    return Data(head.utf8) + sent
}

/// A loopback-only protocol fixture, not a replacement sync server.
/// Mutable state is confined to the listener's serial queue.
private final class MediaSyncFixtureServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "media-sync-fixture")
    private let replies: [Reply]
    private var nextReply = 0
    private var recordedFailures: [String] = []

    var consumedAllResponses: Bool { queue.sync { nextReply == replies.count } }
    var failures: [String] { queue.sync { recordedFailures } }

    init(_ replies: [Reply]) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        self.replies = replies
    }

    var endpoint: String { "http://127.0.0.1:\(listener.port!.rawValue)/" }

    func start() async throws {
        listener.newConnectionHandler = { [self] connection in
            connection.start(queue: queue)
            receive(connection, buffer: Data())
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    listener.stateUpdateHandler = nil
                    continuation.resume()
                case .failed(let error):
                    listener.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default: break
                }
            }
            listener.start(queue: queue)
        }
    }

    func stop() { listener.cancel() }

    private func receive(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [self] data, _, complete, error in
            var buffer = buffer
            buffer.append(data ?? Data())
            guard error == nil, !complete, buffer.count < 262144 else {
                connection.cancel()
                return
            }
            guard let separator = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                receive(connection, buffer: buffer)
                return
            }
            let headers = String(decoding: buffer[..<separator.lowerBound], as: UTF8.self)
            let bodySize = buffer.count - separator.upperBound
            let length = headers.lowercased().components(separatedBy: "\r\n")
                .first { $0.hasPrefix("content-length:") }
                .flatMap { Int($0.dropFirst("content-length:".count).trimmingCharacters(in: .whitespaces)) }
            let bodyComplete = length.map { bodySize >= $0 } ?? (buffer.suffix(7) == Data("\r\n0\r\n\r\n".utf8))
            guard bodyComplete else {
                receive(connection, buffer: buffer)
                return
            }
            let path = headers.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init)
            guard nextReply < replies.count, path == replies[nextReply].path else {
                let expected = nextReply < replies.count ? replies[nextReply].path : "end"
                recordedFailures.append("Unexpected media-sync request \(nextReply): \(path ?? headers); expected \(expected)")
                connection.cancel()
                return
            }
            let reply = replies[nextReply]
            nextReply += 1
            connection.send(content: httpResponse(for: reply), completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}
