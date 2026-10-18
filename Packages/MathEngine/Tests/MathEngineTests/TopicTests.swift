import XCTest
@testable import MathEngine

final class TopicTests: XCTestCase {
    func testSurdsAndExactForms() {
        XCTAssertEqual(QuizFactory.surd(12).0, 2)
        XCTAssertEqual(QuizFactory.surd(12).1, 3)
        XCTAssertEqual(QuizFactory.exact(7, rad: 3, den: 3).text, "7√3/3")
        XCTAssertEqual(QuizFactory.exact(5, rad: 4, den: 1).text, "10")
        XCTAssertEqual(QuizFactory.exact(6, rad: 2, den: 4).text, "3√2/2")
        XCTAssertEqual(QuizFactory.exact(6, rad: 2, den: 4).value, 3 * 2.0.squareRoot() / 2, accuracy: 1e-12)
    }

    /// The drawn triangle has the side lengths written on it.
    func testTriangleFiguresMatchTheirLabels() {
        for level in Level.allCases {
            for seed in UInt64(1)...60 {
                let q = QuizFactory.make(.triangle, level: level, seed: seed)
                guard let f = q.triangle else { return XCTFail("no figure: \(q.prompt)") }
                let p = f.points
                XCTAssertTrue(p.allSatisfy(\.isFinite), q.prompt)
                for i in 0..<3 {
                    guard let label = f.sideLabels[i], let v = Double(label) else { continue }
                    let j = (i + 1) % 3
                    let d = hypot(p[2 * i] - p[2 * j], p[2 * i + 1] - p[2 * j + 1])
                    XCTAssertEqual(d, v, accuracy: 1e-6 * max(1, v), "\(q.prompt)")
                }
                guard case .number(let v) = q.answer else { return XCTFail() }
                XCTAssertTrue(v.isFinite && v > 0, q.prompt)
            }
        }
    }

    /// The labelled angle at A agrees with the drawn triangle.
    func testTriangleAnglesMatch() {
        for seed in UInt64(1)...60 {
            let q = QuizFactory.make(.triangle, level: .medium, seed: seed)
            guard let f = q.triangle, let label = f.angleLabels[0], label.hasSuffix("°"), let deg = Double(label.dropLast()) else { continue }
            let p = f.points
            let u = (p[2] - p[0], p[3] - p[1]), w = (p[4] - p[0], p[5] - p[1])
            let angle = acos((u.0 * w.0 + u.1 * w.1) / (hypot(u.0, u.1) * hypot(w.0, w.1))) * 180 / .pi
            XCTAssertEqual(angle, deg, accuracy: 1e-6, q.prompt)
        }
    }

    func testLawOfCosinesAnswer() {
        // AB = c, AC = b, ∠A: BC² = b² + c² − 2bc cos A — checked against the figure.
        for seed in UInt64(1)...40 {
            let q = QuizFactory.make(.triangle, level: .easy, seed: seed)
            guard q.topic == "triangle:law of cosines", case .number(let v) = q.answer, let p = q.triangle?.points else { continue }
            XCTAssertEqual(hypot(p[2] - p[4], p[3] - p[5]), v, accuracy: 1e-9)
        }
    }

    func testProbabilitiesAreProbabilities() {
        for level in Level.allCases {
            for seed in UInt64(1)...60 {
                let q = QuizFactory.make(.probability, level: level, seed: seed)
                guard case .number(let v) = q.answer else { return XCTFail() }
                if q.topic == "probability:how many" {
                    XCTAssertEqual(v, v.rounded())
                    XCTAssertGreaterThan(v, 0)
                } else {
                    XCTAssertTrue(v > 0 && v < 1, "\(q.prompt) = \(v)")
                }
                if q.topic == "probability:table" { XCTAssertNotNil(q.table) }
            }
        }
    }

    func testToleranceAcceptsRoundedAnswers() {
        for seed in UInt64(1)...40 {
            let q = QuizFactory.make(.triangle, level: .hard, seed: seed)
            guard let tol = q.tolerance, case .number(let v) = q.answer else { continue }
            XCTAssertLessThanOrEqual(tol, 0.01)
            let rounded = (v * 100).rounded() / 100
            XCTAssertTrue(QuizChecker.check(.num(rounded), for: q))
            XCTAssertFalse(QuizChecker.check(.num(rounded + 0.05), for: q))
        }
    }

