# 01 — Architecture

Two layers, split by what can be built/tested without Xcode.

## `VaultVerseCore` (Swift Package — all product logic)
- **Models/** — immutable value-type domain structs + enums.
- **Providers/** — `MusicProviderConnector` protocol + DTOs; `MockAppleMusicService`
  (seed-data backed) and `LiveAppleMusicService` (stub).
- **Services/** — `TrackNormalizer`, `TrackMatchingService`, `PlaylistImportService`,
  `SnapshotService`, `PlaylistRestoreService`, `ExportService`, `AnalyticsService`.
- **Persistence/** — repository protocols (`VaultStore`) + `InMemoryVaultStore`
  (reference impl, used by tests + demo).
- **Security/** — `KeychainStore`. **Support/** — errors, checksum, similarity, artwork cache.

Everything here is provider-neutral and fully unit-testable via `swift test`.

## `VaultVerse` (Xcode app — thin UI shell)
- **Persistence/** — `SwiftDataVaultStore` (`@ModelActor`) implementing `VaultStore`,
  plus `@Model` entities + mappers to/from domain structs.
- **AppEnvironment** — `@Observable` DI container; picks the connector (mock now),
  owns the store, vends services. Falls back to `InMemoryVaultStore` if SwiftData
  can't initialize.
- **Features/**, **Components/**, **Theme/** — SwiftUI, `NavigationSplitView` shell.

## Key decisions & trade-offs
- **Protocol-first connectors** so providers are pluggable without touching
  services/UI. The neutral DTOs decouple the vault from provider quirks.
- **Repository seam** vends domain structs only; persistence types never leak.
  This is the swap point for SwiftData ⇄ in-memory ⇄ future cloud sync.
- **Actors** for the store and mock connector → safe concurrency, clean `async`.
- **swift-testing** (not XCTest): XCTest isn't in Command Line Tools; swift-testing is.
- **Domain models are immutable value types**; services build new values and hand
  them to the repository (no shared mutable state).
