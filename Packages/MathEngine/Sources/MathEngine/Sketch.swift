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

// MARK: - Modes

/// How a sketch is judged.
public enum SketchMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Pen-and-paper precise: positions *and* values of peaks, dips, zeros and ends.
    case precision
    /// Like Precision, but more forgiving.
    case standard
    /// Only proportions matter: your y-scale can be anything, but the graph's
    /// heights relative to each other (and the x-axis) must be right.
    case proportions
    /// The rough structure you'd picture in your head: rises, falls, peaks
    /// and dips in about the right places. No values at all.
    case shape

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .precision: "Precision"
        case .standard: "Standard"
        case .proportions: "Proportions"
        case .shape: "Shape only"
        }
    }

    public var summary: String {
        switch self {
        case .precision: "Like pen and paper: peaks, dips, zeros and end values must be close to exact."
        case .standard: "Same checks as Precision, with more room for error."
        case .proportions: "Any vertical scale. Heights must be right relative to each other and to the x-axis."
        case .shape: "Only the rough structure: where it rises, falls and turns."
        }
    }

    /// Whether the canvas shows numbers on the y-axis.
    public var showsYScale: Bool { self == .precision || self == .standard }

    public var tolerance: SketchTolerance {
        switch self {
        case .precision: .precision
        case .standard: .standard
        case .proportions: .proportions
        case .shape: .shape
        }
    }
}

// MARK: - Tunable tolerances

/// The "close enough" thresholds. Errors are measured relative to the
/// function's range on the interval (max − min), positions relative to the
/// interval width.
public struct SketchTolerance: Hashable, Sendable {
    public enum Normalization: String, Hashable, Sendable {
        case none     // compare actual y values
        case scale    // first stretch the sketch vertically to fit best (proportions)
        case minMax   // compare only shapes, each squeezed to 0…1
    }

    /// Number of x columns the drawing is sampled at.
    public var columns = 80
    /// Number of x strips judged separately.
    public var segments = 8
    /// Fraction of the interval that must be drawn.
    public var minCoverage = 0.72
    /// Allowed mean |error| in a strip.
    public var segmentError = 0.28
    /// Allowed error at each end of the interval.
    public var endpointError = 0.32
    /// Allowed |y| where the graph should touch/cross zero.
    public var zeroError = 0.2
    /// How far a peak/dip may be from its true x position.
    public var extremumShift = 0.12
    /// A peak or dip only counts if it's at least this tall.
    public var prominence = 0.15
    /// A rise/fall only counts if the true graph changes at least this much
    /// across a strip; the sketch must then go the same way.
    public var trendThreshold = 0.25
    /// If set, the height of every peak/dip must be within this error.
    public var extremeValueError: Double? = nil
    public var normalization: Normalization = .none
    public var checkValues = true
    public var checkZeros = true
    public var checkEndpoints = true
    /// If set: at most this many extra bumps the true graph doesn't have.
    public var maxExtraExtrema: Int? = nil

    public init() {}

    public static let precision: SketchTolerance = {
        var t = SketchTolerance()
        t.minCoverage = 0.9; t.segmentError = 0.12; t.endpointError = 0.1; t.zeroError = 0.07
        t.extremumShift = 0.05; t.prominence = 0.1; t.trendThreshold = 0.15; t.extremeValueError = 0.08
        return t
    }()

    public static let standard: SketchTolerance = {
        var t = SketchTolerance()
        t.minCoverage = 0.8; t.segmentError = 0.22; t.endpointError = 0.22; t.zeroError = 0.14
        t.extremumShift = 0.09; t.prominence = 0.12; t.trendThreshold = 0.2; t.extremeValueError = 0.2
        return t
    }()

    public static let proportions: SketchTolerance = {
        var t = SketchTolerance()
        t.normalization = .scale
        t.minCoverage = 0.72; t.segmentError = 0.28; t.endpointError = 0.32; t.zeroError = 0.2
        t.extremumShift = 0.12; t.trendThreshold = 0.25; t.extremeValueError = 0.28
        return t
    }()

    public static let shape: SketchTolerance = {
        var t = SketchTolerance()
        t.normalization = .minMax
        t.minCoverage = 0.6; t.extremumShift = 0.2; t.trendThreshold = 0.3; t.prominence = 0.15
        t.checkValues = false; t.checkZeros = false; t.checkEndpoints = false; t.maxExtraExtrema = 1
        return t
    }()
}

// MARK: - Result

