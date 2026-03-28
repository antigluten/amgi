public import Dependencies

private enum AnkiBackendKey: DependencyKey {
    static let liveValue: AnkiBackend = {
        try! AnkiBackend(preferredLangs: ["en"])
    }()

    static let testValue: AnkiBackend = {
        try! AnkiBackend(preferredLangs: ["en"])
    }()
}

extension DependencyValues {
    public var ankiBackend: AnkiBackend {
        get { self[AnkiBackendKey.self] }
        set { self[AnkiBackendKey.self] = newValue }
    }
}
