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

/// VaultVerse palette + reusable styling. Warm dark "vinyl lounge" skeuomorphism:
/// deep cocoa surfaces, cream text, cherry accents, brushed-bronze hardware.
enum VaultTheme {
    // Surfaces
    static let deepCocoa      = Color(hex: 0x2C1A14) // app bg, sidebar, deepest surfaces
    static let cocoaMid       = Color(hex: 0x3A2218) // card / panel background
    static let chocolateBrown = Color(hex: 0x4A2C24) // secondary surfaces, bezel rings

    // Accents
    static let cherryPink     = Color(hex: 0xE14D6A) // primary action, active, CTA, selected nav
    static let blush          = Color(hex: 0xF6C9D4) // hover, highlights, badge backgrounds
    static let deepCherry     = Color(hex: 0xC93A56) // pressed, destructive

    // Text
    static let warmCream      = Color(hex: 0xFBF3EC) // primary text on dark surfaces
    static let mutedTan       = Color(hex: 0xD4B5A0) // secondary / caption text
    static let warmGrey       = Color(hex: 0x8A6B5A) // disabled / tertiary

    // Semantic
    static let vaultGreen     = Color(hex: 0x5DAE75) // success, connected, confident
    static let warmAmber      = Color(hex: 0xD4944C) // review, warning
    static let softRed        = Color(hex: 0xC94444) // failed, error, destructive confirm

    // Material
    static let brushedBronze  = Color(hex: 0x5C3D30) // card borders, dividers, ring strokes

    /// Blush at 10% — soft "blush glow" highlight fill.
    static let blushGlow = blush.opacity(0.10)

    /// Reduced-strength bronze for hairline dividers on dark surfaces.
    static let divider = brushedBronze.opacity(0.5)

    // MARK: Gradients

    /// Linear bronze panel for header / hero faceplates (chocolate → cocoa, top→bottom).
    static let bronzePanel = LinearGradient(
        colors: [chocolateBrown, cocoaMid],
        startPoint: .top, endPoint: .bottom
    )

    /// Warm radial "spotlight" used as the card fill — lighter warm center fading to base.
    static let cardSpotlight = RadialGradient(
        colors: [chocolateBrown.opacity(0.5), .clear],
        center: UnitPoint(x: 0.5, y: 0.32),
        startRadius: 2,
        endRadius: 260
    )

    /// Confidence → color for mapping/restore badges and readiness rings.
    /// 80+ reads as one continuous "healthy" green zone; cherry is reserved for action.
    static func confidenceColor(_ score: Int) -> Color {
        switch score {
        case 90...:   return vaultGreen
        case 80..<90: return vaultGreen
        case 60..<80: return warmAmber
        default:      return softRed
        }
    }
}

/// Warm, lit, bronze-bezeled card used for most surfaces. Border warms to cherry on hover.
struct CardModifier: ViewModifier {
    var padding: CGFloat = 16
    @State private var isHovering = false

    private let radius: CGFloat = 14

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(VaultTheme.cocoaMid)
                    shape.fill(VaultTheme.cardSpotlight)
                }
            }
            .overlay {
                // 0.5px blush inner top highlight — a glossy edge catching overhead light.
                shape
                    .strokeBorder(VaultTheme.blush.opacity(0.10), lineWidth: 0.6)
                    .mask(
                        LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center)
                    )
            }
            .overlay {
                // 1px bronze bezel; warms to cherry on hover.
                shape.strokeBorder(
                    isHovering ? VaultTheme.cherryPink.opacity(0.30) : VaultTheme.brushedBronze,
                    lineWidth: 1
                )
            }
            .shadow(color: VaultTheme.deepCocoa.opacity(0.40), radius: 16, x: 0, y: 4)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

extension View {
    func vaultCard(padding: CGFloat = 16) -> some View { modifier(CardModifier(padding: padding)) }
}
