import Foundation

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case integral, derivative, sketch, random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integral: "Integral"
        case .derivative: "Derivative"
        case .sketch: "Graph Sketch"
        case .random: "Random"
        }
    }

    static let concreteKinds: [ChallengeKind] = [.integral, .derivative, .sketch]

    /// Picks a concrete challenge for `.random`; other kinds return themselves.
    func resolved() -> ChallengeKind {
        self == .random ? (Self.concreteKinds.randomElement() ?? .integral) : self
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum AlarmSound: String, Codable, CaseIterable, Identifiable {
    case classic, rising, pulse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic beeps"
        case .rising: "Rising sweep"
        case .pulse: "Two-tone pulse"
        }
    }

    var fileName: String { "\(rawValue).wav" }

    var url: URL? { Bundle.main.url(forResource: rawValue, withExtension: "wav") }
}

enum RepeatMode: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekdays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: "One time"
        case .daily: "Every day"
        case .weekdays: "Weekdays"
        }
    }
}

struct TimeOfDay: Codable, Hashable {
    var hour: Int
    var minute: Int

    var formatted: String {
        let date = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

struct DayStamp: Codable, Hashable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }

    static var tomorrow: DayStamp {
        DayStamp(date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }
}

/// One weekday row in the "Weekdays" repeat mode, with its own time.
struct WeekdayTime: Codable, Hashable, Identifiable {
    /// 1 = Sunday … 7 = Saturday (Calendar's numbering).
    var weekday: Int
    var enabled: Bool
    var time: TimeOfDay

    var id: Int { weekday }

    var name: String {
        Calendar.current.weekdaySymbols[(weekday - 1) % 7]
    }

    var shortName: String {
        Calendar.current.shortWeekdaySymbols[(weekday - 1) % 7]
    }

    /// Monday-first week: Mon–Fri on at 07:00, weekend off.
    static var defaultWeek: [WeekdayTime] {
        [2, 3, 4, 5, 6, 7, 1].map { day in
            WeekdayTime(weekday: day, enabled: day >= 2 && day <= 6, time: TimeOfDay(hour: 7, minute: 0))
        }
    }
}

struct AlarmItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var label = "Alarm"
    var isEnabled = true
    var repeatMode: RepeatMode = .daily
    /// Time for `.once` and `.daily`.
    var time = TimeOfDay(hour: 7, minute: 0)
    /// Calendar day for `.once`. Stored as a wall-clock day so a time-zone
    /// change keeps "7:00 on the 20th" meaning 7:00 local time.
    var onceDay = DayStamp.tomorrow
    var weekdayTimes = WeekdayTime.defaultWeek
    var sound: AlarmSound = .classic
    var challenge: ChallengeKind = .random
    var difficulty: Difficulty = .medium

    /// AlarmKit alarm IDs currently scheduled for this item.
    var systemAlarmIDs: [UUID] = []
    /// For `.once`: the absolute instant last handed to AlarmKit, so a
    /// time-zone change can be detected and the alarm moved.
    var scheduledOnceDate: Date?

    init() {}

    enum CodingKeys: String, CodingKey {
        case id, label, isEnabled, repeatMode, time, onceDay, weekdayTimes
        case sound, challenge, difficulty, systemAlarmIDs, scheduledOnceDate
    }

