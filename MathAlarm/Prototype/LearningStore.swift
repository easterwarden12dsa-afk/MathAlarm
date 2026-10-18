import Foundation
import SwiftUI
import MathEngine

/// Any problem the app can show, so history, favourites, review and share
/// codes work for every mode.
enum PracticeItem: Codable, Hashable {
    case calculus(CalculusProblem)
    case sketch(SketchProblem)
    case change(ChangeProblem)
    case quiz(QuizProblem)

    var signature: String {
        switch self {
        case .calculus(let p): p.signature
        case .sketch(let p): p.signature
        case .change(let p): p.signature
        case .quiz(let q): q.signature
        }
    }

    /// For weak-spot statistics, e.g. "Derivative · Chain rule".
    var topic: String {
        switch self {
        case .calculus(let p): "\(p.kind == .integral ? "Integral" : "Derivative") · \(p.technique)"
        case .sketch(let p): "Sketch · \(p.family?.kind.rawValue ?? "graph")"
        case .change(let c): "Change · \(c.kindName)"
        case .quiz(let q): "\(q.kind.title) · \(q.topic.split(separator: ":").last.map(String.init) ?? "")"
        }
    }

    var title: String {
        switch self {
        case .calculus(let p): p.kind == .integral ? "Integral" : "Derivative"
        case .sketch: "Graph Sketch"
        case .change(let c): "Change: \(c.transform.formula)"
        case .quiz(let q):
            if let v = q.variant, let variant = q.kind.variants.first(where: { $0.id == v }) { "\(q.kind.title) · \(variant.title)" } else { q.kind.title }
        }
    }

    var level: Level {
        switch self {
        case .calculus(let p): p.level
        case .sketch(let p): p.level
        case .change(let c): c.level
        case .quiz(let q): q.level
        }
    }

    /// The formula to show in lists.
    var formula: Expr? {
        switch self {
        case .calculus(let p): p.display
        case .sketch(let p): p.function
        case .change(let c): c.base.function
        case .quiz(let q): q.formula
        }
    }

    var subtitle: String? {
        switch self {
        case .quiz(let q): q.formulaText ?? q.prompt
        default: nil
        }
    }
}

@MainActor
final class LearningStore: ObservableObject {
    static let shared = LearningStore()

    struct TopicStat: Codable, Hashable {
        var attempts = 0
        var correct = 0
        var last = Date()
        var rate: Double { attempts == 0 ? 0 : Double(correct) / Double(attempts) }
    }

    struct RingRecord: Codable, Identifiable, Hashable {
        var id = UUID()
        var date: Date
        var seconds: Double
        var wrongAnswers: Int
        var surrendered: Bool
        var challenge: String
    }

    struct Entry: Codable, Identifiable, Hashable {
        var id = UUID()
        var item: PracticeItem
        var date = Date()
        var solved: Bool
    }

    /// Spaced repetition: missed problems come back after 1, 3 and 7 days.
    struct ReviewEntry: Codable, Identifiable, Hashable {
        var id = UUID()
        var item: PracticeItem
        var due: Date
        var stage: Int
    }

    struct Saved: Codable {
        var topics: [String: TopicStat] = [:]
        var rings: [RingRecord] = []
        var history: [Entry] = []
        var favourites: [Entry] = []
        var review: [ReviewEntry] = []
        var bestSpeedRound: Double?
        var examsDone = 0
        var fastestSolve: Double?
    }

    @Published private(set) var data: Saved
    private static let file = "learning.json"

    private init() {
        data = Persistence.load(Saved.self, from: Self.file) ?? Saved()
    }

    private func save() { Persistence.save(data, to: Self.file) }

    // MARK: Recording

