import Foundation

/// A solution of an equation, with an exact label when there is one
/// ("−√6/2", "π/3", "e^(−1/2)") or an approximation ("≈ 1.37").
struct AlgebraRoot {
    var x: Double
    var label: String
}

/// The worked lines for solving "… = 0", and the solutions.
struct Solved {
    var lines: [SolutionStep] = []
    var roots: [AlgebraRoot] = []
    /// False when some roots are only approximations.
    var exact = true

    mutating func say(_ text: String, depth: Int = 1) { lines.append(SolutionStep(text, depth: depth)) }

    mutating func append(_ other: Solved, indent: Int = 0) {
        lines += other.lines.map { var s = $0; s.depth += indent; return s }
        roots += other.roots
        exact = exact && other.exact
    }
}

/// f′ or f″ written in factored form, and how to solve it = 0.
struct Factored {
    var display: Expr
    var solve: Solved
}

/// What a generator family knows exactly about its function.
struct Investigation {
    var zeros: Solved?
    var d1: Factored?
    var d2: Factored?
}

// MARK: - Equation solving with worked lines

struct Solver {
    let a: Double
    let b: Double
    let piBased: Bool

    // MARK: Text helpers

    static func minus(_ s: String) -> String { s.replacingOccurrences(of: "-", with: "−") }

    /// n/d reduced, e.g. "−3/2" or "2".
    static func frac(_ n: Int, _ d: Int) -> String {
        var n = n, d = d
        if d < 0 { n = -n; d = -d }
        let g = gcd(Swift.abs(n), d)
        n /= g; d /= g
        return minus(d == 1 ? "\(n)" : "\(n)/\(d)")
    }

    static func sup(_ k: Int) -> String {
        let digits: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴", "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"]
        return String(String(k).map { digits[$0] ?? $0 })
    }

    static func power(_ v: String, _ k: Int) -> String { k == 1 ? v : v + sup(k) }

    /// Integer coefficients, highest power first: [2, 0, −3] → "2x² − 3".
    static func polyText(_ c: [Int], _ v: String = "x") -> String {
        let deg = c.count - 1
        var out = ""
        for (i, k) in c.enumerated() where k != 0 {
            let p = deg - i
            let mag = Swift.abs(k)
            let body = p == 0 ? "\(mag)" : (mag == 1 ? "" : "\(mag)") + power(v, p)
            if out.isEmpty { out = (k < 0 ? "−" : "") + body } else { out += (k < 0 ? " − " : " + ") + body }
        }
        return out.isEmpty ? "0" : out
    }

    /// Polynomial with integer coefficients as an expression.
    static func polyExpr(_ c: [Int]) -> Expr {
        let deg = c.count - 1
        return .sum(c.enumerated().map { i, k in
            let p = deg - i
            let xp: Expr = p == 0 ? 1 : (p == 1 ? .x : .p(.x, p))
            return .scaled(k, 1, xp)
        })
    }

    /// √n = out·√in with `in` square-free.
    static func sqrtParts(_ n: Int) -> (out: Int, inner: Int) {
        var out = 1, inner = n, f = 2
        while f * f <= inner {
            while inner % (f * f) == 0 { inner /= f * f; out *= f }
            f += 1
        }
        return (out, inner)
    }

    /// Label of (p + sign·s·√r)/q.
    static func radicalLabel(_ p: Int, _ s: Int, _ r: Int, _ q: Int) -> String {
        var p = p, s = s, q = q
        if q < 0 { p = -p; s = -s; q = -q }
        let g = gcd(gcd(Swift.abs(p), Swift.abs(s)), q)
        p /= g; s /= g; q /= g
        let rad = (Swift.abs(s) == 1 ? "" : "\(Swift.abs(s))") + "√\(r)"
        let top = p == 0 ? (s < 0 ? "−" + rad : rad) : minus("\(p)") + (s < 0 ? " − " : " + ") + rad
        if q == 1 { return top }
        return p == 0 ? "\(top)/\(q)" : "(\(top))/\(q)"
    }

    static func approx(_ v: Double) -> String { "≈ " + GraphSteps.num(v) }

    /// "π/3" when x is a multiple of π/12 (exactly), otherwise "≈ 1.05".
    func xLabel(_ x: Double, exact: Bool) -> String {
        if Swift.abs(x) < 1e-12 { return "0" }
        let twelfths = x / (Double.pi / 12)
        if exact, Swift.abs(twelfths - twelfths.rounded()) < 1e-7 { return SketchFormat.x(x, piBased: true) }
        return Self.approx(x)
    }

    func inside(_ x: Double) -> Bool {
        let eps = 1e-9 * (b - a)
        return x > a + eps && x < b - eps
    }

    // MARK: Building blocks

    /// A factor that is never 0.
    func never(_ factor: String, _ reason: String) -> Solved {
        var s = Solved()
        s.say("\(factor) = 0 has no solution: \(reason).")
        return s
    }

    /// One factor = 0 per part; the solutions are all of theirs.
    func product(_ parts: [(String, Solved)]) -> Solved {
        var s = Solved()
        s.say("A product is 0 exactly when one of its factors is 0:")
        for (name, part) in parts {
            s.say("• \(name) = 0", depth: 1)
            s.append(part, indent: 1)
        }
        return s
    }

    /// Numerator = 0 (the denominator is never 0 here).
    func fraction(_ numerator: String, _ part: Solved, denominator: String, reason: String) -> Solved {
        var s = Solved()
        s.say("A fraction is 0 when its numerator is 0. The denominator \(denominator) is \(reason), so solve \(numerator) = 0:")
        s.append(part)
        return s
    }

