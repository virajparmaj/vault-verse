import SwiftUI
import VaultVerseCore

/// "Restore My Library" — the emergency restore hub for re-subscribing / switching.
struct RestoreView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var entries: [Entry] = []
    @State private var loaded = false

    struct Entry: Identifiable {
        let playlist: Playlist
        let snapshotId: String
        let readiness: Int
        var id: String { playlist.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Restore my library").font(.system(.title2, design: .rounded).weight(.semibold))
                        Text("Rebuild playlists into Apple Music after resubscribing or switching devices. VaultVerse checks every song before creating anything.")
                            .font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
                    }
                    if entries.isEmpty && loaded {
                        EmptyStateView(systemImage: "arrow.uturn.backward.circle", title: "Nothing to restore yet", message: "Import some playlists first.")
                    } else {
                        ForEach(entries) { entry in
                            NavigationLink {
                                RestoreFlowView(snapshotId: entry.snapshotId, playlistTitle: entry.playlist.title)
                            } label: {
                                row(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Restore")
            .background(VaultTheme.offWhite)
        }
        .task { await load() }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: entry.playlist.artworkURL, title: entry.playlist.title, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.playlist.title).font(.headline).foregroundStyle(VaultTheme.graphite)
                Text("\(entry.playlist.trackCount) tracks · restore readiness \(entry.readiness)%")
                    .font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            }
            Spacer()
            ReadinessRing(percent: entry.readiness, size: 44)
            Image(systemName: "chevron.right").foregroundStyle(VaultTheme.brushedSilver)
        }
        .vaultCard()
    }

    private func load() async {
        let playlists = ((try? await env.store.allPlaylists()) ?? []).sorted { $0.trackCount > $1.trackCount }
        var result: [Entry] = []
        for playlist in playlists {
            guard let snapshot = try? await env.store.latestSnapshot(forPlaylist: playlist.id) else { continue }
            let readiness = (try? await env.analyticsService.restoreReadiness(playlistId: playlist.id))?.percent ?? 0
            result.append(Entry(playlist: playlist, snapshotId: snapshot.id, readiness: readiness))
        }
        entries = result
        loaded = true
    }
}
