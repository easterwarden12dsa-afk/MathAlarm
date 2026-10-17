import Foundation

/// A labelled point on the solution graph (Change: A on f, A′ on g).
public struct GraphMarker: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var label: String
    /// On the graph to draw (g) rather than the given graph (f).
    public var onTarget: Bool
}

/// Worked "how to draw it" solutions for Graph Sketch and Change.
///
/// Sketch: the standard function investigation in headed steps — domain,
/// intercepts, f′ = 0 solved by algebra with a sign table as proof,
/// f″ = 0 and concavity, then the points to plot.
/// Change: key points of f are lettered and moved one by one by the rule;
/// nothing is claimed that can't be read off the given graph.
public enum GraphSteps {
    public static func steps(for p: SketchProblem, name: String = "f") -> [SolutionStep] {
        let f = p.function
        let a = p.xMin, b = p.xMax
        let d1 = f.derivative()
        let d2 = d1.derivative()
        let solver = Solver(a: a, b: b, piBased: p.piBased)
        let inv = GraphAlgebra.investigate(p)
        let width = b - a
        var labels: [(Double, String)] = [(a, p.xLabel(a)), (b, p.xLabel(b))]
        func X(_ x: Double) -> String {
            labels.first { Swift.abs($0.0 - x) < 1e-7 * (width + 1) }?.1 ?? solver.xLabel(x, exact: true)
        }
        func Y(_ y: Double) -> String { num(y) }
        /// Without "≈", for inequalities and coordinates.
        func XB(_ x: Double) -> String { bare(X(x)) }
        /// "x = π/6" or "x ≈ 0.355".
        func eq(_ x: Double) -> String { equation(X(x)) }
        func pt(_ x: Double) -> String { "(\(XB(x)), \(Y(f.evaluate(at: x))))" }

        /// Algebraic solutions inside the interval, checked against the
        /// numeric roots; falls back to sign changes if they disagree.
        func accept(_ solved: Solved?, of e: Expr, name eqName: String) -> (lines: [SolutionStep], roots: [Double], exact: Bool) {
            let numeric = roots(of: e, in: a...b)
            if let solved {
                var inside: [AlgebraRoot] = []
                for r in solved.roots where solver.inside(r.x) && !inside.contains(where: { Swift.abs($0.x - r.x) < 1e-7 * (width + 1) }) {
                    inside.append(r)
                }
                inside.sort { $0.x < $1.x }
                let matches = algebraAgrees(inside.map(\.x), numeric: numeric, e: e, a: a, b: b)
                if matches {
                    for r in inside { labels.append((r.x, r.label)) }
                    var lines = solved.lines
                    lines.append(.result(inside.isEmpty
                        ? "No solutions inside \(X(a)) < x < \(X(b))."
                        : "Inside \(X(a)) < x < \(X(b)):  " + inside.map { equation($0.label) }.joined(separator: ",  "), depth: 1))
                    return (lines, inside.map(\.x), solved.exact)
                }
            }
            var s = solver.numeric(e, name: eqName)
            s.lines.insert(SolutionStep("This equation can't be solved exactly by hand. \(eqName) is continuous, so it is 0 wherever it changes sign (intermediate value theorem):", depth: 1), at: 0)
            for r in s.roots { labels.append((r.x, r.label)) }
            return (s.lines, s.roots.map(\.x), false)
        }

        var steps: [SolutionStep] = []
        steps.append(.heading("The function"))
        steps.append(SolutionStep("", label: "\(name)(x) =", math: f))
        steps.append(SolutionStep("on the interval \(X(a)) ≤ x ≤ \(X(b))."))

        // Step 1 · Domain
        steps.append(.heading("Step 1 · Domain"))
        steps.append(SolutionStep(domainNote(f)))
        steps.append(SolutionStep("On \(X(a)) ≤ x ≤ \(X(b)) it is defined and continuous, so there are no vertical asymptotes here (and on a closed interval no horizontal ones either)."))

        // Step 2 · Intercepts
        steps.append(.heading("Step 2 · Intercepts with the axes"))
        if a <= 0 && b >= 0 {
            steps.append(.subheading("y-axis (x = 0)"))
            steps.append(SolutionStep("\(name)(0) = \(Y(f.evaluate(at: 0)))  →  the point (0, \(Y(f.evaluate(at: 0))))", depth: 1))
        }
        steps.append(.subheading("x-axis: solve \(name)(x) = 0"))
        let zeroPart = accept(inv?.zeros, of: f, name: "\(name)(x)")
        steps += zeroPart.lines
        let zs = zeroPart.roots

        // Step 3 · Extreme points
        steps.append(.heading("Step 3 · Extreme points"))
        steps.append(.subheading("The derivative"))
        if let d = inv?.d1 {
            steps.append(SolutionStep("Differentiate and factor:", label: "\(name)′(x) =", math: d.display, depth: 1))
        } else {
            steps.append(SolutionStep(d1.size <= 80 ? "Differentiate:" : "Differentiate (a long expression — only its sign matters below).",
                                      label: d1.size <= 80 ? "\(name)′(x) =" : nil, math: d1.size <= 80 ? d1 : nil, depth: 1))
        }
        steps.append(.subheading("Solve \(name)′(x) = 0"))
        let critPart = accept(inv?.d1?.solve, of: d1, name: "\(name)′(x)")
        steps += critPart.lines
        let crit = critPart.roots

        steps.append(.subheading("Sign of \(name)′ — the proof"))
        steps.append(SolutionStep("\(name)′ can only change sign where it is 0, so one test point in each part decides the sign there:", depth: 1))
        let s1 = signTable(d1, cuts: crit, a: a, b: b, solver: solver, X: X)
        for row in s1 {
            steps.append(SolutionStep("\(XB(row.lo)) < x < \(XB(row.hi)):   \(name)′(\(row.testLabel)) \(num(row.value, approx: true)) \(row.positive ? "> 0   ↗ increasing" : "< 0   ↘ decreasing")", depth: 1))
        }
        steps.append(.subheading("Conclusion"))
        if crit.isEmpty {
            steps.append(.result("\(name)′ never changes sign: \(name) is \(s1.first?.positive == true ? "increasing" : "decreasing") on the whole interval, with no turning points.", depth: 1))
        }
        for (i, c) in crit.enumerated() {
            let left = s1[i].positive, right = s1[i + 1].positive
            let v2 = d2.evaluate(at: c)
            let check = v2.isFinite && Swift.abs(v2) > 1e-9
                ? "  Check: \(name)″(\(XB(c))) \(num(v2, approx: true)) \(v2 < 0 ? "< 0 (∩)" : "> 0 (∪)") ✓"
                : ""
            if left && !right {
                steps.append(.result("\(eq(c)): \(name)′ changes from + to −  ⇒  maximum at \(pt(c)).", depth: 1))
                if !check.isEmpty { steps.append(SolutionStep(check.trimmingCharacters(in: .whitespaces), depth: 2)) }
            } else if !left && right {
                steps.append(.result("\(eq(c)): \(name)′ changes from − to +  ⇒  minimum at \(pt(c)).", depth: 1))
                if !check.isEmpty { steps.append(SolutionStep(check.trimmingCharacters(in: .whitespaces), depth: 2)) }
            } else {
                steps.append(.result("\(eq(c)): \(name)′ = 0 but doesn't change sign  ⇒  no turn, just a flat moment at \(pt(c)).", depth: 1))
            }
        }
        if let first = s1.first, let last = s1.last {
            steps.append(SolutionStep("End points: \(pt(a)) is an end \(first.positive ? "minimum" : "maximum") (the graph \(first.positive ? "rises" : "falls") from it), \(pt(b)) is an end \(last.positive ? "maximum" : "minimum").", depth: 1))
        }

        // Step 4 · Inflection points
        steps.append(.heading("Step 4 · Inflection points"))
        steps.append(.subheading("The second derivative"))
        if let d = inv?.d2 {
            steps.append(SolutionStep("Differentiate \(name)′ again:", label: "\(name)″(x) =", math: d.display, depth: 1))
        } else {
            let d2s = d2.simplified()
            steps.append(SolutionStep(d2s.size <= 80 ? "Differentiate \(name)′ again:" : "Differentiate \(name)′ again (a long expression — only its sign matters below).",
                                      label: d2s.size <= 80 ? "\(name)″(x) =" : nil, math: d2s.size <= 80 ? d2s : nil, depth: 1))
        }
        steps.append(.subheading("Solve \(name)″(x) = 0"))
        let inflPart = accept(inv?.d2?.solve, of: d2, name: "\(name)″(x)")
        steps += inflPart.lines
        let s2 = signTable(d2, cuts: inflPart.roots, a: a, b: b, solver: solver, X: X)
        steps.append(.subheading("Sign of \(name)″"))
        for row in s2 {
            steps.append(SolutionStep("\(XB(row.lo)) < x < \(XB(row.hi)):   \(name)″(\(row.testLabel)) \(num(row.value, approx: true)) \(row.positive ? "> 0   ∪ bends up" : "< 0   ∩ bends down")", depth: 1))
        }
        steps.append(.subheading("Conclusion"))
        var infl: [Double] = []
        for (i, c) in inflPart.roots.enumerated() where s2[i].positive != s2[i + 1].positive {
            infl.append(c)
            steps.append(.result("\(eq(c)): \(name)″ changes sign  ⇒  inflection point \(pt(c)).", depth: 1))
        }
        for (i, c) in inflPart.roots.enumerated() where s2[i].positive == s2[i + 1].positive {
            steps.append(SolutionStep("\(eq(c)): \(name)″ = 0 but keeps its sign — not an inflection point.", depth: 1))
        }
        if infl.isEmpty {
            steps.append(.result("No inflection points: \(name) bends \(s2.first?.positive == true ? "up (∪)" : "down (∩)") everywhere.", depth: 1))
        }

        // Step 5 · Draw it
        steps.append(.heading("Step 5 · Draw it"))
        steps.append(SolutionStep("Plot these points from left to right and join them, rising/falling (Step 3) and bending (Step 4) as found:"))
        var key: [(Double, String)] = [(a, "start"), (b, "end")]
        key += zs.map { ($0, "on the x-axis") }
        key += crit.enumerated().compactMap { i, c in
            let l = s1[i].positive, r = s1[i + 1].positive
            return l == r ? nil : (c, l ? "maximum" : "minimum")
        }
        key += infl.map { ($0, "inflection") }
        var seen: [(Double, String)] = []
        for k in key.sorted(by: { $0.0 < $1.0 }) {
            if let i = seen.firstIndex(where: { Swift.abs($0.0 - k.0) < 1e-6 * (width + 1) }) {
                seen[i].1 += ", " + k.1
            } else {
                seen.append(k)
            }
        }
        for (x, what) in seen {
            steps.append(SolutionStep("\(pt(x))  — \(what)", depth: 1))
        }
        return steps
    }

