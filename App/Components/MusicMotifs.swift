import SwiftUI

// Functional decorative flourishes — each reinforces what a screen does (archive,
// import, restore, compare) through a music metaphor. Kept simple and performant:
// `Canvas` for multi-line drawing, gated animations for motion.

// MARK: - Brand emblem

/// VaultVerse vault-dial / vinyl emblem. Backed by the `VaultVerseEmblem` asset
/// (bronze grooves + cherry center), falling back to a drawn record if absent.
struct BrandEmblem: View {
    var size: CGFloat = 28
    var body: some View {
        Image("VaultVerseEmblem")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

// MARK: - Spindle dot

/// A small cherry "record dot" — spindle / recording indicator.
struct RecordDot: View {
    var diameter: CGFloat = 8
    var color: Color = VaultTheme.cherryPink
    var body: some View {
        Circle().fill(color).frame(width: diameter, height: diameter)
    }
}

// MARK: - Monoline vinyl icon

/// Simple monoline record icon for card headers and turntable pickers.
struct VinylIcon: View {
    var size: CGFloat = 16
    var color: Color = VaultTheme.cherryPink
    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 1.4)
            Circle().stroke(color.opacity(0.6), lineWidth: 1).padding(size * 0.27)
            Circle().fill(color).frame(width: size * 0.18, height: size * 0.18)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Equalizer bars

/// Three cherry equalizer bars of varying height.
struct EqualizerBarsIcon: View {
    var heights: [CGFloat] = [9, 16, 6]
    var barWidth: CGFloat = 3
    var color: Color = VaultTheme.cherryPink
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(color).frame(width: barWidth, height: heights[i])
            }
        }
        .frame(height: 16, alignment: .bottom)
    }
}

// MARK: - Vinyl groove arcs

/// Faint concentric record grooves radiating from the left edge — sits behind hero text.
struct VinylGrooveArcs: View {
    var arcCount: Int = 8
    var spacing: CGFloat = 26
    var color: Color = VaultTheme.brushedBronze

    var body: some View {
        Canvas { ctx, size in
            let origin = CGPoint(x: -30, y: size.height / 2)
            for i in 0..<arcCount {
                let radius = CGFloat(i) * spacing + 50
                let rect = CGRect(x: origin.x - radius, y: origin.y - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.stroke(Path(ellipseIn: rect), with: .color(color.opacity(0.15)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Mini vinyl placeholder

/// Dark grooved record with a cherry center label — artwork fallback.
/// When `label` is set the center disc carries initials; otherwise it shows a spindle hole.
struct MiniVinylPlaceholder: View {
    var size: CGFloat = 56
    var label: String? = nil
    var body: some View {
        ZStack {
            Circle().fill(VaultTheme.deepCocoa)
            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(VaultTheme.brushedBronze.opacity(0.4), lineWidth: 0.75)
                    .padding(CGFloat(i) * (size * 0.11) + size * 0.10)
            }
            if let label, !label.isEmpty {
                Circle().fill(VaultTheme.cherryPink).frame(width: size * 0.44, height: size * 0.44)
                Text(label)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(VaultTheme.warmCream)
            } else {
                Circle().fill(VaultTheme.cherryPink).frame(width: size * 0.30, height: size * 0.30)
                Circle().fill(VaultTheme.deepCocoa).frame(width: size * 0.06, height: size * 0.06)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Needle-tracking shimmer

/// A blush highlight sweeping L→R over a progress bar — like a needle tracking a record.
/// Pass `active` so the repeating animation only runs during an active import.
struct NeedleShimmer: View {
    var active: Bool = true
    @State private var phase: CGFloat = -0.4

    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [.clear, VaultTheme.blush.opacity(0.45), .clear],
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 0.4)
            .offset(x: geo.size.width * phase)
            .onAppear { if active { startSweep() } }
            .onChange(of: active) { _, isActive in if isActive { startSweep() } }
        }
        .clipped()
        .allowsHitTesting(false)
    }

    private func startSweep() {
        phase = -0.4
        withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
            phase = 1.1
        }
    }
}

// MARK: - Staff lines

/// Five faint horizontal staff lines — a subtle music-manuscript reference behind headers.
struct StaffLines: View {
    var lineCount: Int = 5
    var color: Color = VaultTheme.brushedBronze
    var body: some View {
        Canvas { ctx, size in
            let gap = size.height / CGFloat(lineCount + 1)
            for i in 1...lineCount {
                let y = gap * CGFloat(i)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(color.opacity(0.16)), lineWidth: 0.75)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Dotted timeline

/// A perforated connector line for the restore stepper. Lit cherry when the segment is reached.
struct DottedTimeline: View {
    var active: Bool = false
    var body: some View {
        HorizontalLine()
            .stroke(
                active ? VaultTheme.cherryPink : VaultTheme.brushedBronze,
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4])
            )
            .frame(height: 2)
            .frame(maxWidth: 30)
    }

    private struct HorizontalLine: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

// MARK: - Watermarks

/// Faint background watermark glyph (brushed-bronze, very low alpha).
struct Watermark: View {
    enum Kind { case rewind, brokenRecord, vinyl }
    var kind: Kind
    var size: CGFloat = 200

    var body: some View {
        Image(systemName: symbol)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(VaultTheme.brushedBronze.opacity(opacity))
            .rotationEffect(kind == .brokenRecord ? .degrees(8) : .zero)
            .allowsHitTesting(false)
    }

    private var symbol: String {
        switch kind {
        case .rewind: return "backward.fill"
        case .brokenRecord, .vinyl: return "opticaldisc"
        }
    }
    private var opacity: Double {
        switch kind {
        case .rewind: return 0.12
        case .brokenRecord: return 0.10
        case .vinyl: return 0.08
        }
    }
}

// MARK: - Speaker grille texture

/// Barely-visible vertical grain for the sidebar — a wood-veneer / speaker-grille reference.
struct SpeakerGrilleTexture: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 4
            var x: CGFloat = 0
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.black.opacity(0.04)), lineWidth: 1)
                x += step
            }
        }
        .allowsHitTesting(false)
    }
}
