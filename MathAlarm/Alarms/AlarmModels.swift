import Foundation
import MathEngine

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case integral, derivative, sketch, change, random

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integral: "Integral"
        case .derivative: "Derivative"
        case .sketch: "Graph Sketch"
        case .change: "Change"
        case .random: "Random"
        }
    }

    var summary: String {
        switch self {
        case .integral: "Find an antiderivative"
        case .derivative: "Differentiate a function"
        case .sketch: "Draw the graph of a function"
        case .change: "Given f, draw a related graph like 1/f(x)² or |f(x)|"
        case .random: "A mix — choose which types below"
        }
    }

    static let concreteKinds: [ChallengeKind] = [.integral, .derivative, .sketch, .change]

    /// Picks a concrete challenge for `.random`; other kinds return themselves.
    func resolved() -> ChallengeKind {
        self == .random ? (Self.concreteKinds.randomElement() ?? .integral) : self
    }

    /// Which math-engine problem to generate. Graph Sketch temporarily uses
    /// a derivative until milestone 3.
    var problemKind: ProblemKind {
        switch self {
        case .integral: .integral
        case .derivative, .sketch, .change: .derivative
        case .random: Bool.random() ? .integral : .derivative
        }
    }

    var symbol: String {
        switch self {
        case .integral: "sum"
        case .derivative: "function"
        case .sketch: "scribble.variable"
        case .change: "arrow.triangle.swap"
        case .random: "shuffle"
        }
    }
}

enum Difficulty: String, Codable, CaseIterable, Identifiable {
    case easy, medium, hard
    /// Hardest Bagrut 5-unit questions, using only that syllabus.
    case bagrut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bagrut: "Bagrut 5U"
        default: rawValue.capitalized
        }
    }

    var level: Level {
        switch self {
        case .easy: .easy
        case .medium: .medium
        case .hard: .hard
        case .bagrut: .bagrut
        }
    }
}

/// Remembers recently shown problems so they aren't repeated.
final class ProblemHistory {
    static let shared = ProblemHistory()
    private static let fileName = "problemHistory.json"
    private static let limit = 400

    private var recent: [String]

    private init() {
        recent = Persistence.load([String].self, from: Self.fileName) ?? []
    }

    var avoid: Set<String> { Set(recent) }

    /// A new problem that hasn't been shown recently; records it as shown.
    func fresh(_ kind: ProblemKind, level: Level) -> CalculusProblem {
        let p = ProblemFactory.make(kind, level: level, seed: ProblemFactory.randomSeed(), avoiding: avoid)
        remember(p.signature)
        return p
    }

    func freshChange(level: Level) -> ChangeProblem {
        let p = ChangeFactory.make(level: level, seed: ProblemFactory.randomSeed(), avoiding: avoid)
        remember(p.signature)
        return p
    }

    /// `whole`: draw the whole graph (non-periodic functions), from Settings by default.
    func freshSketch(level: Level, whole: Bool = UserDefaults.standard.bool(forKey: "wholeGraph")) -> SketchProblem {
        let p = SketchFactory.make(level: level, seed: ProblemFactory.randomSeed(), avoiding: avoid, wholeDomain: whole)
        remember(p.signature)
        return p
    }

    private func remember(_ signature: String) {
        recent.append(signature)
        if recent.count > Self.limit { recent.removeFirst(recent.count - Self.limit) }
        Persistence.save(recent, to: Self.fileName)
    }
}

/// An alarm sound: one of the built-in tones, the iPhone's default alarm
/// sound, or a file the user imported. Stored as a single string ID so
/// alarms saved by older versions ("classic") still load.
struct AlarmSound: Codable, Hashable, Identifiable {
    let id: String

    init(id: String) { self.id = id }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        id = AlarmSound.legacyRenames[value] ?? value
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(id)
    }

    static let classic = AlarmSound(id: "classic")
    static let systemDefault = AlarmSound(id: "system")

    static let builtIns: [AlarmSound] = ["classic", "siren", "klaxon", "bell", "rising", "pulse"].map(AlarmSound.init(id:))
    private static let legacyRenames: [String: String] = [:]

    var isSystemDefault: Bool { id == Self.systemDefault.id }
    var isCustom: Bool { id.hasPrefix("custom-") }

    var title: String {
        switch id {
        case "classic": return "Digital beeps"
        case "siren": return "Siren"
        case "klaxon": return "Klaxon buzzer"
        case "bell": return "Ringing bell"
        case "rising": return "Speeding-up beeps"
        case "pulse": return "Two-tone alert"
        case "system": return "iPhone alarm sound"
        default: return CustomSoundLibrary.shared.title(for: self) ?? "Imported sound"
        }
    }

    /// File name AlarmKit looks up (app bundle for built-ins, Library/Sounds for imports).
    var fileName: String {
        if isCustom { return "\(id).caf" }
        return "\(id).wav"
    }

    /// File the in-app player uses. The iPhone default sound isn't available
    /// to apps, so inside the app it falls back to the digital beeps.
    var playbackURL: URL? {
        if isSystemDefault { return Self.classic.playbackURL }
        if isCustom { return CustomSoundLibrary.soundsDirectory.appendingPathComponent(fileName) }
        return Bundle.main.url(forResource: id, withExtension: "wav")
    }

    /// Falls back to the default tone if an imported file was deleted.
    var resolved: AlarmSound {
        if isCustom, let url = playbackURL, !FileManager.default.fileExists(atPath: url.path) { return .classic }
        return self
    }
}

