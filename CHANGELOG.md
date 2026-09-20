# Changelog

Notable changes per release. For everything else, see the
[commit log](https://github.com/antigluten/amgi/commits/main).

Versions are `0.MINOR.PATCH` until 1.0: a minor release carries features, a
patch release carries fixes only.

## 0.2.0 — 2026-09-19

Two things that were quietly broken got fixed: media sync now waits for the
engine to report completion instead of firing and forgetting, and collection
maintenance is addressed through the service the FFI actually dispatches. The
rest is reach and polish — Shortcuts and Siri actions, a streak card, duplicate
detection in the browser, decks as a grid, keyboard control in the reviewer, and
a Human Interface Guidelines pass over the deck, settings and review screens.

No collection format change — the engine is still Anki `26.05`, the same as
0.1.0, so a collection opened in 0.2.0 stays readable by 0.1.0.

### Studying

- Feat: rate, reveal and undo a card from a hardware keyboard, with the
  typed-answer field surviving the reveal.
- Feat: deck import shows progress while it runs instead of an alert once it is
  over.
- Fix: undo no longer borrows the deck-finished haptic.
- Fix: the reviewer releases its audio session when it closes.
- Fix: a deck counts as empty by its card total, not by today's queue, so an
  all-suspended deck no longer claims to be finished.

### Decks

- Feat: the library lists decks as rows or as a grid.
- Feat: HIG pass on deck detail and deck options — semantic toolbar placements,
  real alert titles, confirmations separated from plain alerts.
- Feat: the library toolbar is Sync, New Deck and a More menu, instead of four
  unlabelled icons.

### Notes

- Feat: find duplicate notes that share a first field, through an app-only RPC
  (service 200) rather than Anki's `dupe:` operator, which only answers "who
  else has *this* value".
- Feat: clear unused tags from the tag manager.
- Feat: the image-occlusion editor stores the fitted image rather than the
  camera original.
- Fix: a warning before discarding an unsaved note.
- Fix: a failed browse load offers a retry instead of asking for a pull that
  does nothing.

### Reader

- Feat: both web views share one tap-to-lookup extractor, so a lookup in the
  reviewer behaves exactly like a lookup in the reader.
- Feat: redesigned continue-reading ribbon and cover placeholder.
- Fix: lookups start at the tapped character and honour the configured scan
  length; ruby annotations are no longer tokenized.

### Sync

- Feat: media sync polls the engine for completion instead of firing and
  forgetting, and shows the engine's own progress text. The proto progress
  fields are localized display lines with no numbers to parse, so the previous
  code showed "Syncing media 0/0" for an entire download
  (PR #27, thanks to [@myaumura](https://github.com/myaumura)).
- Fix: a profile switch waits for cancellation before swapping the collection.
- Fix: a failed reopen after a `.colpkg` export is surfaced rather than
  swallowed.

### Statistics

- Feat: a streak card at the top of the dashboard — current streak against the
  same point last month.
- Feat: every chart carries a VoiceOver summary instead of being an unlabelled
  image.

### Beyond the phone

- Feat: Shortcuts and Siri actions — study a deck, sync the collection, ask how
  many cards are due. Available from Shortcuts, Spotlight and voice.

### Appearance

- Feat: a four-step welcome tour on first run, skippable at any point.
- Fix: every bundled palette meets WCAG AA contrast, with a test that fails if a
  future palette does not.

### Under the hood

- Change: package targets dropped the `Amgi` prefix — `AmgiTheme` is `Theme`,
  `AmgiCharts` is `StatsCharts`, `AmgiAppCore` is `AppCore`. Module names only;
  no API behaviour changed.
- Change: `AmgiApp.xcodeproj` is no longer tracked. It is generated from
  `AmgiApp/project.yml`, so run `xcodegen generate` after cloning.
- Change: the guides are split by domain under `Documentation/`, and each
  package carries an `AGENTS.md` describing the rules it enforces.
- Fix: collection maintenance ops are addressed through the backend service;
  `CollectionService` (2) is never dispatched over the FFI.
- Fix: findings from an audit of the staged tree — a reload race in the
  duplicates view, an unguarded `postMessage`, temp `.apkg` cleanup, and
  collection open-path ordering.

## 0.1.0 — 2026-09-02

Adopted `0.MINOR.PATCH` versioning and pinned the engine to Anki `26.05`
(from `25.09.2`). A long correctness and performance pass: blocking engine calls
moved off the main thread, reviews and writes stopped being lost silently,
startup became recoverable, and sync endpoints, card navigation and occlusion
mask serialization were hardened. Adds suspend/bury, per-deck limit extension,
and honest loading states across review, sync and stats.

## 0.0.5 and earlier — 2026-07-27 and before

Foundation: the Rust engine bridge, sync (including self-hosted servers), FSRS
scheduling, the EPUB reader with offline dictionary lookup, image occlusion, the
card template editor, multi-theme support, widgets and the watchOS app. See the
[release history](https://github.com/antigluten/amgi/releases).
