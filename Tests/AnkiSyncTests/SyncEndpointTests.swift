import Testing
@testable import AnkiSync

@Suite struct SyncEndpointTests {
    @Test(arguments: [
        "http://192.168.1.5:8080",
        "http://10.0.0.2",
        "http://172.16.0.1",
        "http://172.31.255.255",
        "http://127.0.0.1:27701",
        "http://169.254.1.1",
        "http://100.64.0.1",
        "http://100.101.102.103",
        "http://localhost:8080",
        "http://nas:27701",
        "http://anki-server",
        "http://nas.local",
        "http://box.lan",
        "http://sync.home.arpa",
        "http://anki.internal",
        "http://box.tailnet-x.ts.net",
        "http://[::1]:8080",
        "http://[fd00::1]",
        "HTTP://192.168.1.5",
    ])
    func cleartextToPrivateHostIsAllowed(_ raw: String) throws {
        #expect(try SyncEndpoint.normalized(raw) == raw)
    }

    @Test(arguments: [
        "http://sync.example.com",
        "http://8.8.8.8",
        "http://100.128.0.1",
        "http://100.63.255.255",
        "http://172.32.0.1",
        "http://172.15.0.1",
        "http://192.169.0.1",
        "http://010.0.0.1",
        "http://134744072",
        "http://0x8080808",
        "http://evil.com.local.example.com",
        "http://[2001:4860:4860::8888]",
        "http://[::ffff:10.0.0.1]",
        "http://[fe80::1]",
        "http://user:pass@10.0.0.1",
        "http://evil.com#@10.0.0.1",
    ])
    func cleartextToPublicHostIsRejected(_ raw: String) {
        #expect(throws: SyncEndpoint.ValidationError.insecureScheme) {
            try SyncEndpoint.normalized(raw)
        }
    }

    @Test func httpsAndBareHostsAreUnchanged() throws {
        #expect(try SyncEndpoint.normalized("https://sync.example.com") == "https://sync.example.com")
        #expect(try SyncEndpoint.normalized("  sync.example.com\n") == "https://sync.example.com")
        #expect(try SyncEndpoint.normalized("192.168.1.5:8080") == "https://192.168.1.5:8080")
    }

    @Test func emptyAndMalformedInputThrow() {
        #expect(throws: SyncEndpoint.ValidationError.empty) { try SyncEndpoint.normalized("  ") }
        #expect(throws: SyncEndpoint.ValidationError.malformed) { try SyncEndpoint.normalized("http://") }
        #expect(throws: SyncEndpoint.ValidationError.malformed) {
            try SyncEndpoint.normalized(#"http://evil.com\@10.0.0.1"#)
        }
    }
}
