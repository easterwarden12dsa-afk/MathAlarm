import XCTest
@testable import MathEngine

/// The Bagrut question types added for the full 5-unit syllabus: every
/// sub-type at every level builds, answers are finite, choices are distinct,
/// drawings are finite and the worked steps never show nan/inf.
final class BagrutTests: XCTestCase {
    static let newKinds: [QuizKind] = [.sequence, .induction, .geometry, .trigIdentity, .vectors, .conics, .complex, .growth, .antiderivative]

    private func check(_ q: QuizProblem, _ context: String) {
        switch q.answer {
        case .number(let v):
            XCTAssertTrue(v.isFinite, "\(context): answer \(v) — \(q.prompt)")
        case .choice(let options, let correct):
            XCTAssertTrue(options.indices.contains(correct), context)
            let texts = options.compactMap(\.text)
            if texts.count == options.count { XCTAssertEqual(Set(texts).count, texts.count, "\(context): repeated options \(texts)") }
        case .function(let f):
            let finite = [0.3, 0.9, 1.7, 2.6, 3.4].filter { f.evaluate(at: $0).isFinite }
            XCTAssertGreaterThanOrEqual(finite.count, 4, "\(context): \(f)")
        case .signs:
            break
        }
        XCTAssertFalse(q.steps.isEmpty, context)
        let text = ([q.prompt] + q.steps.map(\.text)).joined(separator: "\n")
        XCTAssertNil(text.range(of: #"\bnan\b|\binf\b|\(\)|Optional"#, options: .regularExpression), "\(context): \(text)")
        if let f = q.figure {
            for p in f.points { XCTAssertTrue(p.x.isFinite && p.y.isFinite, "\(context): figure point") }
            for c in f.curves { XCTAssertTrue(c.xy.allSatisfy(\.isFinite), "\(context): curve") }
            for s in f.segments { XCTAssertTrue(f.points.indices.contains(s.a) && f.points.indices.contains(s.b), "\(context): segment") }
            for a in f.angles { XCTAssertTrue([a.vertex, a.from, a.to].allSatisfy(f.points.indices.contains), "\(context): angle") }
        }
    }

    func testEveryNewTypeBuilds() {
        for kind in Self.newKinds + [.probability, .area, .equation] {
            for level in Level.allCases {
                for variant in [nil] + kind.variants.map(\.id) {
                    for seed in UInt64(1)...40 {
                        let q = QuizFactory.make(kind, level: level, seed: seed &* 7_919, variant: variant)
                        XCTAssertEqual(q.kind, kind, "\(kind) \(variant ?? "all") fell back to \(q.kind)")
                        check(q, "\(kind):\(variant ?? "all"):\(level):\(seed)")
                    }
                }
            }
        }
    }

    func testEveryVariantIsReachable() {
        for kind in Self.newKinds + [.probability, .area, .equation] {
            for v in kind.variants {
                var topics = Set<String>()
                for seed in UInt64(1)...30 { topics.insert(QuizFactory.make(kind, level: .hard, seed: seed, variant: v.id).topic) }
                XCTAssertFalse(topics.isEmpty, "\(kind):\(v.id)")
            }
        }
    }

    // MARK: Answers checked independently

    func testSequenceAnswers() {
        for seed in UInt64(1)...200 {
            let q = QuizFactory.make(.sequence, level: .bagrut, seed: seed, variant: "infinite")
            guard case .number(let v) = q.answer else { continue }
            if q.topic == "sequence:find q" || q.topic == "sequence:series in x" { XCTAssertLessThan(Swift.abs(v) * (q.topic == "sequence:series in x" ? 1 : 1), 1.0001, q.prompt) }
        }
    }

    func testInductionThresholds() {
        let expected = ["2ⁿ > n²": 5, "3ⁿ > n³": 4, "n! > 2ⁿ": 4, "n! > 3ⁿ": 7, "2ⁿ > 2n + 1": 3, "2ⁿ > 5n": 5]
        var seen = 0
        for seed in UInt64(1)...120 {
            let q = QuizFactory.make(.induction, level: .bagrut, seed: seed, variant: "inequality")
            guard case .number(let v) = q.answer, let key = expected.keys.first(where: { q.prompt.contains($0 + " is") }) else { continue }
            XCTAssertEqual(Int(v), expected[key], q.prompt)
            seen += 1
        }
        XCTAssertGreaterThan(seen, 20)
    }

    func testTangentToCircleTouches() {
        for seed in UInt64(1)...150 {
            let q = QuizFactory.make(.conics, level: .hard, seed: seed, variant: "circle")
            guard case .function(let line) = q.answer, let fig = q.figure, let c = fig.circles.first,
                  let p = fig.points.first(where: { $0.label == "P" }) else { continue }
            // The line passes through P and its distance from the centre is the radius.
            XCTAssertEqual(line.evaluate(at: p.x), p.y, accuracy: 1e-9, q.prompt)
            let m = line.evaluate(at: 1) - line.evaluate(at: 0), b = line.evaluate(at: 0)
            let dist = Swift.abs(m * c.cx - c.cy + b) / (m * m + 1).squareRoot()
            XCTAssertEqual(dist, c.r, accuracy: 1e-9, q.prompt)
        }
    }

    func testComplexRootsPolygon() {
        for seed in UInt64(1)...100 {
            let q = QuizFactory.make(.complex, level: .bagrut, seed: seed, variant: "roots")
            guard q.topic == "complex:roots polygon", case .number(let area) = q.answer, let fig = q.figure else { continue }
            // Shoelace area of the drawn polygon.
            let pts = fig.points.filter { $0.label.hasPrefix("z") }
            var s = 0.0
            for i in pts.indices { let a = pts[i], b = pts[(i + 1) % pts.count]; s += a.x * b.y - b.x * a.y }
            XCTAssertEqual(Swift.abs(s) / 2, area, accuracy: 1e-9, q.prompt)
        }
    }

    func testVectorAngles() {
        for seed in UInt64(1)...100 {
            let q = QuizFactory.make(.vectors, level: .hard, seed: seed, variant: "angles")
            guard case .number(let v) = q.answer else { continue }
            XCTAssertTrue(v > 0 && v <= 90, q.prompt)
        }
    }

    func testAntiderivativeMatchesDerivative() {
        for seed in UInt64(1)...150 {
            for level in Level.allCases {
                let q = QuizFactory.make(.antiderivative, level: level, seed: seed)
                guard case .function(let F) = q.answer, let shown = q.formula else { continue }
                let target = q.formulaLabel == "f″(x) =" ? F.derivative().derivative() : F.derivative()
                for x in [0.4, 1.3, 2.2] {
                    XCTAssertEqual(target.evaluate(at: x), shown.evaluate(at: x), accuracy: 1e-9, "\(q.prompt) \(F)")
                }
            }
        }
    }

    func testGeometryAnswersMatchDrawing() {
        // Similar triangles and the bisector are drawn to scale: compare with the drawing.
        for seed in UInt64(1)...100 {
            let q = QuizFactory.make(.geometry, level: .hard, seed: seed, variant: "bisector")
            guard q.topic == "geometry:angle bisector", case .number(let v) = q.answer, let fig = q.figure,
                  let b = fig.points.first(where: { $0.label == "B" }), let d = fig.points.first(where: { $0.label == "D" }) else { continue }
            XCTAssertEqual(hypot(d.x - b.x, d.y - b.y), v, accuracy: 1e-9)
        }
    }

    func testBagrutExams() {
        for paper in BagrutExam.Paper.allCases {
            for seed in UInt64(1)...6 {
                let exam = BagrutExam.make(paper, level: .bagrut, seed: seed)
                XCTAssertEqual(exam.questions.count, paper == .p571 ? 8 : 5, "\(paper)")
                for question in exam.questions {
                    XCTAssertGreaterThanOrEqual(question.parts.count, 2)
                    for part in question.parts { check(part, "exam \(paper) Q\(question.number)") }
                }
            }
        }
    }
}

final class BagrutExamScoreTests: XCTestCase {
    func testScoreCountsBestQuestions() {
        let exam = BagrutExam.make(.p571, level: .medium, seed: 3)
        XCTAssertEqual(exam.score { _, _ in 1 }, 100, accuracy: 1e-9)
        XCTAssertEqual(exam.score { _, _ in 0 }, 0)
        // Question 1 needs only 2 of its 4 parts.
        XCTAssertEqual(exam.questionScores { q, p in q == 1 && p < 2 ? 1 : 0 }[0], 25, accuracy: 1e-9)
        let e572 = BagrutExam.make(.p572, level: .medium, seed: 3)
        XCTAssertEqual(e572.score { q, _ in q <= 3 ? 1 : 0 }, 100, accuracy: 1e-9)
    }
}
