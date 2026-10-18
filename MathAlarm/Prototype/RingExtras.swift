import SwiftUI
import CoreMotion

/// Counts steps since `start()` (for "walk before the alarm stops").
@MainActor
final class StepCounter: ObservableObject {
    static var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    @Published private(set) var steps = 0
    @Published private(set) var denied = false
    private let pedometer = CMPedometer()

    func start() {
        guard Self.isAvailable else { return }
        pedometer.startUpdates(from: Date()) { data, error in
            let n = data?.numberOfSteps.intValue
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let n { self.steps = n }
                if failed { self.denied = CMPedometer.authorizationStatus() == .denied }
            }
        }
    }

    func stop() { pedometer.stopUpdates() }
}

/// After the last problem: walk N steps, then the alarm stops.
struct StepGateView: View {
    let needed: Int
    var onDone: () -> Void
    @StateObject private var counter = StepCounter()
    @State private var finished = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 72, weight: .bold))
                .foregroundStyle(.orange)
                .symbolEffect(.bounce, options: .repeating, value: counter.steps)
            Text("Get out of bed")
                .font(.largeTitle.bold())
            Text("Walk \(needed) steps to turn the alarm off.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
            ZStack {
                Circle().stroke(Color.white.opacity(0.15), lineWidth: 16)
                Circle()
                    .trim(from: 0, to: min(1, Double(counter.steps) / Double(max(1, needed))))
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: counter.steps)
                Text("\(min(counter.steps, needed)) / \(needed)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 200, height: 200)
            if counter.denied {
                Text("Motion access is off (Settings → Privacy → Motion & Fitness). Use Surrender, or turn the steps setting off.")
                    .font(.footnote)
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .onAppear { counter.start() }
        .onDisappear { counter.stop() }
        .onChange(of: counter.steps) { _, n in
            if n >= needed && !finished {
                finished = true
                Haptics.success()
                onDone()
            }
        }
    }
}

/// A few minutes after solving: just prove you didn't go back to sleep.
struct AwakeCheckView: View {
    var onAwake: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
            Text("Still awake?")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text("You solved your alarm a few minutes ago. Tap to show you didn't fall back asleep.")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
            Button {
                Haptics.success()
                onAwake()
            } label: {
                Label("I'm awake", systemImage: "checkmark")
                    .font(.title.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 80)
                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 22))
            }
            .buttonStyle(PressableStyle())
            Spacer()
        }
        .padding(.horizontal, 8)
    }
}

/// Surrender that must be held for two seconds (so it isn't a half-asleep reflex).
struct HoldToSurrenderButton: View {
    var hold: Bool
    var action: () -> Void
    @State private var progress: CGFloat = 0
    @State private var pressing = false
    @State private var showHint = false
    private let duration: Double = 2

    var body: some View {
        if hold {
            label
                .overlay(alignment: .leading) {
                    GeometryReader { g in
                        Color.white.opacity(0.35)
                            .frame(width: g.size.width * progress)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .allowsHitTesting(false)
                }
                .scaleEffect(pressing ? 0.95 : 1)
                .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
                    Haptics.press()
                    progress = 0
                    action()
                } onPressingChanged: { down in
                    pressing = down
                    if down {
                        Haptics.tap()
                        withAnimation(.linear(duration: duration)) { progress = 1 }
                    } else {
                        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
                        showHint = true
                    }
                }
                .overlay(alignment: .bottom) {
                    if showHint && !pressing {
                        Text(streakWarning)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                            .fixedSize()
                            .offset(y: 18)
                            .transition(.opacity)
                            .task {
                                try? await Task.sleep(nanoseconds: 2_500_000_000)
                                withAnimation { showHint = false }
                            }
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Hold for two seconds to turn the alarm off")
                .accessibilityAction { action() }
        } else {
            Button(action: action) { label }
                .buttonStyle(PressableStyle())
                .accessibilityHint("Turns the alarm off immediately")
        }
    }

    private var streakWarning: String {
        let s = AppSettings.shared.streak
        return s > 0 ? "Hold 2 s · your \(s)-day streak resets" : "Hold for 2 seconds"
    }

    private var label: some View {
        Label("Surrender", systemImage: "flag.fill")
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(minWidth: 116, minHeight: 48)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 14))
    }
}
