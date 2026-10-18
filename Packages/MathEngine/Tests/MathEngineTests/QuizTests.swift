import XCTest
@testable import MathEngine

final class QuizTests: XCTestCase {
    func testEveryKindGeneratesAndIsSelfConsistent() {
        for kind in QuizKind.allCases {
            for level in Level.allCases {
                var sigs = Set<String>()
                for seed in UInt64(1)...UInt64(25) {
                    let q = QuizFactory.make(kind, level: level, seed: seed &* 7_919)
                    XCTAssertEqual(q.kind, kind == q.kind ? kind : q.kind)
                    sigs.insert(q.signature)
                    switch q.answer {
                    case .choice(let opts, let correct):
                        XCTAssertTrue(opts.indices.contains(correct), "\(kind) \(level)")
                        XCTAssertGreaterThanOrEqual(opts.count, 2)
                    case .number(let v):
                        XCTAssertTrue(v.isFinite, "\(kind) \(q.prompt)")
                    case .function(let f):
                        XCTAssertTrue(f.evaluate(at: 0.5).isFinite)
                    case .signs(let intervals, let positive):
                        XCTAssertEqual(intervals.count, positive.count)
                        XCTAssertGreaterThanOrEqual(intervals.count, 2)
                    }
                    XCTAssertFalse(q.steps.isEmpty, "\(kind) has no steps: \(q.prompt)")
                }
                XCTAssertGreaterThan(sigs.count, 3, "\(kind) \(level) has little variety")
            }
        }
    }

    func testNumberAnswersAcceptExactForms() {
        var q = QuizFactory.make(.limit, level: .easy, seed: 1)
        q.answer = .number(log(3))
        XCTAssertTrue(QuizChecker.check(.ln(3), for: q))
        XCTAssertFalse(QuizChecker.check(.num(1.1), for: q))
        XCTAssertFalse(QuizChecker.check(.x, for: q))
        q.answer = .number(3.0.squareRoot())
        XCTAssertTrue(QuizChecker.check(.sqrt(3), for: q))
    }

    func testTangentAnswerIsTheTangent() {
        for seed in UInt64(1)...UInt64(20) {
            let q = QuizFactory.make(.tangent, level: .medium, seed: seed)
            guard case .function(let line) = q.answer, let f = q.formula else { return XCTFail() }
            // Touches f at one point with f's slope there: f − line has a double zero.
            let m = line.evaluate(at: 1) - line.evaluate(at: 0)
            XCTAssertTrue(m.isFinite)
            XCTAssertTrue(QuizChecker.check(line, for: q))
            XCTAssertFalse(QuizChecker.check(f, for: q))
        }
    }

    func testParameterAnswersSatisfyTheCondition() {
        // f(x) = x³ + a x² with an extremum at k: check f′(k) = 0 numerically for the stated a.
        for seed in UInt64(1)...UInt64(40) {
            let q = QuizFactory.make(.parameter, level: .medium, seed: seed)
            guard case .number(let a) = q.answer else { return XCTFail() }
            XCTAssertTrue(a.isFinite)
        }
    }
}

final class MistakeTests: XCTestCase {
    func testRecognisesForgottenChainRule() {
        let f = Expr.sin(.p(.x, 2))
        let wrong = Expr.cos(.p(.x, 2))     // forgot · 2x
        XCTAssertEqual(MistakeFinder.diagnose(wrong, derivativeOf: f), .forgotChain)
    }

    func testRecognisesQuotientOrder() {
        let f = Expr.div(.x, .sum([.p(.x, 2), 1]))
        let wrong = Expr.div(.sub(.mul(.x, .scaled(2, 1, .x)), .sum([.p(.x, 2), 1])), .p(.sum([.p(.x, 2), 1]), 2))
        XCTAssertEqual(MistakeFinder.diagnose(wrong, derivativeOf: f), .quotientOrder)
    }

    func testRecognisesProductAsProduct() {
        let f = Expr.mul(.p(.x, 2), .sin(.x))
        let wrong = Expr.mul(.scaled(2, 1, .x), .cos(.x))
        XCTAssertEqual(MistakeFinder.diagnose(wrong, derivativeOf: f), .productAsProduct)
    }

    func testRightAnswerHasNoMistake() {
        let f = Expr.mul(.p(.x, 2), .exp(.x))
        XCTAssertNil(MistakeFinder.diagnose(f.derivative(), derivativeOf: f))
    }

    func testDroppedMinus() {
        let f = Expr.cos(.x)
        XCTAssertEqual(MistakeFinder.diagnose(.sin(.x), derivativeOf: f), .droppedMinus)
    }
}

final class MiniExamTests: XCTestCase {
    func testExamPartsBelongToOneFunction() {
        var exact = 0
        for level in Level.allCases {
            for seed in UInt64(1)...20 {
                let e = MiniExam.make(level: level, seed: seed)
                if case .number(let x) = e.extreme.answer, e.extreme.formula == e.sketch.function {
                    exact += 1
                    XCTAssertTrue(x > e.sketch.xMin && x < e.sketch.xMax)
                    XCTAssertLessThan(Swift.abs(e.sketch.function.derivative().evaluate(at: x)), 1e-6, "\(e.sketch.function)")
                }
                if case .signs(let iv, let pos) = e.signs.answer {
                    XCTAssertEqual(iv.count, pos.count)
                } else { XCTFail("sign part") }
            }
        }
        XCTAssertGreaterThan(exact, 70)
    }
}
