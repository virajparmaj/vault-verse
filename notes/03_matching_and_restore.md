# 03 — Matching & restore

## Track matching (`TrackMatchingService`)
Confidence 0–100, first strong signal wins:

| Rule | Score | Method |
|---|---|---|
| Exact ISRC | 100 | `.isrc` |
| Title + artist + duration (±3s) | 95 | `.titleArtistDuration` |
| Title + artist + album | 90 | `.titleArtistAlbum` |
| Title + artist + duration (±10s) | 85 | `.titleArtistDurationClose` |
| Fuzzy title + artist | ≤ 84 | `.fuzzy` |
| Manual override | (wins) | `.manual` |

- **Thresholds:** ≥ 80 confident · 60–79 review · < 60 unmatched.
- **Normalization** (`TrackNormalizer`): lowercase, fold diacritics, drop
  `(feat. …)` and edition noise (remastered/deluxe/explicit/clean/radio edit),
  delete apostrophes so contractions join, `&`→`and`. Preserves materially
  different variants (live/acoustic/remix).
- **Fuzzy** blends Jaro–Winkler + Levenshtein ratio so neither prefix bias nor
  length difference dominates.

## Restore (`PlaylistRestoreService`) — careful & transparent
1. **Preflight** (no writes): for each snapshot track → manual override (wins) →
   else live catalog search + score. Buckets each as
   `confident / review / unavailable / unmatched`. Confident catalog matches are
   persisted as mappings (builds the passport). Review/unmatched create
   `UnmatchedTrack` records with suggestions.
2. **Resolve** — user picks a suggestion → saved as a permanent **manual override**
   (remembered on every future restore).
3. **Confirm** — create the target playlist, add resolved + confident tracks in
   order, record per-track failures, write a **missing-songs CSV**, return a report.

### Why preflight re-searches instead of trusting import IDs
Region/catalog availability changes over time, and cross-platform restores have no
source ID. Preflight reflects the live catalog ("how many can be confidently
restored"). Only manual overrides short-circuit it.

## Demo outcome (Summer 2024 seed)
`4 confident · 1 review · 1 unavailable · 1 unmatched` — the review case
("A Bar Song (Tipsy)" → catalog "Tipsy", ~62) is created by an authored catalog
discrepancy in the seed (`catalogTweaks`), since a real Apple→Apple restore would
otherwise match nearly everything.