/// One thing to fix, with the x-range it applies to. Regions are numbered in
/// the app, and each hint says what to do in that band.
public struct SketchRegion: Hashable, Sendable {
    public enum Issue: String, Sendable {
        case tooHigh, tooLow          // value clearly off: bring it down / up
        case shouldRise, shouldFall   // going the wrong way
        case missingFeature           // a peak, dip or zero is missing or misplaced
        case notDrawn                 // nothing drawn here
    }
    public var lo: Double
    public var hi: Double
    public var issue: Issue
    public var hint: String
}

public struct SketchResult: Sendable {
    public var passed: Bool
    /// x-ranges to highlight, most important first (at most 4). The true
    /// curve is never revealed.
    public var regions: [SketchRegion]
    public var hints: [String] { regions.map(\.hint) }
    public var coverage: Double
}

// MARK: - Checker

public enum SketchChecker {
    static let maxRegions = 4

    public static func check(_ strokes: [SketchStroke], for problem: SketchProblem,
                             mode: SketchMode) -> SketchResult {
        check(strokes, for: problem, tolerance: mode.tolerance)
    }

    public static func check(_ strokes: [SketchStroke], for problem: SketchProblem,
                             tolerance t: SketchTolerance) -> SketchResult {
        let a = problem.xMin, b = problem.xMax, width = b - a
        let n = t.columns
        let half = width / Double(2 * n)
        let xs = (0..<n).map { a + width * (Double($0) + 0.5) / Double(n) }
        let rawTruth = xs.map { problem.value(at: $0) }
        let fMax = rawTruth.max() ?? 1, fMin = rawTruth.min() ?? 0
        let rawRange = Swift.max(fMax - fMin, 1e-9)
        let absolute = t.normalization == .none
        func lbl(_ x: Double) -> String { problem.xLabel(x) }
        func whole(_ hint: String, _ issue: SketchRegion.Issue = .missingFeature) -> SketchResult {
            SketchResult(passed: false, regions: [SketchRegion(lo: a, hi: b, issue: issue, hint: hint)], coverage: 1)
        }

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
                    let lo = xs[s] - half, hi = xs[i - 1] + half
                    regions.append(SketchRegion(lo: lo, hi: hi, issue: .notDrawn,
                                                hint: "Nothing drawn from x = \(lbl(lo)) to x = \(lbl(hi)) — draw across the whole interval."))
                    start = nil
                }
            }
            return SketchResult(passed: false, regions: Array(regions.prefix(maxRegions)), coverage: coverage)
        }
        var user = smoothed(fillGaps(sampled), radius: 2)
        var truth = rawTruth
        var range = rawRange

        // 2. Normalise for the relative modes.
        switch t.normalization {
        case .none:
            break
        case .scale:
            // Best vertical stretch: user ≈ α·truth (keeps y = 0 where it is).
            let num = zip(user, truth).reduce(0) { $0 + $1.0 * $1.1 }
            let den = truth.reduce(0) { $0 + $1 * $1 }
            guard den > 1e-12 else { break }
            let alpha = num / den
            let userRange = (user.max() ?? 0) - (user.min() ?? 0)
            guard alpha > 0.05, userRange > 1e-9 else {
                return whole("The overall shape is upside down or flat — compare with where the graph is above and below the x-axis.")
            }
            user = user.map { $0 / alpha }
        case .minMax:
            let uMin = user.min() ?? 0, uMax = user.max() ?? 0
            guard uMax - uMin > 1e-9 else { return whole("Your sketch is flat — show where the graph rises and falls.") }
            user = user.map { ($0 - uMin) / (uMax - uMin) }
            truth = truth.map { ($0 - fMin) / rawRange }
            range = 1
        }

        var features: [SketchRegion] = []   // peaks, dips, zeros
        var trends: [SketchRegion] = []     // rising vs falling
        var values: [SketchRegion] = []     // clearly too high / too low
        let shift = t.extremumShift * width

        // 3. Peaks and dips: present, at about the right place (and height).
        let trueExtrema = extrema(xs: xs, ys: truth, range: range, minProminence: t.prominence)
        for e in trueExtrema {
            let window = xs.indices.filter { Swift.abs(xs[$0] - e.x) <= 2 * shift }
            guard window.count >= 5 else { continue }
            let tv = window.map { truth[$0] }, uv = window.map { user[$0] }
            func drop(_ v: [Double], _ isMax: Bool) -> Double {
                let extreme = isMax ? v.max()! : v.min()!
                return isMax ? Swift.min(extreme - v.first!, extreme - v.last!)
                             : Swift.min(v.first! - extreme, v.last! - extreme)
            }
            let trueDrop = drop(tv, e.isMax)
            let nearEnd = e.x - a < 2 * shift || b - e.x < 2 * shift
            guard trueDrop > 0.05 * range || nearEnd else { continue }
            let userDrop = drop(uv, e.isMax)
            let extreme = e.isMax ? uv.max()! : uv.min()!
            let cutoff = 0.5 * Swift.max(userDrop, 1e-12)
            var wSum = 0.0, xSum = 0.0
            for (k, i) in window.enumerated() {
                let w = Swift.max(0, cutoff - Swift.abs(uv[k] - extreme))
                wSum += w; xSum += w * xs[i]
            }
            let centre = wSum > 0 ? xSum / wSum : xs[window[uv.firstIndex(of: extreme)!]]
            let shapeOK = nearEnd || userDrop >= 0.25 * trueDrop
            let name = e.isMax ? "peak" : "dip"
            if !shapeOK {
                features.append(SketchRegion(lo: e.x - shift, hi: e.x + shift, issue: .missingFeature,
                                             hint: "There should be a \(name) near x = \(lbl(e.x))."))
            } else if Swift.abs(centre - e.x) > shift {
                let side = centre < e.x ? "further right" : "further left"
                features.append(SketchRegion(lo: e.x - shift, hi: e.x + shift, issue: .missingFeature,
                                             hint: "Your \(name) is in the wrong place — move it \(side), to about x = \(lbl(e.x))."))
            } else if let maxErr = t.extremeValueError {
                let u = interpolate(user, xs: xs, at: e.x)
                if Swift.abs(u - e.y) / range > maxErr {
                    let high = u > e.y
                    let hint = absolute
                        ? "The \(name) near x = \(lbl(e.x)) should be at y ≈ \(SketchFormat.number(problem.value(at: e.x))) (yours is too \(high ? "high" : "low"))."
                        : "The \(name) near x = \(lbl(e.x)) is too \(high ? "high" : "low") compared with the rest of your graph."
                    features.append(SketchRegion(lo: e.x - shift, hi: e.x + shift, issue: high ? .tooHigh : .tooLow, hint: hint))
                }
            }
        }

        // Shape mode: no big extra bumps the graph doesn't have.
        if let extra = t.maxExtraExtrema {
            let userExtrema = extrema(xs: xs, ys: smoothed(user, radius: 3), range: range, minProminence: 0.2)
            let unmatched = userExtrema.filter { u in !trueExtrema.contains { $0.isMax == u.isMax && Swift.abs($0.x - u.x) <= 2 * shift } }
            if unmatched.count > extra, let first = unmatched.first {
                features.append(SketchRegion(lo: first.x - shift, hi: first.x + shift, issue: .missingFeature,
                                             hint: "Your sketch has an extra \(first.isMax ? "peak" : "dip") near x = \(lbl(first.x)) that the graph doesn't have."))
            }
        }

        // 4. Zeros: where the graph crosses or touches the x-axis.
        if t.checkZeros {
            for x0 in zeros(xs: xs, ys: rawTruth, range: rawRange) {
                if features.contains(where: { x0 >= $0.lo && x0 <= $0.hi }) { continue }
                let u0 = interpolate(user, xs: xs, at: x0)
                if Swift.abs(u0) / range > t.zeroError {
                    features.append(SketchRegion(lo: x0 - shift * 0.7, hi: x0 + shift * 0.7, issue: .missingFeature,
                                                 hint: "The graph should reach y = 0 at x = \(lbl(x0)) (yours is \(u0 > 0 ? "above" : "below") it)."))
                }
            }
        }

        // 5. Strip by strip: going the right way, and roughly the right height.
        let perSegment = Swift.max(1, n / t.segments)
        var s0 = 0
        while s0 < n {
            let s1 = Swift.min(n, s0 + perSegment) - 1
            let lo = xs[s0] - half, hi = xs[s1] + half
            defer { s0 = s1 + 1 }
            if features.contains(where: { $0.lo < hi && $0.hi > lo }) { continue }
            let trueChange = truth[s1] - truth[s0]
            let userChange = user[s1] - user[s0]
            if Swift.abs(trueChange) >= t.trendThreshold * range && userChange * trueChange <= 0.15 * trueChange * trueChange {
                let rise = trueChange > 0
                trends.append(SketchRegion(lo: lo, hi: hi, issue: rise ? .shouldRise : .shouldFall,
                                           hint: "The graph should go \(rise ? "up" : "down") from x = \(lbl(lo)) to x = \(lbl(hi))."))
                continue
            }
            guard t.checkValues else { continue }
            var absSum = 0.0, signedSum = 0.0
            for i in s0...s1 {
                absSum += Swift.abs(user[i] - truth[i])
                signedSum += user[i] - truth[i]
            }
            let count = Double(s1 - s0 + 1)
            if absSum / count / range > t.segmentError {
                let high = signedSum > 0
                values.append(SketchRegion(lo: lo, hi: hi, issue: high ? .tooHigh : .tooLow,
                                           hint: high ? "Too high from x = \(lbl(lo)) to x = \(lbl(hi)) — bring it down."
                                                      : "Too low from x = \(lbl(lo)) to x = \(lbl(hi)) — bring it up."))
            }
        }

        // 6. End points.
        if t.checkEndpoints {
            let endWidth = width / Double(t.segments) / 2
            for (i, isLeft) in [(0, true), (n - 1, false)] {
                let x = isLeft ? a : b
                let lo = isLeft ? a : b - endWidth, hi = isLeft ? a + endWidth : b
                let covered = (features + trends + values).contains { $0.lo < hi && $0.hi > lo }
                if !covered, Swift.abs(user[i] - truth[i]) / range > t.endpointError {
                    let high = user[i] > truth[i]
                    let hint = absolute
                        ? "At x = \(lbl(x)) the graph should \(isLeft ? "start" : "end") near y = \(SketchFormat.number(problem.value(at: x)))."
                        : "At x = \(lbl(x)) the graph should \(isLeft ? "start" : "end") \(high ? "lower" : "higher")."
                    values.append(SketchRegion(lo: lo, hi: hi, issue: high ? .tooHigh : .tooLow, hint: hint))
                }
            }
        }

        let all = mergeAdjacent(features, label: lbl) + mergeAdjacent(trends, label: lbl) + mergeAdjacent(values, label: lbl)
        let shown = Array(all.prefix(maxRegions)).sorted { $0.lo < $1.lo }
        return SketchResult(passed: all.isEmpty, regions: shown, coverage: coverage)
    }

    /// Joins neighbouring strips with the same issue into one band and
    /// rewrites its hint for the combined x-range.
    static func mergeAdjacent(_ regions: [SketchRegion], label: (Double) -> String) -> [SketchRegion] {
        let sorted = regions.sorted { $0.lo < $1.lo }
        var out: [SketchRegion] = []
        for r in sorted {
            if var last = out.last, r.issue == last.issue, r.issue != .missingFeature,
               r.lo <= last.hi + 1e-9 {
                last.hi = Swift.max(last.hi, r.hi)
                let range = "from x = \(label(last.lo)) to x = \(label(last.hi))"
                switch last.issue {
                case .tooHigh: last.hint = "Too high \(range) — bring it down."
                case .tooLow: last.hint = "Too low \(range) — bring it up."
                case .shouldRise: last.hint = "The graph should go up \(range)."
                case .shouldFall: last.hint = "The graph should go down \(range)."
                case .notDrawn: last.hint = "Nothing drawn \(range)."
                case .missingFeature: break
                }
                out[out.count - 1] = last
            } else {
                out.append(r)
            }
        }
        return out
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
}

