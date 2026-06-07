import SwiftUI
import VaultVerseCore

struct ConnectImportView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var importJobs: [ImportJob] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                connectionCard
                importCard
                historyCard
            }
            .padding(28)
        }
        .navigationTitle("Connections")
        .task { await loadJobs() }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProviderBadge(provider: .appleMusic)
                Spacer()
                statusPill
            }
            if let account = env.account {
                Text(account.displayName ?? "Apple Music user")
                    .font(.headline).foregroundStyle(VaultTheme.graphite)
                Text("Storefront: \(account.storefront?.uppercased() ?? "—") · Connected \(PlaylistCard.relative(account.connectedAt))")
                    .font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            } else {
                Text("Not connected")
                    .font(.headline).foregroundStyle(VaultTheme.graphite)
                Text("VaultVerse runs on demo data in this build. Connecting performs a mock Apple Music authorization — no credentials needed.")
                    .font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            }
            HStack {
                Picker("Source", selection: Binding(get: { env.providerMode }, set: { env.providerMode = $0 })) {
                    ForEach(AppEnvironment.ProviderMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).frame(maxWidth: 280)
                .disabled(true) // live mode is a future build
                Spacer()
                if env.isConnected {
                    Button("Disconnect", role: .destructive) { Task { await env.disconnect() } }
                }
            }
        }
        .vaultCard(padding: 20)
    }

    private var statusPill: some View {
        let connected = env.isConnected
        return Text(connected ? "Connected" : "Disconnected")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((connected ? Color(hex: 0x3E8E5E) : VaultTheme.mutedGrey).opacity(0.16))
            .foregroundStyle(connected ? Color(hex: 0x3E8E5E) : VaultTheme.mutedGrey)
            .clipShape(Capsule())
    }

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Import library", subtitle: "VaultVerse saves playlist names, artwork, track order, artists, albums, and platform IDs. It does not store music files.")
            if env.isImporting, let progress = env.importProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(progress.processedPlaylists), total: Double(max(progress.totalPlaylists, 1)))
                    Text("Importing \(progress.currentPlaylistName ?? "…") — \(progress.tracksImported) tracks so far")
                        .font(.caption).foregroundStyle(VaultTheme.mutedGrey)
                }
            }
            Button {
                Task { await env.connectAndImport(); await loadJobs() }
            } label: {
                Label(env.isImporting ? "Importing…" : "Connect & import playlists", systemImage: "arrow.down.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(env.isImporting)
        }
        .vaultCard(padding: 20)
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Import history")
            if importJobs.isEmpty {
                Text("No imports yet.").font(.caption).foregroundStyle(VaultTheme.mutedGrey)
            } else {
                ForEach(importJobs) { job in
                    HStack {
                        Image(systemName: job.status == .succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(job.status == .succeeded ? Color(hex: 0x3E8E5E) : Color(hex: 0xB8772E))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(job.playlistsImported) playlists · \(job.tracksImported) tracks · \(job.snapshotsCreated) snapshots")
                                .font(.subheadline).foregroundStyle(VaultTheme.graphite)
                            Text(job.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundStyle(VaultTheme.mutedGrey)
                        }
                        Spacer()
                        if !job.errors.isEmpty {
                            Text("\(job.errors.count) issues").font(.caption2).foregroundStyle(Color(hex: 0xB8772E))
                        }
                    }
                    Divider().overlay(VaultTheme.hairline)
                }
            }
        }
        .vaultCard(padding: 20)
    }

    private func loadJobs() async {
        importJobs = (try? await env.store.allImportJobs()) ?? []
    }
}
