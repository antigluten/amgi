import AmgiReader
import CHoshiDicts
import Dependencies
import Foundation

/// Live engine binding. Internal so the `import CHoshiDicts` doesn't bleed
/// Cxx-mode requirements into consumers' swiftinterface — only the
/// public `+Live.swift` wires this up via `liveValue`.
///
/// All methods are async and run on the actor's serial executor, which
/// also gives us a single-writer guarantee for the underlying
/// `DictionaryQuery` / `Deinflector` / `Lookup` triple (those C++ types
/// aren't thread-safe and must be torn down + rebuilt atomically when
/// the enabled-dictionary set changes).
actor DictionaryLookupRuntime {
    private struct ManagedDictionary {
        var info: AppDictionaryInfo
        var path: URL
    }

    private struct RecommendedArchive {
        var metadataURL: String
        var kind: AppDictionaryKind
    }

    private struct SyncedConfig: Codable {
        var updatedAt: Date
        var config: AppDictionaryConfig
    }

    private struct TimestampedConfig {
        var config: AppDictionaryConfig
        var updatedAt: Date
    }

    enum RuntimeError: LocalizedError {
        case importFailed([String])
        case dictionaryNotFound(String)
        case noUpdatableDictionaries

        var errorDescription: String? {
            switch self {
            case let .importFailed(files):
                return files.isEmpty
                    ? "Failed to import dictionary archive."
                    : "Failed to import: \(files.joined(separator: ", "))."
            case let .dictionaryNotFound(id):
                return "Dictionary not found: \(id)"
            case .noUpdatableDictionaries:
                return "No updatable dictionaries found."
            }
        }
    }

    private static let collectionConfigKey = "amgi.reader.dictionaryConfig"
    private static let recommendedArchives: [RecommendedArchive] = [
        RecommendedArchive(
            metadataURL: "https://github.com/yomidevs/jmdict-yomitan/releases/latest/download/JMdict_english.json",
            kind: .term
        ),
        RecommendedArchive(
            metadataURL: "https://api.jiten.moe/api/frequency-list/index",
            kind: .frequency
        ),
    ]

    private let configStore: DictionaryConfigStore
    private var activeProfileID: String?
    private var termDictionaries: [ManagedDictionary] = []
    private var frequencyDictionaries: [ManagedDictionary] = []
    private var pitchDictionaries: [ManagedDictionary] = []
    private var dictQuery: DictionaryQuery?
    private var deinflector: Deinflector?
    private var lookupEngine: Lookup?

    init(configStore: DictionaryConfigStore) {
        self.configStore = configStore
    }

    // MARK: - Public surface

    func lookup(_ text: String, maxResults: Int, scanLength: Int) async throws -> DictionaryLookupResult {
        try await ensureLoaded()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return DictionaryLookupResult(query: text, entries: [], isPlaceholder: false)
        }

        guard termDictionaries.contains(where: \.info.isEnabled) else {
            return DictionaryLookupResult(query: trimmed, entries: [], isPlaceholder: true)
        }

        let resolvedMaxResults = max(1, maxResults)
        let resolvedScanLength = max(1, scanLength)
        var rawResults = performLookup(trimmed, maxResults: resolvedMaxResults, scanLength: resolvedScanLength)

        // Try the lowercased form for ASCII queries; pick whichever yields
        // the higher-quality match. Mirrors DreamAfar's behavior so JMdict
        // entries surface for queries the user typed in mixed case.
        let lowercaseQuery = trimmed.lowercased()
        if lowercaseQuery != trimmed, Self.containsASCIIUppercase(trimmed) {
            let lowercaseResults = performLookup(lowercaseQuery, maxResults: resolvedMaxResults, scanLength: resolvedScanLength)
            if Self.lookupQualityScore(lowercaseResults, query: lowercaseQuery)
                > Self.lookupQualityScore(rawResults, query: trimmed) {
                rawResults = lowercaseResults
            }
        }

        return DictionaryLookupResult(
            query: trimmed,
            entries: rawResults.map(Self.makeEntry),
            isPlaceholder: false,
            dictionaryStyles: loadStylesSync()
        )
    }

    func loadStyles() async -> [String: String] {
        loadStylesSync()
    }

    func mediaFile(dictionary: String, mediaPath: String) async throws -> Data {
        try await ensureLoaded()
        let bytes = dictQuery?.get_media_file(std.string(dictionary), std.string(mediaPath)) ?? []
        return Data(bytes.map { UInt8(bitPattern: $0) })
    }

    func loadState() async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()
        return libraryState()
    }

    func importArchives(_ urls: [URL], kind: AppDictionaryKind) async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        var failed: [String] = []
        var didImport = false
        for url in urls {
            do {
                _ = try importArchive(at: url, kind: kind, requiresSecurityScope: true)
                didImport = true
            } catch {
                failed.append(url.lastPathComponent)
            }
        }

        guard didImport else { throw RuntimeError.importFailed(failed) }

        try await reloadState(for: currentProfileID())
        return libraryState()
    }

    func importRecommended() async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        var temporaries: [URL] = []
        defer {
            for file in temporaries { try? FileManager.default.removeItem(at: file) }
        }

        for archive in Self.recommendedArchives {
            guard let metadataURL = URL(string: archive.metadataURL) else { continue }
            let (data, _) = try await URLSession.shared.data(from: metadataURL)
            let remoteIndex = try JSONDecoder().decode(AppDictionaryIndex.self, from: data)
            guard let downloadURL = URL(string: remoteIndex.downloadURL) else { continue }
            let (file, _) = try await URLSession.shared.download(from: downloadURL)
            temporaries.append(file)
            _ = try importArchive(at: file, kind: archive.kind, requiresSecurityScope: false)
        }

        try await reloadState(for: currentProfileID())
        return libraryState()
    }

    func updateDictionaries() async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        let candidates = allDictionariesForUpdate()
        guard !candidates.isEmpty else { throw RuntimeError.noUpdatableDictionaries }

        var temporaries: [URL] = []
        defer {
            for file in temporaries { try? FileManager.default.removeItem(at: file) }
        }

        for candidate in candidates {
            let index = candidate.dictionary.info.index
            guard index.isUpdatable, let metadataURL = URL(string: index.indexURL) else { continue }

            let (data, _) = try await URLSession.shared.data(from: metadataURL)
            let remoteIndex = try JSONDecoder().decode(AppDictionaryIndex.self, from: data)
            guard remoteIndex.revision != index.revision,
                  let downloadURL = URL(string: remoteIndex.downloadURL) else { continue }

            let oldPath = candidate.dictionary.path
            let oldTitle = index.title
            let (file, _) = try await URLSession.shared.download(from: downloadURL)
            temporaries.append(file)
            let importedTitle = try importArchive(at: file, kind: candidate.kind, requiresSecurityScope: false)
            if importedTitle != oldTitle {
                try? FileManager.default.removeItem(at: oldPath)
            }
        }

        try await reloadState(for: currentProfileID())
        return libraryState()
    }

    func setEnabled(kind: AppDictionaryKind, dictionaryID: String, enabled: Bool) async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        switch kind {
        case .term:
            guard let i = termDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            termDictionaries[i].info.isEnabled = enabled
        case .frequency:
            guard let i = frequencyDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            frequencyDictionaries[i].info.isEnabled = enabled
        case .pitch:
            guard let i = pitchDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            pitchDictionaries[i].info.isEnabled = enabled
        }

        try await persistAndRebuild()
        return libraryState()
    }

    func reorder(kind: AppDictionaryKind, dictionaryIDs: [String]) async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        switch kind {
        case .term: termDictionaries = applyOrder(dictionaryIDs, to: termDictionaries)
        case .frequency: frequencyDictionaries = applyOrder(dictionaryIDs, to: frequencyDictionaries)
        case .pitch: pitchDictionaries = applyOrder(dictionaryIDs, to: pitchDictionaries)
        }

        try await persistAndRebuild()
        return libraryState()
    }

    private func applyOrder(_ ids: [String], to dictionaries: [ManagedDictionary]) -> [ManagedDictionary] {
        var byID: [String: ManagedDictionary] = [:]
        for d in dictionaries { byID[d.info.id] = d }
        var result: [ManagedDictionary] = []
        for id in ids {
            if let d = byID.removeValue(forKey: id) { result.append(d) }
        }
        // Anything the caller didn't reference keeps its prior order at
        // the tail — defensive against UI/state drift between client and
        // runtime.
        for d in dictionaries where byID[d.info.id] != nil {
            result.append(d)
            byID.removeValue(forKey: d.info.id)
        }
        return normalized(result)
    }

    func delete(kind: AppDictionaryKind, dictionaryID: String) async throws -> AppDictionaryLibraryState {
        try await ensureLoaded()

        switch kind {
        case .term:
            guard let i = termDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            try? FileManager.default.removeItem(at: termDictionaries[i].path)
            termDictionaries.remove(at: i)
            termDictionaries = normalized(termDictionaries)
        case .frequency:
            guard let i = frequencyDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            try? FileManager.default.removeItem(at: frequencyDictionaries[i].path)
            frequencyDictionaries.remove(at: i)
            frequencyDictionaries = normalized(frequencyDictionaries)
        case .pitch:
            guard let i = pitchDictionaries.firstIndex(where: { $0.info.id == dictionaryID })
            else { throw RuntimeError.dictionaryNotFound(dictionaryID) }
            try? FileManager.default.removeItem(at: pitchDictionaries[i].path)
            pitchDictionaries.remove(at: i)
            pitchDictionaries = normalized(pitchDictionaries)
        }

        try await persistAndRebuild()
        return libraryState()
    }

    // MARK: - Engine

    private func performLookup(_ query: String, maxResults: Int, scanLength: Int) -> [LookupResult] {
        Array(lookupEngine?.lookup(std.string(query), Int32(maxResults), scanLength) ?? [])
    }

    private func loadStylesSync() -> [String: String] {
        Array(dictQuery?.get_styles() ?? [])
            .reduce(into: [:]) { acc, style in
                acc[String(style.dict_name)] = String(style.styles)
            }
    }

    private func rebuildLookupQuery() {
        // Tear down in reverse-construction order so the C++ refs in
        // `Lookup` drop before the things they point at.
        lookupEngine = nil
        deinflector = Deinflector()
        dictQuery = DictionaryQuery()

        for d in termDictionaries where d.info.isEnabled {
            dictQuery?.add_term_dict(std.string(d.path.path(percentEncoded: false)))
        }
        for d in frequencyDictionaries where d.info.isEnabled {
            dictQuery?.add_freq_dict(std.string(d.path.path(percentEncoded: false)))
        }
        for d in pitchDictionaries where d.info.isEnabled {
            dictQuery?.add_pitch_dict(std.string(d.path.path(percentEncoded: false)))
        }

        lookupEngine = Lookup(&dictQuery!, &deinflector!)
    }

    @discardableResult
    private func importArchive(at url: URL, kind: AppDictionaryKind, requiresSecurityScope: Bool) throws -> String {
        let started = requiresSecurityScope ? url.startAccessingSecurityScopedResource() : false
        if requiresSecurityScope, !started {
            throw RuntimeError.importFailed([url.lastPathComponent])
        }
        defer { if started { url.stopAccessingSecurityScopedResource() } }

        let outputDirectory = try dictionaryDirectory(for: kind, profileID: currentProfileID())
        let result = dictionary_importer.import(
            std.string(url.path(percentEncoded: false)),
            std.string(outputDirectory.path(percentEncoded: false)),
            false
        )
        guard result.success else {
            throw RuntimeError.importFailed([url.lastPathComponent])
        }
        return String(result.title)
    }

    // MARK: - State

    private func ensureLoaded() async throws {
        let profileID = currentProfileID()
        if activeProfileID != profileID {
            try await reloadState(for: profileID)
        }
    }

    private func reloadState(for profileID: String) async throws {
        let storedTerm = try dictionariesFromStorage(kind: .term, profileID: profileID)
        let storedFrequency = try dictionariesFromStorage(kind: .frequency, profileID: profileID)
        let storedPitch = try dictionariesFromStorage(kind: .pitch, profileID: profileID)
        let config = try await loadConfig(profileID: profileID) ?? AppDictionaryConfig()

        termDictionaries = collect(stored: storedTerm, configured: config.termDictionaries)
        frequencyDictionaries = collect(stored: storedFrequency, configured: config.frequencyDictionaries)
        pitchDictionaries = collect(stored: storedPitch, configured: config.pitchDictionaries)

        activeProfileID = profileID
        try await persistAndRebuild()
    }

    private func persistAndRebuild() async throws {
        guard let profileID = activeProfileID else { return }
        try await saveConfig(profileID: profileID)
        rebuildLookupQuery()
    }

    private func libraryState() -> AppDictionaryLibraryState {
        AppDictionaryLibraryState(
            termDictionaries: termDictionaries.map(\.info),
            frequencyDictionaries: frequencyDictionaries.map(\.info),
            pitchDictionaries: pitchDictionaries.map(\.info)
        )
    }

    private func allDictionariesForUpdate() -> [(dictionary: ManagedDictionary, kind: AppDictionaryKind)] {
        termDictionaries.map { ($0, .term) }
            + frequencyDictionaries.map { ($0, .frequency) }
            + pitchDictionaries.map { ($0, .pitch) }
    }

    private func collect(
        stored: [ManagedDictionary],
        configured: [AppDictionaryConfig.Entry]
    ) -> [ManagedDictionary] {
        var result: [ManagedDictionary] = []
        for entry in configured.sorted(by: { $0.order < $1.order }) {
            guard let s = stored.first(where: { $0.info.fileName == entry.fileName }) else { continue }
            var d = s
            d.info.isEnabled = entry.isEnabled
            d.info.order = entry.order
            result.append(d)
        }
        let existing = Set(result.map(\.info.fileName))
        for s in stored where !existing.contains(s.info.fileName) {
            var d = s
            d.info.isEnabled = true
            d.info.order = result.count
            result.append(d)
        }
        return normalized(result)
    }

    private func normalized(_ dicts: [ManagedDictionary]) -> [ManagedDictionary] {
        dicts.enumerated().map { i, d in
            var d = d
            d.info.order = i
            return d
        }
    }

    private func dictionariesFromStorage(kind: AppDictionaryKind, profileID: String) throws -> [ManagedDictionary] {
        let directory = try dictionaryDirectory(for: kind, profileID: profileID)
        return try FileManager.default
            .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            .compactMap { url in
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
                guard values?.isDirectory == true else {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
                let indexURL = url.appendingPathComponent("index.json")
                guard let data = try? Data(contentsOf: indexURL),
                      let index = try? JSONDecoder().decode(AppDictionaryIndex.self, from: data) else {
                    try? FileManager.default.removeItem(at: url)
                    return nil
                }
                return ManagedDictionary(
                    info: AppDictionaryInfo(fileName: url.lastPathComponent, index: index),
                    path: url
                )
            }
            .sorted { $0.info.title.localizedCaseInsensitiveCompare($1.info.title) == .orderedAscending }
    }

    // MARK: - Config persistence (via injected DictionaryConfigStore)

    private func loadConfig(profileID: String) async throws -> AppDictionaryConfig? {
        let local = try loadLocalConfig(profileID: profileID)
        let remote = try await loadRemoteConfig()

        // Last-writer-wins between local file and the synced collection
        // config. Whichever is newer becomes authoritative; the other side
        // gets backfilled so they stay in step.
        let resolved: TimestampedConfig?
        switch (local, remote) {
        case let (l?, r?):
            resolved = l.updatedAt >= r.updatedAt ? l : r
        case let (l?, nil):
            resolved = l
        case let (nil, r?):
            resolved = r
        case (nil, nil):
            resolved = nil
        }

        guard let resolved else { return nil }

        if local?.config != resolved.config || local?.updatedAt != resolved.updatedAt {
            try writeLocalConfig(resolved.config, updatedAt: resolved.updatedAt, profileID: profileID)
        }
        if remote?.config != resolved.config || remote?.updatedAt != resolved.updatedAt {
            try await writeRemoteConfig(resolved.config, updatedAt: resolved.updatedAt)
        }
        return resolved.config
    }

    private func saveConfig(profileID: String) async throws {
        let config = AppDictionaryConfig(
            termDictionaries: termDictionaries.map(Self.entry),
            frequencyDictionaries: frequencyDictionaries.map(Self.entry),
            pitchDictionaries: pitchDictionaries.map(Self.entry)
        )
        let updatedAt = Date()
        try writeLocalConfig(config, updatedAt: updatedAt, profileID: profileID)
        try await writeRemoteConfig(config, updatedAt: updatedAt)
    }

    private static func entry(_ d: ManagedDictionary) -> AppDictionaryConfig.Entry {
        AppDictionaryConfig.Entry(
            fileName: d.info.fileName,
            isEnabled: d.info.isEnabled,
            order: d.info.order
        )
    }

    private func loadLocalConfig(profileID: String) throws -> TimestampedConfig? {
        let url = try configURL(profileID: profileID)
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return nil }
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(AppDictionaryConfig.self, from: data)
        let updatedAt = try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast
        return TimestampedConfig(config: config, updatedAt: updatedAt)
    }

    private func loadRemoteConfig() async throws -> TimestampedConfig? {
        guard let data = try await configStore.load(Self.collectionConfigKey) else { return nil }
        let synced = try JSONDecoder().decode(SyncedConfig.self, from: data)
        return TimestampedConfig(config: synced.config, updatedAt: synced.updatedAt)
    }

    private func writeLocalConfig(
        _ config: AppDictionaryConfig,
        updatedAt: Date,
        profileID: String
    ) throws {
        let url = try configURL(profileID: profileID)
        let data = try JSONEncoder().encode(config)
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.modificationDate: updatedAt],
            ofItemAtPath: url.path(percentEncoded: false)
        )
    }

    private func writeRemoteConfig(_ config: AppDictionaryConfig, updatedAt: Date) async throws {
        let synced = SyncedConfig(updatedAt: updatedAt, config: config)
        let data = try JSONEncoder().encode(synced)
        try await configStore.save(data, Self.collectionConfigKey)
    }

    // MARK: - Filesystem layout

    private func configURL(profileID: String) throws -> URL {
        try rootDirectory(profileID: profileID).appendingPathComponent("config.json")
    }

    private func dictionaryDirectory(for kind: AppDictionaryKind, profileID: String) throws -> URL {
        let directory = try rootDirectory(profileID: profileID).appendingPathComponent(kind.storageDirectoryName)
        if !FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func rootDirectory(profileID: String) throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base
            .appendingPathComponent("ReaderDictionaries", isDirectory: true)
            .appendingPathComponent(profileID, isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func currentProfileID() -> String {
        let raw = UserDefaults.standard.string(forKey: "amgi.selectedUser") ?? "default"
        return Self.sanitizedUserFolderName(raw)
    }

    private static func sanitizedUserFolderName(_ user: String) -> String {
        let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "default" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let mapped = trimmed.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let folder = String(mapped).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return folder.isEmpty ? "default" : folder
    }

    // MARK: - Lookup helpers

    private static func containsASCIIUppercase(_ text: String) -> Bool {
        text.unicodeScalars.contains { (65...90).contains(Int($0.value)) }
    }

    private static func lookupQualityScore(_ results: [LookupResult], query: String) -> Int {
        let normalized = query.lowercased()
        var best = 0
        for r in results {
            let matched = String(r.matched).lowercased()
            let term = String(r.term.expression).lowercased()
            if matched == normalized || term == normalized { return 4 }
            if matched.count > 1, normalized.hasPrefix(matched) {
                best = max(best, 3)
            } else if term.count > 1, normalized.hasPrefix(term) {
                best = max(best, 2)
            } else if !matched.isEmpty || !term.isEmpty {
                best = max(best, 1)
            }
        }
        return best
    }

    // MARK: - Cxx -> Swift mapping

    private static func makeEntry(from result: LookupResult) -> DictionaryLookupEntry {
        let glossariesArray = Array(result.term.glossaries)

        let glossaries = glossariesArray.flatMap { g in
            glossaryLines(dictName: String(g.dict_name), rawGlossary: String(g.glossary))
        }

        let structuredGlossaries = glossariesArray.map { g in
            DictionaryLookupGlossary(
                dictionary: String(g.dict_name),
                content: String(g.glossary),
                definitions: flattenGlossary(String(g.glossary)),
                definitionTags: String(g.definition_tags).nilIfEmpty,
                termTags: String(g.term_tags).nilIfEmpty
            )
        }

        let frequenciesArray = Array(result.term.frequencies)

        let structuredFrequencies = frequenciesArray.map { entry in
            DictionaryLookupFrequency(
                dictionary: String(entry.dict_name),
                frequencies: Array(entry.frequencies).map { f in
                    DictionaryLookupFrequencyValue(
                        value: Int(f.value),
                        displayValue: String(f.display_value).nilIfEmpty
                    )
                }
            )
        }

        let pitchesArray = Array(result.term.pitches)
        let structuredPitches = pitchesArray.map { entry in
            let positions = Array(entry.pitch_positions)
                .map(Int.init)
                .reduce(into: [Int]()) { out, p in
                    if !out.contains(p) { out.append(p) }
                }
            return DictionaryLookupPitch(
                dictionary: String(entry.dict_name),
                positions: positions
            )
        }

        let frequency = frequenciesArray
            .compactMap { entry -> String? in
                let values = Array(entry.frequencies)
                    .map { f -> String in
                        let display = String(f.display_value)
                        return display.isEmpty ? String(f.value) : display
                    }
                    .filter { !$0.isEmpty }
                guard !values.isEmpty else { return nil }
                let dictName = String(entry.dict_name)
                return dictName.isEmpty
                    ? values.joined(separator: ", ")
                    : "\(dictName): \(values.joined(separator: ", "))"
            }
            .joined(separator: "  ")

        let pitch = pitchesArray
            .compactMap { entry -> String? in
                let positions = Array(entry.pitch_positions).map { String($0) }
                guard !positions.isEmpty else { return nil }
                let dictName = String(entry.dict_name)
                return dictName.isEmpty
                    ? positions.joined(separator: ", ")
                    : "\(dictName): \(positions.joined(separator: ", "))"
            }
            .joined(separator: "  ")

        let trace = Array(result.trace.reversed()).map {
            DictionaryLookupDeinflectionStep(
                name: String($0.name),
                description: String($0.description).nilIfEmpty
            )
        }
        let traceText = trace.map(\.name).filter { !$0.isEmpty }.joined(separator: " -> ")
        let matched = String(result.matched)
        let source = traceText.isEmpty ? matched : "\(matched) • \(traceText)"
        let rules = String(result.term.rules)
            .split(separator: " ").map(String.init).filter { !$0.isEmpty }

        return DictionaryLookupEntry(
            term: String(result.term.expression),
            reading: String(result.term.reading).nilIfEmpty,
            matched: matched.nilIfEmpty,
            rules: rules,
            deinflectionTrace: trace,
            structuredGlossaries: structuredGlossaries,
            structuredFrequencies: structuredFrequencies,
            structuredPitches: structuredPitches,
            glossaries: glossaries,
            frequency: frequency.nilIfEmpty,
            pitch: pitch.nilIfEmpty,
            source: source.nilIfEmpty
        )
    }

    private static func glossaryLines(dictName: String, rawGlossary: String) -> [String] {
        let flattened = flattenGlossary(rawGlossary)
        guard !flattened.isEmpty else {
            return dictName.isEmpty ? [] : [dictName]
        }
        guard !dictName.isEmpty else { return flattened }
        if let first = flattened.first {
            return ["\(dictName): \(first)"] + flattened.dropFirst()
        }
        return [dictName]
    }

    private static func flattenGlossary(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) else {
            return glossaryTextLines(from: raw)
        }
        return flattenGlossary(json)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func flattenGlossary(_ value: Any) -> [String] {
        switch value {
        case let s as String: return glossaryTextLines(from: s)
        case let n as NSNumber: return [n.stringValue]
        case let arr as [Any]: return arr.flatMap(flattenGlossary)
        case let dict as [String: Any]:
            if let type = dict["type"] as? String, type == "structured-content",
               let content = dict["content"] {
                return flattenGlossary(content)
            }
            if let tag = (dict["tag"] as? String)?.lowercased() {
                if tag == "br" { return [] }
                if let content = dict["content"] {
                    let inner = flattenGlossary(content)
                    switch tag {
                    case "li", "dt", "dd", "p", "div", "tr", "td", "th":
                        let joined = inner.joined(separator: " ")
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        return joined.isEmpty ? [] : [joined]
                    default:
                        return inner
                    }
                }
            }
            if let text = dict["text"] { return flattenGlossary(text) }
            if let value = dict["value"] { return flattenGlossary(value) }
            if let data = dict["data"] { return flattenGlossary(data) }
            if let title = dict["title"] as? String { return glossaryTextLines(from: title) }
            return dict.keys.sorted().reduce(into: [String]()) { out, key in
                if let v = dict[key] { out.append(contentsOf: flattenGlossary(v)) }
            }
        default:
            return []
        }
    }

    private static func glossaryTextLines(from text: String) -> [String] {
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}

private extension AppDictionaryKind {
    var storageDirectoryName: String {
        switch self {
        case .term: return "Term"
        case .frequency: return "Frequency"
        case .pitch: return "Pitch"
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