    /// Every numeric root has an algebraic one next to it, and every
    /// algebraic one really is a zero (double roots the scan can miss count).
    static func algebraAgrees(_ algebra: [Double], numeric: [Double], e: Expr, a: Double, b: Double) -> Bool {
        let tol = 2e-3 * (b - a)
        let scale = (0...200).map { e.evaluate(at: a + (b - a) * Double($0) / 200) }.filter(\.isFinite).map(Swift.abs).max() ?? 1
        let allFound = numeric.allSatisfy { n in algebra.contains { Swift.abs($0 - n) < tol } }
        let allReal = algebra.allSatisfy { r in
            let v = e.evaluate(at: r)
            return v.isFinite && Swift.abs(v) <= 1e-7 * Swift.max(1, scale)
        }
        return allFound && allReal
    }

    // MARK: Sign tables

    struct SignRow {
        var lo: Double
        var hi: Double
        var testLabel: String
        var value: Double
        var positive: Bool
    }

    /// One test point per part between the cuts; prefers simple x values.
    static func signTable(_ e: Expr, cuts: [Double], a: Double, b: Double, solver: Solver,
                          X: (Double) -> String) -> [SignRow] {
        let pts = [a] + cuts + [b]
        var rows: [SignRow] = []
        for (l, r) in zip(pts, pts.dropFirst()) {
            let (t, label) = testPoint(l, r, piBased: solver.piBased)
            var v = e.evaluate(at: t)
            if !v.isFinite || v == 0 { v = e.evaluate(at: (l + r) / 2) }
            rows.append(SignRow(lo: l, hi: r, testLabel: label, value: v, positive: v > 0))
        }
        return rows
    }