    /// One finished attempt at a problem (right or wrong).
    func record(_ item: PracticeItem, correct: Bool, fromReview: Bool = false) {
        var t = data.topics[item.topic] ?? TopicStat()
        t.attempts += 1
        if correct { t.correct += 1 }
        t.last = Date()
        data.topics[item.topic] = t

        if let i = data.history.firstIndex(where: { $0.item.signature == item.signature }) {
            data.history[i].solved = data.history[i].solved || correct
            data.history[i].date = Date()
        } else {
            data.history.insert(Entry(item: item, solved: correct), at: 0)
            if data.history.count > 150 { data.history.removeLast(data.history.count - 150) }
        }

        let days: [Double] = [1, 3, 7]
        if let i = data.review.firstIndex(where: { $0.item.signature == item.signature }) {
            if correct && fromReview {
                let next = data.review[i].stage + 1
                if next >= days.count {
                    data.review.remove(at: i)
                } else {
                    data.review[i].stage = next
                    data.review[i].due = Date().addingTimeInterval(days[next] * 86_400)
                }
            } else if !correct {
                data.review[i].stage = 0
                data.review[i].due = Date().addingTimeInterval(86_400)
            }
        } else if !correct {
            data.review.append(ReviewEntry(item: item, due: Date().addingTimeInterval(86_400), stage: 0))
        }
        save()
    }

    func recordRing(started: Date, wrongAnswers: Int, surrendered: Bool, challenge: String) {
        let seconds = Date().timeIntervalSince(started)
        data.rings.append(RingRecord(date: Date(), seconds: seconds, wrongAnswers: wrongAnswers, surrendered: surrendered, challenge: challenge))
        if data.rings.count > 120 { data.rings.removeFirst(data.rings.count - 120) }
        if !surrendered { data.fastestSolve = min(data.fastestSolve ?? .infinity, seconds) }
        save()
    }

    func recordSpeedRound(seconds: Double) {
        data.bestSpeedRound = min(data.bestSpeedRound ?? .infinity, seconds)
        save()
    }

    func recordExam() {
        data.examsDone += 1
        save()
    }

    // MARK: Favourites

    func isFavourite(_ item: PracticeItem) -> Bool {
        data.favourites.contains { $0.item.signature == item.signature }
    }

    func toggleFavourite(_ item: PracticeItem) {
        if let i = data.favourites.firstIndex(where: { $0.item.signature == item.signature }) {
            data.favourites.remove(at: i)
        } else {
            data.favourites.insert(Entry(item: item, solved: false), at: 0)
        }
        save()
    }

    func removeFavourite(_ entry: Entry) {
        data.favourites.removeAll { $0.id == entry.id }
        save()
    }

    // MARK: Queries

    var dueReview: [ReviewEntry] {
        data.review.filter { $0.due <= Date() }.sorted { $0.due < $1.due }
    }

    /// Topics with the lowest success (at least 2 attempts), worst first.
    var weakTopics: [(topic: String, stat: TopicStat)] {
        data.topics.filter { $0.value.attempts >= 2 }
            .sorted { $0.value.rate < $1.value.rate }
            .map { ($0.key, $0.value) }
    }

    func clearAll() {
        data = Saved()
        save()
    }

    // MARK: Achievements

    struct Achievement: Identifiable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
        let unlocked: Bool
    }

    var achievements: [Achievement] {
        let solved = data.history.filter(\.solved)
        let bagrut = solved.filter { $0.item.level == .bagrut }.count
        let noSurrender = data.rings.suffix(10)
        let streak = AppSettings.shared.streak
        return [
            Achievement(id: "first", title: "First steps", detail: "Solve your first problem", symbol: "star.fill", unlocked: !solved.isEmpty),
            Achievement(id: "ten", title: "Warming up", detail: "Solve 10 problems", symbol: "flame.fill", unlocked: solved.count >= 10),
            Achievement(id: "fifty", title: "Problem eater", detail: "Solve 50 problems", symbol: "fork.knife", unlocked: solved.count >= 50),
            Achievement(id: "bagrut", title: "Bagrut ready", detail: "Solve 10 Bagrut 5U problems", symbol: "graduationcap.fill", unlocked: bagrut >= 10),
            Achievement(id: "fast", title: "Quick riser", detail: "Turn off an alarm within 60 s", symbol: "bolt.fill", unlocked: (data.fastestSolve ?? .infinity) <= 60),
            Achievement(id: "nosurrender", title: "No white flag", detail: "10 alarms in a row without surrendering",
                        symbol: "flag.slash.fill", unlocked: noSurrender.count >= 10 && noSurrender.allSatisfy { !$0.surrendered }),
            Achievement(id: "streak7", title: "One week", detail: "A 7-day solving streak", symbol: "calendar", unlocked: streak >= 7),
            Achievement(id: "streak30", title: "One month", detail: "A 30-day solving streak", symbol: "calendar.badge.checkmark", unlocked: streak >= 30),
            Achievement(id: "speed", title: "Speed demon", detail: "Finish a speed round in under 3 minutes", symbol: "stopwatch.fill", unlocked: (data.bestSpeedRound ?? .infinity) < 180),
            Achievement(id: "exam", title: "Exam mode", detail: "Finish a mini exam", symbol: "doc.text.fill", unlocked: data.examsDone > 0),
            Achievement(id: "review", title: "Second chance", detail: "Clear every due review problem", symbol: "arrow.counterclockwise.circle.fill",
                        unlocked: dueReview.isEmpty && data.history.contains(where: { !$0.solved })),
        ]
    }
}

