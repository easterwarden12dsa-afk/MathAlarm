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
        XCTAssertTrue(kinds.isSuperset(of: [.hyperbola, .ratOblique, .recipQuad, .xOverQuad, .tanX, .cosOverSin, .expOverLin, .ratTwoPoles]), "\(kinds)")
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

    func testBagrutChangeKinds() {
        var seen = Set<String>()
        for seed in UInt64(1)...UInt64(120) {
            let c = ChangeFactory.make(level: .bagrut, seed: seed &* 9_973)
            switch c.transform {
            case .antiderivative: seen.insert("anti")
                // g′ = f really holds.
                let x = (c.base.xMin + c.base.xMax) / 2
                XCTAssertEqual(NumericDerivative.at(x, of: c.target.function), c.base.value(at: x), accuracy: 1e-4)
            case .reciprocal where !c.target.poles.isEmpty: seen.insert("poles")
            case .lnOf: seen.insert("ln")
            case .expOf: seen.insert("exp")
            case .absX: seen.insert("absX")
            default: break
            }
            XCTAssertGreaterThan(GraphSteps.steps(for: c, formulaVisible: false).count, 6)
            XCTAssertFalse(GraphSteps.markers(for: c).isEmpty)
        }
        XCTAssertTrue(seen.isSuperset(of: ["anti", "poles", "ln", "exp"]), "\(seen)")
    }

    func testRootsIgnorePoles() {
        let r = GraphSteps.roots(of: .div(1, .sub(.x, 1)), in: -3...4)
        XCTAssertTrue(r.isEmpty, "\(r)")
    }
}

final class VarietyTests: XCTestCase {
    func testConsecutiveSketchesLookDifferent() {
        for level in Level.allCases {
            var memory = ShapeMemory()
            var seen = Set<String>()
            var kinds: [String] = []
            var lookalikes = 0
            for i in 1...30 {
                let p = SketchFactory.make(level: level, seed: UInt64(i) &* 2_654_435_761, avoiding: seen, memory: memory)
                let key = ShapeKey.of(p)
                if memory.shapes.suffix(10).contains(where: { ShapeKey.distance($0, key) < 0.09 }) { lookalikes += 1 }
                seen.insert(p.signature)
                let kind = p.family?.kind.rawValue ?? "other"
                kinds.append(kind)
                memory.remember(shape: key, kind: kind)
            }
            XCTAssertLessThanOrEqual(lookalikes, level == .easy ? 6 : 3, "\(level): \(lookalikes) look-alikes")
            for i in 3..<kinds.count {
                XCTAssertFalse(kinds[i - 3..<i].contains(kinds[i]), "\(level): family \(kinds[i]) repeated within 3: \(kinds)")
            }
        }
    }

    func testConsecutiveChangesLookDifferent() {
        for level in Level.allCases {
            var memory = ShapeMemory()
            var seen = Set<String>()
            var lookalikes = 0
            var sameKindInARow = 0
            var last = ""
            var names: [String] = []
            for i in 1...25 {
                let c = ChangeFactory.make(level: level, seed: UInt64(i) &* 40_503, avoiding: seen, memory: memory)
                let key = ShapeKey.of(c.target)
                if memory.shapes.suffix(10).contains(where: { ShapeKey.distance($0, key) < 0.09 }) { lookalikes += 1 }
                if c.kindName == last { sameKindInARow += 1 }
                last = c.kindName
                names.append(c.kindName)
                seen.insert(c.signature)
                memory.remember(shape: key, kind: c.kindName)
            }
            XCTAssertLessThanOrEqual(lookalikes, level == .easy ? 7 : 4, "\(level)")
            XCTAssertLessThanOrEqual(sameKindInARow, 2, "\(level): \(names)")
        }
    }
}

final class HardIntegralTests: XCTestCase {
    func testHardHasIntegralTasks() {
        var count = 0
        for seed in UInt64(1)...UInt64(80) {
            let c = ChangeFactory.make(level: .hard, seed: seed &* 31)
            if case .antiderivative = c.transform {
                count += 1
                let x = (c.base.xMin + c.base.xMax) / 2
                XCTAssertEqual(NumericDerivative.at(x, of: c.target.function), c.base.value(at: x), accuracy: 1e-4)
                XCTAssertTrue(c.transform.formula.hasPrefix("g(x) = ∫"))
            }
        }
        XCTAssertGreaterThan(count, 5)
    }
}

final class TracingTests: XCTestCase {
    /// A hand tracing of the solution graph: small wobble (1.5% of the box)
    /// and a slight sideways offset, one stroke per visible branch.
    func traced(_ p: SketchProblem) -> [SketchStroke] {
        let box = p.yMax - p.yMin, w = p.xMax - p.xMin
        var strokes: [SketchStroke] = [], cur: SketchStroke = []
        for i in 0...300 {
            let x = p.xMin + w * Double(i) / 300
            let y = p.value(at: x - 0.008 * w) + 0.015 * box * sin(Double(i) * 0.7)
            if y.isFinite, y >= p.yMin, y <= p.yMax { cur.append(SketchPoint(x: x, y: y)) } else if !cur.isEmpty { strokes.append(cur); cur = [] }
        }
        if !cur.isEmpty { strokes.append(cur) }
        return strokes
    }