    static func testPoint(_ l: Double, _ r: Double, piBased: Bool) -> (Double, String) {
        let w = r - l
        let lo = l + 0.15 * w, hi = r - 0.15 * w
        let mid = (l + r) / 2
        var best: (Double, String)?
        func consider(_ x: Double, _ label: String) {
            guard x >= lo, x <= hi else { return }
            if best == nil || Swift.abs(x - mid) < Swift.abs(best!.0 - mid) { best = (x, label) }
        }
        if piBased {
            let step = Double.pi / 12
            for k in Int((lo / step).rounded(.up))...Swift.max(Int((lo / step).rounded(.up)), Int((hi / step).rounded(.down))) {
                consider(Double(k) * step, SketchFormat.x(Double(k) * step, piBased: true))
            }
        }
        if best == nil {
            for denom in [1, 2, 4, 10] {
                let d = Double(denom)
                let first = Int((lo * d).rounded(.up)), last = Int((hi * d).rounded(.down))
                if first <= last {
                    for k in first...last { consider(Double(k) / d, num(Double(k) / d)) }
                    break
                }
            }
        }
        return best ?? (mid, num(mid))
    }

    // MARK: - Change

    /// Key points of a graph: ends, zeros, peaks, dips and inflection points.
    struct KeyPoint {
        enum Kind: String { case leftEnd = "left end", rightEnd = "right end", zero = "on the x-axis", peak, dip, inflection = "steepest point (inflection)" }
        var x: Double
        var kinds: [Kind]
        var text: String { kinds.map(\.rawValue).joined(separator: ", ") }
    }

