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
    /// Which generator family made it (lets the solution solve f′ = 0 exactly).
    public var family: SketchFamily? = nil
    /// x positions of vertical asymptotes (in or near the interval).
    public var asymptotes: [Double]? = nil
    /// Draw the whole graph (zoom and pan); xMin…yMax is then just the starting view.
    public var wholeDomain: Bool? = nil
    /// Whole-graph problems defined only for x > domainLow (ln, √).
    public var domainLow: Double? = nil
    /// Exact names for the asymptotes ("ln 4", "1/e"), same order as `asymptotes`.
    public var asymptoteLabels: [String]? = nil
    /// Single x values missing from the domain (no asymptote), e.g. 0 for 4x(ln x² − 1).
    public var holes: [Double]? = nil

    public var isWhole: Bool { wholeDomain == true }
    public var poles: [Double] { asymptotes ?? [] }

    /// The same problem seen through another window (zoomed or panned).
    public func windowed(_ v: SketchViewport) -> SketchProblem {
        var p = self
        p.xMin = v.xMin; p.xMax = v.xMax; p.yMin = v.yMin; p.yMax = v.yMax
        return p
    }

    public var viewport: SketchViewport { SketchViewport(xMin: xMin, xMax: xMax, yMin: yMin, yMax: yMax) }

    public var signature: String { "sketch:\(function.description):\(xMin):\(xMax)" }

    public func value(at x: Double) -> Double { function.evaluate(at: x) }

    /// Label for an x position, e.g. "−π/4" or "1.5".
    public func xLabel(_ x: Double) -> String { SketchFormat.x(x, piBased: piBased) }
}

/// The visible part of the plane on the canvas.
public struct SketchViewport: Codable, Hashable, Sendable {
    public var xMin: Double
    public var xMax: Double
    public var yMin: Double
    public var yMax: Double
    public init(xMin: Double, xMax: Double, yMin: Double, yMax: Double) {
        self.xMin = xMin; self.xMax = xMax; self.yMin = yMin; self.yMax = yMax
    }

    /// Zoomed by `factor` (> 1 zooms in) around a point.
    public func zoomed(_ factor: Double, around c: SketchPoint) -> SketchViewport {
        SketchViewport(xMin: c.x - (c.x - xMin) / factor, xMax: c.x + (xMax - c.x) / factor,
                       yMin: c.y - (c.y - yMin) / factor, yMax: c.y + (yMax - c.y) / factor)
    }

    public func moved(dx: Double, dy: Double) -> SketchViewport {
        SketchViewport(xMin: xMin + dx, xMax: xMax + dx, yMin: yMin + dy, yMax: yMax + dy)
    }

