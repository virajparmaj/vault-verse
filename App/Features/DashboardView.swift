import SwiftUI
import VaultVerseCore

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var summary: DashboardSummary?
    @State private var topArtists: [NamedCount] = []
    @State private var topAlbums: [NamedCount] = []
    @State private var recurring: [RecurringTrack] = []

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                hero
                if let summary, summary.totalPlaylists > 0 {
                    statsGrid(summary)
                    insights
                } else {
                    emptyArchive
                }
            }
            .padding(28)
        }
        .navigationTitle("Dashboard")
        .task(id: env.lastImport?.id) { await load() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your playlists are safe, even when your subscriptions are not.")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .foregroundStyle(VaultTheme.graphite)
            Text("VaultVerse archives playlist names, artwork, track order, artists, albums, and platform IDs. It never stores music files.")
                .font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statsGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            StatTile(title: "Playlists", value: "\(summary.totalPlaylists)", systemImage: "square.stack")
            StatTile(title: "Tracks", value: "\(summary.totalTracks)", systemImage: "music.note.list")
            StatTile(title: "Snapshots", value: "\(summary.totalSnapshots)", systemImage: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 8) {
                Text("RESTORE READINESS").font(.caption2.weight(.semibold)).foregroundStyle(VaultTheme.mutedGrey)
                HStack {
                    ReadinessRing(percent: summary.restoreReadinessPercent, size: 54)
                    VStack(alignment: .leading) {
                        Text("\(summary.mappedTracks) ready").font(.subheadline.weight(.semibold))
                        Text("to restore").font(.caption).foregroundStyle(VaultTheme.mutedGrey)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .vaultCard()
            StatTile(title: "Needs review", value: "\(summary.unresolvedUnmatchedCount)", systemImage: "questionmark.diamond")
            StatTile(title: "Last backup", value: summary.lastBackupDate.map(PlaylistCard.relative) ?? "—", systemImage: "externaldrive.badge.checkmark")
            StatTile(title: "Largest", value: summary.largestPlaylistTitle ?? "—", systemImage: "chart.bar")
            StatTile(title: "Oldest", value: summary.oldestPlaylistTitle ?? "—", systemImage: "calendar")
        }
    }

    private var insights: some View {
        HStack(alignment: .top, spacing: 14) {
            listCard(title: "Top artists", items: topArtists.map { ($0.name, "\($0.count)") }, empty: "No artists yet")
            listCard(title: "Appears in multiple playlists", items: recurring.map { ($0.title, "×\($0.playlistCount)") }, empty: "No cross-playlist songs yet")
        }
    }

    private func listCard(title: String, items: [(String, String)], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            if items.isEmpty {
                Text(empty).font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            } else {
                ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { _, item in
                    HStack {
                        Text(item.0).font(.subheadline).foregroundStyle(VaultTheme.graphite).lineLimit(1)
                        Spacer()
                        Text(item.1).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(VaultTheme.mutedGrey)
                    }
                    Divider().overlay(VaultTheme.hairline)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    private var emptyArchive: some View {
        VStack(spacing: 14) {
            EmptyStateView(
                systemImage: "tray.and.arrow.down",
                title: "Your vault is empty",
                message: "Connect Apple Music and import your playlists to start your permanent archive."
            )
            Button {
                Task { await env.connectAndImport(); await load() }
            } label: {
                Label(env.isImporting ? "Importing…" : "Connect & import (demo)", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(env.isImporting)
        }
        .vaultCard(padding: 24)
    }

    private func load() async {
        summary = try? await env.analyticsService.dashboardSummary()
        topArtists = (try? await env.analyticsService.topArtists(limit: 8)) ?? []
        topAlbums = (try? await env.analyticsService.topAlbums(limit: 8)) ?? []
        recurring = (try? await env.analyticsService.songsInMultiplePlaylists()) ?? []
    }
}
