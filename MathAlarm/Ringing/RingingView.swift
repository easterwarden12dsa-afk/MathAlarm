import SwiftUI
import MathEngine

/// Full-screen ringing screen, designed for someone half asleep:
/// black background, big high-contrast controls, screen kept awake.
/// Top bar: Mute (left) and Surrender (right) are always visible.
struct RingingView: View {
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            VStack(spacing: 8) {
                topBar(now: now)

                if ring.sound.outputVolume < 0.5, !(ring.session?.isMuted(at: now) ?? false) {
                    Label("Volume is low — press the volume-up button", systemImage: "speaker.wave.1.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.black)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 10))
                }

                if let session = ring.session, let sketch = session.sketch {
                    SketchChallengeView(
                        problem: sketch,
                        strokes: Binding(get: { ring.session?.strokes ?? [] },
                                         set: { ring.updateStrokes($0) }),
                        mode: AppSettings.shared.sketchMode,
                        steps: { GraphSteps.steps(for: sketch) },
                        onSolutionViewed: { ring.replaceProblem() },
                        allowZoneReveal: AppSettings.shared.zoneRevealInAlarms,
                        onSolved: { ring.solvedOne() }) {
                        SketchHeader(problem: sketch)
                    }
                    .id(sketch.signature + "\(session.solvesDone ?? 0)")
                } else if let session = ring.session, let change = session.change {
                    let display = AppSettings.shared.changeDisplay
                    SketchChallengeView(
                        problem: change.target,
                        strokes: Binding(get: { ring.session?.strokes ?? [] },
                                         set: { ring.updateStrokes($0) }),
                        mode: AppSettings.shared.sketchMode,
                        reference: display.showsGraph ? change.base : nil,
                        steps: { GraphSteps.steps(for: change, formulaVisible: display.showsFormula) },
                        onSolutionViewed: { ring.replaceProblem() },
                        allowZoneReveal: AppSettings.shared.zoneRevealInAlarms,
                        onSolved: { ring.solvedOne() }) {
                        ChangeHeader(change: change, display: display)
                    }
                    .id(change.signature + "\(session.solvesDone ?? 0)")
                } else if let session = ring.session, let problem = session.problem {
                    ChallengeView(
                        problem: problem,
                        editor: Binding(get: { ring.session?.editor ?? MathEditor() },
                                        set: { ring.updateEditor($0) }),
                        onSolutionViewed: { ring.replaceProblem() },
                        onSolved: { ring.solvedOne() })
                    .id(problem.seed)
                } else {
                    Spacer()
                    ProgressView().tint(.white)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 4)
        }
        .background(Color.black.ignoresSafeArea())
        .toast($ring.toast)
        .interactiveDismissDisabled()
    }

    // MARK: Top bar

    private func topBar(now: Date) -> some View {
        HStack(spacing: 10) {
            muteButton(now: now)
            Spacer(minLength: 4)
            VStack(spacing: 0) {
                Text(now.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(ring.session?.progressText ?? ring.session?.label ?? "Alarm")
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .foregroundStyle(.white)
            Spacer(minLength: 4)
            Button {
                ring.resolve(.surrendered)
            } label: {
                Label("Surrender", systemImage: "flag.fill")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .frame(minWidth: 120, minHeight: 54)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(PressableStyle())
            .accessibilityHint("Turns the alarm off immediately")
        }
    }

    private func muteButton(now: Date) -> some View {
        let remaining = ring.session?.muteUntil.map { max(0, $0.timeIntervalSince(now)) } ?? 0
        let muted = remaining > 0
        return Button {
            ring.mute()
        } label: {
            Label(muted ? countdown(remaining) : "Mute",
                  systemImage: muted ? "speaker.slash.fill" : "speaker.slash")
                .font(.headline.bold())
                .monospacedDigit()
                .foregroundStyle(muted ? Color.black : Color.white)
                .frame(minWidth: 120, minHeight: 54)
                .background(muted ? Color.orange : Color.white.opacity(0.2),
                            in: RoundedRectangle(cornerRadius: 14))
                .animation(.easeInOut(duration: 0.2), value: muted)
        }
        .buttonStyle(PressableStyle())
        .disabled(muted)
        .accessibilityLabel(muted ? "Muted, \(Int(remaining)) seconds left" : "Mute for 90 seconds")
    }

    private func countdown(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
