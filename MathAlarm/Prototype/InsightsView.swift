import SwiftUI
import Charts
import AlarmKit
import MathEngine

/// The Progress tab: wake-up times, accuracy per topic, the exam countdown
/// with today's plan, and achievements.
struct InsightsView: View {
    @ObservedObject private var store = LearningStore.shared
    @ObservedObject private var settings = AppSettings.shared
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let exam = settings.examDate { examCard(exam) }
                    statsRow
                    wakeCard
                    topicsCard
                    achievementsCard
                    Button("Reset progress data", role: .destructive) { confirmClear = true }
                        .font(.footnote)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Progress")
            .confirmationDialog("Delete history, favourites, review and charts?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { store.clearAll() }
            }
        }
    }

    // MARK: Cards

    private func card<Content: View>(_ title: String, _ symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol).font(.headline).foregroundStyle(.orange)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }

    private func examCard(_ exam: Date) -> some View {
        let days = max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()),
                                                         to: Calendar.current.startOfDay(for: exam)).day ?? 0)
        return card("Bagrut countdown", "graduationcap.fill") {
            HStack(alignment: .firstTextBaseline) {
                Text("\(days)").font(.system(size: 48, weight: .bold, design: .rounded)).monospacedDigit()
                Text(days == 1 ? "day left" : "days left").font(.title3).foregroundStyle(.secondary)
                Spacer()
                Text(exam.formatted(date: .abbreviated, time: .omitted)).font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Today's plan").font(.subheadline.weight(.bold))
            ForEach(plan(daysLeft: days), id: \.self) { line in
                Label(line, systemImage: "circle").font(.subheadline)
            }
        }
    }

    /// More, harder work as the exam gets closer, aimed at the weakest topics.
    private func plan(daysLeft: Int) -> [String] {
        var out: [String] = []
        let due = store.dueReview.count
        if due > 0 { out.append("Review \(due) problem\(due == 1 ? "" : "s") you missed") }
        let weak = store.weakTopics.prefix(2).map(\.topic)
        let n = daysLeft <= 7 ? 5 : (daysLeft <= 30 ? 3 : 2)
        for t in weak { out.append("\(n) × \(t)") }
        if weak.isEmpty { out.append("\(n) × Graph Sketch at Bagrut 5U") }
        out.append(daysLeft <= 14 ? "1 mini exam at Bagrut 5U" : "1 mini exam at Hard")
        if daysLeft <= 7 { out.append("1 speed round to warm up") }
        return out
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("\(settings.streak)", "day streak", "flame.fill", .orange)
            stat("\(store.data.history.filter(\.solved).count)", "solved", "checkmark.circle.fill", .green)
            stat(store.data.bestSpeedRound.map { String(format: "%.0fs", $0) } ?? "–", "best speed", "stopwatch.fill", .cyan)
        }
    }

    private func stat(_ value: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title2.bold()).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private struct WakePoint: Identifiable {
        let id: UUID
        let day: Date
        let hour: Double
        let minutes: Double
        let surrendered: Bool
    }

    private var wakePoints: [WakePoint] {
        store.data.rings.suffix(30).map { r in
            let c = Calendar.current.dateComponents([.hour, .minute], from: r.date)
            return WakePoint(id: r.id, day: r.date, hour: Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60,
                             minutes: r.seconds / 60, surrendered: r.surrendered)
        }
    }

    private var wakeCard: some View {
        card("Waking up", "sunrise.fill") {
            let points = wakePoints
            if points.isEmpty {
                Text("After your first alarm, this shows when you got up and how long the problem took.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Text("Time to turn the alarm off (minutes)").font(.caption).foregroundStyle(.secondary)
                Chart(points) { p in
                    BarMark(x: .value("Day", p.day, unit: .day), y: .value("Minutes", p.minutes))
                        .foregroundStyle(p.surrendered ? Color.red : Color.orange)
                }
                .frame(height: 140)
                Text("Time you got up").font(.caption).foregroundStyle(.secondary)
                Chart(points) { p in
                    PointMark(x: .value("Day", p.day, unit: .day), y: .value("Hour", p.hour))
                        .foregroundStyle(p.surrendered ? Color.red : Color.green)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 120)
                let rings = store.data.rings
                let surrendered = rings.filter(\.surrendered).count
                let avg = rings.isEmpty ? 0 : rings.map(\.seconds).reduce(0, +) / Double(rings.count)
                Text("\(rings.count) alarms · \(surrendered) surrendered · average \(Int(avg / 60)) min \(Int(avg) % 60) s")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var topicsCard: some View {
        card("Accuracy by topic", "chart.bar.fill") {
            let topics = store.data.topics.sorted { $0.value.attempts > $1.value.attempts }.prefix(10)
                .map { TopicBar(key: $0.key, value: $0.value) }
            if topics.isEmpty {
                Text("Solve a few problems in Practice to see where you're strong and weak.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(topics) { t in
                    BarMark(x: .value("Correct", t.value.rate * 100), y: .value("Topic", t.key))
                        .foregroundStyle(t.value.rate < 0.5 ? Color.red : (t.value.rate < 0.8 ? Color.yellow : Color.green))
                        .annotation(position: .trailing) {
                            Text("\(t.value.correct)/\(t.value.attempts)").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXScale(domain: 0...115)
                .chartXAxis(.hidden)
                .frame(height: CGFloat(topics.count) * 30 + 20)
            }
        }
    }

    private struct TopicBar: Identifiable {
        let key: String
        let value: LearningStore.TopicStat
        var id: String { key }
    }

    private var achievementsCard: some View {
        card("Achievements", "trophy.fill") {
            let all = store.achievements
            Text("\(all.filter(\.unlocked).count) of \(all.count) unlocked").font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(all) { a in
                    VStack(spacing: 6) {
                        Image(systemName: a.symbol)
                            .font(.title2)
                            .foregroundStyle(a.unlocked ? .yellow : .white.opacity(0.25))
                        Text(a.title).font(.subheadline.weight(.bold))
                        Text(a.detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .padding(6)
                    .background(Color.white.opacity(a.unlocked ? 0.1 : 0.04), in: RoundedRectangle(cornerRadius: 14))
                    .opacity(a.unlocked ? 1 : 0.7)
                }
            }
        }
    }
}

// MARK: - Test my setup

/// Everything that can stop an alarm from ringing, checked in one place.
struct SetupCheckView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var ring: RingCoordinator
    @ObservedObject private var settings = AppSettings.shared
    @State private var testScheduled: Date?

    var body: some View {
        List {
            Section {
                row("Alarm permission", ok: store.authorization == .authorized,
                    detail: store.authorization == .authorized ? "Allowed" : "Not allowed — alarms can't ring. Open iPhone Settings → Math Alarm β.")
                let volume = ring.sound.outputVolume
                row("Volume", ok: volume >= 0.5,
                    detail: "\(Int((volume * 100).rounded()))% — " + (volume >= 0.5 ? "loud enough for in-app ringing" : "turn it up (the in-app sound uses media volume)"))
                if let days = ExpiryMonitor.daysLeft {
                    row("Install expiry", ok: days > 2,
                        detail: days < 1 ? "Expires in less than a day — reinstall now" : "\(Int(days)) days left")
                } else {
                    row("Install expiry", ok: true, detail: "Not found (fine for non-sideloaded builds)")
                }
                let enabled = store.alarms.filter(\.isEnabled)
                row("Alarms on", ok: !enabled.isEmpty,
                    detail: enabled.isEmpty ? "No alarm is switched on" : "\(enabled.count) on · next \(enabled.compactMap { $0.nextFireDate() }.min()?.formatted(date: .abbreviated, time: .shortened) ?? "–")")
                if settings.stepsToWalk > 0 {
                    row("Motion (for steps)", ok: StepCounter.isAvailable,
                        detail: StepCounter.isAvailable ? "Available — you'll be asked once" : "Step counting isn't available")
                }
            } header: {
                Text("Checks")
            }
            Section {
                Button {
                    Task {
                        if await ring.scheduleTestRing() { testScheduled = Date().addingTimeInterval(10) }
                    }
                } label: {
                    Label("Ring a test alarm in 10 seconds", systemImage: "alarm.waves.left.and.right")
                }
                if let testScheduled {
                    Text("Test set for \(testScheduled.formatted(date: .omitted, time: .standard)). Lock the phone to check it rings on the lock screen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("The test uses the challenge and sound from \u{201C}Timers and the 10-second test\u{201D}.")
            }
        }
        .navigationTitle("Test my setup")
    }

    private func row(_ title: String, ok: Bool, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? .green : .yellow)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