    func testTracedChangeAnswersPassInEveryMode() {
        var failures: [String] = []
        for level in [Level.medium, .hard, .bagrut] {
            for seed in UInt64(1)...UInt64(60) {
                let c = ChangeFactory.make(level: level, seed: seed &* 7_717)
                for mode in SketchMode.allCases {
                    let r = SketchChecker.check(traced(c.target), for: c.target, mode: mode)
                    if !r.passed { failures.append("\(level) \(mode) \(c.transform.formula) f=\(c.base.function): \(r.hints)") }
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) failures:\n" + failures.prefix(8).joined(separator: "\n"))
    }

    func testTracedSketchesPassInEveryMode() {
        var failures: [String] = []
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(60) {
                let p = SketchFactory.make(level: level, seed: seed &* 5_051)
                for mode in SketchMode.allCases {
                    let r = SketchChecker.check(traced(p), for: p, mode: mode)
                    if !r.passed { failures.append("\(level) \(mode) \(p.function): \(r.hints)") }
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, "\(failures.count) failures:\n" + failures.prefix(8).joined(separator: "\n"))
    }
}

/// How often each mode accepts deliberately wrong drawings (printed for calibration).
final class StrictnessReport: XCTestCase {
    static func problems() -> [SketchProblem] {
        var out: [SketchProblem] = []
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(40) { out.append(SketchFactory.make(level: level, seed: seed &* 3_331)) }
            for seed in UInt64(1)...UInt64(15) { out.append(ChangeFactory.make(level: level, seed: seed &* 919).target) }
        }
        return out
    }

    static func drawing(_ p: SketchProblem, _ g: (Double) -> Double) -> [SketchStroke] {
        let w = p.xMax - p.xMin
        var strokes: [SketchStroke] = [], cur: SketchStroke = []
        for i in 0...300 {
            let x = p.xMin + w * Double(i) / 300
            let y = g(x)
            if y.isFinite, y >= p.yMin, y <= p.yMax { cur.append(SketchPoint(x: x, y: y)) } else if !cur.isEmpty { strokes.append(cur); cur = [] }
        }
        if !cur.isEmpty { strokes.append(cur) }
        return strokes
    }

    static func variants(_ p: SketchProblem) -> [(String, (Double) -> Double)] {
        let H = p.yMax - p.yMin, W = p.xMax - p.xMin
        let mid = (p.yMax + p.yMin) / 2
        let f = { (x: Double) in p.value(at: x) }
        let wob = { (x: Double) in 0.015 * H * sin((x - p.xMin) / W * 140) }
        // The biggest turn of the graph, flattened.
        let ext = GraphSteps.keyPoints(p, inflections: false).filter { $0.kinds.contains(.peak) || $0.kinds.contains(.dip) }
        let flat: (Double) -> Double = { x in
            guard let e = ext.max(by: { Swift.abs(f($0.x) - mid) < Swift.abs(f($1.x) - mid) }) else { return f(x) }
            let lo = e.x - 0.1 * W, hi = e.x + 0.1 * W
            guard x > lo, x < hi else { return f(x) }
            let t = (x - lo) / (hi - lo)
            return f(lo) + t * (f(hi) - f(lo))
        }
        return [
            ("traced", { f($0 - 0.008 * W) + wob($0) }),
            ("up 8%", { f($0) + 0.08 * H + wob($0) }),
            ("up 15%", { f($0) + 0.15 * H + wob($0) }),
            ("up 25%", { f($0) + 0.25 * H + wob($0) }),
            ("squash 0.7", { mid + 0.7 * (f($0) - mid) + wob($0) }),
            ("squash 0.5", { mid + 0.5 * (f($0) - mid) + wob($0) }),
            ("sideways 4%", { f($0 - 0.04 * W) + wob($0) }),
            ("sideways 8%", { f($0 - 0.08 * W) + wob($0) }),
            ("sideways 12%", { f($0 - 0.12 * W) + wob($0) }),
            ("flat peak", { flat($0) + wob($0) }),
            ("bumpy", { f($0) + 0.1 * H * sin(($0 - p.xMin) / W * 2 * .pi * 5) }),
        ]
    }

    func testPrintAcceptanceRates() {
        let ps = Self.problems()
        for mode in SketchMode.allCases {
            var line = "SAMPLE strictness \(mode):"
            for (i, name) in Self.variants(ps[0]).map(\.0).enumerated() {
                var ok = 0, total = 0
                for p in ps {
                    let g = Self.variants(p)[i].1
                    total += 1
                    if SketchChecker.check(Self.drawing(p, g), for: p, mode: mode).passed { ok += 1 }
                }
                line += "  \(name) \(Int((100 * Double(ok) / Double(total)).rounded()))%"
            }
            print(line)
        }
    }
}

final class StrictnessDebug: XCTestCase {
    func testPrintFlatPeakEscapes() {
        var shown = 0
        for p in StrictnessReport.problems() where shown < 8 {
            let v = StrictnessReport.variants(p)
            let g = v.first { $0.0 == "flat peak" }!.1
            let r = SketchChecker.check(StrictnessReport.drawing(p, g), for: p, mode: .precision)
            if r.passed {
                shown += 1
                let ext = GraphSteps.keyPoints(p, inflections: false).filter { $0.kinds.contains(.peak) || $0.kinds.contains(.dip) }.map { "\(GraphSteps.num($0.x)):\(GraphSteps.num(p.value(at: $0.x)))" }
                print("SAMPLE escape \(p.function) [\(GraphSteps.num(p.xMin)), \(GraphSteps.num(p.xMax))] y[\(GraphSteps.num(p.yMin)), \(GraphSteps.num(p.yMax))] ext \(ext)")
            }
        }
    }
}
