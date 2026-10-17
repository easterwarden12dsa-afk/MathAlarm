import XCTest
@testable import MathEngine

final class GraphAlgebraTests: XCTestCase {
    /// Every generated sketch problem, plenty of seeds per level.
    func allProblems() -> [SketchProblem] {
        var out: [SketchProblem] = [SketchFactory.testCase()]
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(160) {
                var rng = SeededRandom(seed: seed &* 2_654_435_761)
                if let p = SketchFactory.candidate(level: level, rng: &rng, seed: seed) { out.append(p) }
            }
        }
        return out
    }

    func close(_ u: Double, _ v: Double) -> Bool { Swift.abs(u - v) <= 1e-6 * Swift.max(1, Swift.abs(v)) }

    /// The factored f′ and f″ shown in the solution really are f′ and f″.
    func testFactoredFormsAreTheDerivatives() {
        var failures: [String] = []
        for p in allProblems() {
            guard let inv = GraphAlgebra.investigate(p) else { continue }
            let d1 = p.function.derivative(), d2 = d1.derivative()
            for i in 1..<40 {
                let x = p.xMin + (p.xMax - p.xMin) * Double(i) / 40
                let t1 = d1.evaluate(at: x), t2 = d2.evaluate(at: x)
                if let f1 = inv.d1, t1.isFinite, !close(f1.display.evaluate(at: x), t1) {
                    failures.append("f′ \(p.family!.kind) \(p.family!.p) at \(x): \(f1.display.evaluate(at: x)) vs \(t1)"); break
                }
                if let f2 = inv.d2, t2.isFinite, !close(f2.display.evaluate(at: x), t2) {
                    failures.append("f″ \(p.family!.kind) \(p.family!.p) at \(x): \(f2.display.evaluate(at: x)) vs \(t2)"); break
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.prefix(10).joined(separator: "\n"))
    }

    /// The algebraic solutions inside the interval are exactly the numeric ones
    /// (so the solution never has to fall back to "≈ by sign changes").
    func testAlgebraFindsEveryRoot() {
        var failures: [String] = []
        var checked = 0
        for p in allProblems() {
            guard let inv = GraphAlgebra.investigate(p) else { continue }
            let S = Solver(a: p.xMin, b: p.xMax, piBased: p.piBased)
            let w = p.xMax - p.xMin
            let parts: [(String, Solved?, Expr)] = [("f", inv.zeros, p.function),
                                                   ("f′", inv.d1?.solve, p.function.derivative()),
                                                   ("f″", inv.d2?.solve, p.function.derivative().derivative())]
            for (name, solved, e) in parts {
                guard let solved else { continue }
                checked += 1
                var inside: [Double] = []
                for r in solved.roots where S.inside(r.x) && !p.poles.contains(where: { Swift.abs($0 - r.x) < 1e-7 * (w + 1) })
                    && !inside.contains(where: { Swift.abs($0 - r.x) < 1e-7 * (w + 1) }) {
                    inside.append(r.x)
                }
                inside.sort()
                let numeric = GraphSteps.roots(of: e, in: p.xMin...p.xMax)
                let ok = GraphSteps.algebraAgrees(inside, numeric: numeric, e: e, a: p.xMin, b: p.xMax)
                if !ok { failures.append("\(name) \(p.family!.kind) \(p.family!.p) k=\(p.family!.factor) [\(p.xMin), \(p.xMax)]: algebra \(inside) vs numeric \(numeric)") }
            }
        }
        XCTAssertGreaterThan(checked, 300)
        XCTAssertTrue(failures.isEmpty, failures.prefix(12).joined(separator: "\n"))
    }

    func testQuadraticLabels() {
        let S = Solver(a: -10, b: 10, piBased: false)
        XCTAssertEqual(Set(S.poly([1, 0, -3]).roots.map(\.label)), ["√3", "−√3"])
        XCTAssertEqual(Set(S.poly([1, -6, 6]).roots.map(\.label)), ["3 + √3", "3 − √3"])
        XCTAssertEqual(Set(S.poly([2, 0, -3]).roots.map(\.label)), ["√6/2", "−√6/2"])
        XCTAssertEqual(Set(S.poly([1, -1, -2]).roots.map(\.label)), ["2", "−1"])
        XCTAssertEqual(S.poly([1, 0, 1]).roots.count, 0)
        // Rational root, then a quadratic: x³ − 7x + 6 = (x − 1)(x² + x − 6).
        XCTAssertEqual(Set(S.poly([1, 0, -7, 6]).roots.map(\.label)), ["1", "2", "−3"])
        // Biquadratic: x⁴ − 5x² + 4.
        XCTAssertEqual(Set(S.poly([1, 0, -5, 0, 4]).roots.map(\.label)), ["1", "−1", "2", "−2"])
    }

    func testReferenceCaseIsSolvedByAlgebra() {
        let steps = GraphSteps.steps(for: SketchFactory.testCase())
        let text = steps.map(\.text).joined(separator: "\n")
        XCTAssertTrue(text.contains("cos 3x"), text)
        XCTAssertTrue(text.contains("x = −π/6,  x = 0,  x = π/6"), text)
        XCTAssertTrue(text.contains("changes from + to −"), text)
        // Only f″ = 0 needs the numeric method here; f′ = 0 is solved exactly.
        XCTAssertEqual(text.components(separatedBy: "can't be solved exactly").count - 1, 1, text)
        XCTAssertTrue(steps.contains { $0.style == .heading && $0.text.hasPrefix("Step 3") })
    }

    func testBagrutStepsAreExact() {
        // x² − 2 ln x: minimum at x = 1, found by algebra.
        let p = SketchFactory.finish(.sub(.p(.x, 2), .scaled(2, 1, .ln(.x))), 0.2, 2.9, piBased: false, level: .bagrut, seed: 1,
                                     family: SketchFamily(.x2Ln, [2]))!
        let text = GraphSteps.steps(for: p).map(\.text).joined(separator: "\n")
        XCTAssertTrue(text.contains("minimum at (1, 1)"), text)
        XCTAssertTrue(text.contains("Δ"), text)
    }
}

final class SketchGuideTests: XCTestCase {
    func testGuideJoinsTheUsersDrawing() {
        let p = SketchFactory.testCase()
        let w = p.xMax - p.xMin
        let zone = (p.xMin + 0.4 * w)...(p.xMin + 0.6 * w)
        // The user's sketch: half as tall and 0.1 higher than the truth, wrong (flat) inside the zone.
        func user(_ x: Double) -> Double { zone.contains(x) ? 0.3 : 0.5 * p.value(at: x) + 0.1 }
        let stroke = (0...300).map { i -> SketchPoint in
            let x = p.xMin + w * Double(i) / 300
            return SketchPoint(x: x, y: user(x))
        }
        let guide = SketchGuide.continuation(of: [stroke], for: p, in: zone, flagged: [zone])
        XCTAssertFalse(guide.isEmpty)
        // Joins the drawing at both edges…
        XCTAssertEqual(guide.first!.y, user(guide.first!.x), accuracy: 0.02)
        XCTAssertEqual(guide.last!.y, user(guide.last!.x), accuracy: 0.02)
        // …and follows the user's scale inside, not the exact curve.
        let mid = guide[guide.count / 2]
        XCTAssertEqual(mid.y, 0.5 * p.value(at: mid.x) + 0.1, accuracy: 0.03)
    }
}

final class SolutionSampleTests: XCTestCase {
    /// Prints a few full solutions into the CI log for proofreading.
    func testPrintSamples() {
        func dump(_ title: String, _ steps: [SolutionStep]) {
            print("SAMPLE ===== \(title)")
            for s in steps {
                let pad = String(repeating: "  ", count: s.depth)
                let tag = s.style.map { "[\($0.rawValue)] " } ?? ""
                let math = s.math.map { "  {\(s.label ?? "") \($0.description)}" } ?? ""
                print("SAMPLE \(pad)\(tag)\(s.text)\(math)")
            }
        }
        dump("reference", GraphSteps.steps(for: SketchFactory.testCase()))
        let x2ln = SketchFactory.finish(.sub(.p(.x, 2), .scaled(3, 1, .ln(.x))), 0.2, 3.1, piBased: false, level: .bagrut, seed: 1,
                                        family: SketchFamily(.x2Ln, [3]))!
        dump("x² − 3 ln x", GraphSteps.steps(for: x2ln))
        var rng = SeededRandom(seed: 99)
        if let p = SketchFactory.candidate(level: .hard, rng: &rng, seed: 99) { dump("hard \(p.function)", GraphSteps.steps(for: p)) }
        var r2 = SeededRandom(seed: 3)
        for _ in 0..<400 {
            if let p = SketchFactory.candidate(level: .bagrut, rng: &r2, seed: 3), p.family?.kind == .ratOblique {
                dump("oblique \(p.function)", GraphSteps.steps(for: SketchFactory.whole(p))); break
            }
        }
        let c = ChangeFactory.make(level: .bagrut, seed: 4242)
        dump("change graph-only \(c.transform.formula)", GraphSteps.steps(for: c, formulaVisible: false))
        dump("change formula \(c.transform.formula)", GraphSteps.steps(for: c, formulaVisible: true))
    }
}
