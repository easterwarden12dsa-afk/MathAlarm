import XCTest
@testable import MathEngine

/// Prints sample questions with their steps (run by hand to read them).
final class BagrutDump: XCTestCase {
    func testDump() throws {
        guard let path = ProcessInfo.processInfo.environment["BAGRUT_DUMP"] else { throw XCTSkip("set BAGRUT_DUMP=<file>") }
        var out = ""
        func print(_ s: String) { out += s + "\n" }
        for kind in BagrutTests.newKinds + [.probability, .area, .equation] {
            for v in kind.variants {
                for seed in UInt64(1)...2 {
                    let q = QuizFactory.make(kind, level: seed == 1 ? .medium : .bagrut, seed: seed * 31, variant: v.id)
                    var answer = ""
                    switch q.answer {
                    case .number(let x): answer = "\(x)"
                    case .choice(let o, let c): answer = o.map { $0.text ?? "graph" }.enumerated().map { $0.offset == c ? "[\($0.element)]" : $0.element }.joined(separator: " | ")
                    case .function(let f): answer = "y = \(f)"
                    case .signs: answer = "signs"
                    }
                    print("=== \(kind.rawValue):\(v.id) \(q.topic)\n\(q.prompt)\n  \(q.formulaLabel ?? "") \(q.formula.map { "\($0)" } ?? "")\n  ANSWER: \(answer)")
                    for s in q.steps { print("   " + String(repeating: "  ", count: s.depth) + (s.style == .heading ? "# " : (s.style == .result ? "=> " : "")) + s.text) }
                }
            }
        }
        for paper in BagrutExam.Paper.allCases {
            let exam = BagrutExam.make(paper, level: .bagrut, seed: 5)
            print("##### EXAM \(paper.title)")
            for q in exam.questions { print("Q\(q.number) [\(q.chapterTitle)] \(q.title): " + q.parts.map { $0.topic }.joined(separator: ", ")) }
        }
        try out.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
