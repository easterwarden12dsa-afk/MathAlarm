import SwiftUI

/// Full-screen ringing screen, designed for someone half asleep:
/// black background, huge high-contrast buttons, screen kept awake.
struct RingingView: View {
    @EnvironmentObject private var ring: RingCoordinator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            VStack(spacing: 0) {
                topBar(now: now)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                if ring.sound.outputVolume < 0.4, !(ring.session?.isMuted(at: now) ?? false) {
                    Label("Volume is low — press volume up", systemImage: "speaker.wave.1.fill")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Color.yellow)
                        .padding(.top, 8)
                }

                Spacer(minLength: 16)

                VStack(spacing: 8) {
                    Text(now.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                    Text(ring.session?.label ?? "Alarm")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer(minLength: 16)

                challengeArea
                    .padding(.horizontal, 16)

                Spacer(minLength: 16)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .interactiveDismissDisabled()
        .statusBarHidden(false)
    }

    // MARK: Top bar: Mute (left), Surrender (right)

    private func topBar(now: Date) -> some View {
        HStack(spacing: 12) {
            muteButton(now: now)
            Spacer(minLength: 8)
            Button {
                ring.resolve(.surrendered)
            } label: {
                Text("Surrender")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(minWidth: 140, minHeight: 60)
                    .background(Color.red, in: RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityHint("Turns the alarm off immediately")
        }
    }

    private func muteButton(now: Date) -> some View {
        let remaining = ring.session?.muteUntil.map { max(0, $0.timeIntervalSince(now)) } ?? 0
        let muted = remaining > 0
        return Button {
            ring.mute()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.slash")
                Text(muted ? countdown(remaining) : "Mute")
                    .monospacedDigit()
            }
            .font(.title3.bold())
            .foregroundStyle(muted ? Color.black : Color.white)
            .frame(minWidth: 140, minHeight: 60)
            .background(muted ? Color.orange : Color.white.opacity(0.18),
                        in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(muted)
        .accessibilityLabel(muted ? "Muted, \(Int(remaining)) seconds left" : "Mute for 90 seconds")
    }

    private func countdown(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // MARK: Challenge (placeholder until M2 adds the math)

    private var challengeArea: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(ring.session?.challenge.title ?? "")
                    .font(.title.bold())
                    .foregroundStyle(.orange)
                Text("\(ring.session?.difficulty.title ?? "") difficulty")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("The math challenge arrives in milestone 2. For now, use Dismiss.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))

            Button {
                ring.resolve(.solved)
            } label: {
                Text("Dismiss (temporary)")
                    .font(.title2.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(Color.green, in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}
