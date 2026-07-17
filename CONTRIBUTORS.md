# Contributors

Thank you to everyone who has contributed to Amgi.

## Maintainer

- **Vladimir Gusev** ([@antigluten](https://github.com/antigluten)) — project lead

## Contributors

- **DreamAfar** ([@DreamAfar](https://github.com/DreamAfar)) — v0.0.3 and v0.0.4 forks.

  In **v0.0.3**: Image Occlusion (create, edit, reviewer parity), the multi-theme system (Palette + Vivid/Muted × Light/Dark), the Settings tab and maintenance surfaces (Empty Cards, Media Check), the card template editor with uncommitted preview, the Statistics retrievability chart and dual-axis tooltips, tag management, the rich note field editor with HTML preview, the extended card context menu, and the tag-triggered GitHub Actions IPA workflow.

  In **v0.0.4**: the Reader stack — `AmgiReader` and `AmgiReaderDictionary` SPM packages, Yomitan-compatible `hoshidicts` engine integration via Cxx interop, structured-content rendering through the bundled `popup.js`, tap-to-lookup in the chapter reader and reviewer card via WKWebView JS bridge, the `ReaderLookupNoteTemplate` flow for making notes from lookup entries, the stacked lookup popup UX (chained queries with `NavigationStack`), language-aware TTS, dictionary-bundled audio playback with autoplay, the dictionary library settings (drag-to-reorder, audio template, scan length), the chapter CSS shell (font picker integration, vertical writing mode, ruby toggle, debug overlay), the bookshelf with sort modes / column count / search / cover-image resolution / custom-color theme editor, per-deck FSRS optimizer with simulator and preset CRUD, browse multi-select with the batch tag sheet, the `SyncCoordinator` state machine and `AnkiMobileAttributionView`, MathJax CHTML asset bundling for the reviewer, and the in-context `.apkg` import + single-deck `.colpkg` export from `DeckDetailView`.

## Upstream Acknowledgments

Amgi is built on top of work by:

- **[Damien Elmes](https://github.com/dae)** and the [ankitects/anki](https://github.com/ankitects/anki) project — the Rust backend that powers all card scheduling, sync, template rendering, and persistence in this app.
- **[AnkiDroid](https://github.com/ankidroid/Anki-Android)** — the original mobile Anki client and the reference for bridging the Rust backend to a mobile platform.

## How to be Listed

Open a pull request that closes a non-trivial issue or introduces a new feature. After the merge, your name and a short description of your contribution will be added here. Drive-by typo fixes are appreciated but not listed individually.