    public var center: SketchPoint { SketchPoint(x: (xMin + xMax) / 2, y: (yMin + yMax) / 2) }
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
        case .shape: "Judged by eye: does your drawing look like the graph? Scale and exact values don't matter."
        }
    }

    /// Whether the canvas shows numbers on the y-axis.
    /// Proportions accepts any vertical scale, so numbers would mislead; Shape keeps them (heights still matter for the look).
    public var showsYScale: Bool { self != .proportions }

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
    /// Judge purely by eye: how close the two curves look (both squeezed
    /// into the same box), not by values or features.
    public var visual = false
    /// Visual mode: average gap between the curves (fraction of the box).
    public var visualMeanTolerance = 0.08
    /// Visual mode: a stretch where the gap is bigger than this is flagged.
    public var visualLocalTolerance = 0.2

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
        t.visual = true
        t.minCoverage = 0.6
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

    /// Checks a drawing. Every correction it reports can really be fixed
    /// in its zone: redrawing each zone along its guide (the "eye" curve)
    /// is simulated first, and zones that wouldn't be enough are widened —
    /// up to one band over the whole stretch that's off.
    public static func check(_ strokes: [SketchStroke], for problem: SketchProblem,
                             tolerance t: SketchTolerance) -> SketchResult {
        var r = consolidate(rawCheck(strokes, for: problem, tolerance: t), problem)
        guard !r.passed, !r.regions.contains(where: { $0.issue == .notDrawn }) else { return r }
        let w = problem.xMax - problem.xMin
        for _ in 0..<4 {
            let after = rawCheck(fixedAlongGuides(strokes, problem, r.regions, t), for: problem, tolerance: t)
            if after.passed { return r }
            // Widen zones the fix wouldn't cure; add the new trouble spots.
            var regions = r.regions
            for bad in after.regions {
                if let i = regions.firstIndex(where: { $0.lo < bad.hi + 0.02 * w && $0.hi > bad.lo - 0.02 * w }) {
                    regions[i].lo = Swift.max(problem.xMin, Swift.min(regions[i].lo, bad.lo) - 0.12 * w)
                    regions[i].hi = Swift.min(problem.xMax, Swift.max(regions[i].hi, bad.hi) + 0.12 * w)
                    regions[i].issue = .missingFeature
                    regions[i].hint = "The shape is off from x = \(problem.xLabel(regions[i].lo)) to x = \(problem.xLabel(regions[i].hi)) — redraw this whole stretch (the eye shows the right shape)."
                } else {
                    regions.append(bad)
                }
            }
            r.regions = consolidate(SketchResult(passed: false, regions: regions, coverage: r.coverage), problem).regions
        }
        if rawCheck(fixedAlongGuides(strokes, problem, r.regions, t), for: problem, tolerance: t).passed { return r }
        // Piece by piece doesn't work: one band over everything that's off,
        // or over the whole graph if even that isn't enough.
        var lo = r.regions.map(\.lo).min() ?? problem.xMin, hi = r.regions.map(\.hi).max() ?? problem.xMax
        let band = [SketchRegion(lo: lo, hi: hi, issue: .missingFeature, hint: "")]
        if !rawCheck(fixedAlongGuides(strokes, problem, band, t), for: problem, tolerance: t).passed {
            lo = problem.xMin; hi = problem.xMax
        }
        r.regions = [SketchRegion(lo: lo, hi: hi, issue: .missingFeature,
                                  hint: "The general shape from x = \(problem.xLabel(lo)) to x = \(problem.xLabel(hi)) is off — redraw it (the eye shows the right shape).")]
        return r
    }

    /// The drawing with every zone erased and redrawn along its guide.
    static func fixedAlongGuides(_ strokes: [SketchStroke], _ p: SketchProblem, _ regions: [SketchRegion],
                                 _ t: SketchTolerance) -> [SketchStroke] {
        let zones = regions.map { $0.lo...$0.hi }
        var fixed = strokes
        for z in zones { fixed = SketchEraser.erase(fixed, xFrom: z.lowerBound, to: z.upperBound) }
        for z in zones {
            let g = SketchGuide.continuation(of: strokes, for: p, in: z, flagged: zones, fit: t.normalization)
            if !g.isEmpty { fixed.append(g) }
        }
        return fixed
    }

    /// At most `maxRegions` corrections: the closest ones are merged rather
    /// than dropped, so fixing every shown zone fixes everything.
    static func consolidate(_ r: SketchResult, _ p: SketchProblem) -> SketchResult {
        var regions = r.regions.sorted { $0.lo < $1.lo }
        // Overlaps first.
        var merged: [SketchRegion] = []
        for reg in regions {
            if var last = merged.last, reg.lo <= last.hi {
                last.hi = Swift.max(last.hi, reg.hi)
                if reg.issue != last.issue { last.issue = .missingFeature }
                if reg.hint != last.hint { last.hint += " " + reg.hint }
                merged[merged.count - 1] = last
            } else {
                merged.append(reg)
            }
        }
        regions = merged
        while regions.count > maxRegions {
            var best = 0
            for i in 0..<(regions.count - 1) where regions[i + 1].lo - regions[i].hi < regions[best + 1].lo - regions[best].hi { best = i }
            let a = regions[best], b = regions[best + 1]
            regions[best] = SketchRegion(lo: a.lo, hi: b.hi, issue: a.issue == b.issue ? a.issue : .missingFeature,
                                         hint: "Several things are off from x = \(p.xLabel(a.lo)) to x = \(p.xLabel(b.hi)) — redraw this part (the eye shows the right shape).")
            regions.remove(at: best + 1)
        }
        var out = r
        out.regions = regions
        return out
    }

    static func rawCheck(_ strokes: [SketchStroke], for problem: SketchProblem,
                         tolerance t: SketchTolerance) -> SketchResult {
        let a = problem.xMin, b = problem.xMax, width = b - a
        let n = t.columns
        let half = width / Double(2 * n)
        let xs = (0..<n).map { a + width * (Double($0) + 0.5) / Double(n) }
        let exact = xs.map { problem.value(at: $0) }
        // Columns where the graph is on screen. Elsewhere (it runs off the
        // top/bottom near an asymptote, or isn't defined) nothing is
        // required; both curves are bridged straight across.
        let viewPad = 0.02 * (problem.yMax - problem.yMin)
        let visible = exact.map { $0.isFinite && $0 >= problem.yMin - viewPad && $0 <= problem.yMax + viewPad }
        guard visible.contains(true) else {
            return SketchResult(passed: false, regions: [SketchRegion(lo: a, hi: b, issue: .notDrawn,
                                                                     hint: "None of the graph is on screen here — move or zoom the view.")], coverage: 0)
        }
        let anyOff = visible.contains(false)
        let rawTruth = anyOff ? fillGaps(exact.indices.map { visible[$0] ? exact[$0] : nil }) : exact
        func nearOff(_ i: Int, _ k: Int) -> Bool {
            anyOff && (Swift.max(0, i - k)...Swift.min(n - 1, i + k)).contains { !visible[$0] }
        }
        func column(_ x: Double) -> Int { Swift.max(0, Swift.min(n - 1, Int(((x - a) / width * Double(n)).rounded(.down)))) }
        // Visible stretches between off-screen parts, numbered (−1 = off screen).
        var run = [Int](repeating: -1, count: n)
        var runCount = 0
        for i in 0..<n where visible[i] {
            if i == 0 || !visible[i - 1] { runCount += 1 }
            run[i] = runCount
        }
        let fMax = rawTruth.max() ?? 1, fMin = rawTruth.min() ?? 0
        let rawRange = Swift.max(fMax - fMin, 1e-9)
        let absolute = t.normalization == .none
        func lbl(_ x: Double) -> String { problem.xLabel(x) }
        func whole(_ hint: String, _ issue: SketchRegion.Issue = .missingFeature) -> SketchResult {
            SketchResult(passed: false, regions: [SketchRegion(lo: a, hi: b, issue: issue, hint: hint)], coverage: 1)
        }

        // 1. The drawing as one y value per column (only where the graph is on screen).
        let drawn = sampleDrawing(strokes, xs: xs, columnWidth: width / Double(n))
        let sampled = anyOff ? drawn.indices.map { visible[$0] ? drawn[$0] : nil } : drawn
        let filled = sampled.compactMap { $0 }.count
        let coverage = Double(filled) / Double(visible.filter { $0 }.count)

        if coverage < t.minCoverage {
            var regions: [SketchRegion] = []
            var start: Int?
            for i in 0...n {
                let missing = i < n && visible[i] && sampled[i] == nil
                if missing, start == nil { start = i }
                if !missing, let s = start {
                    let lo = xs[s] - half, hi = xs[i - 1] + half
                    regions.append(SketchRegion(lo: lo, hi: hi, issue: .notDrawn,
                                                hint: "Nothing drawn from x = \(lbl(lo)) to x = \(lbl(hi)) — draw across the whole interval."))
                    start = nil
                }
            }
            return SketchResult(passed: false, regions: regions, coverage: coverage)
        }
        guard filled >= 2 else {
            return SketchResult(passed: false, regions: [SketchRegion(lo: a, hi: b, issue: .notDrawn, hint: "Draw the graph across the box.")], coverage: coverage)
        }
        // The drawing is lightly smoothed (finger jitter); the true graph gets
        // the same smoothing so a perfect sketch compares as perfect.
        var user = smoothed(fillGaps(sampled), radius: 2)
        var truth = smoothed(rawTruth, radius: 2)
        // Errors are measured against at least half the box, so a graph that
        // only fills a small part of it (Change: f and g share the box) doesn't
        // turn normal hand wobble into "wrong".
        let boxFloor = 0.5 * (problem.yMax - problem.yMin)
        var range = Swift.max(rawRange, boxFloor)

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
            let k = rawRange / Swift.max(rawRange, boxFloor)
            user = user.map { k * ($0 - uMin) / (uMax - uMin) }
            truth = truth.map { k * ($0 - fMin) / rawRange }
            range = 1
        }

        // Where the graph leaves the box (e.g. at a vertical asymptote), the
        // drawing must leave it the same way: up at the top, down at the bottom.
        var exits: [SketchRegion] = []
        if anyOff {
            let drawnVals = sampled.compactMap { $0 }
            let uMin = drawnVals.min() ?? 0, uMax = drawnVals.max() ?? 1
            for j in 0..<n where visible[j] {
                for k in [j - 1, j + 1] where k >= 0 && k < n && !visible[k] {
                    let off = exact[k]
                    guard !off.isNaN, sampled[j] != nil, uMax - uMin > 1e-9 else { continue }
                    let up = off > problem.yMax
                    // The last few columns before the edge count (a steep climb drawn a hair early is fine).
                    let side = k > j ? -1 : 1
                    // Only the direction matters: over the last few columns before the
                    // edge, is the line climbing (or falling) towards it?
                    let far = j + side * 4
                    guard far >= 0, far < n, visible[far], let uNear = sampled[j], let uFar = sampled[far] else { continue }
                    let climb = (uNear - uFar) / (uMax - uMin)
                    if up ? climb < 0.02 : climb > -0.02 {
                        let edge = (xs[j] + xs[k]) / 2
                        let pole = problem.poles.first { Swift.abs($0 - edge) < 0.08 * width }
                        let why = pole.map { " (vertical asymptote x = \(lbl($0)))" } ?? ""
                        exits.append(SketchRegion(lo: Swift.max(a, xs[Swift.min(j, k)] - 4 * half), hi: Swift.min(b, xs[Swift.max(j, k)] + 4 * half),
                                                  issue: up ? .tooLow : .tooHigh,
                                                  hint: "Near x = \(lbl(edge)) the graph shoots \(up ? "up out of the top" : "down out of the bottom") of the box\(why) — take your line there."))
                    }
                }
            }
        }

        if t.visual {
            var r = visualCheck(user: user, truth: truth, xs: xs, a: a, b: b, half: half, t: t, label: lbl, coverage: coverage,
                                visible: visible)
            if !exits.isEmpty { r.regions += mergeAdjacent(exits, label: lbl); r.passed = false }
            return r
        }

        var features: [SketchRegion] = []   // peaks, dips, zeros
        var trends: [SketchRegion] = []     // rising vs falling
        var values: [SketchRegion] = []     // clearly too high / too low
        let shift = t.extremumShift * width

        // 3. Peaks and dips: present, at about the right place (and height).
        // (Turns created by the straight bridge over an off-screen part don't count.)
        let trueExtrema = extrema(xs: xs, ys: truth, range: range, minProminence: t.prominence)
            .filter { !nearOff(column($0.x), 3) }
        for e in trueExtrema {
            // Search window: wide, but never reaching the neighbouring peak/dip.
            let neighbour = trueExtrema.filter { $0.x != e.x }.map { Swift.abs($0.x - e.x) }.min() ?? .infinity
            let radius = Swift.max(Swift.min(2 * shift, 0.9 * neighbour), 3 * width / Double(n))
            let home = run[column(e.x)]
            let window = xs.indices.filter { Swift.abs(xs[$0] - e.x) <= radius && run[$0] == home }
            guard window.count >= 5 else { continue }
            let tv = window.map { truth[$0] }, uv = window.map { user[$0] }
            func drop(_ v: [Double], _ isMax: Bool) -> Double {
                let extreme = isMax ? v.max()! : v.min()!
                return isMax ? Swift.min(extreme - v.first!, extreme - v.last!)
                             : Swift.min(v.first! - extreme, v.last! - extreme)
            }
            let trueDrop = drop(tv, e.isMax)
            let nearEnd = e.x - a < radius || b - e.x < radius
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
                .filter { !nearOff(column($0.x), 4) }
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
                if nearOff(column(x0), 1) { continue }
                let u0 = interpolate(user, xs: xs, at: x0)
                // Compared with the (equally smoothed) true graph, not with 0:
                // at the edge of the box smoothing shifts both the same way.
                let t0 = interpolate(truth, xs: xs, at: x0)
                // Close to the zero is enough (steep graphs: a tiny sideways shift is a big height error).
                let c0 = column(x0)
                let nearest = (Swift.max(0, c0 - 2)...Swift.min(n - 1, c0 + 2)).filter { visible[$0] }
                    .map { Swift.abs(user[$0] - t0) }.min() ?? Swift.abs(u0 - t0)
                if Swift.min(Swift.abs(u0 - t0), nearest) / range > t.zeroError {
                    features.append(SketchRegion(lo: x0 - shift * 0.7, hi: x0 + shift * 0.7, issue: .missingFeature,
                                                 hint: "The graph should reach y = 0 at x = \(lbl(x0)) (yours is \(u0 > t0 ? "above" : "below") it)."))
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
            if anyOff, (s0...s1).contains(where: { !visible[$0] }) { continue }
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
                let covered = (features + trends + values).contains { $0.lo < hi && $0.hi > lo } || !visible[i] || nearOff(i, 2)
                let near = (Swift.max(0, i - 2)...Swift.min(n - 1, i + 2)).map { Swift.abs(user[i] - truth[$0]) }.min() ?? 0
                // Steep end: allow about two columns of sideways slack.
                let j = isLeft ? Swift.min(n - 1, i + 1) : Swift.max(0, i - 1)
                let slack = 2 * Swift.abs(truth[j] - truth[i])
                if !covered, (near - slack) / range > t.endpointError {
                    let high = user[i] > truth[i]
                    let hint = absolute
                        ? "At x = \(lbl(x)) the graph should \(isLeft ? "start" : "end") near y = \(SketchFormat.number(problem.value(at: x)))."
                        : "At x = \(lbl(x)) the graph should \(isLeft ? "start" : "end") \(high ? "lower" : "higher")."
                    values.append(SketchRegion(lo: lo, hi: hi, issue: high ? .tooHigh : .tooLow, hint: hint))
                }
            }
        }

        let all = mergeAdjacent(features, label: lbl) + mergeAdjacent(exits, label: lbl)
            + mergeAdjacent(trends, label: lbl) + mergeAdjacent(values, label: lbl)
        return SketchResult(passed: all.isEmpty, regions: all.sorted { $0.lo < $1.lo }, coverage: coverage)
    }

    /// "Does it look like the graph?" Both curves live in a unit box (x and
    /// y each 0…1, x stretched by the canvas aspect). For every point of one
    /// curve we take the distance to the *nearest* point of the other, which
    /// is what the eye does: a slightly early hump still looks right, a
    /// missing or extra hump does not.
    static func visualCheck(user: [Double], truth: [Double], xs: [Double], a: Double, b: Double, half: Double,
                            t: SketchTolerance, label: (Double) -> String, coverage: Double,
                            visible: [Bool]? = nil) -> SketchResult {
        let n = xs.count
        let aspect = 1.5
        let reach = n / 4                          // only look ±25% sideways
        // Line the drawing up with the graph the way the eye does: best
        // vertical stretch + shift (least squares). Upside down can't be fixed.
        let mu = user.reduce(0, +) / Double(n), mt = truth.reduce(0, +) / Double(n)
        var cov = 0.0, varU = 0.0
        for i in 0..<n { cov += (user[i] - mu) * (truth[i] - mt); varU += (user[i] - mu) * (user[i] - mu) }
        guard varU > 1e-12, cov > 0 else {
            return SketchResult(passed: false,
                                regions: [SketchRegion(lo: a, hi: b, issue: .missingFeature,
                                                       hint: "It doesn't look like the graph — check where it goes up and where it goes down.")],
                                coverage: coverage)
        }
        let alpha = cov / varU
        let user = user.map { mt + alpha * ($0 - mu) }
        func gap(_ i: Int, from ys: [Double], to other: [Double]) -> Double {
            var best = Double.infinity
            for j in Swift.max(0, i - reach)...Swift.min(n - 1, i + reach) {
                let dx = Double(i - j) / Double(n - 1) * aspect
                let dy = ys[i] - other[j]
                best = Swift.min(best, (dx * dx + dy * dy).squareRoot())
            }
            return best
        }
        let shown = visible ?? Array(repeating: true, count: n)
        let truthGaps = (0..<n).map { shown[$0] ? gap($0, from: truth, to: user) : 0 }   // parts of the graph you missed
        let userGaps = (0..<n).map { shown[$0] ? gap($0, from: user, to: truth) : 0 }    // parts you drew that aren't there
        let mean = (truthGaps.reduce(0, +) + userGaps.reduce(0, +)) / Double(2 * Swift.max(1, shown.filter { $0 }.count))

        var regions: [SketchRegion] = []
        var start: Int?
        for i in 0...n {
            let bad = i < n && Swift.max(truthGaps[i], userGaps[i]) > t.visualLocalTolerance
            if bad, start == nil { start = i }
            if !bad, let s = start {
                if i - s >= 3 {
                    let mid = (s + i - 1) / 2
                    let high = user[mid] > truth[mid]
                    let lo = xs[s] - half, hi = xs[i - 1] + half
                    regions.append(SketchRegion(lo: lo, hi: hi, issue: high ? .tooHigh : .tooLow,
                                                hint: "From x = \(label(lo)) to x = \(label(hi)) it doesn't look like the graph — it should be \(high ? "lower" : "higher") there."))
                }
                start = nil
            }
        }
        if regions.isEmpty && mean > t.visualMeanTolerance {
            regions.append(SketchRegion(lo: a, hi: b, issue: .missingFeature,
                                        hint: "The overall shape is off — compare where it rises, falls and turns."))
        }
        return SketchResult(passed: regions.isEmpty, regions: regions.sorted { $0.lo < $1.lo }, coverage: coverage)
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
        for raw in strokes {
            let stroke = raw.filter { $0.x.isFinite && $0.y.isFinite }
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
    /// Removes everything drawn between x = lo and x = hi (one band),
    /// splitting strokes that cross it.
    public static func erase(_ strokes: [SketchStroke], xFrom lo: Double, to hi: Double) -> [SketchStroke] {
        var out: [SketchStroke] = []
        for stroke in strokes {
            var current: SketchStroke = []
            var previous: SketchPoint?
            for p in stroke {
                // Keep the cut clean: add the crossing point at the band edge.
                if let q = previous {
                    for edge in [lo, hi] where (q.x - edge) * (p.x - edge) < 0 {
                        let t = (edge - q.x) / (p.x - q.x)
                        let cut = SketchPoint(x: edge, y: q.y + t * (p.y - q.y))
                        if !(q.x >= lo && q.x <= hi) { current.append(cut) }
                    }
                }
                if p.x >= lo && p.x <= hi {
                    if !current.isEmpty { out.append(current); current = [] }
                } else {
                    if current.isEmpty, let q = previous, q.x >= lo && q.x <= hi {
                        let edge = p.x > hi ? hi : lo
                        let t = (edge - q.x) / (p.x - q.x)
                        current.append(SketchPoint(x: edge, y: q.y + t * (p.y - q.y)))
                    }
                    current.append(p)
                }
                previous = p
            }
            if !current.isEmpty { out.append(current) }
        }
        return out
    }

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
        if Swift.abs(v) < 1e-9 { return "0" }
        if Swift.abs(v - v.rounded()) < 1e-9 { return v < 0 ? "−\(Int(-v.rounded()))" : "\(Int(v.rounded()))" }
        let s = String(format: "%.2g", v)
        return s.replacingOccurrences(of: "-", with: "−")
    }
}

