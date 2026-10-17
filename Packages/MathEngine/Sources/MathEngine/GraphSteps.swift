import Foundation

/// Worked "how to draw it" solutions for Graph Sketch and Change: the
/// standard function investigation (domain, intercepts, f′ and extrema,
/// increase/decrease, f″ and inflection points, asymptotes, key points).
public enum GraphSteps {
    public static func steps(for p: SketchProblem, name: String = "f") -> [SolutionStep] {
        let f = p.function
        let a = p.xMin, b = p.xMax
        let d1 = f.derivative()
        let d2 = d1.derivative()
        func X(_ x: Double) -> String { p.xLabel(x) }
        func Y(_ y: Double) -> String { num(y) }

        var steps: [SolutionStep] = []
        steps.append(SolutionStep("The function:", label: "\(name)(x) =", math: f))

        // 1. Domain and asymptotes
        steps.append(SolutionStep("1. Domain: \(domainNote(f)) On the interval \(X(a)) ≤ x ≤ \(X(b)) it is defined and continuous, so there are no vertical asymptotes here (and on a closed interval no horizontal ones either)."))

        // 2. End points and intercepts
        steps.append(SolutionStep("2. End points: \(name)(\(X(a))) = \(Y(f.evaluate(at: a))) and \(name)(\(X(b))) = \(Y(f.evaluate(at: b)))."))
        let zs = roots(of: f, in: a...b)
        var intercepts = zs.isEmpty
            ? "The graph never crosses the x-axis here (no solutions of \(name)(x) = 0)."
            : "x-intercepts (\(name)(x) = 0): x = " + zs.map(X).joined(separator: ", ") + "."
        if a < 0 && b > 0 { intercepts += " y-intercept: \(name)(0) = \(Y(f.evaluate(at: 0)))." }
        steps.append(SolutionStep("3. Intercepts: " + intercepts))

        // 3. First derivative: extrema and monotonicity
        steps.append(SolutionStep("4. Derivative (for peaks, dips and where it rises/falls):", label: "\(name)′(x) =", math: d1.size <= 45 ? d1 : nil))
        let crit = roots(of: d1, in: a...b)
        if crit.isEmpty {
            let up = d1.evaluate(at: (a + b) / 2) > 0
            steps.append(SolutionStep("\(name)′(x) = 0 has no solution here: \(name) is \(up ? "increasing" : "decreasing") on the whole interval.", depth: 1))
        } else {
            for c in crit {
                let l = d1.evaluate(at: c - 1e-4 * (b - a)), r = d1.evaluate(at: c + 1e-4 * (b - a))
                let kind = l > 0 && r < 0 ? "maximum (peak)" : (l < 0 && r > 0 ? "minimum (dip)" : "flat point (no turn)")
                steps.append(SolutionStep("\(name)′(\(X(c))) = 0 → local \(kind) at (\(X(c)), \(Y(f.evaluate(at: c))))", depth: 1))
            }
            steps.append(SolutionStep(monotonicity(d1, cuts: crit, a: a, b: b, X: X, name: name), depth: 1))
        }

        // 4. Second derivative: concavity and inflection points
        let infl = roots(of: d2, in: a...b).filter { x in
            let e = 1e-3 * (b - a)
            return (d2.evaluate(at: x - e) < 0) != (d2.evaluate(at: x + e) < 0)
        }
        steps.append(SolutionStep("5. Second derivative (for bending / inflection points):", label: "\(name)″(x) =", math: d2.size <= 45 ? d2 : nil))
        if infl.isEmpty {
            let up = d2.evaluate(at: (a + b) / 2) > 0
            steps.append(SolutionStep("No inflection points: the graph bends \(up ? "upwards (∪, convex)" : "downwards (∩, concave)") throughout.", depth: 1))
        } else {
            steps.append(SolutionStep("Inflection points (\(name)″ changes sign): " + infl.map { "(\(X($0)), \(Y(f.evaluate(at: $0))))" }.joined(separator: ", ") + ".", depth: 1))
            steps.append(SolutionStep(concavity(d2, cuts: infl, a: a, b: b, X: X), depth: 1))
        }

        // 5. Key points in drawing order
        var key: [(Double, String)] = [(a, "start"), (b, "end")]
        key += zs.map { ($0, "crosses/touches the x-axis") }
        key += crit.map { c in
            let l = d1.evaluate(at: c - 1e-4 * (b - a))
            return (c, l > 0 ? "peak" : "dip")
        }
        key += infl.map { ($0, "inflection") }
        var seen: [Double] = []
        let ordered = key.sorted { $0.0 < $1.0 }.filter { k in
            if seen.contains(where: { Swift.abs($0 - k.0) < 1e-6 * (b - a + 1) }) { return false }
            seen.append(k.0); return true
        }
        steps.append(SolutionStep("6. Plot these points from left to right and join them, rising/falling and bending as found above:"))
        for (x, what) in ordered {
            steps.append(SolutionStep("(\(X(x)), \(Y(f.evaluate(at: x))))  — \(what)", depth: 1))
        }
        return steps
    }

    /// Change: first how the transformation acts on f, then the full
    /// investigation of g.
    public static func steps(for c: ChangeProblem) -> [SolutionStep] {
        var steps: [SolutionStep] = []
        steps.append(SolutionStep("Given:", label: "f(x) =", math: c.base.function))
        steps.append(SolutionStep("Task: \(c.transform.formula)"))
        steps.append(SolutionStep("How the change acts on the graph of f:"))
        for line in explanation(c) {
            steps.append(SolutionStep(line, depth: 1))
        }
        steps.append(SolutionStep("Now investigate g directly:"))
        var g = c.target
        g.yMin = c.target.yMin
        steps += self.steps(for: g, name: "g")
        return steps
    }

