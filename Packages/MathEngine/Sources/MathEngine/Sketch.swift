import Foundation

// MARK: - Problem

/// "Sketch y = f(x) for xMin ≤ x ≤ xMax". `yMin…yMax` is the y-range the
/// canvas shows (chosen so the whole graph fits with a margin).
public struct SketchProblem: Codable, Hashable, Sendable {
    public var function: Expr
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double
    public var yMax: Double
    /// Label x positions as multiples of π.
    public var piBased: Bool
    public var level: Level
    public var seed: UInt64

    public var signature: String { "sketch:\(function.description):\(xMin):\(xMax)" }

    public func value(at x: Double) -> Double { function.evaluate(at: x) }

    /// Label for an x position, e.g. "−π/4" or "1.5".
    public func xLabel(_ x: Double) -> String { SketchFormat.x(x, piBased: piBased) }
}

public struct SketchPoint: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public typealias SketchStroke = [SketchPoint]

// MARK: - Tunable tolerances

/// The "close enough" thresholds. All errors are measured relative to the
/// function's range on the interval (max − min), positions relative to the
/// interval width.
public struct SketchTolerance: Hashable, Sendable {
    /// Number of x columns the drawing is sampled at.
    public var columns = 80
    /// Number of x segments that are judged separately (and highlighted).
    public var segments = 8
    /// Fraction of the interval that must be drawn.
    public var minCoverage = 0.85
    /// Allowed mean |error| in a segment.
    public var segmentError = 0.16
    /// Allowed error at each end of the interval.
    public var endpointError = 0.2
    /// Allowed |y| where the graph should touch/cross zero.
    public var zeroError = 0.13
    /// How far a peak/dip may be from its true x position.
    public var extremumShift = 0.08
    /// A peak or dip only counts if it's at least this tall.
    public var prominence = 0.12

    public init() {}

    public static let moderate = SketchTolerance()

    public static let relaxed: SketchTolerance = {
        var t = SketchTolerance()
        t.minCoverage = 0.75; t.segmentError = 0.22; t.endpointError = 0.28
        t.zeroError = 0.18; t.extremumShift = 0.12
        return t
    }()

    public static let strict: SketchTolerance = {
        var t = SketchTolerance()
        t.minCoverage = 0.92; t.segmentError = 0.11; t.endpointError = 0.14
        t.zeroError = 0.09; t.extremumShift = 0.055
        return t
    }()
}

// MARK: - Result

public struct SketchRegion: Hashable, Sendable {
    public enum Issue: String, Sendable { case tooHigh, tooLow, missingFeature, notDrawn }
    public var lo: Double
    public var hi: Double
    public var issue: Issue
}

public struct SketchResult: Sendable {
    public var passed: Bool
    /// x-ranges to highlight. The true curve is never revealed.
    public var regions: [SketchRegion]
    /// Short hints such as "Too high here" or "Missing the dip near x = 0".
    public var hints: [String]
    public var coverage: Double
}

// MARK: - Checker

