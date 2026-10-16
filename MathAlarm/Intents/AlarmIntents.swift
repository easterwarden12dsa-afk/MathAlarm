import AppIntents
import AlarmKit

/// Runs (in the app's process, in the background) after the person presses
/// the system Stop button. Stop can't be blocked, so this schedules a
/// re-ring a few seconds later unless the challenge has been resolved.
struct StopAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop alarm"
    static var description = IntentDescription("Stops a Math Alarm. It rings again until the challenge is solved.")
    static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            await RingCoordinator.shared.handleSystemStop(alarmID: id)
        }
        return .result()
    }
}

/// The "Solve" button on the alarm: opens the app on the challenge screen.
struct SolveAlarmIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Solve to stop"
    static var description = IntentDescription("Opens Math Alarm on the challenge.")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = false

    @Parameter(title: "Alarm ID")
    var alarmID: String

    init(alarmID: String) {
        self.alarmID = alarmID
    }

    init() {
        self.alarmID = ""
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: alarmID) {
            RingCoordinator.shared.handleSolveButton(alarmID: id)
        }
        return .result()
    }
}
