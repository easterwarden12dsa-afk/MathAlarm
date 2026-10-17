import Foundation
import AlarmKit

/// Running countdown timers. AlarmKit does the counting (it keeps going
/// when the app is closed); this store keeps what the Timer tab shows.
@MainActor
final class TimerStore: ObservableObject {
    static let shared = TimerStore()
    private static let fileName = "timers.json"

    struct RunningTimer: Codable, Identifiable, Hashable {
        let id: UUID
        var label: String
        var duration: TimeInterval
        /// When it reaches zero (nil while paused).
        var endDate: Date?
        /// Time left while paused.
        var pausedRemaining: TimeInterval?

        var isPaused: Bool { pausedRemaining != nil }

        func remaining(at now: Date = Date()) -> TimeInterval {
            if let pausedRemaining { return pausedRemaining }
            return Swift.max(0, (endDate ?? now).timeIntervalSince(now))
        }
    }

    @Published private(set) var timers: [RunningTimer]
    @Published var lastError: String?

    private init() {
        timers = Persistence.load([RunningTimer].self, from: Self.fileName) ?? []
        Task { [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                self?.sync(with: alarms)
            }
        }
    }

    func start(duration: TimeInterval, label: String) async {
        let settings = AppSettings.shared
        let name = label.trimmingCharacters(in: .whitespaces).isEmpty ? "Timer" : label
        let context = RingContext(itemID: nil, label: name, challenge: settings.quickChallenge,
                                  difficulty: settings.quickDifficulty, sound: settings.quickSound, purpose: .timer)
        let id = UUID()
        do {
            try await AlarmScheduler.scheduleTimer(id: id, duration: duration, context: context)
            timers.append(RunningTimer(id: id, label: name, duration: duration,
                                       endDate: Date().addingTimeInterval(duration), pausedRemaining: nil))
            save()
        } catch {
            lastError = "Couldn't start the timer: \(error.localizedDescription)"
        }
    }

    func pause(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), !timers[i].isPaused else { return }
        AlarmScheduler.pause(id)
        timers[i].pausedRemaining = timers[i].remaining()
        timers[i].endDate = nil
        save()
    }

    func resume(_ id: UUID) {
        guard let i = timers.firstIndex(where: { $0.id == id }), let left = timers[i].pausedRemaining else { return }
        AlarmScheduler.resume(id)
        timers[i].endDate = Date().addingTimeInterval(left)
        timers[i].pausedRemaining = nil
        save()
    }

    func cancel(_ id: UUID) {
        AlarmScheduler.cancel(id)
        timers.removeAll { $0.id == id }
        save()
    }

    /// Keeps the list in step with AlarmKit: finished timers disappear, and
    /// pausing/resuming from the Lock Screen is reflected here.
    private func sync(with alarms: [Alarm]) {
        let byID = Dictionary(alarms.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let before = timers.count
        timers.removeAll { timer in
            guard let alarm = byID[timer.id] else { return true }   // finished and stopped
            return alarm.state == .alerting                          // ringing now
        }
        var changed = timers.count != before
        for i in timers.indices {
            guard let alarm = byID[timers[i].id] else { continue }
            if alarm.state == .paused, !timers[i].isPaused {
                timers[i].pausedRemaining = timers[i].remaining()
                timers[i].endDate = nil
                changed = true
            } else if alarm.state == .countdown, let left = timers[i].pausedRemaining {
                timers[i].endDate = Date().addingTimeInterval(left)
                timers[i].pausedRemaining = nil
                changed = true
            }
        }
        if changed { save() }
    }

    private func save() {
        Persistence.save(timers, to: Self.fileName)
    }
}