    /// Polynomial with integer coefficients (highest first) = 0, solved exactly:
    /// common factor, linear, quadratic (discriminant), biquadratic, rational
    /// roots; numerically only if none of that works.
    func poly(_ coeffs: [Int], _ v: String = "x", range: ClosedRange<Double>? = nil) -> Solved {
        var c = Array(coeffs.drop { $0 == 0 })
        var s = Solved()
        guard !c.isEmpty else { s.say("This is 0 for every \(v)."); return s }
        if c.count == 1 {
            s.say("\(Self.polyText(c, v)) ≠ 0, so there is no solution.")
            return s
        }
        var k = 0
        while c.last == 0 { c.removeLast(); k += 1 }
        if k > 0 {
            let common = Self.power(v, k)
            if c.count == 1 {
                let k0 = c[0]
                s.say("\(k0 == 1 ? "" : (k0 == -1 ? "−" : Self.minus("\(k0)")))\(common) = 0  ⇒  \(v) = 0")
                s.roots.append(AlgebraRoot(x: 0, label: "0"))
                return s
            }
            s.say("Take out the common factor \(common):  \(common)·(\(Self.polyText(c, v))) = 0")
            s.say("\(common) = 0  ⇒  \(v) = 0", depth: 2)
            s.roots.append(AlgebraRoot(x: 0, label: "0"))
            var rest = poly(c, v, range: range)
            rest.lines = rest.lines.map { var l = $0; l.depth += 1; return l }
            s.append(rest)
            return s
        }
        let text = Self.polyText(c, v)
        switch c.count - 1 {
        case 1:
            s.say("\(text) = 0  ⇒  \(v) = \(Self.frac(-c[1], c[0]))")
            s.roots.append(AlgebraRoot(x: -Double(c[1]) / Double(c[0]), label: Self.frac(-c[1], c[0])))
        case 2:
            s.append(quadratic(c[0], c[1], c[2], v))
        case 4 where c[1] == 0 && c[3] == 0:
            s.say("Only even powers: substitute t = \(v)²:  \(Self.polyText([c[0], c[2], c[4]], "t")) = 0")
            let t = quadratic(c[0], c[2], c[4], "t")
            s.lines += t.lines.map { var l = $0; l.depth += 1; return l }
            for root in t.roots {
                if root.x < -1e-12 {
                    s.say("t = \(root.label) < 0: \(v)² can't be negative, no solution.", depth: 2)
                } else if Swift.abs(root.x) < 1e-12 {
                    s.say("t = 0  ⇒  \(v) = 0", depth: 2)
                    s.roots.append(AlgebraRoot(x: 0, label: "0"))
                } else {
                    let r = root.x.squareRoot()
                    let lbl = sqrtLabel(of: root)
                    s.say("\(v)² = \(root.label)  ⇒  \(v) = ±\(lbl)  (\(Self.approx(r)))", depth: 2)
                    s.roots.append(AlgebraRoot(x: r, label: lbl))
                    s.roots.append(AlgebraRoot(x: -r, label: lbl.hasPrefix("(") || !lbl.contains(" ") ? "−" + lbl : "−(\(lbl))"))
                }
            }
        default:
            if let (p, q) = rationalRoot(c) {
                let r = Self.frac(p, q)
                s.say("Try \(v) = \(r) (rational root test: ± divisors of \(Swift.abs(c.last!)) over divisors of \(Swift.abs(c[0]))): it gives 0.")
                s.roots.append(AlgebraRoot(x: Double(p) / Double(q), label: r))
                let quotient = divide(c, p, q)
                let factorText = q == 1 ? Self.polyText([1, -p], v) : Self.polyText([q, -p], v)
                s.say("So (\(factorText)) is a factor:  (\(factorText))·(\(Self.polyText(quotient, v))) = 0")
                s.append(poly(quotient, v, range: range))
            } else {
                s.say("\(text) = 0 has no rational solutions (rational root test), and there's no formula worth using by hand, so the solutions are found from sign changes (intermediate value theorem):")
                s.append(numeric(Self.polyExpr(c), name: text, range: range))
            }
        }
        return s
    }

    /// √(label) for a root t of a quadratic, simplified when t is rational.
    func sqrtLabel(of t: AlgebraRoot) -> String {
        // Rational t = n/d: √(n/d) = √(n·d)/d.
        for d in 1...48 {
            let n = t.x * Double(d)
            if Swift.abs(n - n.rounded()) < 1e-9, n.rounded() > 0 {
                let num = Int(n.rounded())
                let (o, i) = Self.sqrtParts(num * d)
                if i == 1 { return Self.frac(o, d) }
                return Self.radicalLabel(0, o, i, d)
            }
        }
        return "√(\(t.label))"
    }

    func quadratic(_ a2: Int, _ b1: Int, _ c0: Int, _ v: String) -> Solved {
        var s = Solved()
        let text = Self.polyText([a2, b1, c0], v)
        let disc = b1 * b1 - 4 * a2 * c0
        s.say("\(text) = 0:  Δ = b² − 4ac = \(Self.minus("\(b1 * b1)")) − 4·\(Self.minus("\(a2)"))·\(Self.minus("\(c0)")) = \(Self.minus("\(disc)"))")
        if disc < 0 {
            s.say("Δ < 0, so there are no real solutions.", depth: 2)
            return s
        }
        if disc == 0 {
            let lbl = Self.frac(-b1, 2 * a2)
            s.say("Δ = 0: one (double) solution  \(v) = −b/(2a) = \(lbl)", depth: 2)
            s.roots.append(AlgebraRoot(x: -Double(b1) / Double(2 * a2), label: lbl))
            return s
        }
        let (o, i) = Self.sqrtParts(disc)
        let sq = Double(disc).squareRoot()
        let r1 = (-Double(b1) + sq) / Double(2 * a2), r2 = (-Double(b1) - sq) / Double(2 * a2)
        let l1: String, l2: String
        if i == 1 {
            l1 = Self.frac(-b1 + o, 2 * a2)
            l2 = Self.frac(-b1 - o, 2 * a2)
        } else {
            l1 = Self.radicalLabel(-b1, o, i, 2 * a2)
            l2 = Self.radicalLabel(-b1, -o, i, 2 * a2)
        }
        s.say("\(v) = (−b ± √Δ)/(2a) = (\(Self.minus("\(-b1)")) ± √\(disc))/\(2 * a2)  ⇒  \(v) = \(l1)\(i == 1 ? "" : " (\(Self.approx(r1)))")  or  \(v) = \(l2)\(i == 1 ? "" : " (\(Self.approx(r2)))")", depth: 2)
        s.roots.append(AlgebraRoot(x: r1, label: l1))
        s.roots.append(AlgebraRoot(x: r2, label: l2))
        return s
    }

    /// A rational root p/q of an integer polynomial, if any.
    func rationalRoot(_ c: [Int]) -> (Int, Int)? {
        guard let last = c.last, last != 0, let lead = c.first else { return nil }
        func divisors(_ n: Int) -> [Int] { (1...Swift.max(1, Swift.abs(n))).filter { Swift.abs(n) % $0 == 0 } }
        for q in divisors(lead) {
            for p in divisors(last) {
                for sp in [p, -p] {
                    let x = Double(sp) / Double(q)
                    let v = c.reduce(0.0) { $0 * x + Double($1) }
                    if Swift.abs(v) < 1e-9 { return (sp, q) }
                }
            }
        }
        return nil
    }