    static func explanation(_ c: ChangeProblem) -> [String] {
        let f = c.base
        let fz = roots(of: f.function, in: f.xMin...f.xMax).map(f.xLabel)
        let fCrit = roots(of: f.function.derivative(), in: f.xMin...f.xMax).map(f.xLabel)
        let zerosText = fz.isEmpty ? "f has no zeros here" : "f is zero at x = " + fz.joined(separator: ", ")
        let critText = fCrit.isEmpty ? "f has no peaks or dips here" : "f turns at x = " + fCrit.joined(separator: ", ")
        switch c.transform {
        case .shift(let k):
            return ["Every point moves \(Swift.abs(k)) \(k > 0 ? "up" : "down"). The shape is unchanged.",
                    "\(critText) — g turns at the same x values.",
                    "Zeros of f are not zeros of g any more (they move to y = \(k))."]
        case .negate:
            return ["Reflect in the x-axis: every height changes sign.",
                    "Peaks of f become dips of g and vice versa (\(critText)).",
                    "\(zerosText) — these stay zeros of g."]
        case .scale(let p, let q):
            let k = Double(p) / Double(q)
            return ["Every height is multiplied by \(num(k))\(k < 0 ? " (which also flips the graph)" : "").",
                    "\(zerosText) — zeros stay zeros.",
                    "\(critText) — g turns at the same x values."]
        case .negateShift(let k):
            return ["First reflect in the x-axis (−f), then move \(Swift.abs(k)) \(k > 0 ? "up" : "down").",
                    "Peaks of f become dips of g and vice versa (\(critText))."]
        case .absolute:
            return ["Keep the parts of f above the x-axis; flip the parts below it upwards.",
                    "\(zerosText) — there g touches the x-axis, usually with a sharp corner.",
                    "g is never below the x-axis."]
        case .mirror:
            return ["Reflect in the y-axis: the value at x moves to −x.",
                    "A peak of f at x = a becomes a peak of g at x = −a; the same for zeros."]
        case .reciprocal:
            return ["g = 1/f has the same sign as f everywhere.",
                    "f never reaches 0 on this interval, so g has no vertical asymptote here.",
                    "Where f is large, g is small and vice versa: a peak of f becomes a dip of g (\(critText)).",
                    "If f = 1 somewhere, g = 1 there too — the graphs meet at height 1."]
        case .square:
            return ["Every height is squared, so g ≥ 0 everywhere.",
                    "\(zerosText) — there g touches the x-axis smoothly (a double zero).",
                    "Where |f| > 1 the graph is stretched up; where |f| < 1 it is pulled towards 0.",
                    "\(critText) — those are turning points of g too; new dips appear at f's zeros."]
        case .reciprocalSquare:
            return ["g = 1/f² is always positive.",
                    "f is never 0 here, so no vertical asymptotes on this interval.",
                    "Where |f| is largest, g is lowest; where |f| is smallest, g is highest.",
                    "\(critText) — so g turns at the same x values, with peaks and dips swapped (when f > 0)."]
        case .squareRoot:
            return ["g = √f needs f ≥ 0 (true on this interval).",
                    "√ keeps the order: g rises where f rises and falls where f falls (\(critText)).",
                    "Heights move towards 1: values above 1 shrink, values below 1 grow."]
        case .derivative:
            return ["g = f′ is the slope of f.",
                    "\(critText) — at those x values g = 0 (crosses the x-axis).",
                    "Where f rises, g is above the x-axis; where f falls, g is below it.",
                    "Inflection points of f (steepest slope) become peaks or dips of g."]
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
        // Drop roots sitting exactly on the interval ends (reported as end points).
        let eps = 1e-6 * (b - a)
        return out.sorted().filter { $0 > a + eps && $0 < b - eps }
    }

    static func monotonicity(_ d1: Expr, cuts: [Double], a: Double, b: Double, X: (Double) -> String, name: String) -> String {
        let pts = [a] + cuts + [b]
        var parts: [String] = []
        for (l, r) in zip(pts, pts.dropFirst()) where r - l > 1e-9 {
            let up = d1.evaluate(at: (l + r) / 2) > 0
            parts.append("\(up ? "increasing" : "decreasing") on \(X(l)) < x < \(X(r))")
        }
        return "\(name) is " + parts.joined(separator: "; ") + "."
    }

    static func concavity(_ d2: Expr, cuts: [Double], a: Double, b: Double, X: (Double) -> String) -> String {
        let pts = [a] + cuts + [b]
        var parts: [String] = []
        for (l, r) in zip(pts, pts.dropFirst()) where r - l > 1e-9 {
            let up = d2.evaluate(at: (l + r) / 2) > 0
            parts.append("bends \(up ? "up ∪" : "down ∩") on \(X(l)) < x < \(X(r))")
        }
        return parts.joined(separator: "; ") + "."
    }

    static func domainNote(_ f: Expr) -> String {
        var notes: [String] = []
        if f.contains(.ln) { notes.append("ln needs a positive argument") }
        if f.contains(.sqrt) { notes.append("√ needs a non-negative argument") }
        if f.hasDivision { notes.append("a denominator must not be 0") }
        return notes.isEmpty ? "defined for every x." : notes.joined(separator: "; ") + "."
    }

    static func num(_ v: Double) -> String {
        if !v.isFinite { return "undefined" }
        if Swift.abs(v - v.rounded()) < 1e-9 { return SketchFormat.number(v.rounded()) }
        return String(format: "%.3g", v).replacingOccurrences(of: "-", with: "−")
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
