import SwiftUI
import VaultVerseCore

struct SnapshotCompareView: View {
    @Environment(AppEnvironment.self) private var env
    let playlistId: String

    @State private var snapshots: [PlaylistSnapshot] = []
    @State private var snapshotA: String = ""
    @State private var snapshotB: String = ""
    @State private var diff: SnapshotDiff?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if snapshots.count < 2 {
                    EmptyStateView(systemImage: "arrow.left.arrow.right", title: "Need two snapshots", message: "Re-import this playlist after it changes to compare versions.")
                } else {
                    pickers
                    if let diff { summaryCard(diff); changeLists(diff) }
                }
            }
            .padding(24)
        }
        .background(VaultTheme.deepCocoa)
        .navigationTitle("Compare snapshots")
        .task { await load() }
    }

    private var pickers: some View {
        HStack(spacing: 12) {
            picker("From", selection: $snapshotA)
            Image(systemName: "arrow.right").foregroundStyle(VaultTheme.mutedTan)
            picker("To", selection: $snapshotB)
        }
        .vaultCard()
    }

    private func picker(_ label: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                VinylIcon(size: 13)
                Text(label.uppercased()).font(.caption2.weight(.semibold)).foregroundStyle(VaultTheme.mutedTan)
            }
            Picker(label, selection: selection) {
                ForEach(snapshots) { snapshot in
                    Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened)).tag(snapshot.id)
                }
            }
            .labelsHidden()
            .onChange(of: selection.wrappedValue) { _, _ in Task { await computeDiff() } }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func summaryCard(_ diff: SnapshotDiff) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(VaultTheme.cherryPink).frame(width: 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(diff.humanSummary).font(.headline).foregroundStyle(VaultTheme.warmCream)
                if diff.titleChanged {
                    Text("Title: “\(diff.oldTitle ?? "—")” → “\(diff.newTitle ?? "—")”")
                        .font(.caption).foregroundStyle(VaultTheme.mutedTan)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    @ViewBuilder
    private func changeLists(_ diff: SnapshotDiff) -> some View {
        HStack(alignment: .top, spacing: 14) {
            changeColumn("Added", systemImage: "plus.circle", color: VaultTheme.vaultGreen, items: diff.added.map { "\($0.title) — \($0.artist)" })
            changeColumn("Removed", systemImage: "minus.circle", color: VaultTheme.softRed, items: diff.removed.map { "\($0.title) — \($0.artist)" })
        }
        if !diff.reordered.isEmpty {
            changeColumn("Reordered", systemImage: "arrow.up.arrow.down", color: VaultTheme.cherryPink,
                         items: diff.reordered.map { "\($0.title): #\($0.oldPosition + 1) → #\($0.newPosition + 1)" })
        }
    }

    private func changeColumn(_ title: String, systemImage: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(title) (\(items.count))", systemImage: systemImage).font(.headline).foregroundStyle(color)
            if items.isEmpty {
                Text("None").font(.caption).foregroundStyle(VaultTheme.mutedTan)
            } else {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Text(item).font(.caption).foregroundStyle(VaultTheme.warmCream)
                    Divider().overlay(VaultTheme.divider)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    private func load() async {
        snapshots = (try? await env.store.snapshots(forPlaylist: playlistId)) ?? []
        if snapshots.count >= 2 {
            snapshotA = snapshots[snapshots.count - 2].id
            snapshotB = snapshots[snapshots.count - 1].id
            await computeDiff()
        }
    }

    private func computeDiff() async {
        guard let a = snapshots.first(where: { $0.id == snapshotA }),
              let b = snapshots.first(where: { $0.id == snapshotB }) else { return }
        let aTracks = (try? await env.store.snapshotTracks(snapshotId: a.id)) ?? []
        let bTracks = (try? await env.store.snapshotTracks(snapshotId: b.id)) ?? []
        diff = SnapshotService.diff(oldSnapshot: a, oldTracks: aTracks, newSnapshot: b, newTracks: bTracks)
    }
}
