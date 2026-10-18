import XCTest
@testable import MathEngine

/// Prints a sample of generated text (prompts and worked solutions) so the
/// Hebrew translation can be checked against real output (tools/hebrew_preview.py).
final class TextDumpTests: XCTestCase {
    func testDumpTexts() {
        var lines = Set<String>()
        func add(_ s: String) { if !s.isEmpty { lines.insert(s.replacingOccurrences(of: "\n", with: "⏎")) } }
        for kind in QuizKind.allCases {
            for level in Level.allCases {
                for variant in [nil] + kind.variants.map(\.id) {
                    for seed in UInt64(1)...(variant == nil ? 6 : 3) {
                        let q = QuizFactory.make(kind, level: level, seed: seed &* 7_777, variant: variant)
                        add(q.prompt)
                        q.steps.forEach { add($0.text) }
                        if case .choice(let o, _) = q.answer { o.compactMap(\.text).forEach(add) }
                        if case .signs(let iv, _) = q.answer { iv.forEach(add) }
                    }
                }
            }
        }
        for paper in BagrutExam.Paper.allCases {
            add(paper.title); add(paper.subtitle); add(paper.rules)
            for q in BagrutExam.make(paper, level: .medium, seed: 1).questions { add(q.title); add(q.chapterTitle) }
        }
        for level in Level.allCases {
            for seed in UInt64(1)...4 {
                let s = SketchFactory.make(level: level, seed: seed &* 31)
                GraphSteps.steps(for: s).forEach { add($0.text) }
                let c = ChangeFactory.make(level: level, seed: seed &* 37)
                GraphSteps.steps(for: c).forEach { add($0.text) }
                add(c.transform.formula)
                for kind in ProblemKind.allCases {
                    let p = ProblemFactory.make(kind, level: level, seed: seed &* 41)
                    p.solutionSteps.forEach { add($0.text) }
                    add(p.technique)
                }
            }
        }
        for s in lines.sorted() { print("TXT|" + s) }
        XCTAssertGreaterThan(lines.count, 100)
    }
}
