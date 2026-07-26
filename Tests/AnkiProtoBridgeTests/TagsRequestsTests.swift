import Testing
import AnkiKit
@testable import AnkiProtoBridge
@testable import AnkiBackend
import AnkiProto
private import SwiftProtobuf

@Suite struct TagsRequestsTests {
    // MARK: - allTagPaths

    @Test func allTagPaths_dispatches_with_empty_body() throws {
        let envelope: Request<[String]> = .allTagPaths
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.tagTree)
        #expect(try envelope.body.isEmpty)
    }

    @Test func allTagPaths_flattens_tree_depth_first_with_double_colon_paths() throws {
        var grandchild = Anki_Tags_TagTreeNode()
        grandchild.name = "leaf"
        var child = Anki_Tags_TagTreeNode()
        child.name = "verbs"
        child.children = [grandchild]
        var sibling = Anki_Tags_TagTreeNode()
        sibling.name = "nouns"
        var top = Anki_Tags_TagTreeNode()
        top.name = "korean"
        top.children = [child, sibling]

        var root = Anki_Tags_TagTreeNode()
        root.children = [top]
        let bytes = try root.serializedData()

        let envelope: Request<[String]> = .allTagPaths
        let paths = try envelope.decode(bytes)
        #expect(paths == ["korean", "korean::verbs", "korean::verbs::leaf", "korean::nouns"])
    }

    @Test func allTagPaths_skips_synthetic_root() throws {
        let root = Anki_Tags_TagTreeNode()
        let bytes = try root.serializedData()
        let envelope: Request<[String]> = .allTagPaths
        #expect(try envelope.decode(bytes) == [])
    }

    // MARK: - setTagCollapsed

    @Test func setTagCollapsed_dispatches_and_encodes_fields() throws {
        let envelope: Request<Void> = .setTagCollapsed(tag: "korean", collapsed: false)
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.setTagCollapsed)
        let proto = try Anki_Tags_SetTagCollapsedRequest(serializedBytes: envelope.body)
        #expect(proto.name == "korean")
        #expect(!proto.collapsed)
    }

    // MARK: - addNoteTags / removeNoteTags

    @Test func addNoteTags_dispatches_and_encodes_inputs() throws {
        let envelope: Request<Void> = .addNoteTags(noteIds: [NoteID(1), NoteID(2)], tags: "vocab")
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.addNoteTags)
        let proto = try Anki_Tags_NoteIdsAndTagsRequest(serializedBytes: envelope.body)
        #expect(proto.noteIds == [1, 2])
        #expect(proto.tags == "vocab")
    }

    @Test func removeNoteTags_dispatches_to_removeNoteTags_method() throws {
        let envelope: Request<Void> = .removeNoteTags(noteIds: [NoteID(7)], tags: "drop")
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.removeNoteTags)
        let proto = try Anki_Tags_NoteIdsAndTagsRequest(serializedBytes: envelope.body)
        #expect(proto.noteIds == [7])
        #expect(proto.tags == "drop")
    }

    // MARK: - removeTags / renameTags

    @Test func removeTags_dispatches_and_encodes_name() throws {
        let envelope: Request<Void> = .removeTags(name: "obsolete")
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.removeTags)
        let proto = try Anki_Generic_String(serializedBytes: envelope.body)
        #expect(proto.val == "obsolete")
    }

    @Test func renameTags_dispatches_and_encodes_prefixes() throws {
        let envelope: Request<Void> = .renameTags(oldPrefix: "korean", newPrefix: "ko")
        #expect(envelope.serviceId == ServiceID.tags)
        #expect(envelope.methodId == TagsMethod.renameTags)
        let proto = try Anki_Tags_RenameTagsRequest(serializedBytes: envelope.body)
        #expect(proto.currentPrefix == "korean")
        #expect(proto.newPrefix == "ko")
    }
}
