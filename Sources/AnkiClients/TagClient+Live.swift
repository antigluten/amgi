import AnkiBackend
import AnkiKit
import AnkiProtoBridge
import Foundation
public import Dependencies
import DependenciesMacros
import Logging

private let logger = Logger(label: "com.amgiapp.tag.client")

extension TagClient: DependencyKey {
    public static let liveValue: Self = {
        @Dependency(\.ankiBackend) var backend

        return Self(
            getAllTags: {
                do {
                    let tags = try await backend.invoke(.allTagPaths)
                    logger.info("Retrieved \(tags.count) tags")
                    return tags
                } catch {
                    logger.error("getAllTags failed: \(error)")
                    throw error
                }
            },
            addTag: { tag in
                let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "Tag name cannot be empty")
                }
                do {
                    try await backend.invoke(.setTagCollapsed(tag: normalized, collapsed: false))
                    logger.info("Tag '\(normalized)' created via SetTagCollapsed")
                } catch {
                    logger.error("addTag failed for '\(normalized)': \(error)")
                    throw error
                }
            },
            addTagToNotes: { tag, noteIDs in
                let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "Tag name cannot be empty")
                }
                guard !noteIDs.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "No notes selected")
                }
                do {
                    try await backend.invoke(.addNoteTags(noteIds: noteIDs, tags: normalized))
                    logger.info("Applied tag '\(normalized)' to \(noteIDs.count) notes")
                } catch {
                    logger.error("addTagToNotes failed for tag='\(normalized)': \(error)")
                    throw error
                }
            },
            removeTagFromNotes: { tag, noteIDs in
                let normalized = tag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalized.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "Tag name cannot be empty")
                }
                guard !noteIDs.isEmpty else {
                    throw BackendError(kind: .invalidInput, message: "No notes selected")
                }
                do {
                    try await backend.invoke(.removeNoteTags(noteIds: noteIDs, tags: normalized))
                    logger.info("Removed tag '\(normalized)' from \(noteIDs.count) notes")
                } catch {
                    logger.error("removeTagFromNotes failed for tag='\(normalized)': \(error)")
                    throw error
                }
            },
            removeTag: { tag in
                do {
                    try await backend.invoke(.removeTags(name: tag))
                    logger.info("Tag '\(tag)' removed")
                } catch {
                    logger.error("removeTag failed for '\(tag)': \(error)")
                    throw error
                }
            },
            renameTag: { oldName, newName in
                do {
                    try await backend.invoke(.renameTags(oldPrefix: oldName, newPrefix: newName))
                    logger.info("Tag renamed: '\(oldName)' → '\(newName)'")
                } catch {
                    logger.error("renameTag failed: \(error)")
                    throw error
                }
            },
            findNotesByTag: { tag in
                do {
                    let ids = try await backend.invoke(.searchNoteIds(query: "tag:\(tag)"))
                    logger.info("Found \(ids.count) notes with tag '\(tag)'")
                    return ids
                } catch {
                    logger.error("findNotesByTag failed for '\(tag)': \(error)")
                    throw error
                }
            }
        )
    }()
}
