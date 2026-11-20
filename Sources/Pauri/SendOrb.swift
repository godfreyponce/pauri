import SwiftUI

/// The send button: a small painted scene that follows the time of day. Design record: `design-directions/issue-10.html`.
struct SendOrb: View {
    static let size: CGFloat = 32

    /// Goes up by one per accepted send. Each change plays the send animation once.
    let sends: Int
    let isEnabled: Bool
    let isAnswering: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Seconds of scene motion played in earlier answers, so the scene holds its frame between them.
    @State private var playedMotion: Double = 0
    @State private var movingSince: Date?

    private var isMoving: Bool { isAnswering && !reduceMotion }

    var body: some View {
        // Not `.disabled`: a disabled plain button may draw itself greyed out, and while answering the orb
        // must stay bright and clickable, because a click then stops the answer.
        Button(action: action) {
            TimelineView(.everyMinute) { minute in
                let weights = DaySchedule.weights(
                    atHour: DaySchedule.hour(of: minute.date, in: .current),
                    starts: DaySchedule.starts(DaySchedule.currentSun(now: minute.date)))
                TimelineView(.animation(paused: movingSince == nil)) { frame in
                    orb(weights: weights, motion: motion(at: frame.date))
                }
            }
            .compositingGroup()
        }
        .buttonStyle(.plain)
        .focusable(false)
        .opacity(isEnabled || isAnswering ? 1 : 0.4)
        .modifier(HoverLabel(text: isAnswering ? "Stop" : "Send", above: true))
        .accessibilityLabel(isAnswering ? "Stop" : "Send")
        .onChange(of: isMoving, initial: true) { _, moving in
            if moving {
                movingSince = .now
            } else if let start = movingSince {
                playedMotion += Date.now.timeIntervalSince(start)
                movingSince = nil
            }
        }
    }

    private func motion(at date: Date) -> Double {
        playedMotion + (movingSince.map { date.timeIntervalSince($0) } ?? 0)
    }

    private func orb(weights: [OrbScene: Double], motion: Double) -> some View {
        let shown = OrbScene.allCases.filter { weights[$0, default: 0] > 0 }
        let style = weights.max { $0.value < $1.value }!.key.style
        let reduceMotion = reduceMotion
        return ZStack {
            ForEach(shown, id: \.self) { scene in
                Circle().fill(scene.style.glow).blur(radius: 3).opacity(weights[scene]!)
            }
            ZStack {
                ForEach(shown, id: \.self) { scene in
                    OrbSceneView(scene: scene, motion: motion).opacity(weights[scene]!)
                }
                Circle().fill(RadialGradient(stops: [.init(color: .clear, location: 0.55),
                                                     .init(color: Color(hex: 0x0A1432, opacity: 0.28), location: 1)],
                                             center: UnitPoint(x: 0.35, y: 0.28), startRadius: 0, endRadius: 31))
                Circle()
                    .fill(RadialGradient(colors: [.white.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 10.9))
                    .frame(width: 21.8, height: 21.8)
                    .scaleEffect(x: 1, y: 0.59)
                    .position(x: 0.34 * Self.size, y: 0.20 * Self.size)
                Circle().strokeBorder(Color(hex: 0x141E32, opacity: 0.35), lineWidth: 0.6)
            }
            .frame(width: Self.size, height: Self.size)
            .clipShape(Circle())
            icon(style)
        }
        .frame(width: Self.size, height: Self.size)
        .keyframeAnimator(initialValue: SendPulse(), trigger: sends) { content, pulse in
            content
                .scaleEffect(reduceMotion ? 1 : pulse.scale)
                .background {
                    Circle().fill(style.glowBright).blur(radius: 6).opacity(reduceMotion ? pulse.flash : 0)
                }
                .overlay {
                    Circle().stroke(style.glowBright, lineWidth: 1.5)
                        .scaleEffect(pulse.ringScale)
                        .opacity(reduceMotion ? 0 : pulse.ringOpacity)
                }
        } keyframes: { _ in
            // A, press and ring: 350 ms press, ring 560 ms. Every track ends on its initial value.
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.88, duration: 0.105)
                SpringKeyframe(1, duration: 0.245, spring: .bouncy)
            }
            KeyframeTrack(\.ringScale) {
                CubicKeyframe(1.6, duration: 0.56)
                LinearKeyframe(1, duration: 0)
            }
            KeyframeTrack(\.ringOpacity) {
                LinearKeyframe(0.8, duration: 0.001)
                CubicKeyframe(0, duration: 0.559)
            }
            // The Reduce Motion form: the glow brightens and fades; nothing moves.
            KeyframeTrack(\.flash) {
                CubicKeyframe(1, duration: 0.105)
                CubicKeyframe(0, duration: 0.245)
            }
        }
    }

    /// The arrow, or a square while an answer streams.
    private func icon(_ style: SceneStyle) -> some View {
        ZStack {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(style.arrow)
                .opacity(isAnswering ? 0 : 1)
                .scaleEffect(isAnswering && !reduceMotion ? 0.6 : 1)
            RoundedRectangle(cornerRadius: 2)
                .fill(style.arrow)
                .frame(width: 10, height: 10)
                .opacity(isAnswering ? 1 : 0)
                .scaleEffect(!isAnswering && !reduceMotion ? 0.6 : 1)
        }
        .shadow(color: style.arrowShadow, radius: 1, y: 0.5)
        .animation(.easeOut(duration: 0.15), value: isAnswering)
    }
}

private struct SendPulse {
    var scale = 1.0
    var ringScale = 1.0
    var ringOpacity = 0.0
    var flash = 0.0
}