    static func keyPoints(_ p: SketchProblem, inflections: Bool = true) -> [KeyPoint] {
        let f = p.function, a = p.xMin, b = p.xMax
        let d1 = f.derivative(), d2 = d1.derivative()
        var key: [KeyPoint] = [KeyPoint(x: a, kinds: [.leftEnd]), KeyPoint(x: b, kinds: [.rightEnd])]
        key += roots(of: f, in: a...b).map { KeyPoint(x: $0, kinds: [.zero]) }
        key += roots(of: d1, in: a...b).compactMap { c in
            let l = d1.evaluate(at: c - 1e-4 * (b - a)), r = d1.evaluate(at: c + 1e-4 * (b - a))
            if l > 0 && r < 0 { return KeyPoint(x: c, kinds: [.peak]) }
            if l < 0 && r > 0 { return KeyPoint(x: c, kinds: [.dip]) }
            return nil
        }
        if inflections {
            key += roots(of: d2, in: a...b).filter { x in
                let e = 1e-3 * (b - a)
                return (d2.evaluate(at: x - e) < 0) != (d2.evaluate(at: x + e) < 0)
            }.map { KeyPoint(x: $0, kinds: [.inflection]) }
        }
        var out: [KeyPoint] = []
        for k in key.sorted(by: { $0.x < $1.x }) {
            if let i = out.firstIndex(where: { Swift.abs($0.x - k.x) < 1e-6 * (b - a + 1) }) {
                out[i].kinds += k.kinds
            } else {
                out.append(k)
            }
        }
        return out
    }

