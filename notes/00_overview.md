# 00 — Overview

**VaultVerse** is a native macOS (SwiftUI) app: a permanent, local-first vault for
music playlists. It backs up playlist structure + metadata (never audio), versions
it over time as snapshots, and restores it back into a music platform.

## First-pass scope (this build)
- **Local-first, Apple Music–shaped.** Two zero-account connectors: **demo data**
  (mock) and a **real library** imported from a Music "Export Library…" `.xml`.
- Proves the full loop: import → snapshot → vault → export → restore (to a
  re-importable file). Runs on any Mac with **no paid account, no MusicKit, no
  signing**.
- Live MusicKit write-back is **deferred and paid-only** — compiled but inert,
  never the default connector.
- **Out of scope now:** Spotify, YouTube, web app, cloud auth/DB, live Apple Music
  write-back.

## Why it exists
Subscriptions lapse; accounts get lost; people switch countries and platforms.
The playlists and "music identity" remain personally valuable. VaultVerse keeps
them safe and portable regardless of any subscription.

## Core principles
1. Never store audio; never bypass DRM.
2. Normalize tracks internally; map provider IDs externally (a song outlives any
   single platform ID).
3. Every import is a new **snapshot**, never an overwrite.
4. Restore is **transparent**: preflight before producing a re-importable file.
5. **Open data**: export/delete everything, anytime; restore output is a plain
   `.m3u` + JSON you own.

## Status
- `VaultVerseCore` package: complete + 56 passing tests.
- `vaultverse-demo`: runnable headless proof of the loop.
- SwiftUI app + SwiftData store: builds unsigned in Xcode with **no MusicKit
  entitlement** (see `05_known_gaps.md`).
