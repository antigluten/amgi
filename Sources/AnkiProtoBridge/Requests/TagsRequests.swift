import Foundation
public import AnkiBackend
public import AnkiKit
import AnkiProto
import SwiftProtobuf

// MARK: - tagTree (flattened to [String])

extension Request where Response == [String] {
    /// Returns every tag in the collection as flattened `::`-joined
    /// path strings (depth-first traversal of the tag tree). The
    /// synthetic root is skipped.
    public static var allTagPaths: Self {
        .empty(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.tagTree,
            decode: { bytes in
                let root = try Anki_Tags_TagTreeNode(serializedBytes: bytes)
                var paths: [String] = []
                for child in root.children {
                    flattenTagTree(child, parentPath: "", into: &paths)
                }
                return paths
            }
        )
    }
}

private func flattenTagTree(_ node: Anki_Tags_TagTreeNode, parentPath: String, into paths: inout [String]) {
    let full = parentPath.isEmpty ? node.name : "\(parentPath)::\(node.name)"
    paths.append(full)
    for child in node.children {
        flattenTagTree(child, parentPath: full, into: &paths)
    }
}

// MARK: - tag CRUD (Void)

extension Request where Response == Void {
    /// Creates or updates a tag's collapsed state. Used as a side-effect
    /// to "create" a tag — the backend persists it during this call.
    public static func setTagCollapsed(tag: String, collapsed: Bool) -> Self {
        Self(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.setTagCollapsed,
            encode: {
                var proto = Anki_Tags_SetTagCollapsedRequest()
                proto.name = tag
                proto.collapsed = collapsed
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Applies `tags` (space-separated) to the given notes.
    public static func addNoteTags(noteIds: [NoteID], tags: String) -> Self {
        Self(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.addNoteTags,
            encode: {
                var proto = Anki_Tags_NoteIdsAndTagsRequest()
                proto.noteIds = noteIds.map(\.rawValue)
                proto.tags = tags
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Removes `tags` (space-separated) from the given notes.
    public static func removeNoteTags(noteIds: [NoteID], tags: String) -> Self {
        Self(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.removeNoteTags,
            encode: {
                var proto = Anki_Tags_NoteIdsAndTagsRequest()
                proto.noteIds = noteIds.map(\.rawValue)
                proto.tags = tags
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Removes the named tag from the collection entirely (across all notes).
    public static func removeTags(name: String) -> Self {
        Self(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.removeTags,
            encode: {
                var proto = Anki_Generic_String()
                proto.val = name
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }

    /// Renames a tag prefix everywhere. `oldPrefix` matches a tag tree
    /// branch; every descendant gets reparented under `newPrefix`.
    public static func renameTags(oldPrefix: String, newPrefix: String) -> Self {
        Self(
            serviceId: ServiceID.tags,
            methodId: TagsMethod.renameTags,
            encode: {
                var proto = Anki_Tags_RenameTagsRequest()
                proto.currentPrefix = oldPrefix
                proto.newPrefix = newPrefix
                return try proto.serializedData()
            },
            decode: { _ in () }
        )
    }
}