    /// The lettered points of f used for a Change problem (inflection
    /// points only matter for the derivative).
    static func changeKeys(_ c: ChangeProblem) -> [(letter: String, key: KeyPoint)] {
        var inflections = false
        if case .derivative = c.transform { inflections = true }
        let keys = keyPoints(c.base, inflections: inflections)
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".map(String.init)
        return keys.enumerated().map { (letters[$0.offset % letters.count], $0.element) }
    }

    /// Where a point of f ends up on g.
    static func image(of x: Double, in c: ChangeProblem) -> (x: Double, y: Double) {
        switch c.transform {
        case .mirror: return (-x, c.base.value(at: x))
        case .derivative: return (x, c.base.function.derivative().evaluate(at: x))
        default: return (x, c.target.value(at: x))
        }
    }

    /// Lettered points for the solution graph: A, B, … on f and A′, B′, … on g.
    public static func markers(for c: ChangeProblem) -> [GraphMarker] {
        var out: [GraphMarker] = []
        for (letter, k) in changeKeys(c) {
            let y = c.base.value(at: k.x)
            let img = image(of: k.x, in: c)
            if y.isFinite { out.append(GraphMarker(x: k.x, y: y, label: letter, onTarget: false)) }
            if img.y.isFinite { out.append(GraphMarker(x: img.x, y: img.y, label: letter + "′", onTarget: true)) }
        }
        return out
    }

    /// Change: mark f's key points, apply the rule to each, join them.
    /// With `formulaVisible: false` nothing uses f's formula or values that
    /// can't be read off the grey graph.
    public static func steps(for c: ChangeProblem, formulaVisible: Bool = true) -> [SolutionStep] {
        let f = c.base, g = c.target
        func X(_ x: Double) -> String { f.xLabel(x) }
        let keys = changeKeys(c)
        var steps: [SolutionStep] = []

        steps.append(.heading("What you have"))
        if formulaVisible {
            steps.append(SolutionStep("", label: "f(x) =", math: f.function))
        } else {
            steps.append(SolutionStep("Only the grey graph of f — everything below is read off the picture, no formula and no exact values needed."))
        }
        steps.append(.result("Task: \(c.transform.formula)"))

        steps.append(.heading("Step 1 · Mark the key points of f"))
        steps.append(SolutionStep("Put a letter on every point where something happens (they're marked on the graph below):"))
        for (letter, k) in keys {
            let y = f.value(at: k.x)
            let side = Swift.abs(y) < 1e-9 * (f.yMax - f.yMin + 1) ? "" : (y > 0 ? ", above the x-axis" : ", below the x-axis")
            let coords = formulaVisible ? "  (\(X(k.x)), \(num(y)))" : ""
            steps.append(SolutionStep("\(letter) — \(k.text)\(k.kinds.contains(.zero) ? "" : side)\(coords)", depth: 1))
        }

        steps.append(.heading("Step 2 · The rule"))
        for line in explanation(c) { steps.append(SolutionStep(line, depth: 1)) }

        steps.append(.heading("Step 3 · Move each point"))
        let gKeys = keyPoints(g, inflections: false)
        for (letter, k) in keys {
            let y = f.value(at: k.x)
            let img = image(of: k.x, in: c)
            var line = "\(letter) → \(letter)′: " + move(c, k, y: y)
            if let gk = gKeys.first(where: { Swift.abs($0.x - img.x) < 2e-3 * (g.xMax - g.xMin) }) {
                if gk.kinds.contains(.peak) { line += " — a peak of g" } else if gk.kinds.contains(.dip) { line += " — a dip of g" }
            }
            if formulaVisible, img.y.isFinite {
                line += "  →  \(letter)′ = (\(X(img.x)), \(num(img.y)))"
            }
            steps.append(SolutionStep(line, depth: 1))
        }

        steps.append(.heading("Step 4 · Join the new points"))
        var images = keys.map { (letter: $0.letter + "′", x: image(of: $0.key.x, in: c).x, src: $0.key.x) }
        images.sort { $0.x < $1.x }
        for (l, r) in zip(images, images.dropFirst()) {
            let gl = image(of: l.src, in: c).y, gr = image(of: r.src, in: c).y
            guard gl.isFinite, gr.isFinite else { continue }
            let rises = gr > gl
            steps.append(SolutionStep("\(l.letter) to \(r.letter): g \(rises ? "rises" : "falls")\(joinReason(c, from: l.src, to: r.src, rises: rises))", depth: 1))
        }
        steps.append(SolutionStep("Keep the curve smooth between the points and copy how f bends. There's no need to find g's exact inflection points — the shape between the marked points is enough."))

        if formulaVisible {
            steps.append(.heading("Check with the formula"))
            steps.append(SolutionStep("", label: "g(x) =", math: g.function))
        }
        return steps
    }

