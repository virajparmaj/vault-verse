# 04 — App & UI

SwiftUI, macOS 14+, `NavigationSplitView` shell. Aesthetic: retro-modern
iTunes/iPod utility — warm off-white, graphite, brushed silver, quiet blues
(palette in `App/Theme/Theme.swift`).

## Screens (`App/Features/`)
- **Dashboard** — hero copy, stat tiles (playlists/tracks/snapshots/readiness/last
  backup/largest/oldest), top artists, cross-playlist songs; empty-state import CTA.
- **Connections** (`ConnectImportView`) — connection status, import button +
  progress, import history.
- **Library** — playlist cards (artwork, badges, readiness ring) → detail.
- **Playlist detail** — header + snapshot picker, native `Table` of tracks with
  confidence badges, actions: Restore / Export (JSON/CSV) / Compare.
- **Restore** — "Restore my library" hub → `RestoreFlowView` stepper
  (Preflight → Review → Create → Report) with inline resolution.
- **Compare** — two-snapshot diff (added/removed/reordered/title).
- **Unmatched** — review queue with suggestion resolution.
- **Exports** — generated backups, reveal in Finder.
- **Settings** — what's stored, last backup, disconnect, **delete all data**.

## Components (`App/Components/`)
`PlaylistCard`, `ProviderBadge`, `MappingConfidenceBadge`, `OutcomeBadge`,
`ReadinessRing`, `StatTile`, `ArtworkThumbnail`, `EmptyStateView`, `SectionHeader`.

## State pattern
`AppEnvironment` (`@Observable`, `@MainActor`) is injected via `.environment`.
Views hold `@State` and load data in `.task` by calling services; jobs run as
`async` tasks publishing progress to the environment.

## UX decisions
- Views are **thin** over the tested services — minimal logic in the UI.
- Restore never writes until the user confirms after seeing the preflight.
- Artwork uses `AsyncImage` with a brushed-metal initials placeholder (demo URLs
  don't resolve, and that's handled gracefully).
