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

    // MARK: - Connection card

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProviderBadge(provider: .appleMusic)
                Spacer()
                statusPill
            }
            if let account = env.account {
                Text(account.displayName ?? "Apple Music user")
                    .font(.headline).foregroundStyle(VaultTheme.warmCream)
                Text("Storefront: \(account.storefront?.uppercased() ?? "—") · Connected \(PlaylistCard.relative(account.connectedAt))")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            } else {
                Text("Connect Apple Music")
                    .font(.headline).foregroundStyle(VaultTheme.warmCream)
                Text("VaultVerse will request permission to read your Apple Music library. It archives playlist metadata only — never audio files or passwords.")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            }
            if env.isConnected {
                HStack {
                    Spacer()
                    Button("Disconnect", role: .destructive) { Task { await env.disconnect() } }
                }
            }
        }
        .vaultCard(padding: 20)
    }

    private var statusPill: some View {
        let connected = env.isConnected
        return Text(connected ? "Connected" : "Not connected")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((connected ? VaultTheme.vaultGreen : VaultTheme.warmGrey).opacity(0.16))
            .foregroundStyle(connected ? VaultTheme.vaultGreen : VaultTheme.warmGrey)
            .clipShape(Capsule())
    }

    // MARK: - Import card

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Import library", subtitle: "VaultVerse saves playlist names, artwork, track order, artists, albums, and platform IDs. It does not store music files.")
            if env.isImporting, let progress = env.importProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(progress.processedPlaylists), total: Double(max(progress.totalPlaylists, 1)))
                        .tint(VaultTheme.cherryPink)
                        .overlay(NeedleShimmer(active: env.isImporting).clipShape(Capsule()))
                    Text("Importing \(progress.currentPlaylistName ?? "…") — \(progress.tracksImported) tracks so far")
                        .font(.caption).foregroundStyle(VaultTheme.mutedTan)
                }
            }
            if let error = env.importError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(VaultTheme.warmAmber)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(VaultTheme.warmAmber.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    // MARK: - History card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Import history")
            if importJobs.isEmpty {
                Text("No imports yet.").font(.caption).foregroundStyle(VaultTheme.mutedTan)
            } else {
                ForEach(importJobs) { job in
                    HStack {
                        Image(systemName: job.status == .succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(job.status == .succeeded ? VaultTheme.vaultGreen : VaultTheme.warmAmber)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(job.playlistsImported) playlists · \(job.tracksImported) tracks · \(job.snapshotsCreated) snapshots")
                                .font(.subheadline).foregroundStyle(VaultTheme.warmCream)
                            Text(job.startedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2).foregroundStyle(VaultTheme.mutedTan)
                        }
                        Spacer()
                        if !job.errors.isEmpty {
                            Text("\(job.errors.count) issues").font(.caption2).foregroundStyle(VaultTheme.warmAmber)
                        }
                    }
                    Divider().overlay(VaultTheme.divider)
                }
            }
        }
        .vaultCard(padding: 20)
    }

    private func loadJobs() async {
        importJobs = (try? await env.store.allImportJobs()) ?? []
    }
}
