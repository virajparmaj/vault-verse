import SwiftUI
import UniformTypeIdentifiers
import VaultVerseCore

struct ConnectImportView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var importJobs: [ImportJob] = []
    @State private var showFileImporter = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sourceCard
                importCard
                historyCard
            }
            .padding(28)
        }
        .navigationTitle("Connections")
        .task { await loadJobs() }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.xml, .propertyList],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await env.importAppleMusicExport(url: url); await loadJobs() }
            case .failure(let error):
                env.importError = error.localizedDescription
            }
        }
    }

    // MARK: - Source card

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProviderBadge(provider: .appleMusic)
                Spacer()
                statusPill
            }
            if let account = env.account {
                Text(account.displayName ?? "Your library")
                    .font(.headline).foregroundStyle(VaultTheme.warmCream)
                Text("Source: \(env.source.title) · Imported \(PlaylistCard.relative(account.connectedAt))")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            } else {
                Text("Local-first — no account needed")
                    .font(.headline).foregroundStyle(VaultTheme.warmCream)
                Text("VaultVerse works entirely on this Mac. Start with the demo library, or import your real one from a Music \u{201C}Export Library\u{2026}\u{201D} file. It archives playlist metadata only — never audio files or passwords.")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            }
        }
        .vaultCard(padding: 20)
    }

    private var statusPill: some View {
        let connected = env.isConnected
        return Text(connected ? "Imported" : "No library yet")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background((connected ? VaultTheme.vaultGreen : VaultTheme.warmGrey).opacity(0.16))
            .foregroundStyle(connected ? VaultTheme.vaultGreen : VaultTheme.warmGrey)
            .clipShape(Capsule())
    }

    // MARK: - Import card

    private var importCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Import a library", subtitle: "VaultVerse saves playlist names, artwork, track order, artists, albums, and platform IDs. It does not store music files.")

            if env.isImporting, let progress = env.importProgress {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: Double(progress.processedPlaylists), total: Double(max(progress.totalPlaylists, 1)))
                        .tint(VaultTheme.cherryPink)
                        .overlay(NeedleShimmer(active: env.isImporting).clipShape(Capsule()))
                    Text("Importing \(progress.currentPlaylistName ?? "\u{2026}") — \(progress.tracksImported) tracks so far")
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

            HStack(spacing: 12) {
                Button {
                    Task { await env.loadDemoLibrary(); await loadJobs() }
                } label: {
                    Label("Load demo library", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.bordered)
                .disabled(env.isImporting)

                Button {
                    env.importError = nil
                    showFileImporter = true
                } label: {
                    Label("Import from Apple Music export (.xml)", systemImage: "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .disabled(env.isImporting)
            }

            exportHelp
        }
        .vaultCard(padding: 20)
    }

    private var exportHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to export your real library")
                .font(.caption.weight(.semibold)).foregroundStyle(VaultTheme.warmCream)
            VStack(alignment: .leading, spacing: 3) {
                helpStep("1", "Open the Music app on your Mac.")
                helpStep("2", "Menu bar → File → Library → Export Library\u{2026}")
                helpStep("3", "Save the .xml somewhere you can find it.")
                helpStep("4", "Click \u{201C}Import from Apple Music export\u{201D} above and choose that file.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(VaultTheme.deepCocoa.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func helpStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number)
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(VaultTheme.cherryPink)
                .frame(width: 14, alignment: .trailing)
            Text(text).font(.caption).foregroundStyle(VaultTheme.mutedTan)
        }
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
