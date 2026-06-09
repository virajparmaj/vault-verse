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
- [x] **Store query performance** — `SwiftDataVaultStore` now uses `FetchDescriptor` +
  `#Predicate` (+ `fetchLimit`) for point lookups instead of fetch-whole-table-then-
  filter. The old approach was O(n) per lookup → O(n²) per import / dashboard pass, so
  a real library (≈2.6k tracks) appeared to hang and load empty. Dashboard/Library also
  show a loading spinner now instead of a misleading empty state.
- [ ] **Store splits by sandbox state (data can "revert to demo"/vanish).** The app
  declares `com.apple.security.app-sandbox` but is distributed **unsigned**
  (`CODE_SIGNING_ALLOWED=NO` → ad-hoc, entitlements stripped → **unsandboxed**), so it
  uses `~/Library/Application Support/default.store`. A **signed** run (e.g. Xcode ⌘R)
  is **sandboxed** and uses `~/Library/Containers/com.vaultverse.app/.../default.store`
  — a *different* database (+ different `UserDefaults`/bookmark). Switching how you
  launch silently switches which library you see. Fix options: (a) drop the sandbox
  entitlement so every run is unsandboxed + pin an explicit
  `Application Support/VaultVerse/VaultVerse.store` with migration from `default.store`;
  or (b) keep sandbox for a future Mac App Store build and always run that one signed
  build. Until decided: **run the unsigned `/Applications` build, not Xcode ⌘R.**

## Local-first (current model)
The app is now fully local-first and runs unsigned with **no MusicKit entitlement**:
- ✅ Demo connector (`MockAppleMusicService`) + real-library connector
  (`LibraryXMLConnector`, parses a Music "Export Library…" `.xml`).
- ✅ Restore produces a **re-importable file** (`.m3u` + JSON + missing CSV) instead
  of writing back to a provider.
- ✅ Imported `.xml` access persists across launches via a security-scoped bookmark
  (`App/LibraryBookmarkStore.swift`): the real library auto-reloads on launch
  (`AppEnvironment.restoreActiveLibrary()`, called from `VaultVerseApp.task`) with no
  re-pick. Importing into a non-empty vault offers **Replace** (wipes demo/seed via
  `store.deleteAllData()` first) or **Add**, so a real import doesn't leave demo
  playlists behind. Stale/denied/missing bookmarks fall back to the empty connector
  and a friendly `VaultVerseError.libraryAccessUnavailable` re-import nudge.

## Deferred (paid-only)
- [ ] **Live Apple Music write-back** — `LiveAppleMusicService` stays compiled behind
      `#if canImport(MusicKit)` but is inert and never the default. Enabling it needs
      the MusicKit capability + a **paid Apple Developer membership** and a
      provisioning profile. Only then re-point a connector at it (opt-in).

## Medium
- [x] Persist `.xml` access via a security-scoped bookmark (re-import without re-picking).
- [ ] XCUITest E2E for import → view → export → restore.
- [ ] Artwork caching wired into the UI (service exists; not yet invoked on import).
- [ ] `.fileExporter`-based "save as…" (currently exports to a default dir + reveal).

## Low / future
- [ ] Spotify connector (good second provider — strong APIs, ISRC via external_ids).
- [ ] YouTube Music — *experimental only*; no clean official library API. Keep the
      interface, don't build on unofficial APIs.
- [ ] M3U export. Replay/Wrapped labeling. Archive-growth chart in the dashboard.
- [ ] Tighten Swift 6 strict concurrency (currently Swift 5 language mode).
