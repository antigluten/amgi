# AmgiUI

`Theme` (palette data, tokens, resources) and `UI` (shared SwiftUI components
built on `Theme`). Both are bare-noun modules: anything may depend on them, and
they depend on no feature.

## Themes are data

A theme is a string id plus `PaletteData`, never an enum case. User-created
themes are a planned feature, and the architecture already treats themes as data
so the editor lands without a refactor. Add a palette by adding data.

## The design-token ratchet

`DesignConformanceTests` scans app source for raw styling — system colors and
fonts, hard-coded radii, `.shadow` — and fails on any non-exempt match. Two
things follow:

- Style with tokens (`.amgiSurface`, `.amgiAccent`, `AmgiSpacing`, `amgiFont`).
  Decorative colors are tokenized; domain colors that carry meaning (Anki's
  blue/green/red card states) stay as they are, because tokenizing them dilutes
  the meaning.
- The allowlist is keyed by **path** and the suite asserts no stale entries, so
  a file move fails it in both directions at once. Update `permanentlyExempt` in
  the same commit as the move.

Bundled palettes meet WCAG AA, and a test holds that line.