// MARK: - Eraser

/// Removes only the part of the drawing under the eraser, splitting strokes
/// where needed (so one long stroke isn't deleted all at once).
public enum SketchEraser {
    /// `rx`, `ry`: eraser radius in x- and y-units (an ellipse in graph space
    /// is a circle on screen).
    public static func erase(_ strokes: [SketchStroke], around c: SketchPoint, rx: Double, ry: Double) -> [SketchStroke] {
        func inside(_ p: SketchPoint) -> Bool {
            let dx = (p.x - c.x) / rx, dy = (p.y - c.y) / ry
            return dx * dx + dy * dy <= 1
        }
        var out: [SketchStroke] = []
        for stroke in strokes {
            // Densify so a long straight segment can be cut in the middle.
            var dense: SketchStroke = []
            for (p, q) in zip(stroke, stroke.dropFirst()) {
                dense.append(p)
                let steps = Int((Swift.max(Swift.abs(q.x - p.x) / rx, Swift.abs(q.y - p.y) / ry) * 3).rounded(.up))
                if steps > 1 {
                    for k in 1..<steps {
                        let t = Double(k) / Double(steps)
                        dense.append(SketchPoint(x: p.x + t * (q.x - p.x), y: p.y + t * (q.y - p.y)))
                    }
                }
            }
            if let last = stroke.last { dense.append(last) }
            var current: SketchStroke = []
            for p in dense {
                if inside(p) {
                    if !current.isEmpty { out.append(current); current = [] }
                } else {
                    current.append(p)
                }
            }
            if !current.isEmpty { out.append(current) }
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

// MARK: - "Change": draw a related graph

/// How the graph to draw, g, is made from the given graph f.
public enum GraphTransform: Codable, Hashable, Sendable {
    case shift(Int)          // f(x) + c
    case negate              // −f(x)
    case scale(Int, Int)     // (p/q)·f(x)
    case negateShift(Int)    // −f(x) + c
    case absolute            // |f(x)|
    case mirror              // f(−x)
    case reciprocal          // 1/f(x)
    case square              // f(x)²
    case reciprocalSquare    // 1/f(x)²
    case squareRoot          // √f(x)
    case derivative          // f′(x)

    public func apply(_ f: Expr) -> Expr {
        switch self {
        case .shift(let c): return .sum([f, .n(c)])
        case .negate: return .neg(f)
        case .scale(let p, let q): return .scaled(p, q, f)
        case .negateShift(let c): return .sum([.neg(f), .n(c)])
        case .absolute: return .abs(f)
        case .mirror: return f.substitutingX(with: .neg(.x))
        case .reciprocal: return .div(1, f)
        case .square: return .p(f, 2)
        case .reciprocalSquare: return .div(1, .p(f, 2))
        case .squareRoot: return .sqrt(f)
        case .derivative: return f.derivative()
        }
    }

    /// How the task is written, e.g. "g(x) = 1 / f(x)²".
    public var formula: String {
        func signed(_ c: Int) -> String { c >= 0 ? "+ \(c)" : "− \(-c)" }
        switch self {
        case .shift(let c): return "g(x) = f(x) \(signed(c))"
        case .negate: return "g(x) = −f(x)"
        case .scale(let p, let q): return q == 1 ? "g(x) = \(p)·f(x)" : "g(x) = (\(p)/\(q))·f(x)"
        case .negateShift(let c): return "g(x) = −f(x) \(signed(c))"
        case .absolute: return "g(x) = |f(x)|"
        case .mirror: return "g(x) = f(−x)"
        case .reciprocal: return "g(x) = 1 / f(x)"
        case .square: return "g(x) = f(x)²"
        case .reciprocalSquare: return "g(x) = 1 / f(x)²"
        case .squareRoot: return "g(x) = √f(x)"
        case .derivative: return "g(x) = f′(x)  (the derivative)"
        }
    }
}

/// Given f (as a graph and/or formula), draw g = transform(f).
public struct ChangeProblem: Codable, Hashable, Sendable {
    /// The given graph f on the interval.
    public var base: SketchProblem
    public var transform: GraphTransform
    /// The graph to draw, g. Its y-range also covers f so both fit one canvas.
    public var target: SketchProblem
    public var level: Level
    public var seed: UInt64

    public var signature: String { "change:\(base.function.description):\(transform.formula)" }
}

public extension Expr {
    /// Replaces x by another expression, e.g. x → −x.
    func substitutingX(with r: Expr) -> Expr {
        switch self {
        case .x: return r
        case .num, .pi, .e, .constC: return self
        case .neg(let a): return .neg(a.substitutingX(with: r))
        case .add(let a, let b): return .add(a.substitutingX(with: r), b.substitutingX(with: r))
        case .sub(let a, let b): return .sub(a.substitutingX(with: r), b.substitutingX(with: r))
        case .mul(let a, let b): return .mul(a.substitutingX(with: r), b.substitutingX(with: r))
        case .div(let a, let b): return .div(a.substitutingX(with: r), b.substitutingX(with: r))
        case .pow(let a, let b): return .pow(a.substitutingX(with: r), b.substitutingX(with: r))
        case .fn(let f, let a): return .fn(f, a.substitutingX(with: r))
        }
    }
}

public enum ChangeFactory {
    public static func make(level: Level, seed: UInt64, avoiding: Set<String> = []) -> ChangeProblem {
        var s = seed
        for _ in 0..<80 {
            var rng = SeededRandom(seed: s)
            if let p = candidate(level: level, rng: &rng, seed: s), !avoiding.contains(p.signature) {
                return p
            }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        // Always-valid fallback: 1/f² for f = x² + 1.
        let base = SketchFactory.finish(.sum([.p(.x, 2), 1]), -2, 2, piBased: false, level: level, seed: seed)!
        return build(base: base, transform: .reciprocalSquare, level: level, seed: seed)!
    }

    /// Graphs that stay well away from zero (safe for 1/f, 1/f², √f).
    static func positiveBase(_ r: inout SeededRandom, level: Level, seed: UInt64) -> SketchProblem? {
        let x = Expr.x, pi = Double.pi
        switch r.int(0...5) {
        case 0: return SketchFactory.finish(.sum([.p(x, 2), .n(r.int(1...3))]), -2, 2, piBased: false, level: level, seed: seed)
        case 1: return SketchFactory.finish(.sum([.n(2), .sin(x)]), -pi, pi, piBased: true, level: level, seed: seed)
        case 2: return SketchFactory.finish(.sum([.exp(.neg(.p(x, 2))), .q(1, 2)]), -2, 2, piBased: false, level: level, seed: seed)
        case 3: return SketchFactory.finish(.sum([.p(.sub(x, 1), 2), 1]), -1, 3, piBased: false, level: level, seed: seed)
        case 4: return SketchFactory.finish(.sum([.n(3), .cos(.mul(2, x))]), -pi, pi, piBased: true, level: level, seed: seed)
        default: return SketchFactory.finish(.div(.sum([.p(x, 2), 4]), 4), -3, 3, piBased: false, level: level, seed: seed)
        }
    }

    static func candidate(level: Level, rng r: inout SeededRandom, seed: UInt64) -> ChangeProblem? {
        let transform: GraphTransform
        let c3 = r.nonZero(-3...3), c2 = r.nonZero(-2...2)
        switch level {
        case .easy:
            transform = r.pick([.shift(c3), .negate, .scale(2, 1), .scale(1, 2)])
        case .medium:
            transform = r.pick([.absolute, .mirror, .negateShift(c2), .scale(-2, 1), .square])
        case .hard:
            transform = r.pick([.reciprocal, .square, .derivative, .absolute, .squareRoot])
        case .bagrut:
            transform = r.pick([.reciprocalSquare, .derivative, .reciprocal, .squareRoot])
        }
        let needsPositive: Bool
        switch transform {
        case .reciprocal, .reciprocalSquare, .squareRoot: needsPositive = true
        default: needsPositive = false
        }
        let baseLevel: Level = level == .bagrut ? .medium : (level == .easy ? .easy : .medium)
        let base: SketchProblem?
        if needsPositive || (level != .easy && r.int(0...2) == 0) {
            base = positiveBase(&r, level: level, seed: seed)
        } else {
            base = SketchFactory.candidate(level: baseLevel, rng: &r, seed: seed)
        }
        guard let base else { return nil }
        // |f| only makes sense if f goes negative; f(−x) needs a symmetric interval and a non-even f.
        if case .absolute = transform {
            guard (0...200).contains(where: { base.value(at: base.xMin + (base.xMax - base.xMin) * Double($0) / 200) < -0.05 * (base.yMax - base.yMin) }) else { return nil }
        }
        if case .mirror = transform {
            guard Swift.abs(base.xMin + base.xMax) < 1e-9 else { return nil }
        }
        return build(base: base, transform: transform, level: level, seed: seed)
    }

    static func build(base: SketchProblem, transform: GraphTransform, level: Level, seed: UInt64) -> ChangeProblem? {
        let g = transform.apply(base.function)
        guard var target = SketchFactory.finish(g, base.xMin, base.xMax, piBased: base.piBased, level: level, seed: seed) else { return nil }
        // Reject transforms that leave the graph unchanged (e.g. f(−x) for an even f).
        let xs = (0...60).map { base.xMin + (base.xMax - base.xMin) * Double($0) / 60 }
        let gRange = target.yMax - target.yMin
        guard xs.contains(where: { Swift.abs(g.evaluate(at: $0) - base.value(at: $0)) > 0.05 * gRange }) else { return nil }
        // Don't let one graph dwarf the other on the shared canvas.
        let fRange = base.yMax - base.yMin
        guard gRange < 12 * fRange, fRange < 12 * gRange else { return nil }
        target.yMin = Swift.min(target.yMin, base.yMin)
        target.yMax = Swift.max(target.yMax, base.yMax)
        return ChangeProblem(base: base, transform: transform, target: target, level: level, seed: seed)
    }
}