public enum SketchChecker {
    public static func check(_ strokes: [SketchStroke], for problem: SketchProblem,
                             tolerance t: SketchTolerance = .moderate) -> SketchResult {
        let a = problem.xMin, b = problem.xMax, width = b - a
        let n = t.columns
        let xs = (0..<n).map { a + width * (Double($0) + 0.5) / Double(n) }
        let truth = xs.map { problem.value(at: $0) }
        let fMax = truth.max() ?? 1, fMin = truth.min() ?? 0
        let range = Swift.max(fMax - fMin, 1e-9)

        // 1. The drawing as one y value per column.
        let sampled = sampleDrawing(strokes, xs: xs, columnWidth: width / Double(n))
        let filled = sampled.compactMap { $0 }.count
        let coverage = Double(filled) / Double(n)

        if coverage < t.minCoverage {
            var regions: [SketchRegion] = []
            var start: Int?
            for i in 0...n {
                let missing = i < n && sampled[i] == nil
                if missing, start == nil { start = i }
                if !missing, let s = start {
                    regions.append(SketchRegion(lo: xs[s] - width / Double(2 * n), hi: xs[i - 1] + width / Double(2 * n), issue: .notDrawn))
                    start = nil
                }
            }
            return SketchResult(passed: false, regions: regions,
                                hints: ["Draw the graph across the whole interval — the shaded parts are empty."],
                                coverage: coverage)
        }
        let user = fillGaps(sampled)

        var regions: [SketchRegion] = []
        var hints: [String] = []
        func addHint(_ h: String) { if !hints.contains(h) { hints.append(h) } }

        // 2. Segment by segment: how far off is the drawing on average?
        let perSegment = Swift.max(1, n / t.segments)
        var segStart = 0
        while segStart < n {
            let segEnd = Swift.min(n, segStart + perSegment)
            var absSum = 0.0, signedSum = 0.0
            for i in segStart..<segEnd {
                let d = user[i] - truth[i]
                absSum += Swift.abs(d)
                signedSum += d
            }
            let count = Double(segEnd - segStart)
            if absSum / count / range > t.segmentError {
                let high = signedSum > 0
                regions.append(SketchRegion(lo: xs[segStart] - width / Double(2 * n),
                                            hi: xs[segEnd - 1] + width / Double(2 * n),
                                            issue: high ? .tooHigh : .tooLow))
                addHint(high ? "Too high in the red band\(regions.count > 1 ? "s" : "")." : "Too low in the red band\(regions.count > 1 ? "s" : "").")
            }
            segStart = segEnd
        }

        // 3. End points.
        let endWidth = width / Double(t.segments) / 2
        if Swift.abs(user[0] - truth[0]) / range > t.endpointError {
            regions.append(SketchRegion(lo: a, hi: a + endWidth, issue: user[0] > truth[0] ? .tooHigh : .tooLow))
            addHint(user[0] > truth[0] ? "The left end starts too high." : "The left end starts too low.")
        }
        if Swift.abs(user[n - 1] - truth[n - 1]) / range > t.endpointError {
            regions.append(SketchRegion(lo: b - endWidth, hi: b, issue: user[n - 1] > truth[n - 1] ? .tooHigh : .tooLow))
            addHint(user[n - 1] > truth[n - 1] ? "The right end finishes too high." : "The right end finishes too low.")
        }

        // 4. Zeros: where the graph crosses or touches the x-axis.
        let shift = t.extremumShift * width
        for x0 in zeros(xs: xs, ys: truth, range: range) {
            let u0 = interpolate(user, xs: xs, at: x0)
            if Swift.abs(u0) / range > t.zeroError {
                regions.append(SketchRegion(lo: x0 - shift, hi: x0 + shift, issue: .missingFeature))
                addHint("The graph should reach y = 0 near x = \(problem.xLabel(x0)).")
            }
        }

        // 5. Peaks and dips must be there, at about the right place. Compared
        // against how much the true curve itself rises/falls in the same window,
        // using a lightly smoothed drawing so finger jitter isn't a "peak".
        let smooth = smoothed(user, radius: 2)
        for e in extrema(xs: xs, ys: truth, range: range, minProminence: t.prominence) {
            let window = xs.indices.filter { Swift.abs(xs[$0] - e.x) <= 2 * shift }
            guard window.count >= 5 else { continue }
            let tv = window.map { truth[$0] }, uv = window.map { smooth[$0] }
            func drop(_ v: [Double], _ isMax: Bool) -> Double {
                let extreme = isMax ? v.max()! : v.min()!
                return isMax ? Swift.min(extreme - v.first!, extreme - v.last!)
                             : Swift.min(v.first! - extreme, v.last! - extreme)
            }
            let trueDrop = drop(tv, e.isMax)
            let atEdgeOfInterval = e.x - a < 2 * shift || b - e.x < 2 * shift
            guard trueDrop > 0.04 * range || atEdgeOfInterval else { continue }
            let userDrop = drop(uv, e.isMax)
            // Where the drawing's peak/dip is: centre of its top (or bottom) part.
            let extreme = e.isMax ? uv.max()! : uv.min()!
            let cutoff = 0.5 * Swift.max(userDrop, 1e-12)
            var wSum = 0.0, xSum = 0.0
            for (k, i) in window.enumerated() {
                let w = Swift.max(0, cutoff - Swift.abs(uv[k] - extreme))
                wSum += w; xSum += w * xs[i]
            }
            let centre = wSum > 0 ? xSum / wSum : xs[window[uv.firstIndex(of: extreme)!]]
            let shapeOK = atEdgeOfInterval ? true : userDrop >= 0.35 * trueDrop
            if !shapeOK || Swift.abs(centre - e.x) > shift {
                regions.append(SketchRegion(lo: e.x - shift, hi: e.x + shift, issue: .missingFeature))
                addHint(e.isMax ? "Missing the peak near x = \(problem.xLabel(e.x))."
                                : "Missing the dip near x = \(problem.xLabel(e.x)).")
            }
        }

        return SketchResult(passed: regions.isEmpty, regions: merge(regions), hints: hints, coverage: coverage)
    }

