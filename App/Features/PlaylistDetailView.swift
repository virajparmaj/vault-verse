import SwiftUI
import VaultVerseCore

struct PlaylistDetailView: View {
    @Environment(AppEnvironment.self) private var env
    let playlistId: String

    @State private var playlist: Playlist?
    @State private var snapshots: [PlaylistSnapshot] = []
    @State private var selectedSnapshotId: String?
    @State private var rows: [TrackRow] = []
    @State private var alertMessage: String?

    struct TrackRow: Identifiable {
        let snapshotTrack: SnapshotTrack
        let confidence: Int?
        var id: String { snapshotTrack.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(VaultTheme.hairline)
            if rows.isEmpty {
                EmptyStateView(systemImage: "music.note.list", title: "No tracks in this snapshot", message: "This version of the playlist has no tracks.")
            } else {
                trackTable
            }
        }
        .background(VaultTheme.offWhite)
        .navigationTitle(playlist?.title ?? "Playlist")
        .task { await load() }
        .alert("Export", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                ArtworkThumbnail(url: playlist?.artworkURL, title: playlist?.title ?? "", size: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(playlist?.title ?? "—").font(.system(.title2, design: .rounded).weight(.semibold))
                    if let description = playlist?.description {
                        Text(description).font(.subheadline).foregroundStyle(VaultTheme.mutedGrey).lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        if let provider = playlist?.sourceProvider { ProviderBadge(provider: provider) }
                        Text("\(playlist?.trackCount ?? 0) tracks").font(.caption).foregroundStyle(VaultTheme.mutedGrey)
                        Text("· \(snapshots.count) snapshots").font(.caption).foregroundStyle(VaultTheme.mutedGrey)
                    }
                }
                Spacer()
            }
            HStack(spacing: 10) {
                snapshotPicker
                Spacer()
                actions
            }
        }
        .padding(20)
        .background(VaultTheme.brushedMetal)
    }

    private var snapshotPicker: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath").foregroundStyle(VaultTheme.mutedGrey)
            Picker("Snapshot", selection: Binding(get: { selectedSnapshotId ?? "" }, set: { newValue in
                selectedSnapshotId = newValue
                Task { await loadTracks() }
            })) {
                ForEach(snapshots) { snapshot in
                    Text(snapshotLabel(snapshot)).tag(snapshot.id)
                }
            }
            .labelsHidden()
            .frame(maxWidth: 260)
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            if let snapshotId = selectedSnapshotId {
                NavigationLink {
                    RestoreFlowView(snapshotId: snapshotId, playlistTitle: playlist?.title ?? "Playlist")
                } label: { Label("Restore", systemImage: "arrow.uturn.backward.circle") }
                    .buttonStyle(.borderedProminent)
            }
            if snapshots.count >= 2 {
                NavigationLink {
                    SnapshotCompareView(playlistId: playlistId)
                } label: { Label("Compare", systemImage: "arrow.left.arrow.right") }
            }
            Menu {
                Button("Export JSON backup") { Task { await export(.json) } }
                Button("Export CSV tracklist") { Task { await export(.csv) } }
            } label: { Label("Export", systemImage: "square.and.arrow.up") }
        }
    }

    private var trackTable: some View {
        Table(rows) {
            TableColumn("#") { row in
                Text("\(row.snapshotTrack.position + 1)").foregroundStyle(VaultTheme.mutedGrey).monospacedDigit()
            }
            .width(34)
            TableColumn("Title") { row in Text(row.snapshotTrack.title) }
            TableColumn("Artist") { row in Text(row.snapshotTrack.artistName) }
            TableColumn("Album") { row in Text(row.snapshotTrack.albumName ?? "—").foregroundStyle(VaultTheme.mutedGrey) }
            TableColumn("Time") { row in Text(formatDuration(row.snapshotTrack.durationMs)).monospacedDigit() }
                .width(56)
            TableColumn("Mapping") { row in
                if let confidence = row.confidence {
                    MappingConfidenceBadge(score: confidence)
                } else {
                    Text("local").font(.caption2).foregroundStyle(VaultTheme.mutedGrey)
                }
            }
            .width(72)
        }
    }

    private func snapshotLabel(_ snapshot: PlaylistSnapshot) -> String {
        let date = snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)
        if let summary = snapshot.changeSummary, !summary.isNoMaterialChange {
            return "\(date)"
        }
        return date
    }

    private func load() async {
        playlist = try? await env.store.playlist(id: playlistId)
        snapshots = (try? await env.store.snapshots(forPlaylist: playlistId)) ?? []
        selectedSnapshotId = snapshots.last?.id
        await loadTracks()
    }

    private func loadTracks() async {
        guard let snapshotId = selectedSnapshotId else { rows = []; return }
        let snapshotTracks = (try? await env.store.snapshotTracks(snapshotId: snapshotId)) ?? []
        var result: [TrackRow] = []
        for snapshotTrack in snapshotTracks {
            let mapping = try? await env.store.mapping(trackId: snapshotTrack.trackId, provider: .appleMusic)
            result.append(TrackRow(snapshotTrack: snapshotTrack, confidence: mapping?.confidenceScore))
        }
        rows = result
    }

    private func export(_ format: ExportFormat) async {
        do {
            let data: Data
            let snapshotId: String?
            switch format {
            case .json:
                data = try await env.exportService.exportJSONData(playlistId: playlistId)
                snapshotId = nil
            case .csv:
                guard let selected = selectedSnapshotId else { return }
                data = try await env.exportService.exportSnapshotCSVData(snapshotId: selected)
                snapshotId = selected
            case .m3u:
                return
            }
            let name = "\(playlist?.title ?? "playlist") \(format.rawValue)"
            let result = try await env.exportService.writeAndRecord(data: data, format: format, playlistId: playlistId, snapshotId: snapshotId, suggestedName: name)
            alertMessage = "Saved to \(result.url.path)"
            revealInFinder(result.url.path)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