    /// Divides an integer polynomial by (q·x − p) (p/q is a root).
    func divide(_ c: [Int], _ p: Int, _ q: Int) -> [Int] {
        // Synthetic division by (x − p/q) in Doubles, then scale by q.
        let r = Double(p) / Double(q)
        var out: [Double] = []
        var acc = 0.0
        for k in c.dropLast() {
            acc = acc * r + Double(k)
            out.append(acc)
        }
        // P(x) = (x − r)·Q(x) = (qx − p)·Q(x)/q.
        return out.map { Int(($0 / Double(q)).rounded()) }
    }

    enum Trig { case sin, cos, tan }

    /// sin/cos/tan(p/q · x) = value, with the general solution and the
    /// values inside the interval.
    func trig(_ t: Trig, _ p: Int, _ q: Int, _ value: Double, _ valueText: String) -> Solved {
        var s = Solved()
        let g = gcd(Swift.abs(p), Swift.abs(q))
        let p = p / g, q = q / g
        let arg: String = {
            if p == 1 && q == 1 { return "x" }
            if q == 1 { return "\(p)x" }
            return p == 1 ? "x/\(q)" : "\(p)x/\(q)"
        }()
        let name: String = { switch t { case .sin: "sin"; case .cos: "cos"; case .tan: "tan" } }()
        let fnText = arg == "x" ? "\(name) x" : "\(name)(\(arg))"
        s.say("\(fnText) = \(valueText)")
        if t != .tan, Swift.abs(value) > 1 + 1e-12 {
            s.say("Impossible: \(name) is always between −1 and 1. No solution.", depth: 2)
            return s
        }
        let alpha: Double
        switch t {
        case .sin: alpha = asin(Swift.max(-1, Swift.min(1, value)))
        case .cos: alpha = acos(Swift.max(-1, Swift.min(1, value)))
        case .tan: alpha = atan(value)
        }
        let nice = Swift.abs(alpha / (Double.pi / 12) - (alpha / (Double.pi / 12)).rounded()) < 1e-9
        let alphaText = nice ? (Swift.abs(alpha) < 1e-12 ? "0" : SketchFormat.x(alpha, piBased: true))
                             : "arc\(name)(\(valueText))"
        let bases: [Double]
        let period: Double
        switch t {
        case .sin:
            bases = [alpha, Double.pi - alpha]
            period = 2 * Double.pi
            if nice, Swift.abs(Swift.abs(alpha) - Double.pi / 2) < 1e-12 {
                s.say("⇒ \(arg) = \(alphaText) + 2πn", depth: 2)
            } else if nice, Swift.abs(alpha) < 1e-12 {
                s.say("⇒ \(arg) = πn", depth: 2)
            } else {
                s.say("⇒ \(arg) = \(alphaText) + 2πn  or  \(arg) = π − \(alphaText) + 2πn", depth: 2)
            }
        case .cos:
            bases = [alpha, -alpha]
            period = 2 * Double.pi
            if nice, Swift.abs(alpha - Double.pi / 2) < 1e-12 {
                s.say("⇒ \(arg) = π/2 + πn", depth: 2)
            } else if nice, Swift.abs(alpha) < 1e-12 || Swift.abs(alpha - Double.pi) < 1e-12 {
                s.say("⇒ \(arg) = \(alphaText) + 2πn", depth: 2)
            } else {
                s.say("⇒ \(arg) = ±\(alphaText) + 2πn", depth: 2)
            }
        case .tan:
            bases = [alpha]
            period = Double.pi
            s.say("⇒ \(arg) = \(alphaText) + πn", depth: 2)
        }
        let m = Double(p) / Double(q)
        var xs: [Double] = []
        for base in bases {
            for n in -40...40 {
                let x = (base + period * Double(n)) / m
                if inside(x), !xs.contains(where: { Swift.abs($0 - x) < 1e-9 }) { xs.append(x) }
            }
        }
        xs.sort()
        let labels = xs.map { xLabel($0, exact: nice) }
        if xs.isEmpty {
            s.say("None of these lie inside the interval.", depth: 2)
        } else {
            s.say("Inside the interval (n = …, −1, 0, 1, …):  x = " + labels.joined(separator: ",  "), depth: 2)
        }
        s.roots += zip(xs, labels).map { AlgebraRoot(x: $0, label: $1) }
        return s
    }

    /// Quadratic in s = sin x, then sin x = s for each solution.
    func sinPoly(_ c: [Int]) -> Solved {
        var s = Solved()
        s.say("Substitute s = sin x  (−1 ≤ s ≤ 1):")
        let sp = poly(c, "s", range: -1...1)
        var spLines = sp
        spLines.roots = []
        s.append(spLines, indent: 1)
        for root in sp.roots {
            if Swift.abs(root.x) > 1 + 1e-12 {
                s.say("s = \(root.label) \(Self.approx(root.x)) is outside [−1, 1]: no x.", depth: 2)
            } else {
                s.append(trig(.sin, 1, 1, root.x, root.label), indent: 1)
            }
        }
        return s
    }

    /// ln x = n/d.
    func lnEquals(_ n: Int, _ d: Int, prefix: String? = nil) -> Solved {
        var s = Solved()
        let v = Self.frac(n, d)
        let label = n == 0 ? "1" : (v == "1" ? "e" : "e^(\(v))")
        if let prefix { s.say(prefix) }
        s.say("ln x = \(v)  ⇒  x = \(label)\(n == 0 ? "" : "  (\(Self.approx(exp(Double(n) / Double(d)))))")")
        s.roots.append(AlgebraRoot(x: exp(Double(n) / Double(d)), label: label))
        return s
    }

    /// eˣ = k.
    func expEquals(_ k: Int) -> Solved {
        var s = Solved()
        let label = k == 1 ? "0" : "ln \(k)"
        s.say("eˣ = \(k)  ⇒  x = \(label)\(k == 1 ? "" : "  (\(Self.approx(log(Double(k)))))")")
        s.roots.append(AlgebraRoot(x: log(Double(k)), label: label))
        return s
    }

