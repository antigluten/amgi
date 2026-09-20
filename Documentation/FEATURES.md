# Features

What Amgi does today. For how it is put together, see [ARCHITECTURE.md](ARCHITECTURE.md).

## Studying

- **FSRS scheduling** — the official Rust FSRS engine, not a reimplementation. Ratings, intervals, and review history are computed by the same code as Anki Desktop.
- **Review session** — Again/Hard/Good/Easy with the next interval printed on every button, session progress, rating toast with auto-advance, native typed-answer field, tap-to-play audio, and undo.
- **Keyboard control** — rate, reveal, and undo from a hardware keyboard, with the typed-answer field staying up across the reveal.
- **Dual card rendering** — the Rust template engine renders cards exactly like desktop clients. Simple cards are auto-detected and drawn by a native SwiftUI renderer; complex cards fall back to a sandboxed WebKit host. A per-card chip shows which path is active, and the render mode can be pinned per template.
- **MathJax and audio** — formula rendering and card audio playback in both renderers.
- **Today view** — an aggregate "due now" screen across every deck, with an up-next queue ordered by workload.

## Decks

- **Hierarchical deck tree** — recursive expand/collapse with new/learning/review count badges on every node, as a list or a grid.
- **Deck detail** — per-deck counts, retention, average cards/day, mature card count, and subdeck breakdown.
- **Per-deck study options** — FSRS weights editor with optimizer and simulator, preset CRUD, Easy Days, bury rules, review timer, auto-advance.
- **Custom study and filtered decks** — extend today's new-card and review limits per deck, and rebuild or empty a filtered deck to return its cards to their home decks.
- **Import** — `.apkg` and `.colpkg` import, including from the iOS share sheet, with progress shown while it runs.

## Notes

- **Browser** — search the whole collection with Anki search syntax, deck filter chips (a top-level deck includes its subdecks), tag chips, sorting, and lazy-loaded results.
- **Editor** — rich field editing with accurate field names pulled from the Rust notetype RPC; multi-select for batch operations.
- **Tags** — batch tagging from a selection, plus collection-wide tag management.
- **Duplicates** — find notes that share a first field, which is the question Anki's `dupe:` operator does not answer.
- **Image occlusion** — create and edit occlusion notes with rectangle, ellipse, polygon, and text masks, with reviewer parity with upstream Anki.
- **Card templates** — a full template editor with front/back/styling source editing, live preview, validation, and notetype field management.

## Reader

- **EPUB reader** — read books chapter by chapter with native paging, vertical writing mode, and Latin/CJK auto-detection.
- **Offline dictionary lookup** — tap any word for a Yomitan-compatible lookup, with chained popups, search history, and per-dictionary collapsed memory.
- **Text-to-speech** — a speak button with language-aware voice selection.
- **Bundled Korean fonts** — Sarasa Mono K, Nanum Myeongjo, Nanum Gothic.
- **Progress sync** — reading position travels with the collection across devices.

## Sync and accounts

- **Any compatible sync server** — AnkiWeb or self-hosted: login, incremental sync, full upload/download, media sync, and bidirectional review sync.
- **Safe sync merge** — when local and server collections diverge, merge them (keeping cards from both sides) instead of being forced to overwrite one. Destructive choices require explicit confirmation.
- **Multi-profile accounts** — isolated collections per profile, a fast picker in the Library toolbar, and per-profile sync credentials and review history.
- **Offline-first** — everything works offline; sync when you have a connection.

## Statistics

- **Dashboard** — all-time and windowed summaries (reviewed, time, young, mature, new, relearn), future-due forecast with backlog toggle, stacked review history, and card count breakdown.
- **Review heatmap** — full-year contribution-style heatmap that auto-scrolls to today, with a streak counter.
- **Streak card** — current streak against the same point last month, at the top of the dashboard.
- **VoiceOver** — every chart is readable as an audio summary, not an unlabelled image.
- **Scoping** — every graph can be scoped to the whole collection or one deck, over Today / 7 days / 1 month / 3 months / 1 year / all time.

## Beyond the phone

- **Home-screen widgets** — small, medium, and large families driven by a precomputed forecast timeline, configurable per deck through AppIntents, with no background refresh required.
- **Apple Watch app** — deck list, card review with audio playback, stats, and sync, with the Anki engine running on-device.
- **Shortcuts and Siri** — study a deck, sync the collection, or ask how many cards are due, from Shortcuts, Spotlight, or by voice.

## Maintenance and appearance

- **Guided first run** — a four-step welcome tour before the sync choice, skippable at any point.
- **Multi-theme system** — Vivid and Muted palettes with Light/Dark/Follow-System, shared with the widgets through an App Group. Every bundled palette meets WCAG AA contrast, and a test keeps it that way.
- **Database tools** — check database, find empty cards, media check, and backup management.

## Under the hood

- **Swift 6.2 strict concurrency** — language mode v6, fully actor-isolated, `Sendable` throughout.
- **Rust owns the data** — Swift never touches SQLite. Every read and write goes through the engine's RPC seam.
