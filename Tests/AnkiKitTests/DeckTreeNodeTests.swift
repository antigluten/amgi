import Testing
@testable import AnkiKit

@Suite struct DeckTreeNodeTests {
    private func makeNode(
        id: Int64,
        name: String,
        fullName: String? = nil,
        counts: DeckCounts = .zero,
        children: [DeckTreeNode] = []
    ) -> DeckTreeNode {
        DeckTreeNode(
            id: DeckID(id),
            name: name,
            fullName: fullName ?? name,
            counts: counts,
            children: children
        )
    }

    // MARK: - flattened

    @Test func flattened_skips_receiver_and_walks_descendants() {
        let leaf = makeNode(id: 200, name: "Vocab", fullName: "Korean::Vocab")
        let parent = makeNode(id: 100, name: "Korean", children: [leaf])

        let flat = parent.flattened()

        #expect(flat.count == 1)
        #expect(flat[0].id == DeckID(200))
        #expect(flat[0].name == "Korean::Vocab")
    }

    @Test func array_flattened_includes_all_top_level_nodes() {
        let a = makeNode(id: 1, name: "A", counts: DeckCounts(newCount: 1, learnCount: 0, reviewCount: 0))
        let b = makeNode(id: 2, name: "B", counts: DeckCounts(newCount: 0, learnCount: 2, reviewCount: 0))

        let flat: [DeckInfo] = [a, b].flattened()

        #expect(flat.map(\.id) == [DeckID(1), DeckID(2)])
        #expect(flat[0].counts.newCount == 1)
        #expect(flat[1].counts.learnCount == 2)
    }

    @Test func array_flattened_walks_nested_children() {
        let leaf = makeNode(id: 30, name: "Leaf", fullName: "Top::Leaf")
        let mid = makeNode(id: 20, name: "Mid", fullName: "Top::Mid", children: [leaf])
        let top = makeNode(id: 10, name: "Top", children: [mid])

        let flat: [DeckInfo] = [top].flattened()

        #expect(flat.map(\.name) == ["Top", "Top::Mid", "Top::Leaf"])
    }

    // MARK: - sortedByName

    @Test func array_sortedByName_returns_DeckInfo_sorted() {
        let beta = makeNode(id: 1, name: "Beta")
        let alpha = makeNode(id: 2, name: "Alpha")

        let sorted = [beta, alpha].sortedByName

        #expect(sorted.map(\.name) == ["Alpha", "Beta"])
    }

    @Test func deckInfo_sortedByName_sorts_by_name() {
        let infos: [DeckInfo] = [
            DeckInfo(id: DeckID(1), name: "Zeta"),
            DeckInfo(id: DeckID(2), name: "Alpha"),
        ]

        #expect(infos.sortedByName.map(\.name) == ["Alpha", "Zeta"])
    }

    // MARK: - find

    @Test func find_returns_matching_descendant() {
        let leaf = makeNode(id: 200, name: "Vocab", fullName: "Korean::Vocab")
        let parent = makeNode(id: 100, name: "Korean", children: [leaf])

        let hit = parent.find(DeckID(200))

        #expect(hit?.id == DeckID(200))
    }

    @Test func find_returns_nil_when_absent() {
        let parent = makeNode(id: 100, name: "Korean")
        #expect(parent.find(DeckID(999)) == nil)
    }

    @Test func array_find_searches_across_top_level_nodes() {
        let a = makeNode(id: 1, name: "A")
        let b = makeNode(id: 2, name: "B")
        #expect([a, b].find(DeckID(2))?.id == DeckID(2))
        #expect([a, b].find(DeckID(3)) == nil)
    }
}
