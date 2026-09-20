# Code style and module boundaries

## Swift

- **Swift 6.2** with strict concurrency (language mode v6).
- **Struct-closure dependency injection** using `@DependencyClient` — never protocols.
- **Value types** everywhere above the engine boundary.
- **`@Observable @MainActor`** for view-bound mutable state.
- **SwiftUI view state as an enum**, not parallel `isLoading` / `data?` / `error?` flags.
- **A `body` is a thin composition** — a list of named subviews and modifiers.
  Lift inline overlays, alert stacks, and multi-line closures out.
- Follow Apple's [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).

## Imports

`InternalImportsByDefault`, `AccessLevelOnImport` and `MemberImportVisibility`
are all enabled in the packages and off in the app target, so a file moving into
a package spells out imports it used to inherit.

- `public import` for a module whose types appear in public API signatures.
- Within `AmgiFeatures`, a `*Feature` module's surface should be `package`, not
  `public`. `RootFeature`, `WidgetFeature` and `WatchFeature` are the only three
  linked directly by an executable target, so they are the only `*Feature`s that
  need `public` — as are the sinks the widget and watch link directly.

## Module boundaries

The dependency graph is one-way and worth preserving. The layer diagram is in
[ARCHITECTURE.md](ARCHITECTURE.md); each package also carries an `AGENTS.md`
with the rules that package enforces. The ones that bite most often:

- **`AppCore` must never gain an `AnkiClients` dependency.** The widget
  extension links it, and that edge would drag the whole Rust engine into a
  process that only reads an App Group.
- **`StatsCharts`, `ReviewCore` and `WatchFeature` must stay watchOS-clean.** No
  `AppShared` (it imports UIKit and WidgetKit unguarded), and no iOS-only API
  without a `#if canImport(UIKit)` guard.
- **Reach for an injection point before importing `ReaderFeature`.** It is the
  only module that touches C++ interop, and every target that imports it
  inherits `.interoperabilityMode(.Cxx)` and drops out of explicit modules and
  compilation caching. Two features take what they need from the environment
  instead — `ReviewFeature` gets the dictionary popup from
  `EnvironmentValues.lookupPopup`, `SettingsFeature` gets the dictionary screen
  from `EnvironmentValues.dictionarySettings` — and breaking the first of those
  edges cut a cached clean build by 27%.
- Prefer routing shared code **down into a sink** (`AppCore`, `AppShared`,
  `ReviewCore`, `StatsCharts`) over adding a feature→feature edge.
- `project.yml` must contain no per-file `path:` entries under `Sources/`.
  Cross-target file sharing goes through an SPM product.

## Design tokens

`DesignConformanceTests` scans app source for raw styling — system colors and
fonts, hard-coded radii, `.shadow` — and fails on any non-exempt match. Style
with the tokens (`.amgiSurface`, `.amgiAccent`, `AmgiSpacing`, `amgiFont`).
Decorative colors are tokenized; domain colors that carry meaning, like Anki's
blue/green/red card states, stay as they are.

## watchOS

- `WatchReviewView` exposes only `.again` and `.good`, to keep the screen clear
  for long cards and allow larger touch targets. Again and Good are the
  recommended buttons for avoiding
  [ease hell](https://readbroca.com/anki/ease-hell/) for users not yet on FSRS.
- Stats sources in `AmgiApp/project.yml` are hand-enumerated so that new stat
  pages get a manual review for watch fit. Text may be small and wrap awkwardly,
  but every included diagram and graph must fit horizontally.
