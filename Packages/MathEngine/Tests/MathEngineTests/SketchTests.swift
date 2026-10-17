import XCTest
@testable import MathEngine

final class SketchTests: XCTestCase {
    let problem = SketchFactory.testCase()

    /// A drawing that follows `g` across the problem's interval, optionally
    /// split into several strokes, with noise relative to the range.
    func drawing(_ g: (Double) -> Double, for p: SketchProblem, noise: Double = 0, strokes: Int = 1,
                 seed: UInt64 = 7, from: Double = 0, to: Double = 1) -> [SketchStroke] {
        var rng = SeededRandom(seed: seed)
        let range = p.yMax - p.yMin
        let total = 240
        var result: [SketchStroke] = []
        for s in 0..<strokes {
            var stroke: SketchStroke = []
            let startIndex = total * s / strokes, endIndex = total * (s + 1) / strokes
            for i in startIndex...endIndex {
                let t = from + (to - from) * Double(i) / Double(total)
                let x = p.xMin + (p.xMax - p.xMin) * t
                // Gaussian noise (Box–Muller) plus a slow wobble, like a shaky finger.
                let u1 = Swift.max(1e-12, rng.double(0...1)), u2 = rng.double(0...1)
                let gauss = (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
                let wobble = sin(t * 9) * 0.6
                stroke.append(SketchPoint(x: x, y: g(x) + noise * range * (gauss + wobble)))
            }
            result.append(stroke)
        }
        return result
    }

    func check(_ g: @escaping (Double) -> Double, _ mode: SketchMode, noise: Double = 0, p: SketchProblem? = nil) -> SketchResult {
        let p = p ?? problem
        return SketchChecker.check(drawing(g, for: p, noise: noise, strokes: 2), for: p, mode: mode)
    }

    // MARK: Reference case

    func testReferenceCaseShape() {
        // sin²x·cos2x on [−π/4, π/4]: zero at −π/4, 0, π/4; humps of height 1/8 near ±π/6.
        XCTAssertEqual(problem.value(at: -.pi / 4), 0, accuracy: 1e-12)
        XCTAssertEqual(problem.value(at: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(problem.value(at: .pi / 6), 0.125, accuracy: 1e-12)
        XCTAssertEqual(problem.xLabel(-.pi / 4), "−π/4")
        XCTAssertEqual(problem.xLabel(.pi / 6), "π/6")
    }

    func testExactSketchPassesEveryMode() {
        for mode in SketchMode.allCases {
            XCTAssertTrue(check(problem.value, mode).passed, "\(mode)")
        }
    }

    // MARK: Each mode accepts what it should

    func testPrecisionAcceptsCarefulRejectsRough() {
        XCTAssertTrue(check(problem.value, .precision, noise: 0.015).passed)
        let w = problem.xMax - problem.xMin
        let rough: (Double) -> Double = { x in 0.7 * self.problem.value(at: x + 0.04 * w) }
        XCTAssertFalse(check(rough, .precision, noise: 0.04).passed)
    }

    func testStandardAcceptsSomewhatRough() {
        let w = problem.xMax - problem.xMin
        let rough: (Double) -> Double = { x in 0.85 * self.problem.value(at: x + 0.02 * w) }
        XCTAssertTrue(check(rough, .standard, noise: 0.03).passed, "\(check(rough, .standard, noise: 0.03).hints)")
    }

    func testProportionsIgnoresVerticalScale() {
        // Drawn 2.5× too tall: wrong values, right proportions.
        let tall: (Double) -> Double = { x in 2.5 * self.problem.value(at: x) }
        XCTAssertTrue(check(tall, .proportions, noise: 0.02).passed, "\(check(tall, .proportions).hints)")
        XCTAssertFalse(check(tall, .standard).passed)
        // But a hump of the wrong relative height fails.
        let lopsided: (Double) -> Double = { x in x > 0 ? 0.35 * self.problem.value(at: x) : self.problem.value(at: x) }
        XCTAssertFalse(check(lopsided, .proportions).passed)
    }

    func testShapeOnlyAcceptsRightStructure() {
        // Wrong scale, offset and slightly misplaced peaks: structure still right.
        let w = problem.xMax - problem.xMin
        let mental: (Double) -> Double = { x in 3 * self.problem.value(at: x + 0.02 * w) + 0.4 }
        XCTAssertTrue(check(mental, .shape, noise: 0.03).passed, "\(check(mental, .shape).hints)")
        // A single hump instead of two fails even here.
        let oneHump: (Double) -> Double = { x in cos(2 * x) }
        XCTAssertFalse(check(oneHump, .shape).passed)
    }

    // MARK: Wrong sketches fail in every mode

    func testWrongShapesFailEveryMode() {
        let flat: (Double) -> Double = { _ in 0.06 }
        let upsideDown: (Double) -> Double = { -self.problem.value(at: $0) }
        let shiftedPeaks: (Double) -> Double = { x in pow(sin(2 * x), 2) * cos(4 * x) }
        for mode in SketchMode.allCases {
            XCTAssertFalse(check(flat, mode).passed, "flat passed in \(mode)")
            XCTAssertFalse(check(upsideDown, mode).passed, "upside-down passed in \(mode)")
            if mode != .shape {
                XCTAssertFalse(check(shiftedPeaks, mode).passed, "shifted peaks passed in \(mode)")
            }
        }
    }

    func testFlagsTheRightRegion() {
        // Correct everywhere except a bump in the middle (where it should dip to 0).
        let bumped: (Double) -> Double = { x in Swift.abs(x) < 0.12 ? 0.11 : self.problem.value(at: x) }
        let r = check(bumped, .standard)
        XCTAssertFalse(r.passed)
        XCTAssertTrue(r.regions.contains { $0.lo <= 0 && $0.hi >= 0 }, "regions: \(r.regions)")
        XCTAssertFalse(r.regions.contains { $0.hi < -0.5 }, "left end wrongly flagged: \(r.regions)")
        XCTAssertTrue(r.hints.contains { $0.contains("x = 0") }, "\(r.hints)")
    }

    func testEachRegionHasItsOwnHint() {
        let wrong: (Double) -> Double = { x in
            if Swift.abs(x) < 0.12 { return 0.11 }
            if x > 0.3 { return 0.0 }
            return self.problem.value(at: x)
        }
        let r = check(wrong, .standard)
        XCTAssertFalse(r.passed)
        // Both wrong spots are covered (fixing them separately wouldn't be enough here,
        // so they may come back as one wider zone).
        XCTAssertTrue(r.regions.contains { $0.lo <= 0 && $0.hi >= 0 }, "\(r.regions)")
        XCTAssertTrue(r.regions.contains { $0.lo <= .pi / 6 && $0.hi >= .pi / 6 }, "\(r.regions)")
        XCTAssertEqual(Set(r.hints).count, r.hints.count, "hints should differ: \(r.hints)")
        XCTAssertLessThanOrEqual(r.regions.count, 4)
    }

    func testHalfDrawnFails() {
        let r = SketchChecker.check(drawing(problem.value, for: problem, from: 0, to: 0.5), for: problem, mode: .standard)
        XCTAssertFalse(r.passed)
        XCTAssertTrue(r.regions.contains { $0.issue == .notDrawn && $0.lo > 0 })
    }

    func testEveryGeneratedProblemWorksInEveryMode() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(25) {
                let p = SketchFactory.make(level: level, seed: seed &* 2_654_435_761)
                for mode in SketchMode.allCases {
                    let exact = check(p.value, mode, noise: 0.01, p: p)
                    XCTAssertTrue(exact.passed, "good sketch rejected (\(mode)) for \(p.function) on [\(p.xMin), \(p.xMax)]: \(exact.hints)")
                    let mean = (p.yMin + p.yMax) / 2
                    XCTAssertFalse(check({ _ in mean }, mode, p: p).passed, "flat line accepted (\(mode)) for \(p.function)")
                }
                let rough = check({ 0.8 * p.value(at: $0) }, .proportions, noise: 0.03, p: p)
                XCTAssertTrue(rough.passed, "rough sketch rejected for \(p.function): \(rough.hints)")
            }
        }
    }

    // MARK: Eraser

    func testEraserCutsOnlyTheMiddle() {
        let stroke = (0...100).map { SketchPoint(x: Double($0) / 100, y: 0) }
        let out = SketchEraser.erase([stroke], around: SketchPoint(x: 0.5, y: 0), rx: 0.05, ry: 0.05)
        XCTAssertEqual(out.count, 2)
        XCTAssertTrue(out[0].allSatisfy { $0.x < 0.46 })
        XCTAssertTrue(out[1].allSatisfy { $0.x > 0.54 })
        XCTAssertGreaterThan(out[0].count, 40)
    }

    func testEraserCutsALongStraightSegment() {
        let stroke = [SketchPoint(x: 0, y: 0), SketchPoint(x: 1, y: 0)]
        let out = SketchEraser.erase([stroke], around: SketchPoint(x: 0.5, y: 0), rx: 0.05, ry: 0.05)
        XCTAssertEqual(out.count, 2)
    }

    func testEraseBandKeepsOutsideParts() {
        let stroke = (0...100).map { SketchPoint(x: Double($0) / 100, y: Double($0) / 100) }
        let out = SketchEraser.erase([stroke], xFrom: 0.3, to: 0.6)
        XCTAssertEqual(out.count, 2)
        XCTAssertTrue(out.flatMap { $0 }.allSatisfy { $0.x <= 0.3 + 1e-9 || $0.x >= 0.6 - 1e-9 })
        XCTAssertEqual(out[0].last!.x, 0.3, accuracy: 0.011)
        XCTAssertEqual(out[1].first!.x, 0.6, accuracy: 0.011)
    }

    func testEraserLeavesOtherStrokesAlone() {
        let a = [SketchPoint(x: 0, y: 0), SketchPoint(x: 1, y: 0)]
        let b = [SketchPoint(x: 0, y: 5), SketchPoint(x: 1, y: 5)]
        let out = SketchEraser.erase([a, b], around: SketchPoint(x: 0.5, y: 0), rx: 0.05, ry: 0.05)
        XCTAssertEqual(out.count, 3)
        XCTAssertTrue(out.contains { $0.allSatisfy { $0.y == 5 } && $0.count >= 2 })
    }

    // MARK: Change

    func testTransformsComputeTheRightGraph() {
        let f = Expr.sum([.p(.x, 2), 1])
        let t = 0.7
        let fv = f.evaluate(at: t)
        XCTAssertEqual(GraphTransform.reciprocalSquare.apply(f).evaluate(at: t), 1 / (fv * fv), accuracy: 1e-12)
        XCTAssertEqual(GraphTransform.shift(2).apply(f).evaluate(at: t), fv + 2, accuracy: 1e-12)
        XCTAssertEqual(GraphTransform.mirror.apply(.exp(.x)).evaluate(at: t), exp(-t), accuracy: 1e-12)
        XCTAssertEqual(GraphTransform.derivative.apply(f).evaluate(at: t), 2 * t, accuracy: 1e-12)
        XCTAssertEqual(GraphTransform.absolute.apply(.sub(.x, 1)).evaluate(at: 0.2), 0.8, accuracy: 1e-12)
        XCTAssertEqual(GraphTransform.reciprocalSquare.formula, "g(x) = 1 / f(x)²")
    }

    func testChangeProblemsAreValidAndSolvable() {
        for level in Level.allCases {
            var transforms = Set<String>()
            for seed in UInt64(1)...UInt64(30) {
                let c = ChangeFactory.make(level: level, seed: seed &* 7_919)
                transforms.insert(c.transform.formula.components(separatedBy: " ").prefix(4).joined())
                let g = c.target
                XCTAssertLessThanOrEqual(g.yMin, c.base.yMin)
                XCTAssertGreaterThanOrEqual(g.yMax, c.base.yMax)
                for i in 0...50 {
                    let x = g.xMin + (g.xMax - g.xMin) * Double(i) / 50
                    XCTAssertTrue(g.value(at: x).isFinite, "\(c.transform.formula) of \(c.base.function) undefined at \(x)")
                }
                XCTAssertTrue(check(g.value, .standard, noise: 0.01, p: g).passed, "\(c.transform.formula), f = \(c.base.function)")
                // Drawing f instead of g must not pass.
                XCTAssertFalse(check(c.base.value, .standard, p: g).passed, "drawing f passed for \(c.transform.formula), f = \(c.base.function)")
            }
            XCTAssertGreaterThan(transforms.count, 1, "no variety at \(level)")
        }
    }
}

final class GraphStepsTests: XCTestCase {
    func testReferenceCaseSteps() {
        let p = SketchFactory.testCase()
        let steps = GraphSteps.steps(for: p)
        let text = steps.map(\.text).joined(separator: "\n")
        // Peaks near ±π/6 and a dip at 0 must be found.
        XCTAssertTrue(text.contains("maximum"), text)
        XCTAssertTrue(text.contains("minimum"), text)
        XCTAssertTrue(text.contains("π/6"), text)
        XCTAssertTrue(text.contains("inflection point"), text)
    }

