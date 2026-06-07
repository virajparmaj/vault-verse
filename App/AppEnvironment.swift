import Foundation
import Observation
import SwiftData
import VaultVerseCore

/// Dependency container + lightweight app state. Chooses the provider connector
/// (mock now, live later), owns the `VaultStore`, and vends services. Injected
/// into the view tree via `.environment(_:)`.
@MainActor
@Observable
final class AppEnvironment {
    enum ProviderMode: String, CaseIterable { case mock = "Demo data", live = "Live Apple Music" }

    let store: any VaultStore
    private(set) var connector: any MusicProviderConnector
    var providerMode: ProviderMode

    // UI state
    var isConnected = false
    var account: ConnectedAccount?
    var isImporting = false
    var importProgress: ImportProgress?
    var lastImport: ImportJob?
    var usingInMemoryFallback = false

    init(store: any VaultStore, connector: any MusicProviderConnector, providerMode: ProviderMode, usingInMemoryFallback: Bool = false) {
        self.store = store
        self.connector = connector
        self.providerMode = providerMode
        self.usingInMemoryFallback = usingInMemoryFallback
    }

    static func makeDefault() -> AppEnvironment {
        var fallback = false
        let store: any VaultStore
        do {
            // Variadic convenience initializer — most robust across SwiftData versions.
            let container = try ModelContainer(
                for: SDTrack.self, SDPlaylist.self, SDSnapshot.self, SDSnapshotTrack.self,
                SDMapping.self, SDImportJob.self, SDRestoreJob.self, SDUnmatched.self,
                SDExport.self, SDAccount.self
            )
            store = SwiftDataVaultStore(modelContainer: container)
        } catch {
            // Keep the app usable even if the SwiftData store can't be created.
            store = InMemoryVaultStore()
            fallback = true
        }
        let connector: any MusicProviderConnector = (try? MockAppleMusicService(latency: .milliseconds(120)))
            ?? LiveAppleMusicService()
        return AppEnvironment(store: store, connector: connector, providerMode: .mock, usingInMemoryFallback: fallback)
    }

    // MARK: - Services (cheap value types; rebuilt on demand)

    var importService: PlaylistImportService { PlaylistImportService(connector: connector, store: store) }
    var restoreService: PlaylistRestoreService { PlaylistRestoreService(connector: connector, store: store) }
    var exportService: ExportService { ExportService(store: store) }
    var analyticsService: AnalyticsService { AnalyticsService(store: store) }

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
        defer { isImporting = false }
        do {
            let job = try await importService.run { [weak self] progress in
                Task { @MainActor in self?.importProgress = progress }
            }
            lastImport = job
            await refreshConnection()
        } catch {
            lastImport = nil
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