/// Settings for the Random challenge: which types it picks from, each with
/// its own difficulty (nil = the alarm's difficulty).
struct RandomMix: Codable, Hashable {
    struct Entry: Codable, Hashable, Identifiable {
        var kind: ChallengeKind
        var enabled: Bool
        var difficulty: Difficulty?
        var id: ChallengeKind { kind }
    }
    var entries: [Entry] = ChallengeKind.concreteKinds.map { Entry(kind: $0, enabled: true, difficulty: nil) }

    var enabledKinds: [ChallengeKind] { entries.filter(\.enabled).map(\.kind) }

    func difficulty(for kind: ChallengeKind, default fallback: Difficulty) -> Difficulty {
        entries.first { $0.kind == kind }?.difficulty ?? fallback
    }

    /// Adds types introduced in newer versions to mixes saved by older ones.
    var upgraded: RandomMix {
        var m = self
        for k in ChallengeKind.concreteKinds where !m.entries.contains(where: { $0.kind == k }) {
            m.entries.append(Entry(kind: k, enabled: true, difficulty: nil))
        }
        return m
    }
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
    var randomMix = RandomMix()

    /// AlarmKit alarm IDs currently scheduled for this item.
    var systemAlarmIDs: [UUID] = []
    /// For `.once`: the absolute instant last handed to AlarmKit, so a
    /// time-zone change can be detected and the alarm moved.
    var scheduledOnceDate: Date?

    init() {}

    /// A new alarm set to the current time (next minute), today.
    static func startingNow() -> AlarmItem {
        var item = AlarmItem()
        let next = Date().addingTimeInterval(60)
        let c = Calendar.current.dateComponents([.hour, .minute], from: next)
        item.time = TimeOfDay(hour: c.hour ?? 7, minute: c.minute ?? 0)
        item.onceDay = DayStamp(date: next)
        item.weekdayTimes = item.weekdayTimes.map { var w = $0; w.time = item.time; return w }
        return item
    }

    enum CodingKeys: String, CodingKey {
        case id, label, isEnabled, repeatMode, time, onceDay, weekdayTimes
        case sound, challenge, difficulty, systemAlarmIDs, scheduledOnceDate, randomMix
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
        randomMix = ((try? c.decodeIfPresent(RandomMix.self, forKey: .randomMix)) ?? nil)?.upgraded ?? d.randomMix
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
        case .daily:
            break
        case .weekdays:
            if enabledWeekdays.isEmpty { return "Turn on at least one day." }
        }
        if challenge == .random && randomMix.enabledKinds.isEmpty { return "Switch on at least one challenge type in the Random mix." }
        return nil
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
    var mix: RandomMix?

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
        mix = item.randomMix
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
    /// The math problem for this ring and what has been typed so far, so a
    /// relaunch returns to exactly the same challenge.
    var problem: CalculusProblem?
    var editor: MathEditor?
    /// Graph Sketch challenge and the strokes drawn so far.
    var sketch: SketchProblem?
    var strokes: [SketchStroke]?
    /// "Change" challenge (uses `strokes` too).
    var change: ChangeProblem?
    /// Random settings and the difficulty of the current problem.
    var mix: RandomMix?
    var currentDifficulty: Difficulty?
    /// "Problems per ring" setting: how many must be solved, and how many are.
    var solvesNeeded: Int?
    var solvesDone: Int?
    /// The challenge type chosen for the alarm (may be Random).
    var requestedChallenge: ChallengeKind?

    init(context: RingContext, solvesNeeded: Int = 1) {
        label = context.label
        requestedChallenge = context.challenge
        challenge = context.challenge.resolved()
        difficulty = context.difficulty
        sound = context.sound
        itemIDs = context.itemID.map { [$0] } ?? []
        self.solvesNeeded = solvesNeeded
        solvesDone = 0
        mix = context.mix
        newChallenge()
    }

    /// Generates the next problem (or sketch) for this ring.
    mutating func newChallenge() {
        var level = difficulty
        if requestedChallenge == .random {
            let mix = (self.mix ?? RandomMix()).upgraded
            challenge = mix.enabledKinds.randomElement() ?? ChallengeKind.concreteKinds.randomElement()!
            level = mix.difficulty(for: challenge, default: difficulty)
        } else if let requested = requestedChallenge {
            challenge = requested.resolved()
        }
        currentDifficulty = level
        problem = nil; editor = nil; sketch = nil; change = nil; strokes = nil
        switch challenge {
        case .sketch:
            sketch = ProblemHistory.shared.freshSketch(level: level.level)
            strokes = []
        case .change:
            change = ProblemHistory.shared.freshChange(level: level.level)
            strokes = []
        default:
            problem = ProblemHistory.shared.fresh(challenge.problemKind, level: level.level)
            editor = MathEditor()
        }
    }

    var hasChallenge: Bool { problem != nil || sketch != nil || change != nil }

    var progressText: String? {
        let needed = solvesNeeded ?? 1
        guard needed > 1 else { return nil }
        return "Problem \(min((solvesDone ?? 0) + 1, needed)) of \(needed)"
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