    func testRootsFindsCrossingsAndTouches() {
        let r = GraphSteps.roots(of: .mul(.sub(.x, 1), .p(.x, 2)), in: -2...3)   // (x−1)·x²
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0], 0, accuracy: 1e-3)
        XCTAssertEqual(r[1], 1, accuracy: 1e-6)
    }

    func testEveryProblemHasSteps() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(15) {
                let p = SketchFactory.make(level: level, seed: seed &* 104_729)
                XCTAssertGreaterThan(GraphSteps.steps(for: p).count, 6)
                let c = ChangeFactory.make(level: level, seed: seed &* 7_919)
                XCTAssertGreaterThan(GraphSteps.steps(for: c).count, 8)
            }
        }
    }

    func testSketchVariety() {
        // Fresh problems should rarely repeat.
        for level in Level.allCases {
            let sigs = (1...40).map { SketchFactory.make(level: level, seed: UInt64($0) &* 2_654_435_761).signature }
            XCTAssertGreaterThan(Set(sigs).count, 24, "too many repeats at \(level)")
        }
    }
}

final class ChangeStepsTests: XCTestCase {
    func testGraphOnlyStepsNeverUseTheFormula() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(12) {
                let c = ChangeFactory.make(level: level, seed: seed &* 31_337)
                let steps = GraphSteps.steps(for: c, formulaVisible: false)
                XCTAssertTrue(steps.allSatisfy { $0.math == nil && $0.prime == nil }, "formula shown for \(c.transform.formula)")
                XCTAssertFalse(steps.contains { $0.text.contains("f′(x) =") || $0.text.contains("f″") })
                XCTAssertGreaterThan(steps.count, 6)
            }
        }
    }

    func testShapeModeIsVisual() {
        let p = SketchFactory.testCase()
        func draw(_ g: (Double) -> Double) -> [SketchStroke] {
            [(0...200).map { i in
                let x = p.xMin + (p.xMax - p.xMin) * Double(i) / 200
                return SketchPoint(x: x, y: g(x))
            }]
        }
        // Looks right (different scale, slightly early humps): passes.
        let w = p.xMax - p.xMin
        XCTAssertTrue(SketchChecker.check(draw { 4 * p.value(at: $0 + 0.02 * w) - 1 }, for: p, mode: .shape).passed)
        // One hump instead of two: doesn't look right.
        XCTAssertFalse(SketchChecker.check(draw { cos(2 * $0) }, for: p, mode: .shape).passed)
        // A wiggly line: doesn't look right.
        XCTAssertFalse(SketchChecker.check(draw { sin(14 * $0) }, for: p, mode: .shape).passed)
    }
}
