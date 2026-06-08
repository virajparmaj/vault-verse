# 05 — Known gaps & TODOs

Prioritized. The core engine is complete and tested; gaps are mostly the
app/Xcode boundary and future providers.

## Toolchain boundary (why some things are unverified here)
This repo was built with **Command Line Tools only** (no full Xcode):
- ✅ `VaultVerseCore` + `vaultverse-demo`: built & tested (48 tests pass).
- ✅ SwiftUI view layer (16 files): type-checked against the SDK.
- ⚠️ `App/Persistence/SwiftDataModels.swift` + `SwiftDataVaultStore.swift`: **not**
  compilable under CLT — the SwiftData macros (`@Model`, `@ModelActor`,
  `#Predicate`) ship only with full Xcode. Written carefully but **verify with a
  real Xcode build** (`xcodegen generate` → ⌘B). Most likely place for small fixes.

## High
- [ ] Build the app once in Xcode and fix any SwiftData/SwiftUI API drift.
- [ ] Confirm SwiftData container persistence path + migration story.

## Local-first (current model)
The app is now fully local-first and runs unsigned with **no MusicKit entitlement**:
- ✅ Demo connector (`MockAppleMusicService`) + real-library connector
  (`LibraryXMLConnector`, parses a Music "Export Library…" `.xml`).
- ✅ Restore produces a **re-importable file** (`.m3u` + JSON + missing CSV) instead
  of writing back to a provider.
- ⚠️ Imported `.xml` access isn't persisted across launches (no security-scoped
  bookmark yet) — re-pick the file each session to re-import. Already-imported data
  stays in the vault and is fully viewable/exportable/restorable.

## Deferred (paid-only)
- [ ] **Live Apple Music write-back** — `LiveAppleMusicService` stays compiled behind
      `#if canImport(MusicKit)` but is inert and never the default. Enabling it needs
      the MusicKit capability + a **paid Apple Developer membership** and a
      provisioning profile. Only then re-point a connector at it (opt-in).

## Medium
- [ ] Persist `.xml` access via a security-scoped bookmark (re-import without re-picking).
- [ ] XCUITest E2E for import → view → export → restore.
- [ ] Artwork caching wired into the UI (service exists; not yet invoked on import).
- [ ] `.fileExporter`-based "save as…" (currently exports to a default dir + reveal).

## Low / future
- [ ] Spotify connector (good second provider — strong APIs, ISRC via external_ids).
- [ ] YouTube Music — *experimental only*; no clean official library API. Keep the
      interface, don't build on unofficial APIs.
- [ ] M3U export. Replay/Wrapped labeling. Archive-growth chart in the dashboard.
- [ ] Tighten Swift 6 strict concurrency (currently Swift 5 language mode).
