# 06 — Roadmap

Mapped from the product's 10-phase plan to the macOS-native build.

## Done (this pass)
1. Foundation — package, domain models, repository layer, app shell.
2. Provider abstraction — protocol + mock + local XML connector + live (deferred) + DI switch.
3. Import — dedup, snapshots, source mappings, checksums.
4. Vault UI — library cards, playlist detail, native track table, snapshot picker.
5. Export — JSON + CSV + M3U.
6. Restore — preflight matching, **re-importable file output** (`.m3u`/JSON/CSV), report.
7. Matching review — low-confidence resolution + manual-match memory.
8. Snapshot compare — diff viewer.
9. Dashboard analytics — archive stats, readiness, top artists, recurring songs.
10. **Local-first** — runs unsigned, no MusicKit entitlement; demo + real `.xml` import.

## Next
- **Live Apple Music write-back** — *deferred, paid-only.* `LiveAppleMusicService`
  is already wired behind `#if canImport(MusicKit)`; enabling it needs the MusicKit
  capability + a paid Apple Developer membership/provisioning. Opt-in only.
- **Persist imported `.xml` access** — security-scoped bookmark so re-import doesn't
  need re-picking the file each session.
- **Spotify connector** — same `MusicProviderConnector` interface; OAuth, playlist
  read/write, ISRC via `external_ids`. First real cross-platform restore (where the
  matching ladder + review flow truly shine).
- **YouTube Music** — keep the interface; mark experimental (no official library
  API). Do not build the product on unofficial APIs.

## Later
- **Cloud sync / multi-device** — add a remote `VaultStore` impl behind the
  existing repository seam; no service/UI changes.
- **iOS / iPadOS** — reuse `VaultVerseCore` unchanged; new SwiftUI layer.
- **Memory layer** — Replay/Wrapped labeling, "timeline of taste" (top artists by
  year, songs recurring across yearly playlists), archive-growth chart.
- **Distribution** — Developer ID signing + notarization, or Mac App Store.
