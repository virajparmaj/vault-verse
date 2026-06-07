# 02 — Data model

All domain types are immutable Swift structs in `Sources/VaultVerseCore/Models/`.

## Identity rule (the most important one)
A song's canonical identity is a normalized **`Track`**. Provider IDs (Apple
Music, Spotify, …) live **only** in **`TrackPlatformMapping`**. The same song keeps
one `Track` and accumulates mappings across platforms over time — the
"cross-platform passport". Never key a song on a single provider ID.

## Entities
- **`Track`** — title, normalized title/artist, artists[], album, durationMs,
  ISRC, releaseDate, explicit, artwork/preview URLs.
- **`TrackPlatformMapping`** — trackId → (provider, providerTrackId, URI/URL,
  catalogCountry, matchMethod, confidence 0–100, isManualOverride, availability).
- **`Playlist`** — provider-neutral, long-lived; contents live in snapshots.
- **`PlaylistSnapshot`** — a versioned capture; carries `checksum`,
  `changeSummary`, and the playlist title/artwork at capture time (for diffs +
  self-contained archival).
- **`SnapshotTrack`** — membership + **position** (order is authoritative);
  denormalized title/artist/album/duration + raw provider payload (archival).
- **`ImportJob` / `RestoreJob`** — job tracking with per-item `JobError`s.
- **`UnmatchedTrack`** — a track needing review, with `SuggestedMatch`es.
- **`Export`**, **`ConnectedAccount`** (no tokens — only a Keychain ref).

## Snapshots vs. overwrite
Re-import compares the new content `checksum` to the latest snapshot:
- different → new snapshot + `changeSummary`.
- identical → **no new snapshot** (logged as "no material change").

## Dedup ladder (import)
ISRC → normalized title+artist+duration (±3s) → create new `Track`.
Local-only items (no catalog ID) are archived as tracks with **no** mapping.

## Persistence
Domain structs ↔ SwiftData `@Model` classes via mappers in
`App/Persistence/SwiftDataModels.swift`. Enums stored as rawValue; nested Codable
values (change summaries, suggestions, job errors) stored as JSON `Data`.