    // Tolerant decoding: fields added in later versions get defaults, so
    // saved alarms survive app updates.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AlarmItem()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? d.id
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? d.label
        isEnabled = try c.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? d.isEnabled
        repeatMode = (try? c.decodeIfPresent(RepeatMode.self, forKey: .repeatMode)) ?? d.repeatMode
        time = try c.decodeIfPresent(TimeOfDay.self, forKey: .time) ?? d.time
        onceDay = try c.decodeIfPresent(DayStamp.self, forKey: .onceDay) ?? d.onceDay
        weekdayTimes = try c.decodeIfPresent([WeekdayTime].self, forKey: .weekdayTimes) ?? d.weekdayTimes
        sound = (try? c.decodeIfPresent(AlarmSound.self, forKey: .sound)) ?? d.sound
        challenge = (try? c.decodeIfPresent(ChallengeKind.self, forKey: .challenge)) ?? d.challenge
        difficulty = (try? c.decodeIfPresent(Difficulty.self, forKey: .difficulty)) ?? d.difficulty
        systemAlarmIDs = try c.decodeIfPresent([UUID].self, forKey: .systemAlarmIDs) ?? []
        scheduledOnceDate = try c.decodeIfPresent(Date.self, forKey: .scheduledOnceDate)
    }

    // MARK: Derived schedule info

    /// The one-time alarm's instant in the *current* time zone.
    var onceFireDate: Date? {
        var c = DateComponents()
        c.year = onceDay.year
        c.month = onceDay.month
        c.day = onceDay.day
        c.hour = time.hour
        c.minute = time.minute
        c.second = 0
        return Calendar.current.date(from: c)
    }

    var enabledWeekdays: [WeekdayTime] { weekdayTimes.filter(\.enabled) }

    func nextFireDate(after now: Date = Date()) -> Date? {
        let cal = Calendar.current
        switch repeatMode {
        case .once:
            guard let d = onceFireDate, d > now else { return nil }
            return d
        case .daily:
            return cal.nextDate(after: now,
                                matching: DateComponents(hour: time.hour, minute: time.minute, second: 0),
                                matchingPolicy: .nextTime)
        case .weekdays:
            return enabledWeekdays.compactMap { wt in
                cal.nextDate(after: now,
                             matching: DateComponents(hour: wt.time.hour, minute: wt.time.minute, second: 0, weekday: wt.weekday),
                             matchingPolicy: .nextTime)
            }.min()
        }
    }

    var headlineTime: String {
        switch repeatMode {
        case .once, .daily:
            return time.formatted
        case .weekdays:
            let times = Set(enabledWeekdays.map(\.time))
            if times.count == 1, let t = times.first { return t.formatted }
            if let next = nextFireDate() { return next.formatted(date: .omitted, time: .shortened) }
            return "—"
        }
    }

    var repeatSummary: String {
        switch repeatMode {
        case .once:
            return onceFireDate?.formatted(date: .abbreviated, time: .omitted) ?? "One time"
        case .daily:
            return "Every day"
        case .weekdays:
            let days = enabledWeekdays
            if days.isEmpty { return "No days selected" }
            let times = Set(days.map(\.time))
            if times.count == 1 { return days.map(\.shortName).joined(separator: " ") }
            return days.map { "\($0.shortName) \($0.time.formatted)" }.joined(separator: ", ")
        }
    }

    /// Whether the editor's current values describe something schedulable.
    var validationMessage: String? {
        switch repeatMode {
        case .once:
            guard let d = onceFireDate, d > Date() else { return "Pick a time in the future." }
            return nil
        case .daily:
            return nil
        case .weekdays:
            return enabledWeekdays.isEmpty ? "Turn on at least one day." : nil
        }
    }
}

/// Why a particular AlarmKit alarm exists.
enum AlarmPurpose: String, Codable {
    case alarm      // a user alarm's regular schedule
    case test       // the "ring in 10 seconds" button
    case reRing     // scheduled after the system Stop button was pressed
    case watchdog   // safety net while a ring is unresolved
    case timer      // countdown timer (M4)
}

/// Everything needed to start a ring from an AlarmKit alarm ID.
struct RingContext: Codable, Hashable {
    var itemID: UUID?
    var label: String
    var challenge: ChallengeKind
    var difficulty: Difficulty
    var sound: AlarmSound
    var purpose: AlarmPurpose
    var createdAt = Date()

    static let fallback = RingContext(itemID: nil, label: "Alarm", challenge: .random,
                                      difficulty: .medium, sound: .classic, purpose: .alarm)

    init(itemID: UUID?, label: String, challenge: ChallengeKind, difficulty: Difficulty,
         sound: AlarmSound, purpose: AlarmPurpose) {
        self.itemID = itemID
        self.label = label
        self.challenge = challenge
        self.difficulty = difficulty
        self.sound = sound
        self.purpose = purpose
    }

    init(item: AlarmItem) {
        self.init(itemID: item.id, label: item.label.isEmpty ? "Alarm" : item.label,
                  challenge: item.challenge, difficulty: item.difficulty,
                  sound: item.sound, purpose: .alarm)
    }
}

/// The alarm that is currently ringing and not yet solved/surrendered.
/// Persisted so a relaunch returns to the same challenge.
struct RingSession: Codable, Identifiable {
    var id = UUID()
    var label: String
    /// Concrete challenge (never `.random`).
    var challenge: ChallengeKind
    var difficulty: Difficulty
    var sound: AlarmSound
    /// User alarms folded into this ring (two alarms close together share one challenge).
    var itemIDs: [UUID]
    var startedAt = Date()
    var muteUntil: Date?
    var reRingID: UUID?
    var watchdogID: UUID?

    init(context: RingContext) {
        label = context.label
        challenge = context.challenge.resolved()
        difficulty = context.difficulty
        sound = context.sound
        itemIDs = context.itemID.map { [$0] } ?? []
    }

    func context(purpose: AlarmPurpose) -> RingContext {
        RingContext(itemID: nil, label: label, challenge: challenge, difficulty: difficulty,
                    sound: sound, purpose: purpose)
    }

    func isMuted(at now: Date = Date()) -> Bool {
        guard let m = muteUntil else { return false }
        return m > now
    }
}
