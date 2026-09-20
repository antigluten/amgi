# Extracting a module

The app target went from ~18.7k LOC to 13 lines across a series of lifts:
`BrowseFeature`, `ReaderFeature` (which absorbed Study), `ReviewCore`,
`ReviewFeature`, `DecksFeature`, `SettingsFeature`, `WidgetFeature`,
`WatchFeature`, and finally `RootFeature`, which carried the composition root
out and let every other feature narrow from `public` to `package`.

Order was forced by the coupling graph each time: `DecksFeature` presents
`ReviewView`, so it followed Review; `ReviewCore` had to exist before Review
could move, because `project.yml` was cherry-picking its files into the watch
target by path.

## Budget for these five

Every lift hit at least two.

1. **`DesignConformanceTests` fails in both directions.** Its allowlist is keyed
   by path *and* it asserts no stale entries, so a file move breaks it coming
   and going. Update `permanentlyExempt` in the same commit.
2. **`@testable import AmgiApp` tests** that reach moved types need a second
   `@testable import <NewModule>`.
3. **`MemberImportVisibility`** is on in the packages and off in the app target.
   A file that borrowed a transitive `import SwiftUI` or
   `import UniformTypeIdentifiers` spells it out once it moves.
4. **Scan for free functions, not just types.** A type-level survey called
   `Decks/` dependency-free; it was calling `switchProfile(to:)`, a free
   function in `AmgiAppApp.swift`. The compiler caught what the survey missed.
5. **Verify with `xcodebuild clean build`.** See `agents/build-and-verify.md`.

## What the lifts actually bought

A package target compiles under the package's stricter settings, and its
previews render independently. That is the reliable payoff.

The payoff that did **not** materialise, twice: moving code out of the app
target does not let the app drop its Cxx settings, because Xcode puts every
package's include dir on the app's `-Xcc` line and the Clang scanner walks
`hoshidicts/include/module.modulemap` regardless of what any source imports.
Both "drop all Cxx settings" and "keep all but the `OTHER_SWIFT_FLAGS` copy"
were tried against clean builds and both fail.

Measured levers, for calibration:

- Breaking the `Review → Reader` edge: cached clean build 110.0s → 80.5s
  (−26.9%, 3/3 paired runs, non-overlapping ranges). Incremental unchanged.
- The `AmgiFeatures` phase-3 split: incremental rebuild −1.7s (−8.7%), clean
  build unchanged. Not enough to schedule; the remaining features moved
  opportunistically instead.

So: expect a boundary and stricter settings. Expect a build-time win only from
breaking a Cxx edge, and measure it paired, with cold DerivedData per arm.

## Extensions

`WidgetFeature` and `WatchFeature` leave only `@main` in the extension target.
Neither shrank the app target, because `Sources/Widgets` and `Sources/Watch`
were already excluded from it. The watch lift bought no previews and no iOS
build coverage — every watch screen reaches `AnkiBackend`, and nothing on iOS
links the product. What it bought is the package's stricter settings.

Moving `AmgiWidget`, its intent and its provider into a package cost the real
WidgetKit previews; see `agents/build-and-verify.md`. Getting them back means
undoing that extraction.

## Two questions already settled

The "three duplicate reader preference systems" are two live readers with
separate namespaces (EPUB `reader_typo_*`, Anki-note `reader_pref_*`, branched
in `ReaderBookDetailView.swift`). Converging them is a product decision, not a
refactor.

The `Theme` / `ReaderThemeColor` hex duplication is deliberate and carries an
exemption in `DesignConformanceTests`.