    /// Solutions from sign changes, for equations algebra can't solve.
    func numeric(_ e: Expr, name: String, range: ClosedRange<Double>? = nil) -> Solved {
        var s = Solved()
        s.exact = false
        let r = range ?? a...b
        let found = GraphSteps.roots(of: e, in: r)
        if found.isEmpty {
            s.say("\(name) doesn't change sign on the interval, so it has no solution here.", depth: 2)
        }
        let h = (r.upperBound - r.lowerBound) / 200
        for x in found {
            let l = e.evaluate(at: x - h), rr = e.evaluate(at: x + h)
            let change = (l < 0) != (rr < 0)
            s.say(change
                  ? "x \(Self.approx(x)):  \(name) is \(l < 0 ? "negative" : "positive") just before and \(rr < 0 ? "negative" : "positive") just after"
                  : "x \(Self.approx(x)):  \(name) touches 0 there", depth: 2)
            s.roots.append(AlgebraRoot(x: x, label: Self.approx(x)))
        }
        return s
    }
}

// MARK: - Family investigations

enum GraphAlgebra {
    /// Exact derivative forms and solving steps for a generated function,
    /// nil if the problem has no family (then everything is numeric).
    static func investigate(_ p: SketchProblem) -> Investigation? {
        guard let fam = p.family else { return nil }
        let S = Solver(a: p.xMin, b: p.xMax, piBased: p.piBased)
        let x = Expr.x
        let q = fam.p
        func P(_ c: [Int]) -> Expr { Solver.polyExpr(c) }
        func pt(_ c: [Int], _ v: String = "x") -> String { Solver.polyText(c, v) }
        func lin(_ k: Int) -> Expr { .scaled(k, 1, x) }
        func arg(_ k: Int) -> String { k == 1 ? "x" : "\(k)x" }
        let expText = "an exponential is always positive"
        var inv: Investigation

        switch fam.kind {
        case .quadRoots:
            let (a, r1, r2) = (q[0], q[1], q[2])
            var z = Solved()
            z.say("f(x) = \(a == 1 ? "" : (a == -1 ? "−" : "\(Solver.minus("\(a)"))"))(\(pt([1, -r1])))(\(pt([1, -r2]))) is already factored:")
            z.say("x = \(Solver.minus("\(r1)"))  or  x = \(Solver.minus("\(r2)"))", depth: 2)
            z.roots = [AlgebraRoot(x: Double(r1), label: Solver.minus("\(r1)")), AlgebraRoot(x: Double(r2), label: Solver.minus("\(r2)"))]
            inv = Investigation(zeros: z,
                                d1: Factored(display: .scaled(a, 1, P([2, -(r1 + r2)])), solve: S.poly([2, -(r1 + r2)])),
                                d2: Factored(display: .n(2 * a), solve: S.never("f″(x) = \(Solver.minus("\(2 * a)"))", "it is a nonzero constant")))
        case .trigSin, .trigCos:
            let (k, m) = (q[0], q[1])
            let sinF = fam.kind == .trigSin
            inv = Investigation(
                zeros: sinF ? S.trig(.sin, m, 1, 0, "0") : S.trig(.cos, m, 1, 0, "0"),
                d1: sinF ? Factored(display: .scaled(k * m, 1, .cos(lin(m))), solve: S.trig(.cos, m, 1, 0, "0"))
                         : Factored(display: .scaled(-k * m, 1, .sin(lin(m))), solve: S.trig(.sin, m, 1, 0, "0")),
                d2: sinF ? Factored(display: .scaled(-k * m * m, 1, .sin(lin(m))), solve: S.trig(.sin, m, 1, 0, "0"))
                         : Factored(display: .scaled(-k * m * m, 1, .cos(lin(m))), solve: S.trig(.cos, m, 1, 0, "0")))
        case .bell:
            let c = q[0]
            let E = Expr.exp(.neg(.div(.p(x, 2), .n(c))))
            let eT = c == 1 ? "e^(−x²)" : "e^(−x²/\(c))"
            inv = Investigation(
                zeros: S.never(eT, expText),
                d1: Factored(display: .neg(.mul(.scaled(2, c, x), E)),
                             solve: S.product([(eT, S.never(eT, expText)), ("x", S.poly([1, 0]))])),
                d2: Factored(display: .mul(.mul(.q(2, c * c), P([2, 0, -c])), E),
                             solve: S.product([(eT, S.never(eT, expText)), (pt([2, 0, -c]), S.poly([2, 0, -c]))])))
        case .cubicAx:
            let a = q[0]
            inv = Investigation(zeros: S.poly([1, 0, -a, 0]),
                                d1: Factored(display: P([3, 0, -a]), solve: S.poly([3, 0, -a])),
                                d2: Factored(display: P([6, 0]), solve: S.poly([6, 0])))
        case .vertex:
            let (a, h, k) = (q[0], q[1], q[2])
            inv = Investigation(zeros: S.poly([a, -2 * a * h, a * h * h + k]),
                                d1: Factored(display: .scaled(2 * a, 1, P([1, -h])), solve: S.poly([1, -h])),
                                d2: Factored(display: .n(2 * a), solve: S.never("f″(x) = \(Solver.minus("\(2 * a)"))", "it is a nonzero constant")))
        case .shiftSin:
            let k = q[0]
            inv = Investigation(zeros: S.trig(.sin, 1, 1, Double(-k), Solver.minus("\(-k)")),
                                d1: Factored(display: .cos(x), solve: S.trig(.cos, 1, 1, 0, "0")),
                                d2: Factored(display: .neg(.sin(x)), solve: S.trig(.sin, 1, 1, 0, "0")))
        case .cubic3:
            let (s, r0, r1, r2) = (q[0], q[1], q[2], q[3])
            let s1 = r0 + r1 + r2, s2 = r0 * r1 + r0 * r2 + r1 * r2
            var z = Solved()
            z.say("f is already a product of three brackets:  x = \(Solver.minus("\(r0)")),  x = \(Solver.minus("\(r1)")),  x = \(Solver.minus("\(r2)"))")
            z.roots = [r0, r1, r2].map { AlgebraRoot(x: Double($0), label: Solver.minus("\($0)")) }
            var d1 = S.poly([3, -2 * s1, s2])
            d1.lines.insert(SolutionStep("Multiplying out: f(x) = \(s == 1 ? "" : "−(")\(pt([1, -s1, s2, -r0 * r1 * r2]))\(s == 1 ? "" : ")")", depth: 1), at: 0)
            inv = Investigation(zeros: z,
                                d1: Factored(display: .scaled(s, 1, P([3, -2 * s1, s2])), solve: d1),
                                d2: Factored(display: .scaled(s, 1, P([6, -2 * s1])), solve: S.poly([6, -2 * s1])))
        case .sinCos:
            let (m, n, c) = (q[0], q[1], q[2])
            let mx = arg(m)
            if m == n {
                var d1 = Solved()
                d1.say("If cos(\(mx)) were 0, sin(\(mx)) would be ±1 and f′ ≠ 0 — so we may divide by cos(\(mx)):")
                d1.say("\(m) \(c > 0 ? "−" : "+") \(Solver.frac(m, 2))·tan(\(mx)) = 0  ⇒  tan(\(mx)) = \(Solver.frac(2, c))", depth: 2)
                d1.append(S.trig(.tan, m, 1, 2 / Double(c), Solver.frac(2, c)))
                var d2 = Solved()
                d2.say("f″(x) = −\(m * m == 1 ? "" : "\(m * m)")(sin(\(mx)) \(c > 0 ? "+" : "−") ½cos(\(mx))). Divide by cos(\(mx)) for the same reason:  tan(\(mx)) = \(Solver.frac(-c, 2))")
                d2.append(S.trig(.tan, m, 1, -Double(c) / 2, Solver.frac(-c, 2)))
                inv = Investigation(zeros: nil,
                                    d1: Factored(display: .sum([.scaled(m, 1, .cos(lin(m))), .scaled(-c * m, 2, .sin(lin(m)))]), solve: d1),
                                    d2: Factored(display: .sum([.scaled(-m * m, 1, .sin(lin(m))), .scaled(-c * m * m, 2, .cos(lin(m)))]), solve: d2))
            } else if m == 1 && n == 2 {
                var d1 = S.product([("cos x", S.trig(.cos, 1, 1, 0, "0")),
                                    ("1 \(c > 0 ? "−" : "+") 2sin x", S.trig(.sin, 1, 1, 1 / Double(2 * c), Solver.frac(1, 2 * c)))])
                d1.lines.insert(SolutionStep("Use sin 2x = 2 sin x cos x:  f′(x) = cos x \(c > 0 ? "−" : "+") 2 sin x cos x = cos x·(1 \(c > 0 ? "−" : "+") 2 sin x)", depth: 1), at: 0)
                var d2 = Solved()
                d2.say("Use cos 2x = 1 − 2sin²x:  f″(x) = −sin x \(c > 0 ? "−" : "+") 2(1 − 2sin²x) = \(pt([4 * c, -1, -2 * c], "sin x").replacingOccurrences(of: "sin x²", with: "sin²x"))")
                d2.append(S.sinPoly([4 * c, -1, -2 * c]))
                inv = Investigation(zeros: nil,
                                    d1: Factored(display: .mul(.cos(x), .sum([1, .scaled(-2 * c, 1, .sin(x))])), solve: d1),
                                    d2: Factored(display: .sum([.scaled(4 * c, 1, .p(.sin(x), 2)), .neg(.sin(x)), .n(-2 * c)]), solve: d2))
            } else if m == 2 && n == 1 {
                var d1 = Solved()
                d1.say("Use cos 2x = 1 − 2sin²x:  f′(x) = 2(1 − 2sin²x) \(c > 0 ? "−" : "+") ½ sin x;  set it to 0 and multiply by −2:")
                d1.append(S.sinPoly([8, c, -4]))
                var d2 = S.product([("cos x", S.trig(.cos, 1, 1, 0, "0")),
                                    ("8 sin x \(c > 0 ? "+" : "−") ½", S.trig(.sin, 1, 1, -Double(c) / 16, Solver.frac(-c, 16)))])
                d2.lines.insert(SolutionStep("Use sin 2x = 2 sin x cos x:  f″(x) = −8 sin x cos x \(c > 0 ? "−" : "+") ½ cos x = −cos x·(8 sin x \(c > 0 ? "+" : "−") ½)", depth: 1), at: 0)
                inv = Investigation(zeros: nil,
                                    d1: Factored(display: .sum([.scaled(-4, 1, .p(.sin(x), 2)), .scaled(-c, 2, .sin(x)), 2]), solve: d1),
                                    d2: Factored(display: .neg(.mul(.cos(x), .sum([.scaled(8, 1, .sin(x)), .q(c, 2)]))), solve: d2))
            } else {
                return nil
            }
        case .xExp:
            let c = q[0]
            let E = Expr.exp(.neg(.div(x, .n(c))))
            let eT = c == 1 ? "e^(−x)" : "e^(−x/\(c))"
            inv = Investigation(
                zeros: S.product([("x", S.poly([1, 0])), (eT, S.never(eT, expText))]),
                d1: Factored(display: .scaled(1, c, .mul(E, P([-1, c]))),
                             solve: S.product([(eT, S.never(eT, expText)), (pt([-1, c]), S.poly([-1, c]))])),
                d2: Factored(display: .scaled(1, c * c, .mul(E, P([1, -2 * c]))),
                             solve: S.product([(eT, S.never(eT, expText)), (pt([1, -2 * c]), S.poly([1, -2 * c]))])))
        case .rational1:
            let (s, c) = (q[0], q[1])
            let D = Expr.sum([.p(x, 2), .n(c)])
            let dT = "x² + \(c)"
            inv = Investigation(
                zeros: S.fraction(pt([s, 0]), S.poly([s, 0]), denominator: dT, reason: "always positive"),
                d1: Factored(display: .div(.scaled(s, 1, P([-1, 0, c])), .p(D, 2)),
                             solve: S.fraction(pt([-1, 0, c]), S.poly([-1, 0, c]), denominator: "(\(dT))²", reason: "always positive")),
                d2: Factored(display: .div(.scaled(2 * s, 1, .mul(x, P([1, 0, -3 * c]))), .p(D, 3)),
                             solve: S.fraction("x(\(pt([1, 0, -3 * c])))", S.poly([1, 0, -3 * c, 0]), denominator: "(\(dT))³", reason: "always positive")))
        case .quartic:
            let b = q[0]
            inv = Investigation(zeros: S.poly([1, 0, -2 * b, 0, 0]),
                                d1: Factored(display: .scaled(4, 1, .mul(x, P([1, 0, -b]))), solve: S.poly([1, 0, -b, 0])),
                                d2: Factored(display: P([12, 0, -4 * b]), solve: S.poly([12, 0, -4 * b])))
        case .linExp:
            let a = q[0]
            inv = Investigation(
                zeros: S.product([(pt([1, -a]), S.poly([1, -a])), ("eˣ", S.never("eˣ", expText))]),
                d1: Factored(display: .mul(.exp(x), P([1, 1 - a])),
                             solve: S.product([("eˣ", S.never("eˣ", expText)), (pt([1, 1 - a]), S.poly([1, 1 - a]))])),
                d2: Factored(display: .mul(.exp(x), P([1, 2 - a])),
                             solve: S.product([("eˣ", S.never("eˣ", expText)), (pt([1, 2 - a]), S.poly([1, 2 - a]))])))
        case .bump:
            let (c, k) = (q[0], q[1])
            let D = Expr.sum([.p(x, 2), 1])
            var z: Solved
            if k == 0 {
                z = S.never("\(c)/(x² + 1)", "it is always positive")
            } else {
                z = Solved()
                z.say("\(c)/(x² + 1) = \(Solver.minus("\(-k)"))  ⇒  multiply by (x² + 1):  \(pt([k, 0, k + c])) = 0")
                z.append(S.poly([k, 0, k + c]))
            }
            inv = Investigation(
                zeros: z,
                d1: Factored(display: .div(.scaled(-2 * c, 1, x), .p(D, 2)),
                             solve: S.fraction(pt([-2 * c, 0]), S.poly([-2 * c, 0]), denominator: "(x² + 1)²", reason: "always positive")),
                d2: Factored(display: .div(.scaled(2 * c, 1, P([3, 0, -1])), .p(D, 3)),
                             solve: S.fraction("3x² − 1", S.poly([3, 0, -1]), denominator: "(x² + 1)³", reason: "always positive")))
        case .sinSin:
            let k = q[0]
            func half(_ n: Int) -> String { n % 2 == 0 ? arg(n / 2) : (n == 1 ? "x/2" : "\(n)x/2") }
            let A = "cos(\(half(k + 1)))", B = half(k - 1) == "x" ? "cos x" : "cos(\(half(k - 1)))"
            var d1 = S.product([(A, S.trig(.cos, k + 1, 2, 0, "0")), (B, S.trig(.cos, k - 1, 2, 0, "0"))])
            d1.lines.insert(SolutionStep("Sum to product: cos A + cos B = 2cos((A+B)/2)·cos((A−B)/2), so  f′(x) = cos x + cos \(k)x = 2\(A)·\(B)", depth: 1), at: 0)
            let z: Solved, d2: Factored
            if k == 2 {
                var zz = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")), ("1 + cos x", S.trig(.cos, 1, 1, -1, "−1"))])
                zz.lines.insert(SolutionStep("sin 2x = 2 sin x cos x, so f(x) = sin x + sin x cos x = sin x·(1 + cos x)", depth: 1), at: 0)
                z = zz
                var s2 = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")), ("1 + 4cos x", S.trig(.cos, 1, 1, -0.25, "−1/4"))])
                s2.lines.insert(SolutionStep("f″(x) = −sin x − 2 sin 2x = −sin x − 4 sin x cos x = −sin x·(1 + 4cos x)", depth: 1), at: 0)
                d2 = Factored(display: .neg(.mul(.sin(x), .sum([1, .scaled(4, 1, .cos(x))]))), solve: s2)
            } else {
                var zz = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")), ("2 − (4/3)sin²x", S.sinPoly([-4, 0, 6]))])
                zz.lines.insert(SolutionStep("sin 3x = 3 sin x − 4sin³x, so f(x) = 2 sin x − (4/3)sin³x = sin x·(2 − (4/3)sin²x)", depth: 1), at: 0)
                z = zz
                var s2 = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")), ("6sin²x − 5", S.sinPoly([6, 0, -5]))])
                s2.lines.insert(SolutionStep("f″(x) = −sin x − 3 sin 3x = −sin x − 9 sin x + 12sin³x = 2 sin x·(6sin²x − 5)", depth: 1), at: 0)
                d2 = Factored(display: .scaled(2, 1, .mul(.sin(x), .sum([.scaled(6, 1, .p(.sin(x), 2)), .n(-5)]))), solve: s2)
            }
            inv = Investigation(zeros: z,
                                d1: Factored(display: .scaled(2, 1, .mul(.cos(.scaled(k + 1, 2, x)), .cos(.scaled(k - 1, 2, x)))), solve: d1),
                                d2: d2)
        case .quadGauss:
            let a = q[0]
            let E = Expr.exp(.neg(.div(.p(x, 2), 2)))
            let eT = "e^(−x²/2)"
            inv = Investigation(
                zeros: S.product([(pt([1, 0, -a]), S.poly([1, 0, -a])), (eT, S.never(eT, expText))]),
                d1: Factored(display: .mul(.mul(x, E), P([-1, 0, a + 2])),
                             solve: S.product([("x", S.poly([1, 0])), (eT, S.never(eT, expText)), (pt([-1, 0, a + 2]), S.poly([-1, 0, a + 2]))])),
                d2: Factored(display: .mul(E, P([1, 0, -(a + 5), 0, a + 2])),
                             solve: S.product([(eT, S.never(eT, expText)), (pt([1, 0, -(a + 5), 0, a + 2]), S.poly([1, 0, -(a + 5), 0, a + 2]))])))
        case .sin2cos:
            let k = q[0]
            let z = S.product([("sin²x", S.trig(.sin, 1, 1, 0, "0")), ("cos \(k)x", S.trig(.cos, k, 1, 0, "0"))])
            if k == 2 {
                var d1 = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")), ("cos 3x", S.trig(.cos, 3, 1, 0, "0"))])
                d1.lines.insert(SolutionStep("Product and chain rule: f′(x) = 2 sin x cos x·cos 2x − 2sin²x·sin 2x = 2 sin x·(cos x cos 2x − sin x sin 2x) = 2 sin x·cos 3x  (cos(A + B) = cos A cos B − sin A sin B)", depth: 1), at: 0)
                inv = Investigation(zeros: z, d1: Factored(display: .scaled(2, 1, .mul(.sin(x), .cos(.mul(3, x)))), solve: d1), d2: nil)
            } else {
                let rest = Expr.sum([.scaled(2, 1, .mul(.cos(x), .cos(.mul(3, x)))), .neg(.scaled(3, 1, .mul(.sin(x), .sin(.mul(3, x)))))])
                let d1 = S.product([("sin x", S.trig(.sin, 1, 1, 0, "0")),
                                    ("2cos x cos 3x − 3 sin x sin 3x", S.numeric(rest, name: "2cos x cos 3x − 3 sin x sin 3x"))])
                inv = Investigation(zeros: z, d1: Factored(display: .mul(.sin(x), rest), solve: d1), d2: nil)
            }
        case .powExp:
            let n = q[0]
            let E = Expr.exp(.neg(x))
            let xn1: Expr = n - 1 == 1 ? x : .p(x, n - 1)
            var parts2: [(String, Solved)] = [("e^(−x)", S.never("e^(−x)", expText)),
                                              (pt([1, -2 * n, n * (n - 1)]), S.poly([1, -2 * n, n * (n - 1)]))]
            if n == 3 { parts2.insert(("x", S.poly([1, 0])), at: 0) }
            inv = Investigation(
                zeros: S.product([(Solver.power("x", n), S.poly([1] + Array(repeating: 0, count: n))), ("e^(−x)", S.never("e^(−x)", expText))]),
                d1: Factored(display: .mul(.mul(xn1, E), P([-1, n])),
                             solve: S.product([(Solver.power("x", n - 1), S.poly([1] + Array(repeating: 0, count: n - 1))),
                                               ("e^(−x)", S.never("e^(−x)", expText)), (pt([-1, n]), S.poly([-1, n]))])),
                d2: Factored(display: n == 2 ? .mul(E, P([1, -4, 2])) : .mul(.mul(x, E), P([1, -6, 6])),
                             solve: S.product(parts2)))
        case .sinExpDecay:
            let (k, c) = (q[0], q[1])
            let E = Expr.exp(.neg(.div(x, .n(c))))
            let eT = "e^(−x/\(c))"
            let kx = arg(k)
            var d1 = Solved()
            d1.say("\(eT) > 0, so f′(x) = 0  ⇔  \(k == 1 ? "" : "\(k)")cos(\(kx)) = (1/\(c))·sin(\(kx)).")
            d1.say("cos(\(kx)) = 0 would force sin(\(kx)) = 0 too — impossible — so divide by cos(\(kx)):  tan(\(kx)) = \(k * c)", depth: 2)
            d1.append(S.trig(.tan, k, 1, Double(k * c), "\(k * c)"))
            var d2 = Solved()
            let num = 2 * k * c, den = 1 - k * k * c * c
            d2.say("\(eT) > 0, so f″(x) = 0  ⇔  (1/\(c * c) − \(k * k))·sin(\(kx)) = (\(Solver.frac(2 * k, c)))·cos(\(kx));  divide by cos(\(kx)):  tan(\(kx)) = \(Solver.frac(num, den))")
            d2.append(S.trig(.tan, k, 1, Double(num) / Double(den), Solver.frac(num, den)))
            inv = Investigation(
                zeros: S.product([("sin(\(kx))", S.trig(.sin, k, 1, 0, "0")), (eT, S.never(eT, expText))]),
                d1: Factored(display: .mul(E, .sum([.scaled(k, 1, .cos(lin(k))), .neg(.scaled(1, c, .sin(lin(k))))])), solve: d1),
                d2: Factored(display: .mul(E, .sum([.scaled(den, c * c, .sin(lin(k))), .neg(.scaled(2 * k, c, .cos(lin(k))))])), solve: d2))
        case .quartic3:
            let (a, b) = (q[0], q[1])
            inv = Investigation(zeros: S.poly([1, 0, -a, b, 0]),
                                d1: Factored(display: P([4, 0, -2 * a, b]), solve: S.poly([4, 0, -2 * a, b])),
                                d2: Factored(display: P([12, 0, -2 * a]), solve: S.poly([12, 0, -2 * a])))
        case .ratQuad:
            let (a, b) = (q[0], q[1])
            let D = Expr.sum([.p(x, 2), .n(b)])
            let dT = "x² + \(b)"
            var d1 = S.fraction("\(2 * (a + b))x", S.poly([2 * (a + b), 0]), denominator: "(\(dT))²", reason: "always positive")
            d1.lines.insert(SolutionStep("Quotient rule: f′(x) = [2x(\(dT)) − 2x(\(pt([1, 0, -a])))]/(\(dT))² = \(2 * (a + b))x/(\(dT))²", depth: 1), at: 0)
            inv = Investigation(
                zeros: S.fraction(pt([1, 0, -a]), S.poly([1, 0, -a]), denominator: dT, reason: "always positive"),
                d1: Factored(display: .div(.scaled(2 * (a + b), 1, x), .p(D, 2)), solve: d1),
                d2: Factored(display: .div(.scaled(2 * (a + b), 1, P([-3, 0, b])), .p(D, 3)),
                             solve: S.fraction(pt([-3, 0, b]), S.poly([-3, 0, b]), denominator: "(\(dT))³", reason: "always positive")))
        case .xSin:
            let d1e = Expr.sum([.sin(x), .mul(x, .cos(x))])
            var d1 = Solved()
            d1.exact = false
            d1.say("x = 0 is a solution (sin 0 + 0·cos 0 = 0).")
            d1.say("At any other solution cos x ≠ 0 (otherwise sin x = ±1 ≠ 0), so divide by cos x:  tan x = −x.")
            d1.say("tan x = −x mixes x with tan x, so algebra can't solve it — the solutions are where y = tan x meets y = −x. From sign changes of f′:")
            let found = S.numeric(d1e, name: "f′")
            d1.lines += found.lines
            d1.roots = found.roots.map { Swift.abs($0.x) < 1e-6 ? AlgebraRoot(x: 0, label: "0") : $0 }
            inv = Investigation(zeros: S.product([("x", S.poly([1, 0])), ("sin x", S.trig(.sin, 1, 1, 0, "0"))]),
                                d1: Factored(display: d1e, solve: d1), d2: nil)
        case .x2Ln:
            let a = q[0]
            inv = Investigation(
                zeros: nil,
                d1: Factored(display: .div(P([2, 0, -a]), x),
                             solve: S.fraction(pt([2, 0, -a]), S.poly([2, 0, -a]), denominator: "x", reason: "positive (ln x needs x > 0)")),
                d2: Factored(display: .sum([2, .div(.n(a), .p(x, 2))]), solve: S.never("f″(x) = 2 + \(a)/x²", "it is always positive")))
        case .lnQuad:
            let a = q[0]
            let D = Expr.sum([.p(x, 2), .n(a)])
            var z = Solved()
            z.say("ln(u) = 0 exactly when u = 1:  x² + \(a) = 1  ⇒  \(pt([1, 0, a - 1])) = 0")
            z.append(S.poly([1, 0, a - 1]))
            inv = Investigation(
                zeros: z,
                d1: Factored(display: .div(.scaled(2, 1, x), D),
                             solve: S.fraction("2x", S.poly([2, 0]), denominator: "x² + \(a)", reason: "always positive")),
                d2: Factored(display: .div(.scaled(2, 1, P([-1, 0, a])), .p(D, 2)),
                             solve: S.fraction(pt([-1, 0, a]), S.poly([-1, 0, a]), denominator: "(x² + \(a))²", reason: "always positive")))
        case .xPlusInv:
            let a = q[0]
            inv = Investigation(
                zeros: S.never("x + \(a)/x", "for x > 0 both terms are positive"),
                d1: Factored(display: .div(P([1, 0, -a]), .p(x, 2)),
                             solve: S.fraction(pt([1, 0, -a]), S.poly([1, 0, -a]), denominator: "x²", reason: "positive")),
                d2: Factored(display: .div(.n(2 * a), .p(x, 3)), solve: S.never("f″(x) = \(2 * a)/x³", "it is positive for x > 0")))
        case .expLin:
            let a = q[0]
            inv = Investigation(zeros: nil,
                                d1: Factored(display: .sum([.exp(x), .n(-a)]), solve: S.expEquals(a)),
                                d2: Factored(display: .exp(x), solve: S.never("f″(x) = eˣ", expText)))
        case .powLn:
            let n = q[0]
            let z = S.product([(Solver.power("x", n), S.never(Solver.power("x", n), "x > 0 here")), ("ln x", S.lnEquals(0, 1))])
            if n == 1 {
                inv = Investigation(zeros: z,
                                    d1: Factored(display: .sum([.ln(x), 1]), solve: S.lnEquals(-1, 1)),
                                    d2: Factored(display: .div(1, x), solve: S.never("f″(x) = 1/x", "it is positive for x > 0")))
            } else {
                inv = Investigation(zeros: z,
                                    d1: Factored(display: .mul(x, .sum([.scaled(2, 1, .ln(x)), 1])),
                                                 solve: S.product([("x", S.never("x", "x > 0 here")), ("2 ln x + 1", S.lnEquals(-1, 2))])),
                                    d2: Factored(display: .sum([.scaled(2, 1, .ln(x)), 3]), solve: S.lnEquals(-3, 2)))
            }
        case .lnOverPow:
            let n = q[0]
            let z = S.fraction("ln x", S.lnEquals(0, 1), denominator: Solver.power("x", n), reason: "positive")
            let xn1 = Expr.p(x, n + 1)
            let d1 = S.fraction(n == 1 ? "1 − ln x" : "1 − \(n) ln x", S.lnEquals(1, n), denominator: Solver.power("x", n + 1), reason: "positive")
            let d2: Factored = n == 1
                ? Factored(display: .div(.sum([.scaled(2, 1, .ln(x)), .n(-3)]), .p(x, 3)),
                           solve: S.fraction("2 ln x − 3", S.lnEquals(3, 2), denominator: "x³", reason: "positive"))
                : Factored(display: .div(.sum([.scaled(6, 1, .ln(x)), .n(-5)]), .p(x, 4)),
                           solve: S.fraction("6 ln x − 5", S.lnEquals(5, 6), denominator: "x⁴", reason: "positive"))
            inv = Investigation(zeros: z,
                                d1: Factored(display: .div(.sum([1, .scaled(-n, 1, .ln(x))]), xn1), solve: d1),
                                d2: d2)
        case .sqrtLin:
            let a = q[0]
            inv = Investigation(
                zeros: S.product([("√x", S.poly([1, 0])), (pt([1, -a]), S.poly([1, -a]))]),
                d1: Factored(display: .div(P([3, -a]), .scaled(2, 1, .sqrt(x))),
                             solve: S.fraction(pt([3, -a]), S.poly([3, -a]), denominator: "2√x", reason: "positive for x > 0")),
                d2: Factored(display: .div(P([3, a]), .mul(4, .mul(x, .sqrt(x)))),
                             solve: S.never("f″(x) = (\(pt([3, a])))/(4x√x)", "it is positive for x > 0")))
        case .expOverQuad:
            let c = q[0]
            let D = Expr.sum([.p(x, 2), .n(c)])
            var d1 = Solved()
            d1.say("The denominator (x² + \(c))² is always positive, so only the numerator matters:")
            d1.append(S.product([("eˣ", S.never("eˣ", expText)), (pt([1, -2, c]), S.poly([1, -2, c]))]))
            inv = Investigation(zeros: S.never("eˣ/(x² + \(c))", "both the top and the bottom are positive"),
                                d1: Factored(display: .div(.mul(.exp(x), P([1, -2, c])), .p(D, 2)), solve: d1),
                                d2: nil)
        case .cubicK:
            let k = q[0]
            inv = Investigation(zeros: S.poly([1, 0, -3 * k * k, 0]),
                                d1: Factored(display: .scaled(3, 1, P([1, 0, -k * k])), solve: S.poly([1, 0, -k * k])),
                                d2: Factored(display: P([6, 0]), solve: S.poly([6, 0])))
        case .xGauss:
            let c = q[0]
            let E = Expr.exp(.neg(.div(.p(x, 2), .n(c))))
            let eT = c == 1 ? "e^(−x²)" : "e^(−x²/\(c))"
            inv = Investigation(
                zeros: S.product([("x", S.poly([1, 0])), (eT, S.never(eT, expText))]),
                d1: Factored(display: .scaled(1, c, .mul(E, P([-2, 0, c]))),
                             solve: S.product([(eT, S.never(eT, expText)), (pt([-2, 0, c]), S.poly([-2, 0, c]))])),
                d2: Factored(display: .scaled(2, c * c, .mul(.mul(x, E), P([2, 0, -3 * c]))),
                             solve: S.product([("x", S.poly([1, 0])), (eT, S.never(eT, expText)), (pt([2, 0, -3 * c]), S.poly([2, 0, -3 * c]))])))
        }

        // A vertical factor k multiplies f′ and f″ but doesn't move their zeros.
        let k = fam.factor
        if k != 1 {
            func times(_ e: Expr) -> Expr {
                if case .num(let v) = e { return .num(v * Double(k)) }
                return .scaled(k, 1, e)
            }
            func note(_ s: Solved, _ what: String) -> Solved {
                var s = s
                s.lines.insert(SolutionStep("(The factor \(Solver.minus("\(k)")) in front doesn't change where \(what) is 0.)", depth: 1), at: 0)
                return s
            }
            inv.d1 = inv.d1.map { Factored(display: times($0.display), solve: note($0.solve, "f′")) }
            inv.d2 = inv.d2.map { Factored(display: times($0.display), solve: note($0.solve, "f″")) }
            inv.zeros = inv.zeros.map { note($0, "f") }
        }
        return inv
    }
}
