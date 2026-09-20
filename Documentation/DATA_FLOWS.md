# Data flows

What a user action turns into, RPC by RPC. The layers these calls travel through
are in [ARCHITECTURE.md](ARCHITECTURE.md), and the wire mechanics in
[RUST_BRIDGE.md](RUST_BRIDGE.md).

## Sync

```
1. SyncLogin(username, password) → auth token
2. SyncCollection(auth) → SyncCollectionResponse
   - If FULL_DOWNLOAD or FULL_SYNC:
     3. FullUploadOrDownload(upload: false) → full collection download
   - If NORMAL_SYNC:
     3. Normal incremental sync (handled by Rust)
4. Collection is now up to date locally
```

An empty local collection reports `FULL_DOWNLOAD`, which must be acted on rather
than reported as "already complete".

## Study session

```
1. SetCurrentDeck(deckId)                     — tell Rust which deck
2. GetQueuedCards(fetchLimit: 1)              — next card + scheduling states
3. RenderExistingCard(cardId, browser: false) — rendered HTML
4. Display the card (native renderer or WKWebView)
5. User taps a rating button
6. AnswerCard(cardId, currentState, newState, rating, millisTaken)
7. Go to step 2
```

The `QueuedCard` protobuf carries `SchedulingStates` with `current`, `again`,
`hard`, `good` and `easy`. The chosen rating's state becomes `new_state` in
`AnswerCard`. Pass these through exactly as received — do not reconstruct them.

## Browse and search

```
1. SearchNotes(query) → note IDs
2. GetNote(noteId) per note, lazy-loaded in batches of 50
3. Display in a scrollable list with on-demand loading
```

Deck filtering uses Anki search syntax: `deck:"English::Grammar"` automatically
includes subdecks.

## Statistics

```
1. Graphs(search: "deck:DeckName", daysToInclude: 365) → GraphsResponse
2. Parse review history, card counts and hourly breakdown from the response
3. Render heatmap, streak and summary stats in SwiftUI (StatsCharts)
```

The streak card runs its own 365-day fetch rather than riding the dashboard's
snapshot, whose window follows the selected period — the charts render
engine-side aggregates over that window, so widening the shared fetch would show
a year of data under a "7 days" chip.

## Widgets

The widget extension is a separate process that never touches the engine. The
app writes a precomputed `WidgetSnapshot` — a multi-day forecast honouring
Anki's 4am rollover — into the shared App Group, and `WidgetFeature`'s timeline
provider replays it as timeline entries. No background refresh task is involved.
