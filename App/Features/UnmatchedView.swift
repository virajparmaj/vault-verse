import SwiftUI
import VaultVerseCore

struct UnmatchedView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var items: [UnmatchedTrack] = []
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Needs review").font(.system(.title2, design: .rounded).weight(.semibold))
                    Text("These songs need review. They may be unavailable, renamed, region-locked, or missing from the target catalog.")
                        .font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
                }
                if items.isEmpty && loaded {
                    EmptyStateView(systemImage: "checkmark.seal", title: "Nothing to review", message: "Every song in your restores was confidently matched.")
                } else {
                    ForEach(items) { item in row(item) }
                }
            }
            .padding(24)
        }
        .navigationTitle("Unmatched")
        .background(VaultTheme.offWhite)
        .task { await load() }
    }

    private func row(_ item: UnmatchedTrack) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(.subheadline.weight(.medium)).foregroundStyle(VaultTheme.graphite)
                Text(item.artist).font(.caption).foregroundStyle(VaultTheme.mutedGrey)
                Text(item.reason).font(.caption2).foregroundStyle(Color(hex: 0xB8772E))
            }
            Spacer()
            ProviderBadge(provider: item.attemptedProvider)
            if !item.suggestedMatches.isEmpty {
                Menu {
                    ForEach(item.suggestedMatches) { suggestion in
                        Button("\(suggestion.title) — \(suggestion.artist) [\(suggestion.confidenceScore)]") {
                            Task { await resolve(item, suggestion) }
                        }
                    }
                } label: {
                    Label("Resolve", systemImage: "wand.and.stars")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .vaultCard()
    }

    private func load() async {
        var collected: [UnmatchedTrack] = []
        for job in (try? await env.store.allRestoreJobs()) ?? [] {
            let unmatched = (try? await env.store.unmatched(forRestoreJob: job.id)) ?? []
            collected.append(contentsOf: unmatched.filter { $0.resolvedAt == nil })
        }
        items = collected
        loaded = true
    }

    private func resolve(_ item: UnmatchedTrack, _ suggestion: SuggestedMatch) async {
        try? await env.restoreService.resolveMatch(
            restoreJobId: item.restoreJobId,
            unmatchedTrackId: item.id,
            chosenProviderTrackId: suggestion.providerTrackId,
            providerURI: suggestion.providerURI
        )
        await load()
    }
}