    // MARK: Helpers

    /// For each column, the median y of the drawing there (strokes are
    /// treated as connected lines so fast swipes still cover every column).
    static func sampleDrawing(_ strokes: [SketchStroke], xs: [Double], columnWidth: Double) -> [Double?] {
        var buckets = Array(repeating: [Double](), count: xs.count)
        let a = xs.first! - columnWidth / 2
        func column(_ x: Double) -> Int? {
            let i = Int(((x - a) / columnWidth).rounded(.down))
            return i >= 0 && i < xs.count ? i : nil
        }
        for stroke in strokes {
            if stroke.count == 1, let c = column(stroke[0].x) { buckets[c].append(stroke[0].y) }
            for (p, q) in zip(stroke, stroke.dropFirst()) {
                let lo = Swift.min(p.x, q.x), hi = Swift.max(p.x, q.x)
                for (i, x) in xs.enumerated() where x >= lo && x <= hi {
                    let t = hi == lo ? 0 : (x - p.x) / (q.x - p.x)
                    buckets[i].append(p.y + t * (q.y - p.y))
                }
                if let c = column(p.x) { buckets[c].append(p.y) }
                if let c = column(q.x) { buckets[c].append(q.y) }
            }
        }
        return buckets.map { values in
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }
    }

    static func fillGaps(_ values: [Double?]) -> [Double] {
        let known = values.indices.filter { values[$0] != nil }
        guard let first = known.first, let last = known.last else { return values.map { _ in 0 } }
        var out = [Double](repeating: 0, count: values.count)
        for i in values.indices {
            if let v = values[i] { out[i] = v; continue }
            if i < first { out[i] = values[first]!; continue }
            if i > last { out[i] = values[last]!; continue }
            let l = known.last { $0 < i }!, r = known.first { $0 > i }!
            let t = Double(i - l) / Double(r - l)
            out[i] = values[l]! + t * (values[r]! - values[l]!)
        }
        return out
    }

    static func smoothed(_ ys: [Double], radius: Int) -> [Double] {
        ys.indices.map { i in
            let lo = Swift.max(0, i - radius), hi = Swift.min(ys.count - 1, i + radius)
            return ys[lo...hi].reduce(0, +) / Double(hi - lo + 1)
        }
    }

    static func interpolate(_ ys: [Double], xs: [Double], at x: Double) -> Double {
        if x <= xs[0] { return ys[0] }
        if x >= xs[xs.count - 1] { return ys[ys.count - 1] }
        let step = xs[1] - xs[0]
        let i = Swift.min(xs.count - 2, Int((x - xs[0]) / step))
        let t = (x - xs[i]) / step
        return ys[i] + t * (ys[i + 1] - ys[i])
    }

    /// Crossings (sign changes) and touch points (near-zero extrema).
    static func zeros(xs: [Double], ys: [Double], range: Double) -> [Double] {
        var found: [Double] = []
        for i in 0..<(xs.count - 1) where (ys[i] < 0) != (ys[i + 1] < 0) {
            let t = ys[i] / (ys[i] - ys[i + 1])
            found.append(xs[i] + t * (xs[i + 1] - xs[i]))
        }
        for i in 1..<(xs.count - 1) where Swift.abs(ys[i]) < 0.02 * range {
            let isExtremum = (ys[i] <= ys[i - 1] && ys[i] <= ys[i + 1]) || (ys[i] >= ys[i - 1] && ys[i] >= ys[i + 1])
            if isExtremum, !found.contains(where: { Swift.abs($0 - xs[i]) < (xs[1] - xs[0]) * 3 }) {
                found.append(xs[i])
            }
        }
        return found.sorted()
    }

