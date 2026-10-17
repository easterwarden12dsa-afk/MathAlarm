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

    func testReferenceCaseShape() {
        // sin²x·cos2x on [−π/4, π/4]: zero at −π/4, 0, π/4; humps of height 1/8 near ±π/6.
        XCTAssertEqual(problem.value(at: -.pi / 4), 0, accuracy: 1e-12)
        XCTAssertEqual(problem.value(at: 0), 0, accuracy: 1e-12)
        XCTAssertEqual(problem.value(at: .pi / 6), 0.125, accuracy: 1e-12)
        XCTAssertEqual(problem.xLabel(-.pi / 4), "−π/4")
        XCTAssertEqual(problem.xLabel(.pi / 6), "π/6")
    }

    func testExactSketchPasses() {
        let r = SketchChecker.check(drawing(problem.value, for: problem), for: problem)
        XCTAssertTrue(r.passed, "\(r.hints)")
    }

    func testNoisyMultiStrokeSketchPasses() {
        let r = SketchChecker.check(drawing(problem.value, for: problem, noise: 0.03, strokes: 3), for: problem)
        XCTAssertTrue(r.passed, "\(r.hints)")
    }

    func testFlatLineFails() {
        let r = SketchChecker.check(drawing({ _ in 0.06 }, for: problem), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertFalse(r.regions.isEmpty)
    }

    func testUpsideDownFails() {
        let r = SketchChecker.check(drawing({ -self.problem.value(at: $0) }, for: problem), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertFalse(r.hints.isEmpty)
    }

    /// A quick, imperfect finger sketch: humps 25% too small, slightly
    /// shifted, shaky. The shape is right, so it must pass.
    func testRoughSketchPasses() {
        let w = problem.xMax - problem.xMin
        let rough: (Double) -> Double = { x in 0.75 * self.problem.value(at: x + 0.03 * w) }
        let r = SketchChecker.check(drawing(rough, for: problem, noise: 0.04, strokes: 2), for: problem)
        XCTAssertTrue(r.passed, "\(r.hints)")
    }

    func testEachRegionHasItsOwnHint() {
        // Wrong in two separate places: a bump at 0 and the right hump missing.
        let wrong: (Double) -> Double = { x in
            if Swift.abs(x) < 0.12 { return 0.11 }
            if x > 0.3 { return 0.0 }
            return self.problem.value(at: x)
        }
        let r = SketchChecker.check(drawing(wrong, for: problem), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertGreaterThanOrEqual(r.regions.count, 2, "\(r.regions)")
        XCTAssertEqual(Set(r.hints).count, r.hints.count, "hints should differ: \(r.hints)")
        XCTAssertLessThanOrEqual(r.regions.count, 4)
        XCTAssertTrue(r.regions.contains { $0.lo <= 0 && $0.hi >= 0 })
        XCTAssertTrue(r.regions.contains { $0.lo <= .pi / 6 && $0.hi >= .pi / 6 })
    }

    func testPeaksInTheWrongPlaceFail() {
        // Same height, but peaks at ±π/12 instead of ±π/6.
        let wrong: (Double) -> Double = { x in pow(sin(2 * x), 2) * cos(4 * x) }
        let r = SketchChecker.check(drawing(wrong, for: problem), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertTrue(r.hints.contains { $0.contains("peak") || $0.contains("Too") }, "\(r.hints)")
    }

    func testFlagsTheRightRegion() {
        // Correct everywhere except a bump in the middle (where it should dip to 0).
        let bumped: (Double) -> Double = { x in Swift.abs(x) < 0.12 ? 0.11 : self.problem.value(at: x) }
        let r = SketchChecker.check(drawing(bumped, for: problem), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertTrue(r.regions.contains { $0.lo <= 0 && $0.hi >= 0 }, "regions: \(r.regions)")
        XCTAssertFalse(r.regions.contains { $0.hi < -0.5 }, "left end wrongly flagged: \(r.regions)")
        XCTAssertTrue(r.hints.contains { $0.contains("x = 0") }, "\(r.hints)")
    }

    func testHalfDrawnFails() {
        let r = SketchChecker.check(drawing(problem.value, for: problem, from: 0, to: 0.5), for: problem)
        XCTAssertFalse(r.passed)
        XCTAssertTrue(r.regions.contains { $0.issue == .notDrawn && $0.lo > 0 })
    }

    func testEveryGeneratedProblemAcceptsGoodSketches() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(40) {
                let p = SketchFactory.make(level: level, seed: seed &* 2_654_435_761)
                XCTAssertTrue(p.yMax > p.yMin)
                let exact = SketchChecker.check(drawing(p.value, for: p), for: p)
                XCTAssertTrue(exact.passed, "exact sketch rejected for \(p.function) on [\(p.xMin), \(p.xMax)]: \(exact.hints)")
                let noisy = SketchChecker.check(drawing(p.value, for: p, noise: 0.02, strokes: 2, seed: seed), for: p)
                XCTAssertTrue(noisy.passed, "noisy sketch rejected for \(p.function): \(noisy.hints)")
                let rough = SketchChecker.check(drawing({ 0.78 * p.value(at: $0) }, for: p, noise: 0.03, strokes: 3, seed: seed), for: p)
                XCTAssertTrue(rough.passed, "rough sketch rejected for \(p.function) on [\(p.xMin), \(p.xMax)]: \(rough.hints)")
                let mean = (p.yMin + p.yMax) / 2
                let flat = SketchChecker.check(drawing({ _ in mean }, for: p), for: p)
                XCTAssertFalse(flat.passed, "flat line accepted for \(p.function)")
            }
        }
    }

    func testStrictnessPresetsAreOrdered() {
        let noisy = drawing(problem.value, for: problem, noise: 0.07, strokes: 2)
        let relaxed = SketchChecker.check(noisy, for: problem, tolerance: .relaxed)
        let strict = SketchChecker.check(noisy, for: problem, tolerance: .strict)
        XCTAssertTrue(relaxed.passed || !strict.passed, "strict passed but relaxed failed")
    }
}
