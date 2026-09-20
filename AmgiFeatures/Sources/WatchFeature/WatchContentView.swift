//
//  WatchContentView.swift
//  WatchFeature
//
//  Created by Leaf Eriksen on 17.07.2026.
//

import AnkiKit
public import SwiftUI

public struct WatchContentView: View {
    public init() {}

    public var body: some View {
        NavigationStack {
            WatchDeckListView()
                .navigationDestination(for: DeckInfo.self) { deck in
                    WatchDeckDetailView(deck: deck)
                }
        }
    }
}
