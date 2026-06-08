import Foundation
import Observation
import SwiftData
import VaultVerseCore

/// Dependency container + lightweight app state. **Local-first:** the active
/// connector is either the demo library (`MockAppleMusicService`) or a real
/// exported library (`LibraryXMLConnector`), chosen via `LibrarySource` — never the
/// MusicKit-backed live connector by default. Owns the `VaultStore`, vends
/// services, and is injected into the view tree via `.environment(_:)`.
@MainActor
@Observable
final class AppEnvironment {
    let store: any VaultStore
    /// The connector backing import/restore. Swapped (with a fresh instance) when
    /// the library source changes — see `activate(source:connector:)`.
    private(set) var connector: any MusicProviderConnector
    private(set) var source: LibrarySource

    // UI state
    var isConnected = false
    var account: ConnectedAccount?
    var isImporting = false
    var importProgress: ImportProgress?
    var lastImport: ImportJob?
    var importError: String?
    var usingInMemoryFallback = false

    init(store: any VaultStore, connector: any MusicProviderConnector, source: LibrarySource = .demo, usingInMemoryFallback: Bool = false) {
        self.store = store
        self.connector = connector
        self.source = source
        self.usingInMemoryFallback = usingInMemoryFallback
    }

    static func makeDefault() -> AppEnvironment {
        var fallback = false
        let store: any VaultStore
        do {
            let container = try ModelContainer(
                for: SDTrack.self, SDPlaylist.self, SDSnapshot.self, SDSnapshotTrack.self,
                SDMapping.self, SDImportJob.self, SDRestoreJob.self, SDUnmatched.self,
                SDExport.self, SDAccount.self
            )
            store = SwiftDataVaultStore(modelContainer: container)
        } catch {
            store = InMemoryVaultStore()
            fallback = true
        }
        let source = LibrarySourceStore.load()
        return AppEnvironment(store: store, connector: makeConnector(for: source), source: source, usingInMemoryFallback: fallback)
    }

    /// Build a fresh connector for a source. The XML connector starts empty until a
    /// file is imported; any previously imported data still lives in `store`.
    private static func makeConnector(for source: LibrarySource) -> any MusicProviderConnector {
        switch source {
        case .demo:
            return (try? MockAppleMusicService()) ?? LibraryXMLConnector(parsed: .empty)
        case .appleMusicExport:
            return LibraryXMLConnector(parsed: .empty)
        }
    }

    // MARK: - Services (cheap value types; rebuilt on demand)

    var importService: PlaylistImportService { PlaylistImportService(connector: connector, store: store) }
    var restoreService: PlaylistRestoreService { PlaylistRestoreService(connector: connector, store: store) }
    var exportService: ExportService { ExportService(store: store) }
    var analyticsService: AnalyticsService { AnalyticsService(store: store) }

    // MARK: - Library source

    /// Swap in a freshly built connector for `source` and persist the choice.
    /// Services are computed from `connector`, so they pick up the new one.
    func activate(source: LibrarySource, connector: any MusicProviderConnector) {
        self.connector = connector
        self.source = source
        LibrarySourceStore.save(source)
    }

    /// Switch source without importing yet (used by the Settings picker). The XML
    /// source becomes live once the user picks a file in Connections → Import.
    func selectSource(_ source: LibrarySource) {
        guard source != self.source else { return }
        activate(source: source, connector: Self.makeConnector(for: source))
    }

    /// Load the built-in demo library and import it. Zero setup.
    func loadDemoLibrary() async {
        guard let mock = try? MockAppleMusicService() else {
            importError = VaultVerseError.seedDataMissing("demo library").localizedDescription
            return
        }
        activate(source: .demo, connector: mock)
        await connectAndImport()
    }

    /// Parse a user-selected Music "Export Library…" `.xml` and import it.
    func importAppleMusicExport(url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let connector = try LibraryXMLConnector(data: data)
            activate(source: .appleMusicExport, connector: connector)
            await connectAndImport()
        } catch {
            importError = error.localizedDescription
        }
    }

    // MARK: - Actions

    func refreshConnection() async {
        if let account = try? await store.account(provider: .appleMusic) {
            self.account = account
            self.isConnected = account.status == .connected
        }
    }

    func connectAndImport() async {
        guard !isImporting else { return }
        isImporting = true
        importProgress = nil
        importError = nil
        defer { isImporting = false }
        do {
            let job = try await importService.run { [weak self] progress in
                Task { @MainActor in self?.importProgress = progress }
            }
            lastImport = job
            await refreshConnection()
        } catch {
            lastImport = nil
            importError = error.localizedDescription
        }
    }

    func disconnect() async {
        guard var account = try? await store.account(provider: .appleMusic) else { return }
        account.status = .disconnected
        try? await store.upsertAccount(account)
        await refreshConnection()
    }

    func deleteAllData() async {
        try? await store.deleteAllData()
        account = nil
        isConnected = false
        lastImport = nil
    }
}