    static func move(_ c: ChangeProblem, _ k: KeyPoint, y: Double) -> String {
        let onAxis = Swift.abs(y) < 1e-9 * (c.base.yMax - c.base.yMin + 1)
        let near1 = Swift.abs(Swift.abs(y) - 1) < 0.02
        switch c.transform {
        case .shift(let d):
            return "straight \(d > 0 ? "up" : "down") by \(Swift.abs(d))"
        case .negate:
            return onAxis ? "stays on the x-axis" : "mirror it in the x-axis (same distance, other side)"
        case .scale(let p, let q):
            if onAxis { return "stays on the x-axis" }
            let k = Double(p) / Double(q)
            return "\(num(Swift.abs(k))) times as far from the x-axis\(k < 0 ? ", on the other side" : "")"
        case .negateShift(let d):
            return "mirror it in the x-axis, then move it \(d > 0 ? "up" : "down") by \(Swift.abs(d))"
        case .absolute:
            return y < 0 && !onAxis ? "it's below the x-axis, so flip it up (mirror image above the axis)" : "stays where it is (f isn't negative there)"
        case .mirror:
            return "mirror it in the y-axis: same height, x on the other side"
        case .reciprocal:
            if near1 { return "stays put — at height \(y > 0 ? "1" : "−1"), 1/f = f" }
            return Swift.abs(y) > 1 ? "same x; it's further than 1 from the axis, so 1/f is closer than 1 (between 0 and \(y > 0 ? "1" : "−1"))"
                                    : "same x; it's closer than 1 to the axis, so 1/f is further than 1 (beyond \(y > 0 ? "1" : "−1"))"
        case .square:
            if onAxis { return "stays on the x-axis — g touches it smoothly" }
            let sign = y < 0 ? " and moves above the axis (squares are positive)" : ""
            if near1 { return "goes to height 1\(sign)" }
            return (Swift.abs(y) > 1 ? "same x, higher: squaring a number bigger than 1 makes it bigger"
                                     : "same x, closer to the axis: squaring a number below 1 makes it smaller") + sign
        case .reciprocalSquare:
            if near1 { return "goes to height 1" }
            return Swift.abs(y) > 1 ? "same x, between 0 and 1 (1 ÷ a square bigger than 1)" : "same x, above 1 (1 ÷ a square smaller than 1)"
        case .squareRoot:
            if near1 { return "stays at height 1" }
            return y > 1 ? "same x, lower but still above 1 (√ pulls towards 1)" : "same x, higher but still below 1 (√ pulls towards 1)"
        case .derivative:
            if k.kinds.contains(.peak) || k.kinds.contains(.dip) { return "on the x-axis — f is flat there, its slope is 0" }
            let slope = c.base.function.derivative().evaluate(at: k.x)
            if k.kinds.contains(.inflection) {
                return "f is steepest here, so g reaches its \(slope > 0 ? "highest" : "lowest") value around here"
            }
            return slope > 0 ? "above the x-axis — f rises at \(k.kinds.contains(.leftEnd) || k.kinds.contains(.rightEnd) ? "this end" : "this point")"
                             : "below the x-axis — f falls at \(k.kinds.contains(.leftEnd) || k.kinds.contains(.rightEnd) ? "this end" : "this point")"
        }
    }

