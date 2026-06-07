import SwiftUI

extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

/// VaultVerse palette + reusable styling. Retro-modern iTunes/iPod utility:
/// warm off-white, graphite text, brushed silver, quiet blues.
enum VaultTheme {
    static let offWhite = Color(hex: 0xF8F8F4)
    static let graphite = Color(hex: 0x2C2C2E)
    static let brushedSilver = Color(hex: 0xC8C8C8)
    static let lcdBlue = Color(hex: 0x8FB7D9)
    static let actionBlue = Color(hex: 0x3E6F9E)
    static let mutedGrey = Color(hex: 0x6E6E73)
    static let card = Color(hex: 0xFFFFFF)
    static let panel = Color(hex: 0xF1F1EC)
    static let hairline = Color(hex: 0xDDDDD6)

    static let brushedMetal = LinearGradient(
        colors: [Color(hex: 0xFDFDFB), Color(hex: 0xEDEDE7)],
        startPoint: .top, endPoint: .bottom
    )

    /// Confidence → color for mapping/restore badges.
    static func confidenceColor(_ score: Int) -> Color {
        switch score {
        case 90...: return Color(hex: 0x3E8E5E)   // strong green
        case 80..<90: return actionBlue
        case 60..<80: return Color(hex: 0xB8772E) // amber
        default: return Color(hex: 0xA23B3B)      // red
        }
    }
}

/// Brushed, rounded panel used for most surfaces.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(VaultTheme.brushedMetal)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(VaultTheme.hairline, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

extension View {
    func vaultCard(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }
}
