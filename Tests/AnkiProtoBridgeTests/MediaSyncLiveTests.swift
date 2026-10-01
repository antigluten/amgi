import AnkiKit
import AnkiServices
import Dependencies
import Foundation
import ImageIO
import Network
import Testing
@testable import AnkiBackend
@testable import AnkiProtoBridge

struct IncrementalMediaSyncLiveTests {
    @Test(arguments: [false, true])
    func incrementalMediaSyncRetriesWithoutPartialFiles(interrupted: Bool) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let collection = directory.appendingPathComponent("collection.anki2")
        try fixtureData("collection.anki2").write(to: collection)
        let backend = try AnkiBackend()
        try backend.openCollection(collectionPath: collection.path,
                                   mediaFolderPath: directory.appendingPathComponent("media").path,
                                   mediaDbPath: directory.appendingPathComponent("media.db").path)
        defer { try? backend.closeCollection() }
        let server = try MediaSyncFixtureServer(incrementalInterrupted: interrupted)
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
            #expect(try await backend.invoke(.checkMedia).missing.isEmpty)
            #expect(try await backend.invoke(.checkDatabase).isEmpty)
        }
    }

}

struct MediaSyncLiveTests {
    @Test(arguments: [SyncDirection.download, .upload])
    func fullSyncFetchesRemoteImageWithoutAKnownMediaVersion(direction: SyncDirection) async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let backend = try AnkiBackend()
        try backend.openCollection(
            collectionPath: directory.appendingPathComponent("collection.anki2").path,
            mediaFolderPath: directory.appendingPathComponent("media").path,
            mediaDbPath: directory.appendingPathComponent("media.db").path
        )
        defer { try? backend.closeCollection() }
        let basic = try #require(try await backend.invoke(.notetypeNames).first { $0.name == "Basic" })
        var note = try await backend.invoke(.newNote(notetypeId: basic.id))
        note.fields = ["<img src=\"probe.png\">", "media sync"]
        try await backend.invoke(.addNote(template: note, deckId: DeckID(1)))
        #expect(try await backend.invoke(.checkMedia).missing == ["probe.png"])

        let server = try MediaSyncFixtureServer(direction: direction)
        try await server.start()
        defer { server.stop() }
        try await withDependencies {
            $0.ankiBackend = backend
        } operation: {
            let service = SyncService.liveValue
            try await service.fullSync(server.endpoint, "fixture-key", direction)
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            while try await service.mediaSyncStatus().active {
                try #require(ContinuousClock.now < deadline, "Media sync did not finish")
                try await Task.sleep(for: .milliseconds(20))
            }
        }

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

private func waitForMedia(_ service: SyncService) async throws {
    let deadline = ContinuousClock.now.advanced(by: .seconds(10))
    while try await service.mediaSyncStatus().active {
        try #require(ContinuousClock.now < deadline, "Media sync did not finish")
        try await Task.sleep(for: .milliseconds(20))
    }
}

private func fixtureData(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.resourceURL?.appendingPathComponent("MediaSync/\(name)"))
    return try Data(contentsOf: url)
}

/// A loopback-only protocol fixture, not a replacement sync server.
/// Mutable request ordering is confined to the listener's serial queue.
private final class MediaSyncFixtureServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "media-sync-fixture")
    private let responses: [(path: String, file: String, originalSize: Int)]
    private var nextResponse = 0

    var consumedAllResponses: Bool { queue.sync { nextResponse == responses.count } }

    init(direction: SyncDirection? = nil, incrementalInterrupted: Bool = false) throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        responses = mediaResponses(direction: direction, interrupted: incrementalInterrupted)
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
            let bodyComplete = length.map { bodySize >= $0 } ?? (buffer.suffix(5) == Data("0\r\n\r\n".utf8))
            guard bodyComplete else {
                receive(connection, buffer: buffer)
                return
            }
            let path = headers.split(separator: "\r\n").first?.split(separator: " ").dropFirst().first.map(String.init)
            guard nextResponse < responses.count, path == responses[nextResponse].path else {
                let expected = nextResponse < responses.count ? responses[nextResponse].path : "end"
                Issue.record("Unexpected media-sync request \(nextResponse): \(path ?? headers); expected \(expected)")
                connection.cancel()
                return
            }
            let item = responses[nextResponse]
            nextResponse += 1
            guard let response = try? mediaHTTPResponse(file: item.file, originalSize: item.originalSize) else {
                Issue.record("Invalid media response fixture: \(item.file)")
                connection.cancel()
                return
            }
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
    }
}

private func mediaResponses(direction: SyncDirection?, interrupted: Bool) -> [(path: String, file: String, originalSize: Int)] {
    let changes = ("/msync/mediaChanges", "changes.json.zst", 79)
    let download = ("/msync/downloadFiles", "media.zip.zst", 373)
    let finish = [download, ("/msync/mediaChanges", "empty.json.zst", 21), ("/msync/mediaSanity", "sanity.json.zst", 23)]
    if let direction {
        let collection = direction == .download
            ? ("/sync/download", "collection.anki2.zst", 147456)
            : ("/sync/upload", "upload.json.zst", 2)
        return [collection, ("/msync/begin", "begin.json.zst", 47), changes] + finish
    }
    let attempt = [("/sync/meta", "meta", 0), changes]
    return (interrupted ? attempt + [("/msync/downloadFiles", "truncated", 373)] : [])
        + attempt + finish + [("/sync/meta", "meta", 0)]
}

private func mediaHTTPResponse(file: String, originalSize: Int) throws -> Data {
    let body: Data
    let size: Int
    if file == "meta" {
        let meta: [String: Any] = [
            "mod": 1790783187837, "scm": 1790783187825, "usn": 0,
            "ts": Int(Date().timeIntervalSince1970), "msg": "", "cont": true,
            "hostNum": 0, "empty": false, "media_usn": 1,
        ]
        let json = try JSONSerialization.data(withJSONObject: meta)
        try #require(json.count < 256)
        // One raw-block, single-segment zstd frame; bounded to this tiny metadata fixture.
        let block = (json.count << 3) | 1
        body = Data([0x28, 0xb5, 0x2f, 0xfd, 0x20, UInt8(json.count),
                     UInt8(block & 255), UInt8((block >> 8) & 255), 0]) + json
        size = json.count
    } else {
        let fixture = try fixtureData(file == "truncated" ? "media.zip.zst" : file)
        body = file == "truncated" ? Data(fixture.prefix(fixture.count / 2)) : fixture
        size = originalSize
    }
    let declaredSize = file == "truncated" ? body.count * 2 + 1 : body.count
    return Data("HTTP/1.1 200 OK\r\nContent-Length: \(declaredSize)\r\nanki-original-size: \(size)\r\nConnection: close\r\n\r\n".utf8) + body
}
