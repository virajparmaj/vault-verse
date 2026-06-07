import SwiftUI
import VaultVerseCore

/// The careful, transparent restore flow: preflight → review/resolve → create → report.
struct RestoreFlowView: View {
    @Environment(AppEnvironment.self) private var env
    let snapshotId: String
    let playlistTitle: String

    enum Phase { case loading, review, restoring, done }

    @State private var phase: Phase = .loading
    @State private var preflight: RestorePreflight?
    @State private var unmatched: [UnmatchedTrack] = []
    @State private var report: RestoreReport?
    @State private var errorText: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                stepper
                switch phase {
                case .loading:
                    loadingCard("Checking how many songs can be confidently restored…")
                case .review:
                    if let preflight { reviewSection(preflight) }
                case .restoring:
                    loadingCard("Creating the playlist and adding tracks…")
                case .done:
                    if let report { reportSection(report) }
                }
                if let errorText {
                    Text(errorText).font(.caption).foregroundStyle(Color(hex: 0xA23B3B))
                }
            }
            .padding(24)
        }
        .background(VaultTheme.offWhite)
        .navigationTitle("Restore — \(playlistTitle)")
        .task { await runPreflight() }
    }

    // MARK: Stepper

    private var stepper: some View {
        let steps = ["Preflight", "Review", "Create", "Report"]
        let active: Int = {
            switch phase {
            case .loading: return 0
            case .review: return 1
            case .restoring: return 2
            case .done: return 3
            }
        }()
        return HStack(spacing: 8) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, label in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(index <= active ? VaultTheme.actionBlue : VaultTheme.hairline)
                            .frame(width: 22, height: 22)
                        Text("\(index + 1)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                    }
                    Text(label).font(.caption.weight(index == active ? .semibold : .regular))
                        .foregroundStyle(index <= active ? VaultTheme.graphite : VaultTheme.mutedGrey)
                }
                if index < steps.count - 1 {
                    Rectangle().fill(VaultTheme.hairline).frame(height: 1).frame(maxWidth: 30)
                }
            }
        }
        .vaultCard(padding: 12)
    }

    private func loadingCard(_ text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView()
            Text(text).font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    // MARK: Review

    private func reviewSection(_ preflight: RestorePreflight) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Match summary").font(.headline)
                HStack(spacing: 18) {
                    summaryStat("\(preflight.confidentCount)", "confident", Color(hex: 0x3E8E5E))
                    summaryStat("\(preflight.reviewCount)", "review", Color(hex: 0xB8772E))
                    summaryStat("\(preflight.unavailableCount)", "unavailable", VaultTheme.mutedGrey)
                    summaryStat("\(preflight.unmatchedCount)", "unmatched", Color(hex: 0xA23B3B))
                }
                Text("Nothing is created in Apple Music until you confirm.")
                    .font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .vaultCard()

            VStack(alignment: .leading, spacing: 0) {
                ForEach(preflight.items.sorted { $0.position < $1.position }) { item in
                    itemRow(item)
                    Divider().overlay(VaultTheme.hairline)
                }
            }
            .vaultCard(padding: 0)

            Button {
                Task { await confirm() }
            } label: {
                Label("Create playlist & add \(preflight.confidentCount + resolvedCount) tracks", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
        }
    }

    private func summaryStat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(VaultTheme.mutedGrey)
        }
    }

    private func itemRow(_ item: RestorePreflightItem) -> some View {
        HStack(spacing: 10) {
            Text("\(item.position + 1)").font(.caption.monospacedDigit()).foregroundStyle(VaultTheme.mutedGrey).frame(width: 26, alignment: .trailing)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).font(.subheadline).foregroundStyle(VaultTheme.graphite)
                Text(item.artist).font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            }
            Spacer()
            if let reason = item.reason, item.outcome != .confident {
                Text(reason).font(.caption2).foregroundStyle(VaultTheme.mutedGrey).lineLimit(1).frame(maxWidth: 220, alignment: .trailing)
            }
            OutcomeBadge(outcome: item.outcome)
            if item.outcome == .review || item.outcome == .unmatched {
                resolveMenu(item)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    @ViewBuilder
    private func resolveMenu(_ item: RestorePreflightItem) -> some View {
        if let record = unmatched.first(where: { $0.trackId == item.trackId && $0.resolvedAt == nil }), !record.suggestedMatches.isEmpty {
            Menu {
                ForEach(record.suggestedMatches) { suggestion in
                    Button {
                        Task { await resolve(record: record, suggestion: suggestion) }
                    } label: {
                        Text("\(suggestion.title) — \(suggestion.artist) [\(suggestion.confidenceScore)]")
                    }
                }
            } label: {
                Label("Resolve", systemImage: "wand.and.stars").labelStyle(.iconOnly)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)
        }
    }

    // MARK: Report

    private func reportSection(_ report: RestoreReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Restore complete", systemImage: "checkmark.seal.fill")
                .font(.title3.weight(.semibold)).foregroundStyle(Color(hex: 0x3E8E5E))
            Text(report.createdPlaylistName ?? "Restored playlist").font(.headline)
            HStack(spacing: 18) {
                summaryStat("\(report.restored)", "restored", Color(hex: 0x3E8E5E))
                summaryStat("\(report.skipped)", "skipped", VaultTheme.mutedGrey)
                summaryStat("\(report.failed)", "failed", Color(hex: 0xA23B3B))
                summaryStat("\(report.total)", "total", VaultTheme.graphite)
            }
            if let path = report.missingTracksCSVPath {
                Button {
                    revealInFinder(path)
                } label: { Label("Download list of missing songs (CSV)", systemImage: "arrow.down.doc") }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    // MARK: Actions

    private var resolvedCount: Int { unmatched.filter { $0.resolvedAt != nil }.count }

    private func runPreflight() async {
        phase = .loading
        do {
            let result = try await env.restoreService.preflight(snapshotId: snapshotId, targetProvider: .appleMusic)
            preflight = result
            unmatched = (try? await env.store.unmatched(forRestoreJob: result.restoreJobId)) ?? []
            phase = .review
        } catch {
            errorText = error.localizedDescription
            phase = .review
        }
    }

    private func resolve(record: UnmatchedTrack, suggestion: SuggestedMatch) async {
        guard let preflight else { return }
        do {
            try await env.restoreService.resolveMatch(
                restoreJobId: preflight.restoreJobId,
                unmatchedTrackId: record.id,
                chosenProviderTrackId: suggestion.providerTrackId,
                providerURI: suggestion.providerURI
            )
            await runPreflight()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func confirm() async {
        guard let preflight else { return }
        phase = .restoring
        do {
            report = try await env.restoreService.confirm(restoreJobId: preflight.restoreJobId, newPlaylistName: nil)
            phase = .done
        } catch {
            errorText = error.localizedDescription
            phase = .review
        }
    }
}
