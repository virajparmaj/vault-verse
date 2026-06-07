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
        .background(VaultTheme.lcdBlue.opacity(0.25))
        .foregroundStyle(VaultTheme.actionBlue)
        .clipShape(Capsule())
    }
}

struct MappingConfidenceBadge: View {
    let score: Int
    var body: some View {
        Text("\(score)")
            .font(.caption2.weight(.bold).monospacedDigit())
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(VaultTheme.confidenceColor(score).opacity(0.16))
            .foregroundStyle(VaultTheme.confidenceColor(score))
            .clipShape(Capsule())
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
        case .confident: return Color(hex: 0x3E8E5E)
        case .review: return Color(hex: 0xB8772E)
        case .unavailable: return VaultTheme.mutedGrey
        case .unmatched: return Color(hex: 0xA23B3B)
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
                if let systemImage { Image(systemName: systemImage).foregroundStyle(VaultTheme.actionBlue) }
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(VaultTheme.mutedGrey)
            }
            Text(value)
                .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                .foregroundStyle(VaultTheme.graphite)
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
            Circle().stroke(VaultTheme.hairline, lineWidth: 7)
            Circle()
                .trim(from: 0, to: max(0, min(1, Double(percent) / 100)))
                .stroke(VaultTheme.confidenceColor(percent), style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(percent)%")
                .font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(VaultTheme.graphite)
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
            Text(title).font(.headline).foregroundStyle(VaultTheme.graphite)
            if let subtitle { Text(subtitle).font(.caption).foregroundStyle(VaultTheme.mutedGrey) }
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
            Image(systemName: systemImage).font(.system(size: 38)).foregroundStyle(VaultTheme.brushedSilver)
            Text(title).font(.headline).foregroundStyle(VaultTheme.graphite)
            Text(message).font(.subheadline).foregroundStyle(VaultTheme.mutedGrey)
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
                } placeholder: { placeholder }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(VaultTheme.hairline, lineWidth: 1))
    }
    private var placeholder: some View {
        ZStack {
            VaultTheme.brushedMetal
            Text(initials).font(.system(.headline, design: .rounded).weight(.bold)).foregroundStyle(VaultTheme.brushedSilver)
        }
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
                    Text(playlist.title).font(.headline).foregroundStyle(VaultTheme.graphite).lineLimit(2)
                    ProviderBadge(provider: playlist.sourceProvider)
                }
                Spacer()
                ReadinessRing(percent: readinessPercent, size: 52)
            }
            Divider().overlay(VaultTheme.hairline)
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
            Text(value).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(VaultTheme.graphite)
            Text(label).font(.caption2).foregroundStyle(VaultTheme.mutedGrey)
        }
    }

    static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
