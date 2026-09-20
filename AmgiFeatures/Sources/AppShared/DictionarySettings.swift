//
//  DictionarySettings.swift
//  AppShared
//
//  Created by Vladimir Gusev on 08.09.2026.
//

public import SwiftUI

@MainActor
public protocol DictionarySettingsProviding {
    func settings() -> AnyView
}

public extension EnvironmentValues {
    @Entry var dictionarySettings: (any DictionarySettingsProviding)? = nil
}
