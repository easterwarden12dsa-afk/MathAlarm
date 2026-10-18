import Foundation
import SwiftUI
import UserNotifications
import MathEngine

/// User preferences and simple stats, stored in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    /// How the "Change" challenge shows the given function f.
    enum ChangeDisplay: String, CaseIterable, Identifiable {
        case graph, formula, both
        var id: String { rawValue }
        var title: String {
            switch self {
            case .graph: "Graph"
            case .formula: "Formula"
            case .both: "Both"
            }
        }
        var showsGraph: Bool { self != .formula }
        var showsFormula: Bool { self != .graph }
    }

    /// How Graph Sketch and Change drawings are judged.
    @Published var sketchMode: SketchMode {
        didSet { defaults.set(sketchMode.rawValue, forKey: "sketchMode") }
    }
    @Published var changeDisplay: ChangeDisplay {
        didSet { defaults.set(changeDisplay.rawValue, forKey: "changeDisplay") }
    }
    /// Let the "show the correct graph in this zone" button work during alarms too.
    @Published var zoneRevealInAlarms: Bool {
        didSet { defaults.set(zoneRevealInAlarms, forKey: "zoneRevealInAlarms") }
    }
    /// Graph Sketch: draw the whole graph (zoom and pan) for non-periodic functions.
    @Published var wholeGraph: Bool {
        didSet { defaults.set(wholeGraph, forKey: "wholeGraph") }
    }
    /// Problems to solve before a ring stops (1–3).
    @Published var problemsPerRing: Int {
        didSet { defaults.set(problemsPerRing, forKey: "problemsPerRing") }
    }
    /// Challenge used by the 10-second test and by timers.
    @Published var quickChallenge: ChallengeKind {
        didSet { defaults.set(quickChallenge.rawValue, forKey: "quickChallenge") }
    }
    @Published var quickDifficulty: Difficulty {
        didSet { defaults.set(quickDifficulty.rawValue, forKey: "quickDifficulty") }
    }
    @Published var quickSound: AlarmSound {
        didSet { defaults.set(quickSound.id, forKey: "quickSound") }
    }
    @Published var expiryReminder: Bool {
        didSet {
            defaults.set(expiryReminder, forKey: "expiryReminder")
            Task { await ExpiryMonitor.updateReminder(enabled: expiryReminder) }
        }
    }

    /// English or Hebrew (right to left).
    @Published var language: AppLanguage {
        didSet {
            AppLanguage.current = language
            defaults.set(language.rawValue, forKey: "appLanguage")
            // System texts (alerts, date pickers) follow on the next launch.
            defaults.set([language.rawValue], forKey: "AppleLanguages")
        }
    }

    // Prototype features
    /// Every 3 wrong answers add one more problem (at most 2 extra).
    @Published var escalation: Bool {
        didSet { defaults.set(escalation, forKey: "escalation") }
    }
    /// Minutes after solving for an "are you awake?" ring (0 = off).
    @Published var awakeCheckMinutes: Int {
        didSet { defaults.set(awakeCheckMinutes, forKey: "awakeCheckMinutes") }
    }
    /// Surrender needs a 2-second hold.
    @Published var holdToSurrender: Bool {
        didSet { defaults.set(holdToSurrender, forKey: "holdToSurrender") }
    }
    /// Difficulty on Friday and Saturday mornings (nil = the alarm's own).
    @Published var weekendDifficulty: Difficulty? {
        didSet { defaults.set(weekendDifficulty?.rawValue ?? "", forKey: "weekendDifficulty") }
    }
    /// Steps to walk after solving before the alarm stops (0 = off).
    @Published var stepsToWalk: Int {
        didSet { defaults.set(stepsToWalk, forKey: "stepsToWalk") }
    }
    /// The Bagrut exam date, for the countdown.
    @Published var examDate: Date? {
        didSet { defaults.set(examDate, forKey: "examDate") }
    }

    // Stats
    @Published private(set) var solved: Int
    @Published private(set) var surrendered: Int
    @Published private(set) var streak: Int
    private var lastSolvedDay: String

    private init() {
        sketchMode = SketchMode(rawValue: defaults.string(forKey: "sketchMode") ?? "") ?? .standard
        changeDisplay = ChangeDisplay(rawValue: defaults.string(forKey: "changeDisplay") ?? "") ?? .both
        zoneRevealInAlarms = defaults.bool(forKey: "zoneRevealInAlarms")
        wholeGraph = defaults.bool(forKey: "wholeGraph")
        let perRing = defaults.integer(forKey: "problemsPerRing")
        problemsPerRing = (1...3).contains(perRing) ? perRing : 1
        quickChallenge = ChallengeKind(rawValue: defaults.string(forKey: "quickChallenge") ?? "") ?? .random
        quickDifficulty = Difficulty(rawValue: defaults.string(forKey: "quickDifficulty") ?? "") ?? .medium
        quickSound = AlarmSound(id: defaults.string(forKey: "quickSound") ?? "classic")
        expiryReminder = defaults.object(forKey: "expiryReminder") as? Bool ?? false
        language = AppLanguage.current
        escalation = defaults.object(forKey: "escalation") as? Bool ?? true
        awakeCheckMinutes = defaults.integer(forKey: "awakeCheckMinutes")
        holdToSurrender = defaults.object(forKey: "holdToSurrender") as? Bool ?? true
        weekendDifficulty = Difficulty(rawValue: defaults.string(forKey: "weekendDifficulty") ?? "")
        stepsToWalk = defaults.integer(forKey: "stepsToWalk")
        examDate = defaults.object(forKey: "examDate") as? Date
        solved = defaults.integer(forKey: "statSolved")
        surrendered = defaults.integer(forKey: "statSurrendered")
        streak = defaults.integer(forKey: "statStreak")
        lastSolvedDay = defaults.string(forKey: "statLastSolvedDay") ?? ""
    }

    func recordSolved() {
        solved += 1
        let today = Self.dayKey(Date())
        if lastSolvedDay != today {
            let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())
            streak = lastSolvedDay == yesterday ? streak + 1 : 1
            lastSolvedDay = today
        }
        save()
    }

    func recordSurrender() {
        surrendered += 1
        streak = 0
        save()
    }

    private func save() {
        defaults.set(solved, forKey: "statSolved")
        defaults.set(surrendered, forKey: "statSurrendered")
        defaults.set(streak, forKey: "statStreak")
        defaults.set(lastSolvedDay, forKey: "statLastSolvedDay")
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}

/// Free-Apple-ID apps stop opening 7 days after install. The expiry date is
/// inside the app's embedded provisioning profile, so we can read it and warn.
enum ExpiryMonitor {
    static let reminderID = "math-alarm-expiry"

    /// When this installed copy stops working (nil if unknown, e.g. App Store build).
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }()

    static var daysLeft: Double? {
        expirationDate.map { $0.timeIntervalSinceNow / 86_400 }
    }

    /// Shows a warning when 2 days or less are left.
    static var shouldWarn: Bool {
        guard let d = daysLeft else { return false }
        return d <= 2
    }

    /// Notification the day before expiry (asks for permission when turned on).
    static func updateReminder(enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])
        guard enabled, let expiry = expirationDate else { return }
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        var fire = expiry.addingTimeInterval(-24 * 3600)
        if fire < Date() { fire = Date().addingTimeInterval(60) }
        let content = UNMutableNotificationContent()
        content.title = "Reinstall Math Alarm today"
        content.body = "Your free install stops working \(expiry.formatted(date: .abbreviated, time: .shortened)). Reinstall with iloader to keep your alarms ringing."
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
        let request = UNNotificationRequest(identifier: reminderID, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
        try? await center.add(request)
    }
}