    static func joinReason(_ c: ChangeProblem, from x1: Double, to x2: Double, rises: Bool) -> String {
        let f = c.base
        let mid = (x1 + x2) / 2
        let fUp = f.value(at: x2) > f.value(at: x1)
        switch c.transform {
        case .shift, .squareRoot:
            return " — like f (the rule keeps the order of heights)"
        case .scale(let p, _):
            return p > 0 ? " — like f" : " — opposite to f (the minus flips it)"
        case .negate, .negateShift:
            return " — opposite to f (the minus flips it)"
        case .reciprocal, .reciprocalSquare:
            return " — f \(fUp ? "rises" : "falls") there, and 1/… turns bigger into smaller"
        case .square:
            return f.value(at: mid) >= 0 ? " — f is positive there, so it goes the same way as f" : " — f is negative there, so squaring reverses the direction"
        case .absolute:
            return f.value(at: mid) >= 0 ? " — f is above the axis there: unchanged" : " — f is below the axis there: flipped, so the opposite way"
        case .mirror:
            return " — f read from right to left"
        case .derivative:
            return rises ? " — f bends up (∪) there, so its slope grows" : " — f bends down (∩) there, so its slope shrinks"
        }
    }

    /// How the rule acts, in words (no values).
    static func explanation(_ c: ChangeProblem) -> [String] {
        switch c.transform {
        case .shift(let k):
            return ["Every point moves \(Swift.abs(k)) \(k > 0 ? "up" : "down"). The shape stays exactly the same.",
                    "Peaks stay peaks and dips stay dips, at the same x."]
        case .negate:
            return ["Reflect in the x-axis: every height changes sign.",
                    "Peaks become dips and dips become peaks; points on the x-axis stay."]
        case .scale(let p, let q):
            let k = Double(p) / Double(q)
            return ["Every height is multiplied by \(num(k))\(k < 0 ? ", which also flips the graph" : ""): the graph is \(Swift.abs(k) > 1 ? "stretched away from" : "squashed towards") the x-axis.",
                    "Points on the x-axis stay; peaks and dips stay at the same x\(k < 0 ? " but swap" : "")."]
        case .negateShift(let k):
            return ["First reflect in the x-axis (−f), then move everything \(Swift.abs(k)) \(k > 0 ? "up" : "down").",
                    "Peaks of f become dips of g and vice versa."]
        case .absolute:
            return ["Keep the parts of f above the x-axis; flip the parts below it upwards.",
                    "Where f crosses the x-axis, g just touches it — usually with a sharp corner.",
                    "g is never below the x-axis."]
        case .mirror:
            return ["Reflect in the y-axis: what f does at x, g does at −x.",
                    "The picture is reversed left to right; heights don't change."]
        case .reciprocal:
            return ["Same x, height 1 ÷ (height of f). The sign stays the same.",
                    "f never reaches 0 on this interval, so g has no vertical asymptote here.",
                    "Big becomes small and small becomes big: a peak of f becomes a dip of g, and a dip becomes a peak.",
                    "Where f is at height 1 (or −1), g is there too — the graphs meet."]
        case .square:
            return ["Same x, height squared: g is never below the x-axis.",
                    "Heights further than 1 from the axis grow, heights closer than 1 shrink towards 0.",
                    "Where f crosses the x-axis, g touches it smoothly (a dip of g)."]
        case .reciprocalSquare:
            return ["Same x, height 1 ÷ (height of f)²: g is always positive.",
                    "f is never 0 here, so there are no vertical asymptotes on this interval.",
                    "Where f is furthest from the axis g is lowest; where f is closest g is highest."]
        case .squareRoot:
            return ["Same x, height √(height of f) — f is never negative here.",
                    "√ keeps the order (g rises where f rises) but pulls every height towards 1."]
        case .derivative:
            return ["g = f′ is the slope of f at each x.",
                    "Where f rises g is above the x-axis, where f falls g is below it.",
                    "At peaks and dips of f the slope is 0: g crosses the x-axis there.",
                    "Where f is steepest (its inflection points) g has its peaks and dips."]
        }
    }

