import XCTest
@testable import MathEngine

final class QuizVarietyTests: XCTestCase {
    /// Where the limit is taken, from the label "lim x→3⁺", "lim x→−∞"…
    private func approach(_ label: String) -> [Double] {
        let t = label.replacingOccurrences(of: "lim x→", with: "").replacingOccurrences(of: "−", with: "-")
        if t == "∞" { return [1e5, 3e5] }
        if t == "-∞" { return [-1e5, -3e5] }
        let right = t.hasSuffix("⁺"), left = t.hasSuffix("⁻")
        let p = Double(t.replacingOccurrences(of: "⁺", with: "").replacingOccurrences(of: "⁻", with: ""))!
        if right { return [p + 1e-5, p + 2e-5] }
        if left { return [p - 1e-5, p - 2e-5] }
        return [p + 1e-5, p - 1e-5]
    }

    func testLimitAnswersMatchTheFunction() {
        for level in Level.allCases {
            for seed in UInt64(1)...80 {
                let q = QuizFactory.make(.limit, level: level, seed: seed &* 2_654_435_761)
                guard let f = q.formula, let label = q.formulaLabel else { return XCTFail("no formula") }
                let xs = approach(label)
                switch q.answer {
                case .number(let v):
                    for x in xs {
                        let y = f.evaluate(at: x)
                        // Limits at ∞ converge slowly; points converge fast.
                        let tol = label.contains("∞") ? 2e-3 * max(1, abs(v)) + 2e-3 : 1e-3 * max(1, abs(v))
                        XCTAssertEqual(y, v, accuracy: tol, "\(label) \(f) = \(v), got \(y)")
                    }
                case .choice(let options, let c):
                    let text = options[c].text ?? ""
                    let ys = xs.map { f.evaluate(at: $0) }
                    if text == "+∞" { XCTAssertTrue(ys.allSatisfy { $0 > 1e3 }, "\(label) \(f): \(ys)") }
                    if text == "−∞" { XCTAssertTrue(ys.allSatisfy { $0 < -1e3 }, "\(label) \(f): \(ys)") }
                    if text == "Doesn't exist" { XCTAssertLessThan(ys[0] * ys[1], 0, "\(label) \(f)") }
                default:
                    XCTFail("unexpected answer type")
                }
            }
        }
    }

    func testLimitsAreVaried() {
        for level in Level.allCases {
            var formulas = Set<String>(), topics = Set<String>()
            for seed in UInt64(1)...40 {
                let q = QuizFactory.make(.limit, level: level, seed: seed &* 97_531)
                formulas.insert(q.formula?.description ?? "")
                topics.insert(q.topic)
            }
            XCTAssertGreaterThanOrEqual(formulas.count, 32, "\(level): only \(formulas.count) different limits")
            XCTAssertGreaterThanOrEqual(topics.count, 5, "\(level): topics \(topics)")
        }
    }

    func testRecentTopicsAreAvoided() {
        let first = QuizFactory.make(.limit, level: .medium, seed: 11)
        let next = QuizFactory.make(.limit, level: .medium, seed: 12, avoidTopics: [first.topic])
        XCTAssertNotEqual(first.topic, next.topic)
    }

    func testTangentsAndNormalsAreRight() {
        for level in Level.allCases {
            for seed in UInt64(1)...40 {
                let q = QuizFactory.make(.tangent, level: level, seed: seed &* 7_919)
                guard case .function(let line) = q.answer, let f = q.formula else { return XCTFail() }
                let m = line.evaluate(at: 1) - line.evaluate(at: 0)
                // Find the touching point from the prompt "at x = 2" (or the slope question).
                let x0: Double
                if let r = q.prompt.range(of: "at x = ") {
                    let rest = q.prompt[r.upperBound...].prefix { "0123456789−-".contains($0) }
                    x0 = Double(rest.replacingOccurrences(of: "−", with: "-"))!
                } else {
                    // Slope question: the line touches where f′ = m.
                    let d = f.derivative()
                    x0 = stride(from: -5.0, through: 5.0, by: 1).min { abs(d.evaluate(at: $0) - m) < abs(d.evaluate(at: $1) - m) }!
                }
                XCTAssertEqual(line.evaluate(at: x0), f.evaluate(at: x0), accuracy: 1e-6, q.prompt)
                let slope = f.derivative().evaluate(at: x0)
                if q.topic == "tangent:normal" {
                    XCTAssertEqual(m * slope, -1, accuracy: 1e-6, q.prompt)
                } else {
                    XCTAssertEqual(m, slope, accuracy: 1e-6, q.prompt)
                }
            }
        }
    }

    func testNewAreaFamiliesAgreeWithNumericIntegration() {
        for level in Level.allCases {
            for seed in UInt64(1)...40 {
                let q = QuizFactory.make(.area, level: level, seed: seed &* 31)
                guard case .number(let v) = q.answer, let g = q.graph, let shade = q.shade else { continue }
                let n = 4000
                let h = (shade.upperBound - shade.lowerBound) / Double(n)
                var sum = 0.0
                for i in 0..<n {
                    let t = shade.lowerBound + (Double(i) + 0.5) * h
                    let top = g.value(at: t), bottom = q.lower?.value(at: t) ?? 0
                    // Volumes of revolution: π∫f².
                    sum += q.topic.hasPrefix("volume:") ? Double.pi * top * top * h : abs(top - bottom) * h
                }
                XCTAssertEqual(sum, v, accuracy: 1e-3 * max(1, v), "\(q.topic) \(q.prompt)")
            }
        }
    }
}
