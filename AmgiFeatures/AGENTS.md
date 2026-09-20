# AmgiFeatures

Every screen the app renders, plus the sinks they share. Nothing here depends on
the app target; the sinks never depend on a `*Feature`.

## Naming

- `Anki*` — derived from the upstream engine.
- Bare noun — app-owned and reusable, so another module may depend on it
  (`UI`, `Theme`, `Reader`, `StatsCharts`, `AppCore`, `AppShared`, `ReviewCore`).
- `*Feature` — screen-level, suffix not prefix (`SyncFeature` reads "the Sync
  feature"). App extensions and the watch app count as screen-level.

`StatsCharts` avoids the bare name `Charts` because it imports Apple's. A new
feature takes the `*Feature` suffix rather than a bare noun, which keeps the
screen layer visually distinct from the sinks.

## The sinks

| Module | Holds | Hard rule |
|---|---|---|
| `AppCore` | Preferences, `AccountStore`, app-group keys, `WidgetSnapshot`, `StreakCalculator`, `CardFlag` | Engine-free. An `AnkiClients` edge here drags Rust into the widget and the watch. |
| `AppShared` | `CollectionStore`, `ImportHelper`, `ShareSheet`, `CardContextMenu`, widget-snapshot writing, the `deckImport` modifier | iOS-only: imports UIKit and WidgetKit unguarded, so it cannot build for watchOS. |
| `ReviewCore` | `ReviewSession`, `TemplateRenderOverrides` | watchOS-clean. No `AppShared`, no UI, UIKit behind `#if canImport(UIKit)`. |
| `StatsCharts` | Chart and heatmap views over `GraphsSnapshot` | Compiled for watchOS in its entirety — every file, not only the ones the watch renders. |

Route shared code down into a sink rather than adding a feature→feature edge.

## Feature→feature edges

Four exist, each a sheet over another feature's editor: `Review → Browse`,
`Review → Templates`, `Reader → Browse`, `Decks → Browse`. `RootFeature`
composes the six screens it hosts, which is a composition root doing its job
rather than a sideways reach.

Two edges were deliberately inverted onto an environment key in `AppShared`,
and both stay that way: `Review → Reader` (`EnvironmentValues.lookupPopup`) and
`Settings → Reader` (`EnvironmentValues.dictionarySettings`). The reason is the
Cxx chain below.

## The Cxx chain

`ReaderFeature` declares `.interoperabilityMode(.Cxx)` because it touches
`ReaderDictionary` → `hoshidicts`. Interop is transitive through the module
graph: a target importing a Cxx-mode module gets the `CHoshiDicts` modulemap in
its own Clang dependency scan and fails with "module 'CHoshiDicts' requires
feature 'cplusplus'" without the setting. Every target in the chain drops out of
explicit modules and compilation caching.

The chain is `ReaderFeature → RootFeature → AmgiApp`, and it stays that size.
Breaking the `Review → Reader` edge measured a cached clean build 110.0s →
80.5s (−26.9%, 3/3 paired runs, non-overlapping ranges). Single-file incremental
did not move — caching pays on full-module rebuilds, not the edit loop.

Reach for an injection point in a sink before importing a Cxx-mode module.

## Visibility

`public` survives on exactly the products an executable links directly:
`RootFeature` (the app), `WidgetFeature` (the widget), `WatchFeature` (the
watch), plus the sinks those extensions link. Every other `*Feature` is
`package` throughout — `RootFeature` composes them from inside this package, so
`public` would be dead reach.

## Module notes

- `ReaderFeature` — both readers live here (EPUB via `reader_typo_*`, Anki-note
  via `reader_pref_*`, branched at `ReaderBookDetailView.swift`), plus the Study
  landing screen and the lookup UI. The only target in the Cxx chain.
- `BrowseFeature` — browse, note authoring, batch tagging, tag management, the
  image-occlusion editor. No app-folder dependencies, which is why four features
  can reach into it.
- `SettingsFeature` — the app's fan-in point; depending on six sibling products
  is inherent to a settings screen.
- `WidgetFeature` — deps are `AppCore` + `Theme`. The widget is a separate
  process that reads the app group. No WidgetKit preview API works from a
  package target: a widget preview needs an extension to host it, and
  XCPreviewAgent is an app. The three previews are plain `#Preview`s at a
  hand-set frame.
- `WatchFeature` / `WidgetFeature` — only `@main` stays in the extension target.
- `IntentsFeature` — `StudyDeckIntent`, `SyncCollectionIntent`, `DueCountIntent`
  and their entities. The `AppShortcutsProvider` cannot live here; see
  `AmgiApp/AGENTS.md`.
- `RootFeature` — `RootView`, the tab bar, `AmgiRoot.bootstrap()`,
  `openCollection`, `switchProfile`. `DeckListView.init` and `SettingsView.init`
  take `onSwitchProfile` because profile switching is composition-root work.

## Importing AnkiBackend

Any model that offloads engine work imports `AnkiBackend` for `backendOffload`,
so the list of importers grows with call sites. Check the current set with
`rg -l "^(public |package )?import AnkiBackend" AmgiFeatures/Sources` rather
than trusting a count in a doc. Prefer an `AnkiServices` facade where one
exists.
