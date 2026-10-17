import Foundation
import SwiftUI
import UserNotifications
import MathEngine

/// User preferences and simple stats, stored in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    enum Strictness: String, CaseIterable, Identifiable {
        case relaxed, moderate, strict
        var id: String { rawValue }
        var title: String { rawValue.capitalized }
        var tolerance: SketchTolerance {
            switch self {
            case .relaxed: .relaxed
            case .moderate: .moderate
            case .strict: .strict
            }
        }
    }

    /// How close a Graph Sketch has to be.
    @Published var sketchStrictness: Strictness {
        didSet { defaults.set(sketchStrictness.rawValue, forKey: "sketchStrictness") }
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

    // Stats
    @Published private(set) var solved: Int
    @Published private(set) var surrendered: Int
    @Published private(set) var streak: Int
    private var lastSolvedDay: String

    private init() {
        sketchStrictness = Strictness(rawValue: defaults.string(forKey: "sketchStrictness") ?? "") ?? .moderate
        let perRing = defaults.integer(forKey: "problemsPerRing")
        problemsPerRing = (1...3).contains(perRing) ? perRing : 1
        quickChallenge = ChallengeKind(rawValue: defaults.string(forKey: "quickChallenge") ?? "") ?? .random
        quickDifficulty = Difficulty(rawValue: defaults.string(forKey: "quickDifficulty") ?? "") ?? .medium
        quickSound = AlarmSound(id: defaults.string(forKey: "quickSound") ?? "classic")
        expiryReminder = defaults.object(forKey: "expiryReminder") as? Bool ?? false
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