    // MARK: Helpers

    /// Roots by scanning for sign changes and refining with bisection
    /// (also catches touching zeros where |value| is tiny at a local extremum).
    static func roots(of e: Expr, in range: ClosedRange<Double>) -> [Double] {
        let n = 600
        let a = range.lowerBound, b = range.upperBound
        let xs = (0...n).map { a + (b - a) * Double($0) / Double(n) }
        let ys = xs.map { e.evaluate(at: $0) }
        let scale = ys.filter { $0.isFinite }.map { Swift.abs($0) }.max() ?? 1
        var out: [Double] = []
        for i in 0..<n where ys[i].isFinite && ys[i + 1].isFinite {
            if ys[i] == 0 { out.append(xs[i]); continue }
            if (ys[i] < 0) != (ys[i + 1] < 0) {
                var lo = xs[i], hi = xs[i + 1], flo = ys[i]
                for _ in 0..<60 {
                    let mid = (lo + hi) / 2, fm = e.evaluate(at: mid)
                    if (fm < 0) == (flo < 0) { lo = mid; flo = fm } else { hi = mid }
                }
                out.append((lo + hi) / 2)
            }
        }
        // Touching zeros (e.g. x² at 0).
        for i in 1..<n where ys[i].isFinite && Swift.abs(ys[i]) < 1e-6 * Swift.max(scale, 1e-9) {
            let isExt = (Swift.abs(ys[i]) <= Swift.abs(ys[i - 1])) && (Swift.abs(ys[i]) <= Swift.abs(ys[i + 1]))
            if isExt, !out.contains(where: { Swift.abs($0 - xs[i]) < 3 * (b - a) / Double(n) }) { out.append(xs[i]) }
        }
        // Merge duplicates, and drop roots on the interval ends (reported as end points).
        let eps = 1e-6 * (b - a)
        var merged: [Double] = []
        for x in out.sorted() where x > a + eps && x < b - eps {
            if let last = merged.last, x - last < 2.5 * (b - a) / Double(n) { continue }
            merged.append(x)
        }
        return merged
    }

    static func domainNote(_ f: Expr) -> String {
        var notes: [String] = []
        if f.contains(.ln) { notes.append("ln needs a positive argument") }
        if f.contains(.sqrt) { notes.append("√ needs a non-negative argument") }
        if f.hasDivision { notes.append("a denominator must not be 0") }
        return notes.isEmpty ? "f is defined for every x." : notes.joined(separator: "; ") + "."
    }

    static func bare(_ label: String) -> String {
        label.hasPrefix("≈ ") ? String(label.dropFirst(2)) : label
    }

    static func equation(_ label: String, _ v: String = "x") -> String {
        label.hasPrefix("≈ ") ? "\(v) \(label)" : "\(v) = \(label)"
    }

    /// Integers exactly, otherwise 3 significant digits ("≈ 1.37" with `approx`).
    static func num(_ v: Double, approx: Bool = false) -> String {
        if !v.isFinite { return "undefined" }
        if Swift.abs(v - v.rounded()) < 1e-9 { return (approx ? "= " : "") + SketchFormat.number(Swift.abs(v) < 1e-9 ? 0 : v.rounded()) }
        return (approx ? "≈ " : "") + String(format: "%.3g", v).replacingOccurrences(of: "-", with: "−")
    }
}

extension Expr {
    func contains(_ fn: Fn) -> Bool {
        switch self {
        case .fn(let f, let a): return f == fn || a.contains(fn)
        case .num, .x, .pi, .e, .constC: return false
        case .neg(let a): return a.contains(fn)
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b),
             .div(let a, let b), .pow(let a, let b): return a.contains(fn) || b.contains(fn)
        }
    }

    var hasDivision: Bool {
        switch self {
        case .div(_, let b): return b.containsX || true
        case .fn(_, let a), .neg(let a): return a.hasDivision
        case .num, .x, .pi, .e, .constC: return false
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b), .pow(let a, let b):
            return a.hasDivision || b.hasDivision
        }
    }
}