    struct Extremum { var x: Double; var y: Double; var isMax: Bool; var prominence: Double }

    static func extrema(xs: [Double], ys: [Double], range: Double, minProminence: Double) -> [Extremum] {
        var out: [Extremum] = []
        let n = ys.count
        for i in 1..<(n - 1) {
            let isMax = ys[i] > ys[i - 1] && ys[i] >= ys[i + 1]
            let isMin = ys[i] < ys[i - 1] && ys[i] <= ys[i + 1]
            guard isMax || isMin else { continue }
            // Prominence: how far it stands out before the curve turns back.
            var left = ys[i], right = ys[i]
            var j = i - 1
            while j >= 0 { left = isMax ? Swift.min(left, ys[j]) : Swift.max(left, ys[j]); if isMax ? ys[j] > ys[i] : ys[j] < ys[i] { break }; j -= 1 }
            j = i + 1
            while j < n { right = isMax ? Swift.min(right, ys[j]) : Swift.max(right, ys[j]); if isMax ? ys[j] > ys[i] : ys[j] < ys[i] { break }; j += 1 }
            let prom = isMax ? ys[i] - Swift.max(left, right) : Swift.min(left, right) - ys[i]
            if prom >= minProminence * range {
                out.append(Extremum(x: xs[i], y: ys[i], isMax: isMax, prominence: prom))
            }
        }
        return out
    }

    static func merge(_ regions: [SketchRegion]) -> [SketchRegion] {
        let sorted = regions.sorted { $0.lo < $1.lo }
        var out: [SketchRegion] = []
        for r in sorted {
            if var last = out.last, r.lo <= last.hi, r.issue == last.issue {
                last.hi = Swift.max(last.hi, r.hi)
                out[out.count - 1] = last
            } else {
                out.append(r)
            }
        }
        return out
    }
}

// MARK: - Formatting

public enum SketchFormat {
    public static func x(_ v: Double, piBased: Bool) -> String {
        if piBased {
            let twelfths = v / (Double.pi / 12)
            let k = Int(twelfths.rounded())
            if Swift.abs(twelfths - Double(k)) < 0.15 {
                if k == 0 { return "0" }
                let g = gcd(Swift.abs(k), 12)
                let num = k / g, den = 12 / g
                let sign = num < 0 ? "−" : ""
                let n = Swift.abs(num)
                let top = n == 1 ? "π" : "\(n)π"
                return den == 1 ? "\(sign)\(top)" : "\(sign)\(top)/\(den)"
            }
        }
        return number(v)
    }

    public static func number(_ v: Double) -> String {
        if Swift.abs(v - v.rounded()) < 1e-9 { return v < 0 ? "−\(Int(-v.rounded()))" : "\(Int(v.rounded()))" }
        let s = String(format: "%.2g", v)
        return s.replacingOccurrences(of: "-", with: "−")
    }
}

// MARK: - Generator

