import SwiftUI
import VaultVerseCore

// MARK: - Badges

struct ProviderBadge: View {
    let provider: Provider
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "music.note")
            Text(provider.displayName)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(VaultTheme.cherryPink.opacity(0.15))
        .foregroundStyle(VaultTheme.cherryPink)
        .clipShape(Capsule())
    }
}

struct MappingConfidenceBadge: View {
    let score: Int
    var body: some View {
        Text("\(score)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    /// High confidence reads as the brand cherry; lower tiers fall back to semantic colors.
    private var color: Color {
        switch score {
        case 80...: return VaultTheme.cherryPink
        case 60..<80: return VaultTheme.warmAmber
        default: return VaultTheme.softRed
        }
    }
}

struct OutcomeBadge: View {
    let outcome: RestorePreflightItem.Outcome
    var body: some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    private var label: String {
        switch outcome {
        case .confident: return "Confident"
        case .review: return "Review"
        case .unavailable: return "Unavailable"
        case .unmatched: return "Unmatched"
        }
    }
    private var color: Color {
        switch outcome {
        case .confident: return VaultTheme.vaultGreen
        case .review: return VaultTheme.warmAmber
        case .unavailable: return VaultTheme.warmGrey
        case .unmatched: return VaultTheme.softRed
        }
    }
}

// MARK: - Stats

struct StatTile: View {
    let title: String
    let value: String
    var systemImage: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).foregroundStyle(VaultTheme.cherryPink) }
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VaultTheme.mutedTan)
            }
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(VaultTheme.warmCream)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .vaultCard()
    }
}

struct ReadinessRing: View {
    let percent: Int
    var size: CGFloat = 64
    var body: some View {
        ZStack {
            Circle().stroke(VaultTheme.brushedBronze, lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0, min(1, Double(percent) / 100)))
                .stroke(VaultTheme.confidenceColor(percent), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(VaultTheme.warmCream)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Sections + empty states

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundStyle(VaultTheme.warmCream)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(VaultTheme.mutedTan) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 38)).foregroundStyle(VaultTheme.cherryPink)
            Text(title).font(.headline).foregroundStyle(VaultTheme.warmCream)
            Text(message).font(.subheadline).foregroundStyle(VaultTheme.mutedTan)
                .multilineTextAlignment(.center).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Artwork

struct ArtworkThumbnail: View {
    let url: String?
    let title: String
    var size: CGFloat = 56
    var body: some View {
        Group {
            if let url, let parsed = URL(string: url) {
                AsyncImage(url: parsed) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { MiniVinylPlaceholder(size: size, label: initials) }
            } else {
                MiniVinylPlaceholder(size: size, label: initials)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(VaultTheme.brushedBronze, lineWidth: 1))
    }
    private var initials: String {
        let parts = title.split(separator: " ").prefix(2).compactMap { $0.first }
        return parts.isEmpty ? "♪" : String(parts).uppercased()
    }
}

// MARK: - Playlist card

struct PlaylistCard: View {
    let playlist: Playlist
    let snapshotCount: Int
    let readinessPercent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ArtworkThumbnail(url: playlist.artworkURL, title: playlist.title, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(playlist.title).font(.headline).foregroundStyle(VaultTheme.warmCream).lineLimit(2)
                    ProviderBadge(provider: playlist.sourceProvider)
                }
                Spacer()
                ReadinessRing(percent: readinessPercent, size: 52)
            }
            Divider().overlay(VaultTheme.divider)
            HStack {
                metric("\(playlist.trackCount)", "tracks")
                Spacer()
                metric("\(snapshotCount)", "snapshots")
                Spacer()
                metric(playlist.lastSyncedAt.map(Self.relative) ?? "—", "last backup")
            }
        }
        .vaultCard()
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(VaultTheme.warmCream)
            Text(label).font(.caption2).foregroundStyle(VaultTheme.mutedTan)
        }
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
