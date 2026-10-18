import Foundation

/// A full mock Bagrut paper (5 units), laid out like the real one:
/// 571 — four chapters, eight questions, answer four (25 points each), 3 hours;
/// 572 — two chapters, five questions, answer three (33⅓ points each), 2¾ hours.
/// Each question has sub-questions (a, b, c…) from its chapter's topics.
public struct BagrutExam: Sendable {
    public enum Paper: String, CaseIterable, Identifiable, Sendable {
        case p571 = "571", p572 = "572"

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .p571: "Paper 571 (35571)"
            case .p572: "Paper 572 (35572)"
            }
        }

        public var subtitle: String {
            switch self {
            case .p571: "Short questions · sequences & probability · geometry & trigonometry · calculus"
            case .p572: "Vectors, analytic geometry & complex numbers · growth, exponents & logarithms"
            }
        }

        public var minutes: Int { self == .p571 ? 180 : 165 }
        /// How many questions count.
        public var answerCount: Int { self == .p571 ? 4 : 3 }
        public var pointsPerQuestion: Double { self == .p571 ? 25 : 100.0 / 3 }

        public var rules: String {
            switch self {
            case .p571: "Answer 4 of the 8 questions: at least one from chapter 1 or 2, and at least one from each of chapters 3 and 4. In question 1, answer 2 of the 4 parts."
            case .p572: "Answer 3 of the 5 questions."
            }
        }
    }

    public struct Question: Sendable, Identifiable {
        public var id: Int { number }
        public let number: Int
        public let chapter: Int
        public let chapterTitle: String
        public let title: String
        public let parts: [QuizProblem]
        /// Only this many parts count (question 1 of 571: 2 of 4).
        public let partsToAnswer: Int
    }

    public let paper: Paper
    public let level: Level
    public let seed: UInt64
    public let questions: [Question]

    public static func make(_ paper: Paper, level: Level, seed: UInt64) -> BagrutExam {
        var r = SeededRandom(seed: seed)
        var used = Set<String>()
        var counter: UInt64 = 0
        /// One sub-question; variants are spread so the parts differ.
        func part(_ kind: QuizKind, _ variant: String? = nil) -> QuizProblem {
            counter += 1
            let s = seed &* 2_654_435_761 &+ counter &* 97_531
            let q = QuizFactory.make(kind, level: level, seed: s, avoiding: used, variant: variant)
            used.insert(q.signature)
            return q
        }
        /// n parts of one kind, each from a different sub-type when there are enough.
        func parts(_ kind: QuizKind, _ n: Int, only: [String]? = nil) -> [QuizProblem] {
            var ids = (only ?? kind.variants.map(\.id)).shuffled(using: &r)
            if ids.isEmpty { return (0..<n).map { _ in part(kind) } }
            while ids.count < n { ids += ids }
            return ids.prefix(n).map { part(kind, $0) }
        }
        func q(_ number: Int, _ chapter: Int, _ chapterTitle: String, _ title: String, _ parts: [QuizProblem], answer: Int? = nil) -> Question {
            Question(number: number, chapter: chapter, chapterTitle: chapterTitle, title: title, parts: parts, partsToAnswer: answer ?? parts.count)
        }

        var questions: [Question] = []
        switch paper {
        case .p571:
            let c1 = "Chapter 1 · Short questions", c2 = "Chapter 2 · Sequences and probability"
            let c3 = "Chapter 3 · Geometry and trigonometry in the plane", c4 = "Chapter 4 · Calculus"
            let shortKinds: [QuizKind] = [.sequence, .probability, .geometry, .triangle, .trigIdentity, .limit, .tangent, .induction].shuffled(using: &r)
            questions = [
                q(1, 1, c1, "Short questions — answer 2 of the 4", shortKinds.prefix(4).map { part($0) }, answer: 2),
                q(2, 2, c2, "Sequences", parts(.sequence, 2) + [part(.induction)]),
                q(3, 2, c2, "Probability", parts(.probability, 3)),
                q(4, 3, c3, "Geometry", parts(.geometry, 3)),
                q(5, 3, c3, "Trigonometry in the plane", parts(.triangle, 2) + [part(.trigIdentity)]),
                q(6, 4, c4, "Investigating a function", [part(.limit, "onesided"), part(.parameter, "extremum"), part(.signTable), part(.solutions)]),
                q(7, 4, c4, "Tangents, areas and antiderivatives", [part(.tangent), part(.area), part(.antiderivative), part(.chooseGraph)]),
                q(8, 4, c4, "Extreme-value problem", parts(.optimization, 2)),
            ]
        case .p572:
            let c1 = "Chapter 1 · Analytic geometry, vectors, complex numbers", c2 = "Chapter 2 · Growth and decay, exponential and log functions"
            questions = [
                q(1, 1, c1, "Vectors in space", parts(.vectors, 3)),
                q(2, 1, c1, "Analytic geometry", parts(.conics, 3)),
                q(3, 1, c1, "Complex numbers", parts(.complex, 3)),
                q(4, 2, c2, "Exponential and log functions",
                  [part(.equation, r.pick(["exp", "log"])), part(.parameter, "explog"), part(.area, "explog"), part(.equation, r.pick(["base", "powers"]))]),
                q(5, 2, c2, "Growth, decay and logarithms", parts(.growth, 2) + [part(.limit, "special")]),
            ]
        }
        return BagrutExam(paper: paper, level: level, seed: seed, questions: questions)
    }

    /// The score out of 100. `credit(question, part)` is 0…1 for each part;
    /// a question's points are shared by the parts that count (its best ones),
    /// and only the best `answerCount` questions count.
    public func score(credit: (Int, Int) -> Double) -> Double {
        questionScores(credit: credit).sorted(by: >).prefix(paper.answerCount).reduce(0, +)
    }

    /// Points per question, in order.
    public func questionScores(credit: (Int, Int) -> Double) -> [Double] {
        questions.map { question in
            let best = question.parts.indices.map { credit(question.number, $0) }.sorted(by: >).prefix(question.partsToAnswer)
            return paper.pointsPerQuestion * best.reduce(0, +) / Double(question.partsToAnswer)
        }
    }
}
