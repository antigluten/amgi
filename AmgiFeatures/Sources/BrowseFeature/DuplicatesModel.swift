//
//  DuplicatesModel.swift
//  BrowseFeature
//
//  Created by Vladimir Gusev on 13.09.2026.
//

import AnkiClients
import AnkiKit
import Dependencies
import Foundation

@Observable
@MainActor
final class DuplicatesModel {
    enum State {
        case loading
        case loaded([DuplicateGroup])
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var notesByGroup: [DuplicateGroup.ID: [NoteRecord]] = [:]

    @ObservationIgnored @Dependency(\.noteClient) private var noteClient
    @ObservationIgnored private var generation = 0

    func load() async {
        let loaded = Set(notesByGroup.keys)
        state = .loading
        notesByGroup = [:]
        generation += 1
        let currentGeneration = generation
        do {
            let groups = try await noteClient.findDuplicates()
            guard currentGeneration == generation else { return }
            state = .loaded(groups)
            for group in groups where loaded.contains(group.id) {
                guard currentGeneration == generation else { return }
                await loadNotes(for: group)
            }
        } catch {
            guard currentGeneration == generation else { return }
            state = .failed(error.localizedDescription)
        }
    }

    func loadNotes(for group: DuplicateGroup) async {
        guard notesByGroup[group.id] == nil else { return }
        let capturedGeneration = generation
        var records: [NoteRecord] = []
        records.reserveCapacity(group.noteIDs.count)
        for id in group.noteIDs {
            if let note = try? await noteClient.fetch(id) {
                records.append(note)
            }
        }
        guard capturedGeneration == generation else { return }
        notesByGroup[group.id] = records
    }

    func delete(_ note: NoteRecord, from group: DuplicateGroup) async {
        do {
            try await noteClient.delete(note.id)
        } catch {
            state = .failed(error.localizedDescription)
            return
        }

        notesByGroup[group.id]?.removeAll { $0.id == note.id }

        guard case .loaded(let groups) = state else { return }
        let remaining = group.noteIDs.filter { $0 != note.id }
        state = .loaded(
            groups.compactMap { existing in
                guard existing.id == group.id else { return existing }
                guard remaining.count > 1 else { return nil }
                return DuplicateGroup(
                    notetypeID: existing.notetypeID,
                    value: existing.value,
                    noteIDs: remaining
                )
            }
        )
        if remaining.count <= 1 { notesByGroup[group.id] = nil }
    }
}
