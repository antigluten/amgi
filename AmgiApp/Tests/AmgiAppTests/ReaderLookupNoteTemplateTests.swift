import AmgiReader
import AnkiClients
import Testing

@Suite("ReaderLookupNoteTemplate")
struct ReaderLookupNoteTemplateTests {

    @Test("definitionsByDictionary preserves order and merges duplicates")
    func definitionsByDictionaryPreservesOrder() {
        let glossaries = [
            DictionaryLookupGlossary(dictionary: "DictA", definitions: ["A1", "A2"]),
            DictionaryLookupGlossary(dictionary: "DictB", definitions: ["B1"]),
            DictionaryLookupGlossary(dictionary: "DictA", definitions: ["A3"]),
        ]
        #expect(
            ReaderLookupNotePayload.definitionsByDictionary(from: glossaries)
                == ["A1\nA2\nA3", "B1"]
        )
    }

    @Test("makeDraft maps def1/def2/def3 from per-dictionary groups")
    func makeDraftAssignsDefinitionsToMappedFields() {
        let payload = ReaderLookupNotePayload(
            term: "単語",
            reading: "たんご",
            sentence: "Example sentence",
            definitions: ["dict1-def1\ndict1-def2", "dict2-def1", "dict3-def1"]
        )
        let template = ReaderLookupNoteTemplate(
            definition1Field: "Def1",
            definition2Field: "Def2",
            definition3Field: "Def3"
        )

        let draft = template.makeDraft(
            payload: payload,
            fallbackDeckID: nil,
            sourceDescription: "Source"
        )

        #expect(draft.fieldValues["Def1"] == "dict1-def1\ndict1-def2")
        #expect(draft.fieldValues["Def2"] == "dict2-def1")
        #expect(draft.fieldValues["Def3"] == "dict3-def1")
    }

    @Test("Empty template falls back to common Basic-notetype names")
    func emptyTemplateFallsBackToBasicNames() {
        let payload = ReaderLookupNotePayload(term: "term", sentence: "sentence")
        let template = ReaderLookupNoteTemplate.empty

        let draft = template.makeDraft(
            payload: payload,
            fallbackDeckID: 42,
            sourceDescription: "src"
        )

        #expect(draft.fieldValues["Front"] == "term")
        #expect(draft.fieldValues["Sentence"] == "sentence")
        #expect(draft.deckID == 42)
    }

    @Test("clearInvalidFields drops orphan field names after notetype change")
    func clearInvalidFieldsDropsOrphans() {
        var template = ReaderLookupNoteTemplate(
            termField: "Front",
            readingField: "Reading",
            sentenceField: "GoneField"
        )
        template.clearInvalidFields(validFields: ["Front", "Reading", "Back"])

        #expect(template.termField == "Front")
        #expect(template.readingField == "Reading")
        #expect(template.sentenceField == "")
    }

    @Test("encode/decode round-trips field mappings")
    func encodeDecodeRoundTrip() {
        let original = ReaderLookupNoteTemplate(
            deckID: 1,
            notetypeID: 2,
            termField: "Front",
            definition1Field: "Back"
        )
        let restored = ReaderLookupNoteTemplate.decode(from: original.encodedString())
        #expect(restored == original)
    }
}
