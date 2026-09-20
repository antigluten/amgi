//
//  SharedKeys.swift
//  AppCore
//
//  Created by Vladimir Gusev on 31.03.2026.
//

public import Sharing

public enum SyncMode: String, Sendable, RawRepresentable {
    case local
    case custom
}

extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {
    public static var onboardingCompleted: Self {
        Self[.appStorage("onboardingCompleted"), default: false]
    }
}

extension SharedReaderKey where Self == AppStorageKey<SyncMode>.Default {
    public static var syncMode: Self {
        Self[.appStorage("syncMode"), default: .local]
    }
}
