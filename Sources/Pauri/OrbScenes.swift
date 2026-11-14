import SwiftUI

/// The send orb's ten scenes, painted in a 32 pt circle. Ported from `design-directions/issue-10.html`,
/// which holds the same colors and positions; x and y below are fractions of the orb.
struct OrbSceneView: View {
    let scene: OrbScene
    /// Seconds of scene motion played so far. It only advances while an answer streams.
    let motion: Double

    var body: some View {
        ZStack {
            backdrop
            ForEach(Array(scene.specks.enumerated()), id: \.offset) { index, speck in
                speckView(speck, index: index)
            }
        }
        .frame(width: SendOrb.size, height: SendOrb.size)
        .clipShape(Circle())
        // Flattened, so a cross-fade fades the painting, not each layer (the moon's dark bite would show).
        .compositingGroup()
    }

    @ViewBuilder private var backdrop: some View {
        let t = motion
        switch scene {
        case .blueHour:
            vertical([(0x1B2A5C, 0), (0x2D5C8A, 0.62), (0x8CC3CF, 0.80)])
            hill(0x0F1B33, rx: 0.9, ry: 0.24, x: 0.40, y: 1)
        case .dawn:
            vertical([(0x9C8FD0, 0), (0xE9A9B8, 0.55), (0xFBD3A8, 1)])
            disc(Color(hex: 0xFFF0C2), radius: 6, x: 0.62, y: 0.88, solid: 0.8)
                .offset(y: cos(2 * .pi * t / 10))
            LinearGradient(stops: [.init(color: .clear, location: 0.7),
                                   .init(color: Color(hex: 0xFFF5F0, opacity: 0.75), location: 0.86),
                                   .init(color: Color(hex: 0xFFF5F0, opacity: 0.9), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .offset(x: drift(t, period: 8))
        case .meadow:
            vertical([(0x7FC3EC, 0), (0xD9EFF6, 0.6)])
            hill(0x4FA83A, rx: 0.85, ry: 0.42, x: 0.85, y: 1)
            hill(0x7CCB4E, rx: 0.95, ry: 0.38, x: 0.22, y: 1)
        case .seaside:
            vertical([(0x4FA6E2, 0), (0xBDE3F4, 0.6)])
            sea(top: 0x2F86C6, bottom: 0x1F5E9C)
            ZStack {
                polygon([(0.74, 0.42), (0.74, 0.63), (0.86, 0.63)]).fill(.white)
                polygon([(0.69, 0.64), (0.89, 0.64), (0.86, 0.69), (0.72, 0.69)]).fill(Color(hex: 0xC9473A))
            }
            .rotationEffect(.degrees(1.5 * (1 - cos(2 * .pi * t / 3))), anchor: UnitPoint(x: 0.79, y: 0.66))
            .offset(y: 0.35 * (1 - cos(2 * .pi * t / 3)))
        case .sky:
            vertical([(0x2F7FC8, 0), (0x6DB6E8, 0.55), (0xBFE3F5, 1)])
            ZStack {
                disc(Color(hex: 0xB9CBE2), radius: 8, x: 0.20, y: 1.02)
                disc(Color(hex: 0xB9CBE2), radius: 9, x: 0.46, y: 0.92)
                disc(Color(hex: 0xB9CBE2), radius: 8, x: 0.74, y: 0.98)
                disc(.white, radius: 7, x: 0.18, y: 0.94)
                disc(.white, radius: 8, x: 0.42, y: 0.82)
                disc(.white, radius: 6, x: 0.62, y: 0.86)
                disc(.white, radius: 7, x: 0.84, y: 0.94)
            }
            .blur(radius: 0.35)
            .offset(x: drift(t, period: 9))
        case .golden:
            vertical([(0xFFD98A, 0), (0xF6B85A, 0.6)])
            disc(Color(hex: 0xFFF6D2), radius: 5, x: 0.80, y: 0.50, solid: 0.8)
                .opacity(breathe(t, period: 5))
            hill(0xC98F35, rx: 0.85, ry: 0.40, x: 0.85, y: 1)
            hill(0xE5B44E, rx: 0.95, ry: 0.34, x: 0.20, y: 1)
        case .harbor:
            vertical([(0xF9D79A, 0), (0xF4A86E, 0.5), (0xEC8A6A, 0.64)])
            disc(Color(hex: 0xFFF1B8), radius: 5, x: 0.28, y: 0.62, solid: 0.8)
            sea(top: 0x3B86C4, bottom: 0x1F5E9C)
            LinearGradient(colors: [Color(hex: 0xFFE9A8, opacity: 0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(width: 0.10 * SendOrb.size, height: 0.26 * SendOrb.size)
                .blur(radius: 0.6)
                .position(x: 0.28 * SendOrb.size, y: 0.77 * SendOrb.size)
                .opacity(breathe(t, period: 2.4))
        case .town:
            vertical([(0x3B3A7A, 0), (0x8A6AA8, 0.52), (0xE7A0A0, 0.70)])
            hill(0x1E1C3A, rx: 1, ry: 0.36, x: 0.5, y: 1)
        case .forest:
            radial([(0x2E6672, 0), (0x183E44, 0.55), (0x0D2422, 1)], center: UnitPoint(x: 0.5, y: 0.28), radius: 28)
            hill(0x08160F, rx: 0.34, ry: 0.30, x: 0.14, y: 1)
            hill(0x08160F, rx: 0.30, ry: 0.36, x: 0.46, y: 1.04)
            hill(0x08160F, rx: 0.36, ry: 0.28, x: 0.84, y: 1)
        case .moon:
            radial([(0x2A2F7A, 0), (0x121440, 0.6), (0x0B0C2E, 1)], center: UnitPoint(x: 0.6, y: 0.3), radius: 29.5)
            disc(Color(hex: 0xFFF4CF), radius: 5, x: 0.72, y: 0.28, solid: 0.88)
                .opacity(breathe(t, period: 5))
            disc(Color(hex: 0x1C2062), radius: 4.6, x: 0.78, y: 0.23, solid: 0.9)
            hill(0x090A24, rx: 0.8, ry: 0.26, x: 0.30, y: 1)
            hill(0x0E1033, rx: 0.7, ry: 0.22, x: 0.90, y: 1)
        }
    }

    private func speckView(_ speck: Speck, index: Int) -> some View {
        let motion = scene.speckMotion
        let u = fraction((self.motion + Double(index) * motion.stagger) / motion.period)
        let wave = cos(2 * .pi * u)
        var opacity = speck.opacity
        var offset = CGSize.zero
        switch motion.kind {
        case .twinkle:
            opacity *= 0.6 + 0.4 * wave
        case .sway:
            offset.width = -0.5 * wave
        case .drift:
            offset = CGSize(width: 1.2 * sin(2 * .pi * u), height: -(1 - wave))
            opacity *= 0.6 + 0.4 * cos(4 * .pi * u)
        case .float:
            offset.height = -7 * u
            opacity *= u < 0.2 ? u / 0.2 : (1 - u) / 0.8
        case .flicker:
            if (0.7..<0.78).contains(u) { opacity *= 0.35 }
        }
        let color = Color(hex: speck.color)
        return Circle()
            .fill(color)
            .frame(width: 2 * speck.radius, height: 2 * speck.radius)
            .shadow(color: speck.glows ? color : .clear, radius: speck.glows ? 1.25 : 0)
            .opacity(opacity)
            .offset(offset)
            .position(x: speck.x * SendOrb.size, y: speck.y * SendOrb.size)
    }

    // MARK: Painting helpers

    private func vertical(_ stops: [(UInt32, CGFloat)]) -> LinearGradient {
        LinearGradient(stops: stops.map { .init(color: Color(hex: $0.0), location: $0.1) }, startPoint: .top, endPoint: .bottom)
    }

    private func radial(_ stops: [(UInt32, CGFloat)], center: UnitPoint, radius: CGFloat) -> RadialGradient {
        RadialGradient(stops: stops.map { .init(color: Color(hex: $0.0), location: $0.1) },
                       center: center, startRadius: 0, endRadius: radius)
    }

    /// A soft-edged disc: solid out to `solid` of its radius, then fading out.
    private func disc(_ color: Color, radius: CGFloat, x: CGFloat, y: CGFloat, solid: CGFloat = 0.85) -> some View {
        Circle()
            .fill(RadialGradient(stops: [.init(color: color, location: 0), .init(color: color, location: solid),
                                         .init(color: color.opacity(0), location: 1)],
                                 center: .center, startRadius: 0, endRadius: radius))
            .frame(width: 2 * radius, height: 2 * radius)
            .position(x: x * SendOrb.size, y: y * SendOrb.size)
    }

    /// An ellipse with radii given as fractions of the orb, centered at (x, y).
    private func hill(_ color: UInt32, rx: CGFloat, ry: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Ellipse()
            .fill(Color(hex: color))
            .frame(width: 2 * rx * SendOrb.size, height: 2 * ry * SendOrb.size)
            .position(x: x * SendOrb.size, y: y * SendOrb.size)
    }

    /// The sea: the bottom 36% of the orb.
    private func sea(top: UInt32, bottom: UInt32) -> some View {
        LinearGradient(colors: [Color(hex: top), Color(hex: bottom)], startPoint: .top, endPoint: .bottom)
            .frame(width: SendOrb.size, height: 0.36 * SendOrb.size)
            .position(x: SendOrb.size / 2, y: 0.82 * SendOrb.size)
    }

    private func polygon(_ points: [(CGFloat, CGFloat)]) -> Path {
        Path { path in
            path.addLines(points.map { CGPoint(x: $0.0 * SendOrb.size, y: $0.1 * SendOrb.size) })
            path.closeSubpath()
        }
    }

    private func drift(_ t: Double, period: Double) -> CGFloat { -1.5 * cos(2 * .pi * t / period) }
    private func breathe(_ t: Double, period: Double) -> Double { 1 - 0.175 * (1 - cos(2 * .pi * t / period)) }
    private func fraction(_ x: Double) -> Double { x - x.rounded(.down) }
}

/// The glow and arrow colors that go with a scene.
struct SceneStyle {
    let glow: Color
    let glowBright: Color
    let arrow: Color
    let arrowShadow: Color
}

/// A small dot in a scene: a star, flower, glint, firefly, pollen grain, or lit window.
struct Speck {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let color: UInt32
    let opacity: Double
    var glows = false
}

/// How a scene's specks move while an answer streams. Each speck starts `stagger` seconds further into the loop.
struct SpeckMotion {
    enum Kind { case twinkle, sway, drift, float, flicker }
    let kind: Kind
    let period: Double
    let stagger: Double
}

extension OrbScene {
    var style: SceneStyle {
        func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color {
            Color(.sRGB, red: r / 255, green: g / 255, blue: b / 255, opacity: a)
        }
        return switch self {
        case .blueHour: SceneStyle(glow: rgba(90, 150, 200, 0.45), glowBright: rgba(150, 210, 240, 0.85),
                                   arrow: .white, arrowShadow: rgba(0, 10, 40, 0.5))
        case .dawn: SceneStyle(glow: rgba(240, 170, 190, 0.5), glowBright: rgba(255, 210, 220, 0.9),
                               arrow: .white, arrowShadow: rgba(120, 60, 110, 0.55))
        case .meadow: SceneStyle(glow: rgba(150, 215, 110, 0.45), glowBright: rgba(200, 240, 150, 0.9),
                                 arrow: .white, arrowShadow: rgba(40, 90, 40, 0.6))
        case .seaside: SceneStyle(glow: rgba(110, 185, 240, 0.5), glowBright: rgba(170, 220, 255, 0.9),
                                  arrow: .white, arrowShadow: rgba(30, 80, 140, 0.55))
        case .sky: SceneStyle(glow: rgba(120, 190, 240, 0.5), glowBright: rgba(170, 220, 255, 0.9),
                              arrow: .white, arrowShadow: rgba(30, 80, 140, 0.55))
        case .golden: SceneStyle(glow: rgba(246, 190, 90, 0.5), glowBright: rgba(255, 225, 140, 0.9),
                                 arrow: .white, arrowShadow: rgba(130, 80, 20, 0.55))
        case .harbor: SceneStyle(glow: rgba(244, 168, 110, 0.5), glowBright: rgba(255, 210, 150, 0.9),
                                 arrow: .white, arrowShadow: rgba(130, 50, 30, 0.55))
        case .town: SceneStyle(glow: rgba(200, 140, 190, 0.45), glowBright: rgba(240, 190, 220, 0.85),
                               arrow: .white, arrowShadow: rgba(30, 20, 60, 0.6))
        case .forest: SceneStyle(glow: rgba(190, 230, 110, 0.4), glowBright: rgba(225, 245, 140, 0.85),
                                 arrow: Color(hex: 0xFFF8E0), arrowShadow: rgba(0, 0, 0, 0.6))
        case .moon: SceneStyle(glow: rgba(70, 60, 146, 0.55), glowBright: rgba(110, 100, 220, 0.85),
                               arrow: .white, arrowShadow: rgba(0, 0, 0, 0.5))
        }
    }

    var speckMotion: SpeckMotion {
        switch self {
        case .blueHour, .dawn, .sky, .moon: SpeckMotion(kind: .twinkle, period: 3.2, stagger: 0.8)
        case .seaside, .harbor: SpeckMotion(kind: .twinkle, period: 1.6, stagger: 0.45)
        case .meadow: SpeckMotion(kind: .sway, period: 2.6, stagger: 0.6)
        case .golden: SpeckMotion(kind: .float, period: 5, stagger: 1.25)
        case .town: SpeckMotion(kind: .flicker, period: 3.8, stagger: 0.9)
        case .forest: SpeckMotion(kind: .drift, period: 4.5, stagger: 1.1)
        }
    }

    var specks: [Speck] {
        func white(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ opacity: Double) -> Speck {
            Speck(x: x, y: y, radius: radius, color: 0xFFFFFF, opacity: opacity)
        }
        switch self {
        case .blueHour:
            return [white(0.30, 0.16, 0.5, 0.5), white(0.70, 0.22, 0.4, 0.35), white(0.52, 0.10, 0.4, 0.4)]
        case .dawn:
            return [white(0.28, 0.16, 0.5, 0.55), white(0.70, 0.22, 0.5, 0.40), white(0.50, 0.10, 0.4, 0.45)]
        case .meadow:
            return [
                Speck(x: 0.16, y: 0.78, radius: 0.7, color: 0xF49AC1, opacity: 1),
                Speck(x: 0.28, y: 0.86, radius: 0.6, color: 0xF8E36B, opacity: 1),
                Speck(x: 0.40, y: 0.80, radius: 0.6, color: 0xFFFFFF, opacity: 0.95),
                Speck(x: 0.60, y: 0.88, radius: 0.7, color: 0xF49AC1, opacity: 1),
                Speck(x: 0.72, y: 0.79, radius: 0.6, color: 0xF8E36B, opacity: 1),
                Speck(x: 0.84, y: 0.74, radius: 0.6, color: 0xE86A8E, opacity: 1),
                Speck(x: 0.50, y: 0.93, radius: 0.6, color: 0xF8E36B, opacity: 1),
                Speck(x: 0.24, y: 0.70, radius: 0.5, color: 0xFFFFFF, opacity: 0.9),
            ]
        case .seaside:
            return [white(0.20, 0.76, 0.5, 0.85), white(0.44, 0.84, 0.4, 0.7), white(0.58, 0.74, 0.5, 0.8),
                    white(0.30, 0.90, 0.4, 0.6)]
        case .sky:
            return [white(0.26, 0.20, 0.6, 0.85), white(0.70, 0.16, 0.5, 0.70), white(0.80, 0.40, 0.5, 0.60),
                    white(0.18, 0.46, 0.5, 0.55), white(0.60, 0.10, 0.4, 0.60)]
        case .golden:
            return [
                Speck(x: 0.22, y: 0.40, radius: 0.5, color: 0xFFF2C0, opacity: 0.8),
                Speck(x: 0.70, y: 0.30, radius: 0.4, color: 0xFFF2C0, opacity: 0.7),
                Speck(x: 0.30, y: 0.80, radius: 0.6, color: 0xF9E3A0, opacity: 0.9),
                Speck(x: 0.62, y: 0.86, radius: 0.5, color: 0xF9E3A0, opacity: 0.9),
            ]
        case .harbor:
            return [white(0.62, 0.74, 0.5, 0.85), white(0.76, 0.80, 0.5, 0.75), white(0.20, 0.84, 0.5, 0.70),
                    white(0.52, 0.88, 0.4, 0.70), white(0.86, 0.70, 0.4, 0.70)]
        case .town:
            let windows: [(CGFloat, CGFloat)] = [(0.16, 0.80), (0.26, 0.86), (0.40, 0.78), (0.58, 0.84),
                                                 (0.70, 0.79), (0.84, 0.82), (0.48, 0.90)]
            return [white(0.30, 0.14, 0.4, 0.6)]
                + windows.map { Speck(x: $0.0, y: $0.1, radius: 0.5, color: 0xFFC96B, opacity: 1, glows: true) }
        case .forest:
            return [(0.24, 0.30, 0.7, 0.95), (0.74, 0.24, 0.6, 0.80), (0.82, 0.56, 0.8, 1.0),
                    (0.16, 0.60, 0.6, 0.85), (0.62, 0.78, 0.6, 0.90), (0.36, 0.80, 0.5, 0.75)]
                .map { Speck(x: $0.0, y: $0.1, radius: $0.2, color: 0xE9F57A, opacity: $0.3, glows: true) }
        case .moon:
            return [white(0.24, 0.24, 0.5, 0.6), white(0.44, 0.12, 0.5, 0.45), white(0.18, 0.50, 0.5, 0.4),
                    white(0.86, 0.52, 0.6, 0.7), white(0.34, 0.36, 0.4, 0.4), white(0.58, 0.16, 0.4, 0.5)]
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 0xFF) / 255, green: Double(hex >> 8 & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}