// MARK: - Share codes

/// "MA-d-2-123456": the same problem on any phone (generators are seeded).
enum ShareCode {
    static func code(for item: PracticeItem) -> String {
        switch item {
        case .calculus(let p): return "MA-\(p.kind == .integral ? "i" : "d")-\(levelIndex(p.level))-\(p.seed)"
        case .sketch(let p): return "MA-s-\(levelIndex(p.level))-\(p.seed)"
        case .change(let c): return "MA-c-\(levelIndex(c.level))-\(c.seed)"
        case .quiz(let q):
            let v = q.variant.map { ".\($0)" } ?? ""
            return "MA-q\(QuizKind.allCases.firstIndex(of: q.kind) ?? 0)\(v)-\(levelIndex(q.level))-\(q.seed)"
        }
    }

    static func item(from code: String) -> PracticeItem? {
        let parts = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().split(separator: "-")
        guard parts.count == 4, parts[0] == "MA", let li = Int(parts[2]), Level.allCases.indices.contains(li),
              let seed = UInt64(parts[3]) else { return nil }
        let level = Level.allCases[li]
        switch parts[1] {
        case "I": return .calculus(ProblemFactory.make(.integral, level: level, seed: seed))
        case "D": return .calculus(ProblemFactory.make(.derivative, level: level, seed: seed))
        case "S": return .sketch(SketchFactory.make(level: level, seed: seed))
        case "C": return .change(ChangeFactory.make(level: level, seed: seed))
        default:
            // "Q8" or "Q8.BINOMIAL" (a sub-type).
            let kindPart = parts[1].dropFirst().split(separator: ".", maxSplits: 1)
            guard parts[1].hasPrefix("Q"), let first = kindPart.first, let k = Int(first), QuizKind.allCases.indices.contains(k) else { return nil }
            let variant = kindPart.count > 1 ? String(kindPart[1]).lowercased() : nil
            return .quiz(QuizFactory.make(QuizKind.allCases[k], level: level, seed: seed, variant: variant))
        }
    }

    private static func levelIndex(_ l: Level) -> Int { Level.allCases.firstIndex(of: l) ?? 0 }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - Daily problem

/// One problem per day, the same on every phone (seeded by the date).
enum DailyProblem {
    static func today(_ date: Date = Date()) -> PracticeItem {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let stamp = (c.year ?? 2026) * 10_000 + (c.month ?? 1) * 100 + (c.day ?? 1)
        let seed = UInt64(stamp) &* 2_654_435_761
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        switch day % 8 {
        case 0: return .calculus(ProblemFactory.make(.derivative, level: .hard, seed: seed))
        case 1: return .sketch(SketchFactory.make(level: .hard, seed: seed))
        case 2: return .quiz(QuizFactory.make(.triangle, level: .hard, seed: seed))
        case 3: return .quiz(QuizFactory.make(.probability, level: .hard, seed: seed))
        case 4: return .calculus(ProblemFactory.make(.integral, level: .hard, seed: seed))
        case 5: return .quiz(QuizFactory.make(.optimization, level: .hard, seed: seed))
        case 6: return .change(ChangeFactory.make(level: .hard, seed: seed))
        default: return .quiz(QuizFactory.make(.parameter, level: .bagrut, seed: seed))
        }
    }
}