public enum SketchFactory {
    public static func make(level: Level, seed: UInt64, avoiding: Set<String> = []) -> SketchProblem {
        var s = seed
        for _ in 0..<60 {
            var rng = SeededRandom(seed: s)
            for _ in 0..<50 {
                if let p = candidate(level: level, rng: &rng, seed: s), valid(p), !avoiding.contains(p.signature) {
                    return p
                }
            }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        return testCase(seed: seed)
    }

    /// The reference example: sin²(x)·cos(2x) on [−π/4, π/4].
    public static func testCase(seed: UInt64 = 1) -> SketchProblem {
        finish(.mul(.p(.sin(.x), 2), .cos(.mul(2, .x))), -Double.pi / 4, Double.pi / 4, piBased: true, level: .hard, seed: seed)!
    }

    static func candidate(level: Level, rng r: inout SeededRandom, seed: UInt64) -> SketchProblem? {
        let x = Expr.x
        let pi = Double.pi
        switch level {
        case .easy:
            switch r.int(0...2) {
            case 0:
                let r1 = r.int(-3...1), r2 = r1 + r.int(2...4), a = r.pick([1, -1])
                let f = Expr.scaled(a, 1, .mul(.sum([x, .n(-r1)]), .sum([x, .n(-r2)])))
                return finish(f, Double(r1 - 1), Double(r2 + 1), piBased: false, level: level, seed: seed)
            case 1:
                let f: Expr = r.bool() ? .sin(x) : .cos(x)
                return finish(.scaled(r.int(1...3), 1, f), -pi, pi, piBased: true, level: level, seed: seed)
            default:
                return finish(.exp(.neg(.p(x, 2))), -2, 2, piBased: false, level: level, seed: seed)
            }
        case .medium:
            switch r.int(0...3) {
            case 0:
                var roots = Set<Int>()
                while roots.count < 3 { roots.insert(r.int(-3...3)) }
                let rs = roots.sorted()
                let f = Expr.mul(.mul(.sum([x, .n(-rs[0])]), .sum([x, .n(-rs[1])])), .sum([x, .n(-rs[2])]))
                return finish(f, Double(rs[0]) - 0.5, Double(rs[2]) + 0.5, piBased: false, level: level, seed: seed)
            case 1:
                return finish(.sin(.mul(2, x)), 0, pi, piBased: true, level: level, seed: seed)
            case 2:
                return finish(.mul(x, .exp(.neg(x))), 0, 4, piBased: false, level: level, seed: seed)
            default:
                return finish(.div(x, .sum([.p(x, 2), 1])), -3, 3, piBased: false, level: level, seed: seed)
            }
        case .hard:
            switch r.int(0...4) {
            case 0: return testCase(seed: seed)
            case 1: return finish(.mul(.p(.sin(x), 2), .cos(x)), -pi / 2, pi / 2, piBased: true, level: level, seed: seed)
            case 2: return finish(.mul(.p(x, 2), .exp(.neg(x))), 0, 5, piBased: false, level: level, seed: seed)
            case 3: return finish(.mul(.sin(x), .exp(.neg(.div(x, 3)))), 0, 2 * pi, piBased: true, level: level, seed: seed)
            default: return finish(.sub(.p(x, 4), .mul(2, .p(x, 2))), -1.7, 1.7, piBased: false, level: level, seed: seed)
            }
        case .bagrut:
            switch r.int(0...4) {
            case 0: return finish(.mul(x, .ln(x)), 0.1, 3, piBased: false, level: level, seed: seed)
            case 1: return finish(.div(.ln(x), x), 0.5, 7, piBased: false, level: level, seed: seed)
            case 2: return finish(.mul(.sqrt(x), .sub(x, 3)), 0, 4.5, piBased: false, level: level, seed: seed)
            case 3: return finish(.div(.exp(x), .sum([.p(x, 2), 1])), -3, 2, piBased: false, level: level, seed: seed)
            default:
                let k = r.int(1...3)
                return finish(.sub(.p(x, 3), .mul(.n(3 * k * k), x)), -2.2 * Double(k), 2.2 * Double(k), piBased: false, level: level, seed: seed)
            }
        }
    }

    static func finish(_ f: Expr, _ a: Double, _ b: Double, piBased: Bool, level: Level, seed: UInt64) -> SketchProblem? {
        let xs = (0...200).map { a + (b - a) * Double($0) / 200 }
        let ys = xs.map { f.evaluate(at: $0) }
        guard ys.allSatisfy({ $0.isFinite }) else { return nil }
        var lo = ys.min()!, hi = ys.max()!
        let range = Swift.max(hi - lo, 1e-6)
        // Show the x-axis when it's in (or close to) the picture.
        if lo > 0 && lo < 0.4 * range { lo = 0 }
        if hi < 0 && -hi < 0.4 * range { hi = 0 }
        let margin = 0.15 * (hi - lo)
        return SketchProblem(function: f, xMin: a, xMax: b, yMin: lo - margin, yMax: hi + margin,
                             piBased: piBased, level: level, seed: seed)
    }

    static func valid(_ p: SketchProblem) -> Bool {
        p.yMax > p.yMin && p.xMax > p.xMin
    }
}
