//
//  StatsClient+Live.swift
//  AnkiClients
//
//  Created by Vladimir Gusev on 27.03.2026.
//

import AnkiBackend
import AnkiProtoBridge
public import Dependencies

extension StatsClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            fetchGraphs: { search, days in
                try await backendOffload { try backend.invoke(.graphs(search: search, days: days)) }
            }
        )
    }()
}
