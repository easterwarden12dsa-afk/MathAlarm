import Foundation
import SwiftUI
import AlarmKit
import ActivityKit

/// Remembers why each AlarmKit alarm exists, so an intent that only receives
/// an alarm ID can start the right ring (label, challenge, sound…).
@MainActor
final class AlarmRegistry {
    static let shared = AlarmRegistry()
    private static let fileName = "alarmRegistry.json"

    private var contexts: [UUID: RingContext]

    private init() {
        contexts = Persistence.load([UUID: RingContext].self, from: Self.fileName) ?? [:]
    }

    func register(_ id: UUID, _ context: RingContext) {
        contexts[id] = context
        save()
    }

    func context(for id: UUID) -> RingContext? { contexts[id] }

    func remove(_ id: UUID) {
        guard contexts.removeValue(forKey: id) != nil else { return }
        save()
    }

    func ids(withPurpose purposes: Set<AlarmPurpose>) -> [UUID] {
        contexts.filter { purposes.contains($0.value.purpose) }.map(\.key)
    }

    /// Drops entries for alarms AlarmKit no longer knows about. Entries are kept
    /// for a while after they vanish because the Stop intent can arrive just
    /// after a one-shot alarm has been removed from the system.
    func prune(keeping liveIDs: Set<UUID>) {
        let cutoff = Date().addingTimeInterval(-2 * 24 * 3600)
        let before = contexts.count
        contexts = contexts.filter { liveIDs.contains($0.key) || $0.value.createdAt > cutoff }
        if contexts.count != before { save() }
    }

    private func save() {
        Persistence.save(contexts, to: Self.fileName)
    }
}

/// Thin wrapper around AlarmKit's `AlarmManager`.
@MainActor
enum AlarmScheduler {
    static var manager: AlarmManager { AlarmManager.shared }

    static var authorizationState: AlarmManager.AuthorizationState { manager.authorizationState }

    static func requestAuthorization() async -> Bool {
        do {
            return try await manager.requestAuthorization() == .authorized
        } catch {
            return false
        }
    }

    static func currentAlarms() -> [Alarm] {
        (try? manager.alarms) ?? []
    }

    /// AlarmKit schedules for a user alarm. Daily = weekly on all 7 days.
    /// Weekday rows sharing a time are grouped into one AlarmKit alarm.
    static func schedules(for item: AlarmItem) -> [Alarm.Schedule] {
        switch item.repeatMode {
        case .once:
            guard let date = item.onceFireDate, date > Date() else { return [] }
            return [.fixed(date)]
        case .daily:
            let time = Alarm.Schedule.Relative.Time(hour: item.time.hour, minute: item.time.minute)
            let all: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
            return [.relative(.init(time: time, repeats: .weekly(all)))]
        case .weekdays:
            var byTime: [TimeOfDay: [Locale.Weekday]] = [:]
            for wt in item.enabledWeekdays {
                byTime[wt.time, default: []].append(localeWeekday(wt.weekday))
            }
            return byTime
                .sorted { ($0.key.hour, $0.key.minute) < ($1.key.hour, $1.key.minute) }
                .map { entry -> Alarm.Schedule in
                    let time = Alarm.Schedule.Relative.Time(hour: entry.key.hour, minute: entry.key.minute)
                    return .relative(Alarm.Schedule.Relative(time: time, repeats: .weekly(entry.value)))
                }
        }
    }

    static func localeWeekday(_ calendarWeekday: Int) -> Locale.Weekday {
        switch calendarWeekday {
        case 1: .sunday
        case 2: .monday
        case 3: .tuesday
        case 4: .wednesday
        case 5: .thursday
        case 6: .friday
        default: .saturday
        }
    }

    /// Schedules one AlarmKit alarm. The alert shows the system Stop button
    /// plus our "Solve" button, which opens the app on the challenge.
    static func schedule(id: UUID, schedule: Alarm.Schedule, context: RingContext) async throws {
        let solveButton = AlarmButton(text: "Solve", textColor: .white, systemImageName: "function")
        let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: context.label),
            secondaryButton: solveButton,
            secondaryButtonBehavior: .custom)
        let metadata = MathAlarmMetadata(label: context.label,
                                         challenge: context.challenge.title,
                                         purpose: context.purpose.rawValue)
        let attributes = AlarmAttributes<MathAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: .orange)
        let configuration = AlarmManager.AlarmConfiguration<MathAlarmMetadata>.alarm(
            schedule: schedule,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: SolveAlarmIntent(alarmID: id.uuidString),
            sound: context.sound.isSystemDefault ? .default : .named(context.sound.resolved.fileName))

        AlarmRegistry.shared.register(id, context)
        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
        } catch {
            AlarmRegistry.shared.remove(id)
            throw error
        }
    }

    /// Starts a countdown timer that rings like an alarm when it reaches zero.
    /// Shows a live countdown (with Pause/Resume) on the Lock Screen.
    static func scheduleTimer(id: UUID, duration: TimeInterval, context: RingContext) async throws {
        let label = LocalizedStringResource(stringLiteral: context.label)
        let solveButton = AlarmButton(text: "Solve", textColor: .white, systemImageName: "function")
        let alert = AlarmPresentation.Alert(title: label, secondaryButton: solveButton, secondaryButtonBehavior: .custom)
        let countdown = AlarmPresentation.Countdown(
            title: label,
            pauseButton: AlarmButton(text: "Pause", textColor: .orange, systemImageName: "pause.fill"))
        let paused = AlarmPresentation.Paused(
            title: "Paused",
            resumeButton: AlarmButton(text: "Resume", textColor: .orange, systemImageName: "play.fill"))
        let metadata = MathAlarmMetadata(label: context.label, challenge: context.challenge.title,
                                         purpose: context.purpose.rawValue)
        let attributes = AlarmAttributes<MathAlarmMetadata>(
            presentation: AlarmPresentation(alert: alert, countdown: countdown, paused: paused),
            metadata: metadata,
            tintColor: .orange)
        let configuration = AlarmManager.AlarmConfiguration<MathAlarmMetadata>.timer(
            duration: duration,
            attributes: attributes,
            stopIntent: StopAlarmIntent(alarmID: id.uuidString),
            secondaryIntent: SolveAlarmIntent(alarmID: id.uuidString),
            sound: context.sound.isSystemDefault ? .default : .named(context.sound.resolved.fileName))

        AlarmRegistry.shared.register(id, context)
        do {
            _ = try await manager.schedule(id: id, configuration: configuration)
        } catch {
            AlarmRegistry.shared.remove(id)
            throw error
        }
    }

    static func pause(_ id: UUID) { try? manager.pause(id: id) }
    static func resume(_ id: UUID) { try? manager.resume(id: id) }

    /// Schedules a one-shot alarm at an absolute instant and returns its ID.
    @discardableResult
    static func scheduleFixed(at date: Date, context: RingContext) async throws -> UUID {
        let id = UUID()
        try await schedule(id: id, schedule: .fixed(date), context: context)
        return id
    }

    /// Stops it if ringing and removes it from the system.
    static func cancel(_ id: UUID) {
        try? manager.stop(id: id)
        try? manager.cancel(id: id)
        AlarmRegistry.shared.remove(id)
    }

    /// Silences a ringing alarm (a repeating alarm stays scheduled for next time).
    static func stop(_ id: UUID) {
        try? manager.stop(id: id)
    }
}
