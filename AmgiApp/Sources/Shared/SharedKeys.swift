import Sharing

enum SyncMode: String, Sendable, RawRepresentable {
    case local
    case custom
}

extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    static var onboardingCompleted: Self {
        Self[.appStorage("onboardingCompleted"), default: false]
    }
}

extension SharedReaderKey where Self == AppStorageKey<SyncMode>.Default {
    static var syncMode: Self {
        Self[.appStorage("syncMode"), default: .local]
    }
}
