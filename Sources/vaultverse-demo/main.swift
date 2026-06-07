import Foundation
import VaultVerseCore

// Headless walkthrough of the VaultVerse core loop, driven by the mock Apple
// Music connector + in-memory store. This is the runnable proof that
// connect → import → snapshot → export → restore works end-to-end without Xcode
// or any Apple credentials. The SwiftUI app wires the same services to a UI.

func hr(_ title: String) {
    print("\n\u{001B}[1m== \(title) ==\u{001B}[0m")
}

func runDemo() async throws {
    let store = InMemoryVaultStore()
    let connector = try MockAppleMusicService()

    // 1) IMPORT ---------------------------------------------------------------
    hr("1. Connect Apple Music (mock) & import")
    let importer = PlaylistImportService(connector: connector, store: store)
    let importJob = try await importer.run { progress in
        if let name = progress.currentPlaylistName {
            print("  importing [\(progress.processedPlaylists + 1)/\(progress.totalPlaylists)] \(name)")
        }
    }
    print("  → status: \(importJob.status.rawValue), playlists: \(importJob.playlistsImported), snapshots: \(importJob.snapshotsCreated), tracks: \(importJob.tracksImported)")

    // 2) DASHBOARD ------------------------------------------------------------
    hr("2. Vault dashboard")
    let analytics = AnalyticsService(store: store)
    let summary = try await analytics.dashboardSummary()
    print("  playlists archived : \(summary.totalPlaylists)")
    print("  distinct tracks    : \(summary.totalTracks)")
    print("  snapshots          : \(summary.totalSnapshots)")
    print("  restore readiness  : \(summary.restoreReadinessPercent)% (\(summary.mappedTracks) ready)")
    print("  largest playlist   : \(summary.largestPlaylistTitle ?? "—") (\(summary.largestPlaylistTrackCount ?? 0))")
    let topArtists = try await analytics.topArtists(limit: 5)
    print("  top artists        : " + topArtists.map { "\($0.name) (\($0.count))" }.joined(separator: ", "))
    let recurring = try await analytics.songsInMultiplePlaylists()
    print("  cross-playlist hits: " + (recurring.isEmpty ? "—" : recurring.map { "\($0.title) ×\($0.playlistCount)" }.joined(separator: ", ")))

    // Pick the "Summer 2024" playlist for the rest of the demo.
    let playlists = try await store.allPlaylists()
    guard let summer = playlists.first(where: { $0.title == "Summer 2024" }),
          let snapshot = try await store.latestSnapshot(forPlaylist: summer.id) else {
        print("  (Summer 2024 not found)")
        return
    }

    hr("3. Playlist detail — \(summer.title)")
    let tracks = try await store.snapshotTracks(snapshotId: snapshot.id)
    for track in tracks {
        print(String(format: "  %2d. %@ — %@", track.position + 1, track.title, track.artistName))
    }

    // 4) EXPORT ---------------------------------------------------------------
    hr("4. Export backup (JSON + CSV)")
    let exporter = ExportService(store: store)
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vaultverse-demo", isDirectory: true)
    let json = try await exporter.exportJSONData(playlistId: summer.id)
    let (_, jsonURL) = try await exporter.writeAndRecord(data: json, format: .json, playlistId: summer.id, snapshotId: nil, suggestedName: "Summer 2024 backup", directory: dir)
    let csv = try await exporter.exportSnapshotCSVData(snapshotId: snapshot.id)
    let (_, csvURL) = try await exporter.writeAndRecord(data: csv, format: .csv, playlistId: summer.id, snapshotId: snapshot.id, suggestedName: "Summer 2024 tracks", directory: dir)
    print("  JSON: \(jsonURL.path) (\(json.count) bytes)")
    print("  CSV : \(csvURL.path) (\(csv.count) bytes)")

    // 5) RESTORE PREFLIGHT ----------------------------------------------------
    hr("5. Restore preflight → Apple Music")
    let restorer = PlaylistRestoreService(connector: connector, store: store)
    let preflight = try await restorer.preflight(snapshotId: snapshot.id, targetProvider: .appleMusic)
    print("  \(preflight.summary)")
    for item in preflight.items.sorted(by: { $0.position < $1.position }) {
        let badge = item.score.map { " [\($0)]" } ?? ""
        print("  • \(item.title) — \(item.outcome.rawValue)\(badge)\(item.reason.map { " — \($0)" } ?? "")")
    }

    // 6) RESOLVE the low-confidence match (manual match memory) ---------------
    hr("6. Resolve the 'needs review' track")
    let unmatched = try await store.unmatched(forRestoreJob: preflight.restoreJobId)
    if let review = unmatched.first(where: { $0.reason.localizedCaseInsensitiveContains("review") }),
       let pick = review.suggestedMatches.first {
        print("  '\(review.title)' → choosing suggestion '\(pick.title)' (\(pick.confidenceScore))")
        try await restorer.resolveMatch(restoreJobId: preflight.restoreJobId, unmatchedTrackId: review.id, chosenProviderTrackId: pick.providerTrackId, providerURI: pick.providerURI)
        print("  ✓ saved as a permanent manual match")
    } else {
        print("  (no review item to resolve)")
    }

    // 7) CONFIRM & RESTORE ----------------------------------------------------
    hr("7. Confirm restore")
    let report = try await restorer.confirm(restoreJobId: preflight.restoreJobId)
    print("  created playlist : \(report.createdPlaylistName ?? "—")")
    print("  restored         : \(report.restored)/\(report.total)")
    print("  skipped          : \(report.skipped)")
    print("  failed           : \(report.failed)")
    if let missing = report.missingTracksCSVPath { print("  missing CSV      : \(missing)") }

    hr("Done")
    print("VaultVerse core loop verified: connect → import → snapshot → export → restore ✅")
}

do {
    try await runDemo()
} catch {
    print("Demo failed: \(error)")
    exit(1)
}
