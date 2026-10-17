import SwiftUI

/// Countdown timer that rings like an alarm (same challenge, Mute and Surrender).
struct TimerView: View {
    @ObservedObject private var store = TimerStore.shared
    @ObservedObject private var settings = AppSettings.shared

    @State private var hours = 0
    @State private var minutes = 5
    @State private var seconds = 0
    @State private var label = ""
    @State private var starting = false

    private var duration: TimeInterval { TimeInterval(hours * 3600 + minutes * 60 + seconds) }

    var body: some View {
        NavigationStack {
            List {
                if !store.timers.isEmpty {
                    Section("Running") {
                        ForEach(store.timers) { timer in
                            TimerRow(timer: timer)
                        }
                    }
                }

                Section {
                    HStack(spacing: 0) {
                        wheel($hours, range: 0..<24, unit: "h")
                        wheel($minutes, range: 0..<60, unit: "min")
                        wheel($seconds, range: 0..<60, unit: "s")
                    }
                    .frame(height: 150)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach([1, 5, 10, 15, 25, 45, 60], id: \.self) { m in
                                Button("\(m) min") {
                                    Haptics.tap()
                                    hours = m / 60; minutes = m % 60; seconds = 0
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    TextField("Label (optional)", text: $label)

                    Button {
                        Haptics.press()
                        starting = true
                        Task {
                            await store.start(duration: duration, label: label)
                            starting = false
                        }
                    } label: {
                        Label("Start timer", systemImage: "play.fill")
                            .font(.title3.bold())
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Color.orange, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(duration < 1 || starting)
                    .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                } footer: {
                    Text("When it reaches zero it rings with a \(settings.quickChallenge.title) challenge (\(settings.quickDifficulty.title)). Change this in Settings.")
                }

                if let error = store.lastError {
                    Section { Text(error).foregroundStyle(.yellow) }
                }
            }
            .navigationTitle("Timer")
        }
    }

    private func wheel(_ value: Binding<Int>, range: Range<Int>, unit: String) -> some View {
        HStack(spacing: 2) {
            Picker(unit, selection: value) {
                ForEach(Array(range), id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
            Text(unit).font(.headline).foregroundStyle(.secondary)
        }
    }
}

private struct TimerRow: View {
    let timer: TimerStore.RunningTimer
    @ObservedObject private var store = TimerStore.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(format(timer.remaining(at: context.date)))
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .monospacedDigit()
                    Text(timer.isPaused ? "\(timer.label) · paused" : timer.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Haptics.tap()
                    timer.isPaused ? store.resume(timer.id) : store.pause(timer.id)
                } label: {
                    Image(systemName: timer.isPaused ? "play.fill" : "pause.fill")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(Color.orange.opacity(0.25), in: Circle())
                }
                .buttonStyle(PressableStyle())
                Button {
                    Haptics.tap()
                    store.cancel(timer.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .frame(width: 52, height: 52)
                        .background(Color.red.opacity(0.25), in: Circle())
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func format(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
}
