import XCTest
@testable import MathEngine

final class AsymptoteWholeTests: XCTestCase {
    /// A perfect drawing: the true graph, one stroke per branch, kept inside the box.
    func perfect(_ p: SketchProblem, from: Double? = nil, to: Double? = nil) -> [SketchStroke] {
        let a = from ?? p.xMin, b = to ?? p.xMax
        var strokes: [SketchStroke] = []
        var current: SketchStroke = []
        for i in 0...600 {
            let x = a + (b - a) * Double(i) / 600
            let y = p.value(at: x)
            if y.isFinite, y >= p.yMin, y <= p.yMax {
                current.append(SketchPoint(x: x, y: y))
            } else if !current.isEmpty {
                strokes.append(current); current = []
            }
        }
        if !current.isEmpty { strokes.append(current) }
        return strokes
    }

    func hyperbola() -> SketchProblem {
        SketchFactory.finishPoled(.sum([.div(2, .sub(.x, 1)), 1]), -3, 5, poles: [1], piBased: false, level: .medium, seed: 1,
                                  family: SketchFamily(.hyperbola, [2, 1, 1]))!
    }

    func testPerfectDrawingWithAsymptotePasses() {
        let p = hyperbola()
        for mode in SketchMode.allCases {
            let r = SketchChecker.check(perfect(p), for: p, mode: mode)
            XCTAssertTrue(r.passed, "\(mode): \(r.hints)")
        }
    }

    func testWrongWayAtAsymptoteFails() {
        let p = hyperbola()
        // Left branch drawn going up to +∞ instead of down to −∞.
        let flipped = perfect(p).map { stroke in stroke.map { pt in pt.x < 1 ? SketchPoint(x: pt.x, y: 2 - pt.y) : pt } }
        let r = SketchChecker.check(flipped, for: p, mode: .standard)
        XCTAssertFalse(r.passed)
    }

    func testAsymptoteFamiliesGenerate() {
        var kinds = Set<SketchFamily.Kind>()
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(200) {
                var rng = SeededRandom(seed: seed &* 7_777)
                if let p = SketchFactory.candidate(level: level, rng: &rng, seed: seed), !p.poles.isEmpty {
                    kinds.insert(p.family!.kind)
                    XCTAssertTrue(SketchChecker.check(perfect(p), for: p, mode: .standard).passed,
                                  "\(p.function): \(SketchChecker.check(perfect(p), for: p, mode: .standard).hints)")
                    let text = GraphSteps.steps(for: p).map(\.text).joined(separator: "\n")
                    XCTAssertTrue(text.contains("vertical asymptote"), text)
                }
            }
        }
        XCTAssertEqual(kinds, [.hyperbola, .ratOblique, .recipQuad, .xOverQuad, .tanX])
    }

    /// Every correction shown can be fixed in its zone: redrawing the zones
    /// along their guides passes, in every mode.
    func testCorrectionsAreFixable() {
        var failures: [String] = []
        let problems = [SketchFactory.testCase(), hyperbola()] + (1...30).compactMap { seed -> SketchProblem? in
            var rng = SeededRandom(seed: UInt64(seed) &* 104_729)
            return SketchFactory.candidate(level: Level.allCases[seed % 4], rng: &rng, seed: UInt64(seed))
        }
        for p in problems {
            let w = p.xMax - p.xMin
            let wrongs: [(String, (Double, Double) -> Double)] = [
                ("flat zone", { x, y in Swift.abs(x - (p.xMin + 0.5 * w)) < 0.12 * w ? (p.yMin + p.yMax) / 2 : y }),
                ("half height", { _, y in 0.5 * y }),
                ("shifted", { _, y in y + 0.3 * (p.yMax - p.yMin) }),
                ("bumpy", { x, y in y + 0.25 * (p.yMax - p.yMin) * sin(9 * (x - p.xMin) / w * .pi) }),
            ]
            for (name, wrong) in wrongs {
                let strokes = perfect(p).map { $0.map { SketchPoint(x: $0.x, y: wrong($0.x, $0.y)) } }
                for mode in SketchMode.allCases {
                    let r = SketchChecker.check(strokes, for: p, mode: mode)
                    guard !r.passed else { continue }
                    if r.regions.count > 4 { failures.append("\(p.function) \(name) \(mode): \(r.regions.count) regions") }
                    let fixed = SketchChecker.fixedAlongGuides(strokes, p, r.regions, mode.tolerance)
                    let again = SketchChecker.check(fixed, for: p, mode: mode)
                    if !again.passed { failures.append("\(p.function) \(name) \(mode): still \(again.hints)") }
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.prefix(10).joined(separator: "\n"))
    }

    func testWholeGraph() {
        var rng = SeededRandom(seed: 5)
        var p: SketchProblem?
        while p == nil {
            if let c = SketchFactory.candidate(level: .medium, rng: &rng, seed: 5), c.family?.kind == .xExp { p = SketchFactory.whole(c) }
        }
        let q = p!
        XCTAssertTrue(q.isWhole)
        // Everything drawn: passes.
        let all = SketchChecker.checkWhole(perfect(q), for: q, view: q.viewport, mode: .standard)
        print("SAMPLE whole \(q.function) [\(q.xMin), \(q.xMax)] y[\(q.yMin), \(q.yMax)] checked [\(all.checked.xMin), \(all.checked.xMax)]")
        print("SAMPLE raw: \(SketchChecker.rawCheck(perfect(q), for: all.checked, tolerance: SketchMode.standard.tolerance).hints)")
        XCTAssertTrue(all.result.passed, all.result.hints.joined(separator: " | "))
        // Only the left half drawn: the peak/inflection to the right are missing.
        let half = SketchChecker.checkWhole(perfect(q, to: q.xMin + 0.3 * (q.xMax - q.xMin)), for: q, view: q.viewport, mode: .standard)
        XCTAssertFalse(half.result.passed)
        XCTAssertTrue(half.result.hints.joined().contains("Draw further") || half.result.hints.joined().contains("Several"), half.result.hints.joined())
        // Zoomed in on a dull part: not accepted.
        let w = q.xMax - q.xMin
        let zoom = SketchViewport(xMin: q.xMax - 0.2 * w, xMax: q.xMax, yMin: q.yMin, yMax: q.yMax)
        XCTAssertFalse(SketchChecker.checkWhole(perfect(q), for: q, view: zoom, mode: .standard).result.passed)
        // Steps talk about the ends.
        let text = GraphSteps.steps(for: q).map(\.text).joined(separator: "\n")
        XCTAssertTrue(text.contains("horizontal asymptote"), text)
    }

    func testRootsIgnorePoles() {
        let r = GraphSteps.roots(of: .div(1, .sub(.x, 1)), in: -3...4)
        XCTAssertTrue(r.isEmpty, "\(r)")
    }
}
