# VaultVerse

**Your music memory, permanently archived.**

VaultVerse is a native macOS app that backs up, versions, and restores your music
playlists. Streaming subscriptions come and go — your playlists, yearly replays,
and music identity shouldn't. VaultVerse is a permanent, local-first vault for
playlist structures, track metadata, artwork references, ISRCs, platform IDs, and
versioned snapshots.

> VaultVerse is **not** a streaming app. It stores playlist *structure and
> metadata only* — never audio files, never a way around DRM.

This first pass is **Apple Music–first** and runs entirely on a **mock connector
with realistic demo data**, so the whole product loop works without any Apple
credentials. A real MusicKit connector is stubbed behind the same interface,
ready to switch on later.

---

## What works today

The complete core loop, end-to-end:

**Connect (mock) → import playlists → save metadata/order/artwork locally →
version as snapshots → browse the vault → export JSON/CSV → restore (with
preflight + manual match resolution) → review report.**

Highlights:
- **Versioned snapshots** — re-importing never overwrites; it appends a new,
  checksummed version. "No material change" is detected and skipped.
- **ISRC-first track matching** with a 0–100 confidence ladder and fuzzy fallback.
- **Careful restore** — a no-writes *preflight* shows `confident / review /
  unavailable / unmatched` before anything is created.
- **Manual match memory** — resolve a track once and it's remembered forever.
- **Open exports** — full JSON backup + human-readable CSV. No lock-in.
- **Local-first & private** — single user, offline after import, Keychain for any
  secrets, one-tap "delete all data".

---

## Architecture

Two layers:

| Layer | What | Build/test |
|---|---|---|
| **`VaultVerseCore`** (Swift Package) | All product logic: models, provider connectors, services (import / match / snapshot / restore / export / analytics), repositories. Provider-neutral. | `swift build` / `swift test` — **fully tested (48 tests)** |
| **`VaultVerse`** (Xcode app) | SwiftUI UI + SwiftData persistence. Thin shell over the package. | Requires **Xcode** (`xcodegen` + build) |

The connector abstraction (`MusicProviderConnector`) is the seam that keeps one
neutral internal format while supporting many platforms. Apple Music ships first
(`MockAppleMusicService` now, `LiveAppleMusicService` stubbed); Spotify/YouTube
conform later without touching services or UI.

```
vault-verse/
├── Package.swift                 # VaultVerseCore + vaultverse-demo + tests
├── Sources/VaultVerseCore/       # Models, Providers, Services, Persistence, Security, Support
├── Sources/vaultverse-demo/      # headless core-loop walkthrough
├── Tests/VaultVerseCoreTests/    # 48 unit + integration tests (swift-testing)
├── App/                          # SwiftUI app target (built in Xcode)
│   ├── Features/  Components/  Theme/  Persistence/ (SwiftData)
├── project.yml                   # XcodeGen spec → VaultVerse.xcodeproj
└── notes/                        # design docs
```

---

## Run the app on your Mac (step by step)

First time? Follow these in order. You only do steps 1–2 once per machine.

### 1. Install the tools

- **Xcode** — install from the Mac App Store (or [developer.apple.com/xcode](https://developer.apple.com/download/applications/)). Open it once and let it finish installing components.
- **XcodeGen** (generates the Xcode project from `project.yml`):
  ```bash
  brew install xcodegen
  ```

### 2. Point the system at Xcode (one-time)

A fresh Mac often still points at the Command Line Tools, not full Xcode. Fix it
(these need `sudo`, so run them in Terminal and enter your password):

```bash
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

Verify it worked — this should print an Xcode version, not an error:

```bash
xcodebuild -version
```

### 3. Generate and open the project

```bash
cd /Users/veerr_89/Work/tools/vault-verse
xcodegen generate           # → VaultVerse.xcodeproj (safe to re-run anytime)
open VaultVerse.xcodeproj
```

### 4. Build and run in Xcode

1. In the top toolbar, set the scheme to **VaultVerse** and the run target to **My Mac**.
2. If prompted for signing: enable **Automatically manage signing** and pick your
   personal Apple ID team (running on your own Mac needs no paid account).
3. Press **⌘R** to build and run.

### 5. Operate the app

The app ships with realistic **demo data** — no Apple Music account needed.

1. Go to **Connections → Connect & import** to load the demo library.
2. Open **Library** and browse your imported playlists.
3. Open any playlist to see its tracks, artwork, and snapshot history.
4. **Export** a playlist to JSON or CSV (open backups, no lock-in).
5. **Restore** a playlist — review the preflight (`confident / review / unavailable
   / unmatched`) before anything is created, and resolve unmatched tracks manually.
6. **Settings** → export everything or delete all data, one action each.

> **Troubleshooting:** if the build fails on the two SwiftData files (`@Model` /
> `@ModelActor`), you're still on Command Line Tools — redo **step 2**. Those
> macros require full Xcode. See `notes/05_known_gaps.md`.

---

## Quick start

### Core engine (no Xcode needed)

```bash
swift build                 # compile VaultVerseCore
swift test                  # run the 48-test suite
swift run vaultverse-demo   # headless: connect → import → snapshot → export → restore
```

`vaultverse-demo` prints the whole loop, including a realistic restore preflight
(`4 confident · 1 review · 1 unavailable · 1 unmatched`) and writes JSON/CSV
backups to your temp dir.

### The macOS app (needs Xcode)

```bash
brew install xcodegen
xcodegen generate           # → VaultVerse.xcodeproj (from project.yml)
open VaultVerse.xcodeproj   # build & run in Xcode (⌘R)
```

In the app: **Connections → Connect & import** loads the demo library, then browse
**Library**, open a playlist, **Export** or **Restore**.

> **Toolchain note:** this repo was developed with Command Line Tools only, so the
> Swift package + demo are verified here. The SwiftUI app's view layer (16 files)
> is type-checked against the SDK, but the two SwiftData files (`@Model` /
> `@ModelActor` macros) and the full app build require **full Xcode** — those
> macros don't ship with CLT. See `notes/05_known_gaps.md`.

---

## Going live with Apple Music

Everything is wired for it; flip the switch when you have credentials:

1. Add the **MusicKit** capability to the `VaultVerse` target (adds
   `com.apple.developer.musickit` to the entitlements).
2. Implement `LiveAppleMusicService` (it's stubbed with the exact API calls
   documented inline — MusicKit framework path *or* Apple Music REST + ES256
   developer token).
3. Point `AppEnvironment` at the live connector. No other layer changes.

---

## Security & trust

- **No audio is ever stored** — only metadata, IDs, and artwork references.
- Secrets (Music User Token, `.p8`) live **only in the Keychain**, never in the
  database, models, logs, or exports.
- **App Sandbox** on; network is used solely to cache artwork.
- **Export everything, delete everything** — both one action away in Settings.

---

## Roadmap

Live MusicKit → Spotify & YouTube connectors (same interface) → cloud sync (swap
the repository impl) → iOS/iPadOS sharing the package → Replay/Wrapped labeling &
timeline-of-taste. See `notes/06_roadmap.md`.
