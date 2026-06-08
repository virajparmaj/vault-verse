import SwiftUI
import VaultVerseCore

struct DashboardView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var summary: DashboardSummary?
    @State private var topArtists: [NamedCount] = []
    @State private var topAlbums: [NamedCount] = []
    @State private var recurring: [RecurringTrack] = []
    @State private var hoveredInsight: String?

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
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RecordDot(diameter: 8)
                Text("Your playlists are safe, even when your subscriptions are not.")
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .foregroundStyle(VaultTheme.warmCream)
            }
            Text("VaultVerse archives playlist names, artwork, track order, artists, albums, and platform IDs. It never stores music files.")
                .font(.subheadline).foregroundStyle(VaultTheme.mutedTan)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(VaultTheme.cocoaMid)
                VinylGrooveArcs()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(VaultTheme.brushedBronze, lineWidth: 1))
    }

    private func statsGrid(_ summary: DashboardSummary) -> some View {
        LazyVGrid(columns: columns, spacing: 14) {
            StatTile(title: "Playlists", value: "\(summary.totalPlaylists)", systemImage: "square.stack")
            StatTile(title: "Tracks", value: "\(summary.totalTracks)", systemImage: "music.note.list")
            StatTile(title: "Snapshots", value: "\(summary.totalSnapshots)", systemImage: "clock.arrow.circlepath")
            VStack(alignment: .leading, spacing: 8) {
                Text("RESTORE READINESS").font(.caption2.weight(.semibold)).foregroundStyle(VaultTheme.mutedTan)
                HStack {
                    ReadinessRing(percent: summary.restoreReadinessPercent, size: 54)
                    VStack(alignment: .leading) {
                        Text("\(summary.mappedTracks) ready").font(.subheadline.weight(.semibold)).foregroundStyle(VaultTheme.warmCream)
                        Text("to restore").font(.caption).foregroundStyle(VaultTheme.mutedTan)
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
            listCard(title: "Top artists", accessory: AnyView(EqualizerBarsIcon()),
                     items: topArtists.map { ($0.name, "\($0.count)") }, empty: "No artists yet")
            listCard(title: "Appears in multiple playlists", accessory: AnyView(VinylIcon()),
                     items: recurring.map { ($0.title, "×\($0.playlistCount)") }, empty: "No cross-playlist songs yet")
        }
    }

    private func listCard(title: String, accessory: AnyView, items: [(String, String)], empty: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title).font(.headline).foregroundStyle(VaultTheme.warmCream)
                accessory
                Spacer()
            }
            if items.isEmpty {
                Text(empty).font(.caption).foregroundStyle(VaultTheme.mutedTan)
            } else {
                ForEach(Array(items.prefix(8).enumerated()), id: \.offset) { index, item in
                    let key = "\(title)#\(index)"
                    HStack(spacing: 6) {
                        Text("♪").font(.caption).foregroundStyle(VaultTheme.cherryPink)
                            .opacity(hoveredInsight == key ? 1 : 0).frame(width: 12, alignment: .leading)
                        Text(item.0).font(.subheadline).foregroundStyle(VaultTheme.warmCream).lineLimit(1)
                        Spacer()
                        Text(item.1).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(VaultTheme.mutedTan)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in hoveredInsight = hovering ? key : (hoveredInsight == key ? nil : hoveredInsight) }
                    Divider().overlay(VaultTheme.divider)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.15), value: hoveredInsight)
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
                Label(env.isImporting ? "Importing…" : "Connect & import playlists", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderedProminent)
            .disabled(env.isImporting)
        }
        .background { Watermark(kind: .vinyl, size: 200) }
        .vaultCard(padding: 24)
    }

    private func load() async {
        summary = try? await env.analyticsService.dashboardSummary()
        topArtists = (try? await env.analyticsService.topArtists(limit: 8)) ?? []
        topAlbums = (try? await env.analyticsService.topAlbums(limit: 8)) ?? []
        recurring = (try? await env.analyticsService.songsInMultiplePlaylists()) ?? []
    }
}
