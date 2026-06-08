import SwiftUI
import VaultVerseCore

struct LibraryView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var rows: [Row] = []
    @State private var loaded = false

    struct Row: Identifiable {
        let playlist: Playlist
        let snapshotCount: Int
        let readiness: Int
        var id: String { playlist.id }
    }

    private let columns = [GridItem(.adaptive(minimum: 340), spacing: 16)]

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty && loaded {
                    EmptyStateView(systemImage: "square.stack",
                                   title: "No playlists archived yet",
                                   message: "Import from Apple Music to fill your vault.")
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(rows) { row in
                                NavigationLink(value: row.playlist) {
                                    PlaylistCard(playlist: row.playlist, snapshotCount: row.snapshotCount, readinessPercent: row.readiness)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(24)
                    }
                }
            }
            .navigationTitle("Library")
            .navigationDestination(for: Playlist.self) { playlist in
                PlaylistDetailView(playlistId: playlist.id)
            }
            .background(VaultTheme.deepCocoa)
        }
        .task { await load() }
    }

    private func load() async {
        let playlists = ((try? await env.store.allPlaylists()) ?? []).sorted { $0.title < $1.title }
        var result: [Row] = []
        for playlist in playlists {
            let snapshots = (try? await env.store.snapshots(forPlaylist: playlist.id))?.count ?? 0
            let readiness = (try? await env.analyticsService.restoreReadiness(playlistId: playlist.id))?.percent ?? 0
            result.append(Row(playlist: playlist, snapshotCount: snapshots, readiness: readiness))
        }
        rows = result
        loaded = true
    }
}
