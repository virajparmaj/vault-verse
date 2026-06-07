# 00 — Overview

**VaultVerse** is a native macOS (SwiftUI) app: a permanent, local-first vault for
music playlists. It backs up playlist structure + metadata (never audio), versions
it over time as snapshots, and restores it back into a music platform.

## First-pass scope (this build)
- **Apple Music only**, **mock connector** with realistic demo data.
- Proves the full loop: connect → import → snapshot → vault → export → restore.
- Live MusicKit is **stubbed behind the same interface**, not implemented.
- **Out of scope now:** Spotify, YouTube, web app, cloud auth/DB, live Apple creds.

## Why it exists
Subscriptions lapse; accounts get lost; people switch countries and platforms.
The playlists and "music identity" remain personally valuable. VaultVerse keeps
them safe and portable regardless of any subscription.

## Core principles
1. Never store audio; never bypass DRM.
2. Normalize tracks internally; map provider IDs externally (a song outlives any
   single platform ID).
3. Every import is a new **snapshot**, never an overwrite.
4. Restore is **transparent**: preflight before any write.
5. **Open data**: export/delete everything, anytime.

## Status
- `VaultVerseCore` package: complete + 48 passing tests.
- `vaultverse-demo`: runnable headless proof of the loop.
- SwiftUI app + SwiftData store: complete, builds in Xcode (see `05_known_gaps.md`).
