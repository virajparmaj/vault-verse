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
                        Text("Restore my library").font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(VaultTheme.warmCream)
                        Text("Rebuild a playlist as a re-importable file you can drop back into Music (File → Import\u{2026}). VaultVerse checks every song first — nothing is written to Apple Music.")
                            .font(.subheadline).foregroundStyle(VaultTheme.mutedTan)
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
            .background(VaultTheme.deepCocoa)
        }
        .task { await load() }
    }

    private func row(_ entry: Entry) -> some View {
        HStack(spacing: 14) {
            ArtworkThumbnail(url: entry.playlist.artworkURL, title: entry.playlist.title, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.playlist.title).font(.headline).foregroundStyle(VaultTheme.warmCream)
                Text("\(entry.playlist.trackCount) tracks · restore readiness \(entry.readiness)%")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            }
            Spacer()
            ReadinessRing(percent: entry.readiness, size: 44)
            Watermark(kind: .rewind, size: 26)
            Image(systemName: "chevron.right").foregroundStyle(VaultTheme.cherryPink)
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