// MARK: - Variety

/// What recent problems looked like, so a new one doesn't look the same
/// (same family, or the same shape with different numbers).
public struct ShapeMemory: Codable, Sendable {
    public var shapes: [[Double]] = []
    public var kinds: [String] = []
    public init() {}

    public mutating func remember(shape: [Double], kind: String) {
        shapes.append(shape)
        if shapes.count > 40 { shapes.removeFirst(shapes.count - 40) }
        kinds.append(kind)
        if kinds.count > 12 { kinds.removeFirst(kinds.count - 12) }
    }

    func looksLikeRecent(_ shape: [Double]) -> Bool {
        shapes.suffix(15).contains { ShapeKey.distance($0, shape) < 0.09 }
    }

    func usedRecently(_ kind: String, depth: Int) -> Bool { kinds.suffix(depth).contains(kind) }
}

/// A graph's look: 32 heights scaled to the box (0 = bottom, 1 = top).
public enum ShapeKey {
    public static func of(_ p: SketchProblem) -> [Double] {
        (0..<32).map { i in
            let x = p.xMin + (p.xMax - p.xMin) * (Double(i) + 0.5) / 32
            let y = p.value(at: x)
            guard y.isFinite else { return -0.5 }
            return Swift.max(-0.2, Swift.min(1.2, (y - p.yMin) / Swift.max(p.yMax - p.yMin, 1e-9)))
        }
    }

    /// Mean difference, also against the mirror image and the upside-down
    /// version (those look "the same" too).
    public static func distance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 1 }
        func d(_ u: [Double]) -> Double { zip(u, b).reduce(0) { $0 + Swift.abs($1.0 - $1.1) } / Double(a.count) }
        return Swift.min(d(a), d(a.reversed()), d(a.map { 1 - $0 }), d(a.reversed().map { 1 - $0 }))
    }
}

// MARK: - Generator

/// The generator family of a sketch problem and its parameters, so the
/// worked solution can solve f′(x) = 0 and f″(x) = 0 by algebra.
public struct SketchFamily: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case quadRoots, trigSin, trigCos, bell, cubicAx, vertex, shiftSin
        case cubic3, sinCos, xExp, rational1, quartic, linExp, bump
        case sinSin, quadGauss, sin2cos, powExp, sinExpDecay, quartic3, ratQuad, xSin
        case x2Ln, lnQuad, xPlusInv, expLin, powLn, lnOverPow, sqrtLin, expOverQuad, cubicK, xGauss
        // With vertical asymptotes.
        case hyperbola, ratOblique, recipQuad, xOverQuad, tanX
        // Bagrut 5U.
        case sinSqCos, xPlusTrig, sinOverCos, twoSinSin2, expSin, lnCos, cosOverSin, sinCos2
        case expQuadE, ln2, xLn2, expOverLin, lnQuadratic, ratTwoPoles, logistic
        // From the 571/572/581/582 papers.
        case rootRatX, rootRatX2, trigFrac1, cosPlusInvSq, invCosSq, cosQuadInv, sinRatio, twoSinCos2, cos3Sin
        case expRat2, expOverAMinus, expMinusBOverSq, lnSqRatio, xOverLnA, xnThreeMinusLn, fourXLnX2, xLnPoly
        case xPlusLnQuad, lnQuadMinusX, polyOverExp
        // Easy monotone shapes.
        case expShift, lnShift, sqrtShift

        /// Not periodic, so "draw the whole graph" makes sense.
        public var allowsWholeDomain: Bool {
            switch self {
            case .trigSin, .trigCos, .shiftSin, .sinCos, .sinSin, .sin2cos, .sinExpDecay, .xSin, .tanX, .xPlusInv,
                 .sinSqCos, .xPlusTrig, .sinOverCos, .twoSinSin2, .expSin, .lnCos, .cosOverSin, .sinCos2,
                 .trigFrac1, .cosPlusInvSq, .invCosSq, .cosQuadInv, .sinRatio, .twoSinCos2, .cos3Sin, .lnShift, .sqrtShift: false
            default: true
            }
        }

        /// Whole-graph problems that only exist for x > 0.
        public var positiveDomain: Bool {
            switch self {
            case .x2Ln, .powLn, .lnOverPow, .sqrtLin, .ln2, .xLn2, .lnSqRatio, .xOverLnA, .xnThreeMinusLn, .xLnPoly: true
            default: false
            }
        }
    }
    public var kind: Kind
    public var p: [Int]
    /// Vertical factor the whole function was multiplied by.
    public var factor: Int

    public init(_ kind: Kind, _ p: [Int], factor: Int = 1) {
        self.kind = kind
        self.p = p
        self.factor = factor
    }
}