    /// Min/max answers really are the extreme values: compare with a brute-force search.
    func testOptimizationAgainstBruteForce() {
        // Fence: A(x) = x(L − 2x).
        for seed in UInt64(1)...30 {
            let q = QuizFactory.make(.optimization, level: .easy, seed: seed)
            guard q.topic == "optimization:fence", case .number(let v) = q.answer,
                  let L = Double(q.prompt.components(separatedBy: " m of fence").first?.components(separatedBy: " ").last ?? "") else { continue }
            func fenced(_ t: Double) -> Double { t * (L - 2 * t) }
            let xs = Array(stride(from: 0.0, through: L / 2, by: L / 20000))
            let best = xs.map(fenced).max()!
            let x = xs.max { fenced($0) < fenced($1) }!
            XCTAssertTrue(abs(v - best) < 1e-3 * best || abs(v - x) < 1e-3 * L, q.prompt)
        }
        // Trapezoid and tangent triangle: closed forms.
        XCTAssertEqual(QuizFactory.exact(3 * 16, rad: 3, den: 4).value,
                       stride(from: 0.0, to: .pi / 2, by: 1e-5).map { 16 * (1 + cos($0)) * sin($0) }.max()!, accuracy: 1e-6)
    }

    func testEveryVariantGeneratesItsOwnKind() {
        for kind in QuizKind.allCases {
            for v in kind.variants {
                for level in Level.allCases {
                    var topics = Set<String>()
                    for seed in UInt64(1)...6 {
                        let q = QuizFactory.make(kind, level: level, seed: seed &* 104_729, variant: v.id)
                        XCTAssertEqual(q.kind, kind, "\(kind) \(v.id) \(level)")
                        XCTAssertEqual(q.variant, v.id)
                        topics.insert(q.topic)
                    }
                    XCTAssertFalse(topics.isEmpty)
                }
            }
        }
    }

    /// Every worked solution is split into headed steps and ends with the answer.
    func testSolutionsAreStructured() {
        for kind in QuizKind.allCases {
            for level in Level.allCases {
                for seed in UInt64(1)...12 {
                    let q = QuizFactory.make(kind, level: level, seed: seed &* 7_331)
                    XCTAssertGreaterThanOrEqual(q.steps.filter { $0.style == .heading }.count, 2, "\(kind) \(q.prompt)")
                    XCTAssertTrue(q.steps.contains { $0.style == .result }, "\(kind) \(q.prompt)")
                    XCTAssertFalse(q.steps.contains { $0.text.contains("Optional(") || $0.text.range(of: #"\bnan\b|\binf\b"#, options: .regularExpression) != nil }, "\(kind) \(q.steps.map(\.text))")
                }
            }
        }
    }

    /// Equations that need a check really reject something.
    func testEquationChecksRejectFalseRoots() {
        for seed in UInt64(1)...30 {
            for v in ["root", "log"] {
                let q = QuizFactory.make(.equation, level: .hard, seed: seed, variant: v)
                if q.topic == "equation:square root" || q.topic == "equation:ln domain" || q.topic == "equation:ln" {
                    XCTAssertTrue(q.steps.contains { $0.text.contains("Rejected") }, q.prompt)
                }
                guard case .choice(let options, _) = q.answer else { return XCTFail() }
                XCTAssertEqual(Set(options.compactMap(\.text)).count, options.count, q.prompt)
            }
        }
    }

    func testSquareRootEquationAnswerSolvesIt() {
        for seed in UInt64(1)...30 {
            let q = QuizFactory.make(.equation, level: .hard, seed: seed, variant: "root")
            guard case .choice(let options, let c) = q.answer, let t = options[c].text,
                  let x = Double(t.replacingOccurrences(of: "x = ", with: "").replacingOccurrences(of: "−", with: "-")) else { continue }
            // "Solve: √(x + a) = x − c"
            let body = q.prompt.replacingOccurrences(of: "Solve: √(x", with: "").replacingOccurrences(of: "−", with: "-")
            let parts = body.components(separatedBy: ") = x")
            guard parts.count == 2, let a = Double(parts[0].replacingOccurrences(of: " ", with: "")),
                  let c = Double(parts[1].replacingOccurrences(of: " ", with: "")) else { continue }
            XCTAssertEqual((x + a).squareRoot(), x + c, accuracy: 1e-9, q.prompt)
        }
    }
}
