# VaultVerse

**Your music memory, permanently archived.**

VaultVerse is a native macOS app that backs up, versions, and restores your music
playlists. Streaming subscriptions come and go — your playlists, yearly replays,
and music identity shouldn't. VaultVerse is a permanent, local-first vault for
playlist structures, track metadata, artwork references, ISRCs, platform IDs, and
versioned snapshots.

> VaultVerse is **not** a streaming app. It stores playlist *structure and
> metadata only* — never audio files, never a way around DRM.

VaultVerse is **local-first**: it runs on **any Mac with no paid Apple Developer
account, no MusicKit entitlement, and no code signing**. Start with built-in
**demo data** (zero setup), or import your **real library** from a Music
"Export Library…" `.xml` — both connectors work entirely on your machine with no
account. (A MusicKit live connector exists behind the same interface but is
**deferred and paid-only**; see the bottom of this README.)

---

## What works today

The complete core loop, end-to-end:

**Load demo *or* import your real `Library.xml` → save metadata/order/artwork
locally → version as snapshots → browse the vault → export JSON/CSV → restore to a
re-importable file (with preflight + manual match resolution) → review report.**

Highlights:
- **Two local sources** — built-in demo data, or your real library from a Music
  "Export Library…" `.xml`. No account, no MusicKit, no signing.
- **Versioned snapshots** — re-importing never overwrites; it appends a new,
  checksummed version. "No material change" is detected and skipped.
- **ISRC-first track matching** with a 0–100 confidence ladder and fuzzy fallback.
- **Careful restore** — a no-writes *preflight* shows `confident / review /
  unavailable / unmatched`, then VaultVerse builds a re-importable **`.m3u` + JSON**
  you can drop back into Music. Nothing is written to Apple Music.
- **Manual match memory** — resolve a track once and it's remembered forever.
- **Open exports** — full JSON backup + human-readable CSV + M3U. No lock-in.
- **Local-first & private** — single user, offline after import, Keychain for any
  secrets, one-tap "delete all data".

---

## Architecture

Two layers:

| Layer | What | Build/test |
|---|---|---|
| **`VaultVerseCore`** (Swift Package) | All product logic: models, provider connectors, services (import / match / snapshot / restore / export / analytics), repositories. Provider-neutral. | `swift build` / `swift test` — **fully tested (56 tests)** |
| **`VaultVerse`** (Xcode app) | SwiftUI UI + SwiftData persistence. Thin shell over the package. | Requires **Xcode** (`xcodegen` + build) |

The connector abstraction (`MusicProviderConnector`) is the seam that keeps one
neutral internal format while supporting many sources. Two local connectors ship
today — `MockAppleMusicService` (demo) and `LibraryXMLConnector` (real exported
`Library.xml`); `LiveAppleMusicService` (MusicKit) is deferred/paid. Spotify/YouTube
conform later without touching services or UI.

```
vault-verse/
├── Package.swift                 # VaultVerseCore + vaultverse-demo + tests
├── Sources/VaultVerseCore/       # Models, Providers, Services, Persistence, Security, Support
├── Sources/vaultverse-demo/      # headless core-loop walkthrough
├── Tests/VaultVerseCoreTests/    # 56 unit + integration tests (swift-testing)
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
2. Press **⌘R** to build and run. No signing is required — VaultVerse needs no
   MusicKit entitlement and no paid Apple Developer account.

Prefer the command line? Build an unsigned app without opening Xcode:

```bash
xcodebuild -project VaultVerse.xcodeproj -scheme VaultVerse \
  -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
# → build/Build/Products/Release/VaultVerse.app
```

### 5. Operate the app

VaultVerse is local-first — no account needed for either source.

1. Go to **Connections** and choose a source:
   - **Load demo library** — realistic sample data, zero setup; or
   - **Import from Apple Music export (.xml)** — your real library (see below).
2. Open **Library** and browse your imported playlists.
3. Open any playlist to see its tracks, artwork, and snapshot history.
4. **Export** a playlist to JSON or CSV (open backups, no lock-in).
5. **Restore** a playlist — review the preflight (`confident / review / unavailable
   / unmatched`), then VaultVerse builds a re-importable **`.m3u` + JSON**. Import
   the `.m3u` back into Music with **File → Import…**. Nothing is written to Apple Music.
6. **Settings** → switch library source, export everything, or delete all data.

#### Import your real Apple Music library

1. Open the **Music** app on your Mac.
2. Menu bar → **File → Library → Export Library…**
3. Save the `.xml` somewhere you can find it.
4. In VaultVerse: **Connections → Import from Apple Music export (.xml)** → choose that file.

> **Troubleshooting:** if the build fails on the two SwiftData files (`@Model` /
> `@ModelActor`), you're still on Command Line Tools — redo **step 2**. Those
> macros require full Xcode. See `notes/05_known_gaps.md`.

---

## Quick start

### Core engine (no Xcode needed)

```bash
swift build                 # compile VaultVerseCore
swift test                  # run the 56-test suite
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

In the app: **Connections → Load demo library** (or **Import from Apple Music
export (.xml)**), then browse **Library**, open a playlist, **Export** or **Restore**.

> **Toolchain note:** the Swift package + demo build/test with Command Line Tools.
> The full app build (SwiftData `@Model` / `@ModelActor` macros) requires **full
> Xcode**. The app builds **unsigned** with no MusicKit entitlement (see the
> `xcodebuild … CODE_SIGNING_ALLOWED=NO` command above). See `notes/05_known_gaps.md`.

---

## Live Apple Music write-back (deferred — paid only)

VaultVerse never writes back to Apple Music on the default, local-first path; that
capability is **optional and requires a paid Apple Developer membership**.
`LiveAppleMusicService` is already implemented behind `#if canImport(MusicKit)` and
stays inert (`providerNotConfigured`) until you opt in. To enable it later:

1. Add the **MusicKit** capability to the `VaultVerse` target (re-adds
   `com.apple.developer.musickit` to the entitlements) — this needs a provisioning
   profile with the MusicKit service, i.e. a **paid** membership.
2. Construct `LiveAppleMusicService()` explicitly and route a connector at it
   (it's opt-in; the app never selects it by default). No other layer changes.

---

## Security & trust

- **No audio is ever stored** — only metadata, IDs, and artwork references.
- Secrets (Music User Token, `.p8`) live **only in the Keychain**, never in the
  database, models, logs, or exports.
- **App Sandbox** on; network is used solely to cache artwork.
- **Export everything, delete everything** — both one action away in Settings.

---

## Roadmap

Persist imported `.xml` access (security-scoped bookmark) → Spotify & YouTube
connectors (same interface) → live Apple Music write-back (deferred, paid) → cloud
sync (swap the repository impl) → iOS/iPadOS sharing the package → Replay/Wrapped
labeling & timeline-of-taste. See `notes/06_roadmap.md`.
