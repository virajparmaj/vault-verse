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

## Medium
- [ ] Live Apple Music: implement `LiveAppleMusicService` (MusicKit framework path
      recommended) and add the MusicKit capability.
- [ ] XCUITest E2E for connect → import → view → export → restore.
- [ ] Artwork caching wired into the UI (service exists; not yet invoked on import).
- [ ] `.fileExporter`-based "save as…" (currently exports to a default dir + reveal).

## Low / future
- [ ] Spotify connector (good second provider — strong APIs, ISRC via external_ids).
- [ ] YouTube Music — *experimental only*; no clean official library API. Keep the
      interface, don't build on unofficial APIs.
- [ ] M3U export. Replay/Wrapped labeling. Archive-growth chart in the dashboard.
- [ ] Tighten Swift 6 strict concurrency (currently Swift 5 language mode).
