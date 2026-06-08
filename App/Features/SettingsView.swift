import SwiftUI
import VaultVerseCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var summary: DashboardSummary?
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings & privacy").font(.system(.title2, design: .rounded).weight(.semibold)).foregroundStyle(VaultTheme.warmCream)

                storedDataCard
                if env.usingInMemoryFallback { fallbackWarning }
                privacyCard

                Text("You can export or delete your VaultVerse archive at any time.")
                    .font(.caption).foregroundStyle(VaultTheme.mutedTan)
            }
            .padding(24)
        }
        .navigationTitle("Settings")
        .background(VaultTheme.deepCocoa)
        .task { summary = try? await env.analyticsService.dashboardSummary() }
        .alert("Delete all data?", isPresented: $showDeleteConfirm) {
            Button("Delete everything", role: .destructive) { Task { await env.deleteAllData(); summary = try? await env.analyticsService.dashboardSummary() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes every playlist, snapshot, track, mapping, and export from this device. This cannot be undone.")
        }
    }

    private var storedDataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "What VaultVerse stores", subtitle: "Playlist names, artwork references, track order, artists, albums, ISRCs, and platform IDs. Never audio files, never your password.")
            if let summary {
                HStack(spacing: 18) {
                    labelled("\(summary.totalPlaylists)", "playlists")
                    labelled("\(summary.totalTracks)", "tracks")
                    labelled("\(summary.totalSnapshots)", "snapshots")
                    labelled(summary.lastBackupDate.map(PlaylistCard.relative) ?? "—", "last backup")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    private var fallbackWarning: some View {
        Label("Running with in-memory storage — data won't persist between launches. (SwiftData store unavailable.)", systemImage: "exclamationmark.triangle.fill")
            .font(.caption).foregroundStyle(VaultTheme.warmAmber)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(VaultTheme.warmAmber.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(VaultTheme.warmAmber.opacity(0.3), lineWidth: 1))
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your data, your control")
            HStack {
                Text("Apple Music connection").font(.subheadline).foregroundStyle(VaultTheme.warmCream)
                Spacer()
                if env.isConnected {
                    Button("Disconnect") { Task { await env.disconnect() } }
                        .tint(VaultTheme.warmAmber)
                } else {
                    Text("Not connected").font(.caption).foregroundStyle(VaultTheme.mutedTan)
                }
            }
            Divider().overlay(VaultTheme.divider)
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Delete all data").font(.subheadline).foregroundStyle(VaultTheme.warmCream)
                    Text("Erase the entire vault from this device.").font(.caption).foregroundStyle(VaultTheme.mutedTan)
                }
                Spacer()
                Button("Delete…", role: .destructive) { showDeleteConfirm = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }

    private func labelled(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.headline.monospacedDigit()).foregroundStyle(VaultTheme.warmCream)
            Text(label).font(.caption2).foregroundStyle(VaultTheme.mutedTan)
        }
    }
}