public enum SketchFactory {
    public static func make(level: Level, seed: UInt64, avoiding: Set<String> = [], wholeDomain: Bool = false,
                            memory: ShapeMemory = ShapeMemory()) -> SketchProblem {
        var s = seed
        var anyValid: SketchProblem?
        var notSeen: SketchProblem?
        for attempt in 0..<80 {
            var rng = SeededRandom(seed: s)
            for _ in 0..<12 {
                if var p = candidate(level: level, rng: &rng, seed: s), valid(p) {
                    if wholeDomain { p = whole(p) }
                    if anyValid == nil { anyValid = p }
                    guard !avoiding.contains(p.signature) else { continue }
                    if notSeen == nil { notSeen = p }
                    // A different family from the last few, and a different look.
                    let kind = p.family?.kind.rawValue ?? "other"
                    // First: new family and new look; then: at least a new family.
                    if memory.usedRecently(kind, depth: 3) && attempt < 70 { continue }
                    if memory.looksLikeRecent(ShapeKey.of(p)) && attempt < 40 { continue }
                    return p
                }
            }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        if let notSeen { return notSeen }
        // Everything was seen recently: repeat a random one rather than always the same.
        return anyValid ?? testCase(seed: seed)
    }

    /// "Draw the whole graph" version of a non-periodic problem: the interval
    /// becomes a slightly wider starting view.
    public static func whole(_ p: SketchProblem) -> SketchProblem {
        guard let fam = p.family, fam.kind.allowsWholeDomain else { return p }
        var q = p
        let w = p.xMax - p.xMin
        q.xMin = p.xMin - 0.15 * w
        q.xMax = p.xMax + 0.15 * w
        if fam.kind.positiveDomain { q.domainLow = 0; q.xMin = Swift.max(q.xMin, -0.05 * w) }
        q.wholeDomain = true
        return q
    }

    /// The reference example: sin²(x)·cos(2x) on [−π/4, π/4].
    public static func testCase(seed: UInt64 = 1) -> SketchProblem {
        finish(.mul(.p(.sin(.x), 2), .cos(.mul(2, .x))), -Double.pi / 4, Double.pi / 4, piBased: true, level: .hard, seed: seed,
               family: SketchFamily(.sin2cos, [2]))!
    }

    /// Families of functions with random parameters (coefficients, roots,
    /// frequencies, intervals), so the same graph rarely comes back.
    static func candidate(level: Level, rng r: inout SeededRandom, seed: UInt64) -> SketchProblem? {
        let x = Expr.x
        let pi = Double.pi
        func lin(_ k: Int) -> Expr { .scaled(k, 1, x) }
        // Hard levels also get a random vertical factor, so values differ too.
        let factor = (level == .hard || level == .bagrut) ? r.pick([1, 1, 2, 3, -1, -2]) : 1
        func done(_ f: Expr, _ a: Double, _ b: Double, pi isPi: Bool = false,
                  _ kind: SketchFamily.Kind, _ params: [Int]) -> SketchProblem? {
            finish(factor == 1 ? f : .scaled(factor, 1, f), a, b, piBased: isPi, level: level, seed: seed,
                   family: SketchFamily(kind, params, factor: factor))
        }
        func poled(_ f: Expr, _ a: Double, _ b: Double, _ poles: [Double], pi isPi: Bool = false,
                   _ kind: SketchFamily.Kind, _ params: [Int], labels: [String]? = nil) -> SketchProblem? {
            finishPoled(factor == 1 ? f : .scaled(factor, 1, f), a, b, poles: poles, piBased: isPi, level: level, seed: seed,
                        family: SketchFamily(kind, params, factor: factor), labels: labels)
        }
        switch level {
        case .easy:
            switch r.int(0...10) {
            case 8: // eˣ − c
                let c = r.int(1...3)
                return done(.sum([.exp(x), .n(-c)]), -3, 2, .expShift, [c])
            case 9: // ln(x + a) + k
                let a = r.int(-1...2), k = r.int(-1...1)
                return done(.sum([.ln(.sum([x, .n(a)])), .n(k)]), Double(-a) + 0.05, Double(-a) + 8, .lnShift, [a, k])
            case 10: // √(x + a) − k
                let a = r.int(-1...3), k = r.int(1...2)
                return done(.sum([.sqrt(.sum([x, .n(a)])), .n(-k)]), Double(-a), Double(-a) + 9, .sqrtShift, [a, k])
            case 0: // a(x − r1)(x − r2)
                let r1 = r.int(-4...2), r2 = r1 + r.int(1...5), a = r.pick([1, -1, 2, -2])
                let f = Expr.scaled(a, 1, .mul(.sum([x, .n(-r1)]), .sum([x, .n(-r2)])))
                return done(f, Double(r1 - r.int(1...2)), Double(r2 + r.int(1...2)), .quadRoots, [a, r1, r2])
            case 1: // k·sin(mx) or k·cos(mx)
                let k = r.int(1...4), m = r.int(1...2)
                let isSin = r.bool()
                let f: Expr = isSin ? .sin(lin(m)) : .cos(lin(m))
                let fam: SketchFamily.Kind = isSin ? .trigSin : .trigCos
                return r.bool() ? done(.scaled(k, 1, f), -pi, pi, pi: true, fam, [k, m])
                                : done(.scaled(k, 1, f), 0, 2 * pi, pi: true, fam, [k, m])
            case 2: // bell curve e^(−x²/c)
                let c = r.int(1...3)
                return done(.exp(.neg(.div(.p(x, 2), .n(c)))), -Double(c) - 1.5, Double(c) + 1.5, .bell, [c])
            case 3: // x³ − a·x
                let a = r.int(1...6)
                let w = Double(a).squareRoot() + Double(r.int(1...2)) * 0.5
                return done(.sub(.p(x, 3), .scaled(a, 1, x)), -w, w, .cubicAx, [a])
            case 4: // vertex form a(x − h)² + k
                let h = r.int(-3...3), k = r.int(-4...4), a = r.pick([1, -1])
                return done(.sum([.scaled(a, 1, .p(.sum([x, .n(-h)]), 2)), .n(k)]), Double(h - 3), Double(h + r.int(2...3)),
                            .vertex, [a, h, k])
            case 6, 7: // a/(x − p) + k: a hyperbola
                let a = r.pick([1, 2, 3, -1, -2]), p = r.int(-2...2), k = r.int(-2...2)
                return poled(.sum([.div(.n(a), .sum([x, .n(-p)])), .n(k)]), Double(p - 4), Double(p + 4), [Double(p)], .hyperbola, [a, p, k])
            default: // k + sin(x)
                let k = r.nonZero(-2...2)
                return done(.sum([.n(k), .sin(x)]), -pi, pi, pi: true, .shiftSin, [k])
            }
        case .medium:
            switch r.int(0...9) {
            case 7: // a/(x − p) + k
                let a = r.pick([1, 2, 3, -1, -2, -3]), p = r.int(-3...3), k = r.int(-3...3)
                return poled(.sum([.div(.n(a), .sum([x, .n(-p)])), .n(k)]), Double(p - 4), Double(p + 4), [Double(p)], .hyperbola, [a, p, k])
            case 8: // c/(x² − a²)
                let a = r.int(1...2), c = r.pick([1, 2, -1, 4])
                return poled(.div(.n(c), .sum([.p(x, 2), .n(-a * a)])), -Double(a) - 3, Double(a) + 3, [-Double(a), Double(a)], .recipQuad, [a, c])
            case 9: // tan x
                return poled(.tan(x), -pi, pi, [-pi / 2, pi / 2], pi: true, .tanX, [])
            case 0: // cubic with three roots
                var roots = Set<Int>()
                while roots.count < 3 { roots.insert(r.int(-4...4)) }
                let rs = roots.sorted()
                let sign = r.pick([1, -1])
                let f = Expr.scaled(sign, 1, .mul(.mul(.sum([x, .n(-rs[0])]), .sum([x, .n(-rs[1])])), .sum([x, .n(-rs[2])])))
                return done(f, Double(rs[0]) - 0.5, Double(rs[2]) + 0.5, .cubic3, [sign] + rs)
            case 1: // sin(mx) + (c/2)·cos(nx)
                let m = r.int(1...2), n = r.int(1...3), c = r.pick([1, -1])
                return done(.sum([.sin(lin(m)), .scaled(c, 2, .cos(lin(n)))]), -pi, pi, pi: true, .sinCos, [m, n, c])
            case 2: // x·e^(−x/c)
                let c = r.int(1...3)
                return done(.mul(x, .exp(.neg(.div(x, .n(c))))), 0, 5 * Double(c), .xExp, [c])
            case 3: // s·x/(x² + c)
                let c = r.int(1...4), s = r.pick([1, 2, -1])
                let w = 2 * Double(c).squareRoot() + 1.5
                return done(.div(.scaled(s, 1, x), .sum([.p(x, 2), .n(c)])), -w, w, .rational1, [s, c])
            case 4: // x⁴ − 2b·x²
                let b = r.int(1...4)
                let w = (Double(b)).squareRoot() * 1.25
                return done(.sub(.p(x, 4), .scaled(2 * b, 1, .p(x, 2))), -w, w, .quartic, [b])
            case 5: // (x − a)·e^x
                let a = r.int(-1...2)
                return done(.mul(.sum([x, .n(-a)]), .exp(x)), Double(a) - 4, Double(a) + 1, .linExp, [a])
            default: // c/(x² + 1) + k
                let c = r.int(2...5), k = r.int(-2...1)
                return done(.sum([.div(.n(c), .sum([.p(x, 2), 1])), .n(k)]), -3, 3, .bump, [c, k])
            }
        case .hard:
            switch r.int(0...10) {
            case 9: // x/(x² − a²)
                let a = r.int(1...3)
                return poled(.div(x, .sum([.p(x, 2), .n(-a * a)])), -Double(a) - 3, Double(a) + 3, [-Double(a), Double(a)], .xOverQuad, [a])
            case 10: // c/(x² − a²)
                let a = r.int(1...3), c = r.pick([1, 3, -2])
                return poled(.div(.n(c), .sum([.p(x, 2), .n(-a * a)])), -Double(a) - 3, Double(a) + 3, [-Double(a), Double(a)], .recipQuad, [a, c])
            case 7: // sin(x) + sin(kx)/k
                let k = r.int(2...3)
                return done(.sum([.sin(x), .div(.sin(lin(k)), .n(k))]), -pi, pi, pi: true, .sinSin, [k])
            case 8: // (x² − a)·e^(−x²/2)
                let a = r.int(1...3)
                return done(.mul(.sum([.p(x, 2), .n(-a)]), .exp(.neg(.div(.p(x, 2), 2)))), -3.5, 3.5, .quadGauss, [a])
            case 0, 1: // sin²(x)·cos(kx)
                let k = r.int(2...3)
                let w = pi / Double(2 * k)
                return done(.mul(.p(.sin(x), 2), .cos(lin(k))), -w, w, pi: true, .sin2cos, [k])
            case 2: // xⁿ·e^(−x)
                let n = r.int(2...3)
                return done(.mul(.p(x, n), .exp(.neg(x))), 0, Double(n) + 4, .powExp, [n])
            case 3: // sin(kx)·e^(−x/c)
                let k = r.int(1...2), c = r.int(2...4)
                return done(.mul(.sin(lin(k)), .exp(.neg(.div(x, .n(c))))), 0, 2 * pi, pi: true, .sinExpDecay, [k, c])
            case 4: // x⁴ − a·x² + b·x
                let a = r.int(2...5), b = r.nonZero(-2...2)
                let w = Double(a).squareRoot() * 1.15
                return done(.sum([.p(x, 4), .scaled(-a, 1, .p(x, 2)), .scaled(b, 1, x)]), -w, w, .quartic3, [a, b])
            case 5: // (x² − a)/(x² + b)
                let a = r.int(1...4), b = r.int(1...3)
                return done(.div(.sum([.p(x, 2), .n(-a)]), .sum([.p(x, 2), .n(b)])), -4, 4, .ratQuad, [a, b])
            default: // x·sin(x)
                return done(.mul(x, .sin(x)), -2 * pi, 2 * pi, pi: true, .xSin, [])
            }
        case .bagrut:
            // Bagrut 5U (571/572 style): trig investigations on [0, 2π], ln and
            // eˣ compositions, rational functions with two kinds of asymptote.
            let twoPi = 2 * pi
            switch r.int(0...43) {
            // Shapes taken from real 571/572/581/582 papers (2019–2026).
            case 24: // x/√(x² − a²): two branches, y = ±1
                let a = r.int(1...2)
                return poled(.div(x, .sqrt(.sum([.p(x, 2), .n(-a * a)]))), -Double(a) - 4, Double(a) + 4, [-Double(a), Double(a)], .rootRatX, [a])
            case 25: // x²/√(x² − a²)
                let a = r.int(1...2)
                return poled(.div(.p(x, 2), .sqrt(.sum([.p(x, 2), .n(-a * a)]))), -Double(a) - 4, Double(a) + 4, [-Double(a), Double(a)], .rootRatX2, [a])
            case 26: // sin x/(1 + sin²x)
                return done(.div(.sin(x), .sum([1, .p(.sin(x), 2)])), 0, twoPi, pi: true, .trigFrac1, [])
            case 27: // cos x + 2/cos²x
                return poled(.sum([.cos(x), .div(2, .p(.cos(x), 2))]), -pi, pi, [-pi / 2, pi / 2], pi: true, .cosPlusInvSq, [])
            case 28: // 1/cos²x − 4
                return poled(.sum([.div(1, .p(.cos(x), 2)), .n(-4)]), -pi, pi, [-pi / 2, pi / 2], pi: true, .invCosSq, [])
            case 29: // 6/(2cos²x − 5cos x − 3)
                return poled(.div(6, .sum([.scaled(2, 1, .p(.cos(x), 2)), .scaled(-5, 1, .cos(x)), .n(-3)])), 0, twoPi,
                             [2 * pi / 3, 4 * pi / 3], pi: true, .cosQuadInv, [])
            case 30: // (sin x − 1)/(sin x + 1)
                return poled(.div(.sum([.sin(x), .n(-1)]), .sum([.sin(x), 1])), 0, twoPi, [3 * pi / 2], pi: true, .sinRatio, [])
            case 31: // 2sin x + cos 2x − 1
                return done(.sum([.scaled(2, 1, .sin(x)), .cos(.mul(2, x)), .n(-1)]), -pi / 2, 3 * pi / 2, pi: true, .twoSinCos2, [])
            case 32: // cos³x·sin x
                return done(.mul(.p(.cos(x), 3), .sin(x)), 0, pi, pi: true, .cos3Sin, [])
            case 33: // 2e^(2x)/(e^(2x) − 5eˣ + 4)
                return poled(.div(.scaled(2, 1, .exp(.mul(2, x))), .sum([.exp(.mul(2, x)), .scaled(-5, 1, .exp(x)), 4])), -3, 3,
                             [0, log(4)], .expRat2, [], labels: ["0", "ln 4"])
            case 34: // eˣ/(a − eˣ)
                let a = r.pick([1, 2, 4])
                let la = log(Double(a))
                return poled(.div(.exp(x), .sum([.n(a), .neg(.exp(x))])), la - 4, la + 3, [la], .expOverAMinus, [a],
                             labels: [a == 1 ? "0" : "ln \(a)"])
            case 35: // (eˣ − b)/(eˣ − 4)²
                let b = 3
                return poled(.div(.sum([.exp(x), .n(-b)]), .p(.sum([.exp(x), .n(-4)]), 2)), -2.5, 3, [log(4)], .expMinusBOverSq, [b],
                             labels: ["ln 4"])
            case 36: // (ln x)²/((ln x)² − 1)
                return poled(.div(.p(.ln(x), 2), .sum([.p(.ln(x), 2), .n(-1)])), 0.05, 10, [exp(-1), exp(1)], .lnSqRatio, [],
                             labels: ["1/e", "e"])
            case 37: // x/(ln x − a)
                let a = r.int(0...1)
                return poled(.div(x, .sum([.ln(x), .n(-a)])), a == 0 ? 0.1 : 0.2, a == 0 ? 12 : 28, [exp(Double(a))], .xOverLnA, [a],
                             labels: [a == 0 ? "1" : "e"])
            case 38: // xⁿ(3 − ln x)
                let n = r.int(1...2)
                return done(.mul(n == 1 ? x : .p(x, 2), .sum([3, .neg(.ln(x))])), 0.05, 23, .xnThreeMinusLn, [n])
            case 39: // 4x(ln(x²) − 1): not defined at 0
                if var p = done(.scaled(4, 1, .mul(x, .sum([.ln(.p(x, 2)), .n(-1)]))), -3, 3, .fourXLnX2, []) {
                    p.holes = [0]
                    return p
                }
                return nil
            case 40: // x((ln x)² − 2ln x + 2)
                return done(.mul(x, .sum([.p(.ln(x), 2), .scaled(-2, 1, .ln(x)), 2])), 0.02, 6, .xLnPoly, [])
            case 41: // x + ln(x² − c): two branches
                let c = r.pick([8, 3])
                let rc = Double(c).squareRoot()
                return poled(.sum([x, .ln(.sum([.p(x, 2), .n(-c)]))]), -rc - 5, rc + 5, [-rc, rc], .xPlusLnQuad, [c],
                             labels: c == 8 ? ["−2√2", "2√2"] : ["−√3", "√3"])
            case 42: // 8ln(x² + 7) − 2x
                return done(.sum([.scaled(8, 1, .ln(.sum([.p(x, 2), 7]))), .scaled(-2, 1, x)]), -4, 11, .lnQuadMinusX, [])
            case 43: // (a − x²)·e^(−x)
                let a = r.pick([1, 3, 8])
                let ra = Double(a).squareRoot()
                return done(.mul(.sum([.n(a), .neg(.p(x, 2))]), .exp(.neg(x))), -ra - 0.3, 3 + Double(a + 2).squareRoot(), .polyOverExp, [a])
            case 0, 1: // sin²x + m·cos x
                let m = r.pick([1, -1])
                return done(.sum([.p(.sin(x), 2), .scaled(m, 1, .cos(x))]), 0, twoPi, pi: true, .sinSqCos, [m])
            case 2: // x + 2cos x  or  x − 2sin x
                let v = r.int(0...1)
                return done(v == 0 ? .sum([x, .scaled(2, 1, .cos(x))]) : .sub(x, .scaled(2, 1, .sin(x))), 0, twoPi, pi: true, .xPlusTrig, [v])
            case 3, 4: // sin x/(c + cos x)
                let c = r.int(2...3)
                return done(.div(.sin(x), .sum([.n(c), .cos(x)])), 0, twoPi, pi: true, .sinOverCos, [c])
            case 5: // 2sin x − sin 2x
                return done(.sub(.scaled(2, 1, .sin(x)), .sin(.mul(2, x))), 0, twoPi, pi: true, .twoSinSin2, [])
            case 6: // e^(sin x)
                return done(.exp(.sin(x)), 0, twoPi, pi: true, .expSin, [])
            case 7: // ln(c + cos x)
                let c = r.int(2...3)
                return done(.ln(.sum([.n(c), .cos(x)])), 0, twoPi, pi: true, .lnCos, [c])
            case 8: // cos x/(1 + sin x): asymptote at 3π/2
                return poled(.div(.cos(x), .sum([1, .sin(x)])), 0, twoPi, [3 * pi / 2], pi: true, .cosOverSin, [])
            case 9: // sin x·cos²x
                return done(.mul(.sin(x), .p(.cos(x), 2)), 0, twoPi, pi: true, .sinCos2, [])
            case 10, 11: // e^(2x) − a·eˣ
                let a = r.pick([2, 4, 6])
                let la = log(Double(a))
                return done(.sub(.exp(.mul(2, x)), .scaled(a, 1, .exp(x))), la - log(4) - 2.5, la + 0.6, .expQuadE, [a])
            case 12: // ln²x − 2k·ln x
                let k = r.pick([1, -1])
                return done(.sum([.p(.ln(x), 2), .scaled(-2 * k, 1, .ln(x))]), k == 1 ? 0.15 : 0.05, k == 1 ? 9 : 4, .ln2, [k])
            case 13: // x·ln²x
                return done(.mul(x, .p(.ln(x), 2)), 0.02, 3, .xLn2, [])
            case 14, 15: // eˣ/(x − a)
                let a = r.int(-1...2)
                return poled(.div(.exp(x), .sum([x, .n(-a)])), Double(a) - 4, Double(a) + 2.5, [Double(a)], .expOverLin, [a])
            case 16: // ln(x² − 2px + p² + d)
                let p = r.int(-1...2), d = r.pick([1, 4])
                let w = 3 * Double(d).squareRoot() + 1
                return done(.ln(Solver.polyExpr([1, -2 * p, p * p + d])), Double(p) - w, Double(p) + w, .lnQuadratic, [p, d])
            case 17, 18: // (x² + c)/(x² − a²): two vertical asymptotes, y = 1
                let a = r.int(1...2)
                let c = r.pick([1, 4, a == 1 ? -4 : -1])
                return poled(.div(.sum([.p(x, 2), .n(c)]), .sum([.p(x, 2), .n(-a * a)])), -Double(a) - 3, Double(a) + 3,
                             [-Double(a), Double(a)], .ratTwoPoles, [a, c])
            case 19: // eˣ/(eˣ + c): two horizontal asymptotes
                let c = r.pick([1, 2, 4])
                let lc = log(Double(c))
                return done(.div(.exp(x), .sum([.exp(x), .n(c)])), lc - 5, lc + 5, .logistic, [c])
            case 20: // (x² + a)/(x − p): vertical and oblique asymptote
                let p = r.int(-2...2)
                var a = r.pick([-3, -1, 1, 3, 5])
                if p * p + a == 0 { a += 2 }
                return poled(.div(.sum([.p(x, 2), .n(a)]), .sum([x, .n(-p)])), Double(p) - 6, Double(p) + 6, [Double(p)], .ratOblique, [a, p])
            case 21: // x/(x² − a²)
                let a = r.int(1...3)
                return poled(.div(x, .sum([.p(x, 2), .n(-a * a)])), -Double(a) - 3, Double(a) + 3, [-Double(a), Double(a)], .xOverQuad, [a])
            case 22: // ln(x)/xⁿ  or  x² − a·ln x
                if r.bool() {
                    let n = r.int(1...2)
                    return done(.div(.ln(x), n == 1 ? x : .p(x, 2)), 0.5, n == 1 ? 8 : 5, .lnOverPow, [n])
                }
                let a = r.int(1...4)
                return done(.sub(.p(x, 2), .scaled(a, 1, .ln(x))), 0.2, 2.5 + Double(a) * 0.2, .x2Ln, [a])
            default: // x·e^(−x²/c)  or  eˣ/(x² + c)
                if r.bool() {
                    let c = r.int(1...3)
                    let w = 2.5 * Double(c).squareRoot()
                    return done(.mul(x, .exp(.neg(.div(.p(x, 2), .n(c))))), -w, w, .xGauss, [c])
                }
                let c = r.int(1...3)
                return done(.div(.exp(x), .sum([.p(x, 2), .n(c)])), -3, 2.5, .expOverQuad, [c])
            }
        }
    }

    static func finish(_ f: Expr, _ a: Double, _ b: Double, piBased: Bool, level: Level, seed: UInt64,
                       family: SketchFamily? = nil) -> SketchProblem? {
        let xs = (0...200).map { a + (b - a) * Double($0) / 200 }
        // (A single missing point such as x = 0 in x·ln x² is allowed.)
        let all = xs.map { f.evaluate(at: $0) }
        guard all.filter({ !$0.isFinite }).count <= 1 else { return nil }
        let ys = all.filter(\.isFinite)
        var lo = ys.min()!, hi = ys.max()!
        let range = Swift.max(hi - lo, 1e-6)
        // Show the x-axis when it's in (or close to) the picture.
        if lo > 0 && lo < 0.4 * range { lo = 0 }
        if hi < 0 && -hi < 0.4 * range { hi = 0 }
        let margin = 0.15 * (hi - lo)
        return SketchProblem(function: f, xMin: a, xMax: b, yMin: lo - margin, yMax: hi + margin,
                             piBased: piBased, level: level, seed: seed, family: family)
    }

    /// Like `finish`, for functions with vertical asymptotes: the y-range
    /// comes from the graph away from the poles (plus every turning point),
    /// so the branches run off the top and bottom of the box.
    static func finishPoled(_ f: Expr, _ a: Double, _ b: Double, poles: [Double], piBased: Bool, level: Level, seed: UInt64,
                            family: SketchFamily?, labels: [String]? = nil) -> SketchProblem? {
        let w = b - a
        let keep = 0.12 * w
        let xs = (0...400).map { a + w * Double($0) / 400 }.filter { x in poles.allSatisfy { Swift.abs(x - $0) > keep } }
        var ys = xs.map { f.evaluate(at: $0) }.filter(\.isFinite)
        ys += GraphSteps.roots(of: f.derivative(), in: a...b).map { f.evaluate(at: $0) }.filter(\.isFinite)
        guard ys.count > 20, var lo = ys.min(), var hi = ys.max() else { return nil }
        let range = Swift.max(hi - lo, 1e-6)
        if lo > 0 && lo < 0.4 * range { lo = 0 }
        if hi < 0 && -hi < 0.4 * range { hi = 0 }
        let margin = 0.2 * (hi - lo)
        return SketchProblem(function: f, xMin: a, xMax: b, yMin: lo - margin, yMax: hi + margin,
                             piBased: piBased, level: level, seed: seed, family: family, asymptotes: poles,
                             asymptoteLabels: labels)
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
    case antiderivative(x0: String, y0: String)   // g′ = f, g(x0) = y0
    case lnOf                // ln f(x)
    case expOf               // e^f(x)
    case absX                // f(|x|)

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
        case .antiderivative: return f   // built from the original function instead (see ChangeFactory)
        case .lnOf: return .ln(f)
        case .expOf: return .exp(f)
        case .absX: return f.substitutingX(with: .abs(.x))
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
        case .antiderivative(let x0, let y0): return "g(x) = ∫ f(x) dx,  g(\(x0)) = \(y0)"
        case .lnOf: return "g(x) = ln f(x)"
        case .expOf: return "g(x) = e^f(x)"
        case .absX: return "g(x) = f(|x|)"
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

    /// The kind of rule, e.g. "reciprocal" (for variety between problems).
    public var kindName: String { String(String(describing: transform).prefix { $0 != "(" }) }
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
    public static func make(level: Level, seed: UInt64, avoiding: Set<String> = [], memory: ShapeMemory = ShapeMemory()) -> ChangeProblem {
        var s = seed
        var notSeen: ChangeProblem?
        var otherKind: ChangeProblem?
        // Easy has only three kinds of rule, so it only avoids an immediate repeat.
        let depth = level == .easy ? 1 : 2
        for attempt in 0..<160 {
            var rng = SeededRandom(seed: s)
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            guard let p = candidate(level: level, rng: &rng, seed: s), !avoiding.contains(p.signature) else { continue }
            if notSeen == nil { notSeen = p }
            if otherKind == nil, !memory.usedRecently(p.kindName, depth: 1) { otherKind = p }
            if attempt < 130 && memory.usedRecently(p.kindName, depth: depth) { continue }
            if attempt < 80 && (memory.looksLikeRecent(ShapeKey.of(p.target)) || memory.looksLikeRecent(ShapeKey.of(p.base))) { continue }
            return p
        }
        if let p = otherKind ?? notSeen { return p }
        // Always-valid fallback: 1/f² for f = x² + 1.
        let base = SketchFactory.finish(.sum([.p(.x, 2), 1]), -2, 2, piBased: false, level: level, seed: seed)!
        return build(base: base, transform: .reciprocalSquare, level: level, seed: seed)!
    }

    /// Graphs that stay well away from zero (safe for 1/f, 1/f², √f).
    static func positiveBase(_ r: inout SeededRandom, level: Level, seed: UInt64) -> SketchProblem? {
        let x = Expr.x, pi = Double.pi
        func fin(_ f: Expr, _ a: Double, _ b: Double, _ isPi: Bool = false) -> SketchProblem? {
            SketchFactory.finish(f, a, b, piBased: isPi, level: level, seed: seed)
        }
        switch r.int(0...9) {
        case 0: return fin(.sum([.p(x, 2), .n(r.int(1...3))]), -2, 2)
        case 1: return fin(.sum([.n(r.int(2...3)), .sin(.scaled(r.int(1...2), 1, x))]), -pi, pi, true)
        case 2: return fin(.sum([.exp(.neg(.p(x, 2))), .q(1, r.int(2...4))]), -2.5, 2.5)
        case 3:
            let h = r.int(-1...2)
            return fin(.sum([.p(.sum([x, .n(-h)]), 2), .n(r.int(1...2))]), Double(h) - 2, Double(h) + 2)
        case 4: return fin(.sum([.n(r.int(2...4)), .cos(.scaled(r.int(1...2), 1, x))]), -pi, pi, true)
        case 5: return fin(.div(.sum([.p(x, 2), .n(4)]), .n(r.int(2...4))), -3, 3)
        case 6: return fin(.div(.sum([.exp(x), .exp(.neg(x))]), 2), -2, 2)        // cosh x
        case 7: return fin(.sum([.p(x, 3), .scaled(-3, 1, x), .n(r.int(3...5))]), -2, 2)
        case 8: return fin(.sum([.exp(.scaled(1, 2, x)), .q(1, 2)]), -3, 2.5)
        default: return fin(.div(.n(r.int(4...8)), .sum([.p(x, 2), 2])), -3, 3)
        }
    }

    static func candidate(level: Level, rng r: inout SeededRandom, seed: UInt64) -> ChangeProblem? {
        enum Kind { case shift, negate, scaleUp, scaleDown, absolute, mirror, negateShift, scaleNeg, square,
                    reciprocal, derivative, squareRoot, reciprocalSquare, antiderivative, reciprocalPoles, lnOf, expOf, absX }
        let kinds: [Kind]
        switch level {
        case .easy: kinds = [.shift, .negate, .scaleUp, .scaleDown]
        case .medium: kinds = [.absolute, .mirror, .negateShift, .scaleNeg, .square]
        case .hard: kinds = [.reciprocal, .square, .derivative, .absolute, .squareRoot, .antiderivative, .antiderivative]
        // Weights follow the 571/572/581/582 papers: 1/f most often, then g′ = f, ln f, f′, |f|, e^f, f².
        // (f(|x|) never appears there.)
        case .bagrut: kinds = [.antiderivative, .antiderivative, .reciprocalPoles, .reciprocalPoles, .reciprocalPoles, .lnOf, .lnOf,
                               .expOf, .derivative, .derivative, .absolute, .square, .reciprocalSquare]
        }
        let kind = r.pick(kinds)
        // Bagrut-only kinds build their own base.
        switch kind {
        case .antiderivative:
            // Given the graph of f = F′, draw F through a given point.
            var rr = r
            // Hard integrates simpler graphs than Bagrut.
            let fLevel: Level = level == .bagrut ? (r.bool() ? .hard : .medium) : (r.bool() ? .medium : .easy)
            guard let F = SketchFactory.candidate(level: fLevel, rng: &rr, seed: seed), F.poles.isEmpty,
                  let base = SketchFactory.finish(F.function.derivative(), F.xMin, F.xMax, piBased: F.piBased, level: level, seed: seed)
            else { return nil }
            r = rr
            let y0 = F.value(at: F.xMin)
            let y0Text = Swift.abs(y0 - (y0 * 100).rounded() / 100) < 1e-9 ? SketchFormat.number(y0) : String(format: "%.2f", y0).replacingOccurrences(of: "-", with: "−")
            return build(base: base, transform: .antiderivative(x0: F.xLabel(F.xMin), y0: y0Text), level: level, seed: seed,
                         target: F.function)
        case .reciprocalPoles:
            // 1/f where f crosses the x-axis: vertical asymptotes at f's zeros.
            guard let base = SketchFactory.candidate(level: .medium, rng: &r, seed: seed), base.poles.isEmpty else { return nil }
            let w = base.xMax - base.xMin
            let zeros = GraphSteps.roots(of: base.function, in: base.xMin...base.xMax)
            guard !zeros.isEmpty, zeros.allSatisfy({ z in
                z - base.xMin > 0.1 * w && base.xMax - z > 0.1 * w
                    && Swift.abs(base.function.derivative().evaluate(at: z)) > 1e-3
            }) else { return nil }
            return build(base: base, transform: .reciprocal, level: level, seed: seed, poles: zeros)
        case .lnOf:
            guard let base = positiveBase(&r, level: level, seed: seed) else { return nil }
            return build(base: base, transform: .lnOf, level: level, seed: seed)
        case .expOf:
            guard let base = SketchFactory.candidate(level: .easy, rng: &r, seed: seed), base.poles.isEmpty,
                  base.yMax - base.yMin < 6 else { return nil }
            return build(base: base, transform: .expOf, level: level, seed: seed)
        case .absX:
            guard let base = SketchFactory.candidate(level: .medium, rng: &r, seed: seed), base.poles.isEmpty,
                  Swift.abs(base.xMin + base.xMax) < 1e-9 else { return nil }
            return build(base: base, transform: .absX, level: level, seed: seed)
        default:
            break
        }
        let needsPositive = [.reciprocal, .reciprocalSquare, .squareRoot].contains(kind)
        let baseLevel: Level = level == .easy ? .easy : .medium
        let base: SketchProblem?
        if needsPositive || (level != .easy && r.int(0...2) == 0) {
            base = positiveBase(&r, level: level, seed: seed)
        } else {
            base = SketchFactory.candidate(level: baseLevel, rng: &r, seed: seed)
        }
        guard let base, base.poles.isEmpty else { return nil }
        // Shifts big enough to see: about half the graph's height (at least 1).
        let fRange = base.yMax - base.yMin
        let step = Swift.max(1, Int((fRange / 1.3 / 2).rounded()))
        let sign = r.bool() ? 1 : -1
        let transform: GraphTransform
        switch kind {
        case .shift: transform = .shift(sign * step)
        case .negate: transform = .negate
        case .scaleUp: transform = .scale(2, 1)
        case .scaleDown: transform = .scale(1, 2)
        case .absolute: transform = .absolute
        case .mirror: transform = .mirror
        case .negateShift: transform = .negateShift(sign * step)
        case .scaleNeg: transform = .scale(-2, 1)
        case .square: transform = .square
        case .reciprocal: transform = .reciprocal
        case .derivative: transform = .derivative
        case .squareRoot: transform = .squareRoot
        case .reciprocalSquare: transform = .reciprocalSquare
        case .antiderivative, .reciprocalPoles, .lnOf, .expOf, .absX: return nil
        }
        // |f| only makes sense if f goes negative; f(−x) needs a symmetric interval.
        if case .absolute = transform {
            guard (0...200).contains(where: { base.value(at: base.xMin + (base.xMax - base.xMin) * Double($0) / 200) < -0.05 * fRange }) else { return nil }
        }
        if case .mirror = transform {
            guard Swift.abs(base.xMin + base.xMax) < 1e-9 else { return nil }
        }
        return build(base: base, transform: transform, level: level, seed: seed)
    }

    static func build(base: SketchProblem, transform: GraphTransform, level: Level, seed: UInt64,
                      target targetFunction: Expr? = nil, poles: [Double] = []) -> ChangeProblem? {
        let g = targetFunction ?? transform.apply(base.function)
        let made = poles.isEmpty
            ? SketchFactory.finish(g, base.xMin, base.xMax, piBased: base.piBased, level: level, seed: seed)
            : SketchFactory.finishPoled(g, base.xMin, base.xMax, poles: poles, piBased: base.piBased, level: level, seed: seed, family: nil)
        guard var target = made else { return nil }
        // Reject transforms that barely change the graph (e.g. f(−x) for an
        // even f, or |f| where f is hardly negative): drawing f must not pass.
        let xs = (0...60).map { base.xMin + (base.xMax - base.xMin) * Double($0) / 60 }
        let gRange = target.yMax - target.yMin
        let fRange = base.yMax - base.yMin
        let diffs = xs.map { Swift.abs(g.evaluate(at: $0) - base.value(at: $0)) }.filter(\.isFinite)
        let meanDiff = diffs.reduce(0, +) / Double(Swift.max(1, diffs.count))
        guard meanDiff > 0.3 * Swift.max(gRange, fRange) / 1.3 else { return nil }
        // Don't let one graph dwarf the other on the shared canvas.
        guard gRange < 12 * fRange, fRange < 12 * gRange else { return nil }
        // g must fill a fair part of the shared box, or it's a near-flat line.
        let gVals = xs.map { g.evaluate(at: $0) }.filter { $0.isFinite && $0 >= target.yMin && $0 <= target.yMax }
        let box = Swift.max(target.yMax, base.yMax) - Swift.min(target.yMin, base.yMin)
        guard let gLo = gVals.min(), let gHi = gVals.max(), gHi - gLo > 0.25 * box else { return nil }
        target.yMin = Swift.min(target.yMin, base.yMin)
        target.yMax = Swift.max(target.yMax, base.yMax)
        return ChangeProblem(base: base, transform: transform, target: target, level: level, seed: seed)
    }
}

// MARK: - Whole graph

public extension SketchChecker {
    /// Whole-graph problems: only what was drawn inside the view is checked,
    /// and that stretch must include every peak, dip, zero, inflection point
    /// and vertical asymptote (so zooming into a dull part doesn't pass).
    static func checkWhole(_ strokes: [SketchStroke], for p: SketchProblem, view: SketchViewport,
                           mode: SketchMode) -> (result: SketchResult, checked: SketchProblem) {
        let drawnX = strokes.flatMap { $0 }.filter { $0.x >= view.xMin && $0.x <= view.xMax && $0.y >= view.yMin && $0.y <= view.yMax }.map(\.x)
        guard let lo = drawnX.min(), let hi = drawnX.max(), hi - lo > 1e-6 * (view.xMax - view.xMin) else {
            return (SketchResult(passed: false, regions: [SketchRegion(lo: view.xMin, hi: view.xMax, issue: .notDrawn,
                                                                     hint: "Draw the graph — everything you draw inside the view is checked.")],
                                 coverage: 0), p.windowed(view))
        }
        let checked = p.windowed(SketchViewport(xMin: lo, xMax: hi, yMin: view.yMin, yMax: view.yMax))
        let margin = 0.02 * (p.xMax - p.xMin)
        var missing: [SketchRegion] = []
        for feat in GraphSteps.features(of: p) {
            let where_ = "x ≈ \(p.xLabel(feat.x))"
            let zone = (feat.x - 2 * margin)...(feat.x + 2 * margin)
            if feat.x < view.xMin || feat.x > view.xMax {
                missing.append(SketchRegion(lo: zone.lowerBound, hi: zone.upperBound, issue: .notDrawn,
                                            hint: "The graph has a \(feat.name) at \(where_), outside the view — move or zoom out and draw it too."))
            } else if feat.x < lo - margin || feat.x > hi + margin {
                missing.append(SketchRegion(lo: zone.lowerBound, hi: zone.upperBound, issue: .notDrawn,
                                            hint: "Draw further: the graph has a \(feat.name) at \(where_), and your drawing has to include it."))
            } else if let y = feat.y, y < view.yMin || y > view.yMax {
                missing.append(SketchRegion(lo: zone.lowerBound, hi: zone.upperBound, issue: .notDrawn,
                                            hint: "The \(feat.name) at \(where_) is off the screen \(y > view.yMax ? "(above)" : "(below)") — zoom out or move the view so you can draw it."))
            }
        }
        if !missing.isEmpty {
            return (consolidate(SketchResult(passed: false, regions: missing, coverage: 0), p), checked)
        }
        return (check(strokes, for: checked, mode: mode), checked)
    }
}

// MARK: - Zone guide

/// "Show the correct graph in this zone", fitted to the user's own drawing:
/// the true shape, scaled and shifted like the parts they drew, and bent so
/// it joins their strokes at both edges of the zone — no floating pieces.
public enum SketchGuide {
    /// `fit` follows the drawing mode: `.none` (Precision, Standard) keeps the
    /// true heights, `.scale` (Proportions) takes your vertical scale,
    /// `.minMax` (Shape) your scale and position.
    public static func continuation(of strokes: [SketchStroke], for p: SketchProblem, in zone: ClosedRange<Double>,
                                    flagged: [ClosedRange<Double>] = [],
                                    fit: SketchTolerance.Normalization = .minMax) -> SketchStroke {
        let a = p.xMin, b = p.xMax, w = b - a
        let n = 120
        let colW = w / Double(n)
        let xs = (0..<n).map { a + w * (Double($0) + 0.5) / Double(n) }
        let drawn = SketchChecker.sampleDrawing(strokes, xs: xs, columnWidth: colW)
        func isFlagged(_ x: Double) -> Bool {
            (flagged + [zone]).contains { x >= $0.lowerBound - colW && x <= $0.upperBound + colW }
        }

        // How the user's drawing relates to the true graph where it was right: u ≈ α·f + β.
        var pairs: [(f: Double, u: Double)] = []
        for (i, x) in xs.enumerated() {
            guard let u = drawn[i], !isFlagged(x) else { continue }
            let fv = p.value(at: x)
            if fv.isFinite { pairs.append((fv, u)) }
        }
        var alpha = 1.0, beta = 0.0
        if fit == .none {
            // True heights; only the joins at the edges follow the drawing.
        } else if fit == .scale {
            let num = pairs.reduce(0) { $0 + $1.f * $1.u }, den = pairs.reduce(0) { $0 + $1.f * $1.f }
            if pairs.count >= 6, den > 1e-12, (0.25...4).contains(num / den) { alpha = num / den }
        } else if pairs.count >= 6 {
            let fm = pairs.reduce(0) { $0 + $1.f } / Double(pairs.count)
            let um = pairs.reduce(0) { $0 + $1.u } / Double(pairs.count)
            let cov = pairs.reduce(0) { $0 + ($1.f - fm) * ($1.u - um) }
            let varF = pairs.reduce(0) { $0 + ($1.f - fm) * ($1.f - fm) }
            if varF > 1e-12 { alpha = cov / varF }
            if !(0.25...4).contains(alpha) { alpha = 1 }
            beta = um - alpha * fm
        } else if !pairs.isEmpty {
            beta = pairs.reduce(0) { $0 + ($1.u - $1.f) } / Double(pairs.count)
        }
        let view = (p.yMax - p.yMin)
        func fitted(_ x: Double) -> Double { alpha * p.value(at: x) + beta }

        // Where the drawing meets the zone edges (searching outwards a little).
        func anchor(_ edge: Double, step: Double) -> (x: Double, gap: Double)? {
            var x = edge + step * colW / 2
            for _ in 0..<12 {
                guard x > a, x < b else { return nil }
                let i = Int(((x - a) / colW).rounded(.down))
                if i >= 0, i < n, let u = drawn[i], !zone.contains(xs[i]) {
                    let fx = fitted(xs[i])
                    if fx.isFinite { return (xs[i], u - fx) }
                }
                x += step * colW
            }
            return nil
        }
        let left = anchor(zone.lowerBound, step: -1)
        let right = anchor(zone.upperBound, step: 1)
        func correction(_ x: Double) -> Double {
            switch (left, right) {
            case let (l?, r?):
                let t = Swift.max(0, Swift.min(1, (x - l.x) / Swift.max(r.x - l.x, 1e-12)))
                return l.gap + t * (r.gap - l.gap)
            case let (l?, nil): return l.gap
            case let (nil, r?): return r.gap
            default: return 0
            }
        }

        let lo = Swift.max(a, left?.x ?? zone.lowerBound), hi = Swift.min(b, right?.x ?? zone.upperBound)
        guard hi > lo else { return [] }
        return (0...100).compactMap { i in
            let x = lo + (hi - lo) * Double(i) / 100
            let y = fitted(x) + correction(x)
            return y.isFinite && y > p.yMin - view && y < p.yMax + view ? SketchPoint(x: x, y: y) : nil
        }
    }
}
