import Foundation

// Bagrut 572, chapter 1: analytic geometry (circles, parabola, ellipse,
// hyperbola, loci) and complex numbers (algebraic and polar forms,
// De Moivre, roots and the polygons they make, loci in the plane).

extension QuizFactory {
    /// "(x − 2)²", "(x + 3)²" or "x²".
    static func sq(_ name: String, _ c: Int) -> String { c == 0 ? "\(name)²" : "(\(name)\(sg(-c)))²" }

    static func conicFigure(_ build: (inout GeoFigure) -> Void) -> GeoFigure {
        var f = GeoFigure()
        f.axes = ["x", "y"]
        build(&f)
        return f
    }

    // MARK: - Conics

    static func conics(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 3, 4, 5]
        case .medium: pool = [0, 1, 2, 3, 4, 5]
        case .hard: pool = [1, 2, 4, 5, 6, 7]
        case .bagrut: pool = [1, 2, 6, 7, 4, 5]
        }
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], _ fig: GeoFigure) -> QuizProblem {
            var q = number(.conics, level, seed, prompt, value, topic: "conics:\(topic)", steps: steps)
            q.figure = fig
            return q
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Circle in general form: complete the square.
            let a = r.nonZero(-5...5), b = r.int(-5...5), r2 = r.pick([4, 9, 16, 25, 5, 8, 10, 13, 18, 20])
            let F = a * a + b * b - r2
            let eq = "x² + y²\(signedTerm(-2 * a, "x"))\(signedTerm(-2 * b, "y"))\(sg(F)) = 0"
            let rad = exact(1, rad: r2, den: 1)
            let askR = r.bool()
            let fig = conicFigure { f in
                let rr = Double(r2).squareRoot()
                f.circle(Double(a), Double(b), rr)
                f.point(Double(a), Double(b), "M", highlight: !askR)
            }
            return ask("Find the \(askR ? "radius" : "x-coordinate of the centre") of the circle  \(eq).", askR ? rad.value : Double(a), "circle",
                       [H("Complete the squares"), S("x²\(signedTerm(-2 * a, "x")) = \(sq("x", a)) − \(a * a)"),
                        S("y²\(signedTerm(-2 * b, "y")) = \(sq("y", b))\(b == 0 ? "" : " − \(b * b)")"),
                        S("\(sq("x", a)) + \(sq("y", b)) = \(a * a + b * b)\(sg(-F)) = \(r2)"),
                        H("Read it off"), S("Centre (\(iv(a)), \(iv(b))),  R² = \(r2)"),
                        R(askR ? "R = \(rad.text)" : "The centre's x is \(iv(a))")], fig)
        case 1:
            // Tangent to a circle at a point on it.
            let (dx, dy) = r.pick([(3, 4), (4, 3), (-3, 4), (3, -4), (1, 2), (2, 1), (-1, 2), (2, -1), (1, 1), (-1, 1), (1, 3), (3, 1), (0, 5), (0, 3)])
            let a = r.int(-3...3), b = r.int(-3...3)
            let px = a + dx, py = b + dy
            let r2 = dx * dx + dy * dy
            // Slope −dx/dy;  y = py − dx/dy (x − px).
            let m = Expr.q(-dx, dy), c = Expr.q(py * dy + dx * px, dy)
            let line: Expr = .sum([dx == 0 ? 0 : .mul(m, .x), c])
            var q = blank(.conics, level, seed,
                          "P(\(iv(px)), \(iv(py))) is on the circle  \(sq("x", a)) + \(sq("y", b)) = \(r2). Find the tangent to the circle at P.",
                          .function(line.simplified()), topic: "conics:tangent")
            let tangentText = lineEq(-dx, dy, py * dy + dx * px, dy)
            q.steps = [H("The radius to P"), S("Centre M(\(iv(a)), \(iv(b))); slope of MP = \(dy)/\(dx == 0 ? "0" : iv(dx))" + (dx == 0 ? " — MP is vertical" : " = \(fr(dy, dx))")),
                       H("The tangent is perpendicular to the radius"), S(dx == 0 ? "So the tangent is horizontal: slope 0" : "Slope of the tangent = −1 ÷ \(fr(dy, dx)) = \(fr(-dx, dy))"),
                       H("Line through P"), S("y − \(pv(py)) = (\(fr(-dx, dy)))(x − \(pv(px)))"),
                       R("y = \(tangentText)")]
            q.figure = conicFigure { f in
                f.circle(Double(a), Double(b), Double(r2).squareRoot())
                let M = f.point(Double(a), Double(b), "M"), P = f.point(Double(px), Double(py), "P", highlight: true)
                f.segment(M, P, nil, .dashed)
                let k = -Double(dx) / Double(dy)
                f.line(Double(px) - 3, Double(py) - 3 * k, Double(px) + 3, Double(py) + 3 * k, .highlight)
            }
            return q
        case 2:
            // Line and circle: how many common points?
            let a = r.int(-3...3), b = r.int(-3...3), m = r.int(-2...2), c = r.int(-5...5)
            let top = m * a - b + c, den = m * m + 1
            var r2 = r.int(2...20)
            if r.int(0...2) == 0, (top * top) % den == 0, top != 0 { r2 = top * top / den }
            let lhs = top * top, rhs = r2 * den   // compare dist² = top²/den with r²
            let count = lhs < rhs ? 2 : (lhs == rhs ? 1 : 0)
            let lineText = m == 0 ? "y = \(iv(c))" : "y = \(m == 1 ? "" : (m == -1 ? "−" : iv(m)))x\(sg(c))"
            return ask("How many points do the line  \(lineText)  and the circle  \(sq("x", a)) + \(sq("y", b)) = \(r2)  have in common?", Double(count), "line and circle",
                       [H("Distance from the centre to the line"), S("Centre (\(iv(a)), \(iv(b))),  R² = \(r2);  the line as mx − y + c = 0: \(m == 0 ? "" : "\(coef(m))x ")− y\(sg(c)) = 0"),
                        S("d² = (m·x₀ − y₀ + c)² / (m² + 1) = (\(pv(m))·\(pv(a)) − \(pv(b))\(sg(c)))² / (\(pv(m))² + 1) = \(fr(lhs, den))"),
                        H("Compare with R²"), S("\(fr(lhs, den)) \(count == 2 ? "<" : (count == 1 ? "=" : ">")) \(r2)"),
                        S(count == 2 ? "d < R: the line cuts the circle." : (count == 1 ? "d = R: the line is a tangent." : "d > R: the line misses the circle.")),
                        R("\(count) common point\(count == 1 ? "" : "s")")],
                       conicFigure { f in
                           f.circle(Double(a), Double(b), Double(r2).squareRoot())
                           f.line(-8, -8 * Double(m) + Double(c), 8, 8 * Double(m) + Double(c), .highlight)
                           f.window = [Double(a) - 7, Double(a) + 7, Double(b) - 6, Double(b) + 6]
                       })
        case 3:
            // Parabola y² = 2px.
            let p = r.pick([1, 2, 3, 4, 5, 6, 8])
            let what = r.int(0...2)
            let y0 = 2 * p * r.int(1...2) * (r.bool() ? 1 : -1), x0 = y0 * y0 / (2 * p)
            let fig = conicFigure { f in
                f.curve(-Double(4 * p), Double(4 * p)) { t in (t * t / Double(2 * p), t) }
                f.point(Double(p) / 2, 0, "F", highlight: what == 0)
                f.line(-Double(p) / 2, -Double(4 * p), -Double(p) / 2, Double(4 * p), .dashed, label: "x = \(fr(-p, 2))")
                if what == 2 { let P = f.point(Double(x0), Double(y0), "P"); let F = f.point(Double(p) / 2, 0, ""); f.segment(P, F, "?", .highlight) }
                f.window = [-Double(p) * 1.5, Double(4 * p), -Double(3 * p), Double(3 * p)]
            }
            let eq = "y² = \(2 * p)x"
            let base = [H("Compare with y² = 2px"), S("2p = \(2 * p)  ⇒  p = \(p)"), S("Focus F(p/2, 0) = (\(fr(p, 2)), 0);  directrix x = −p/2 = \(fr(-p, 2))")]
            switch what {
            case 0:
                return ask("Find the x-coordinate of the focus of the parabola  \(eq).", Double(p) / 2, "parabola focus", base + [R("x = \(fr(p, 2))")], fig)
            case 1:
                return ask("The directrix of the parabola  \(eq)  is x = c. Find c.", -Double(p) / 2, "parabola directrix", base + [R("c = \(fr(-p, 2))")], fig)
            default:
                return ask("P(\(x0), \(iv(y0))) is on the parabola  \(eq). Find its distance from the focus.", Double(x0) + Double(p) / 2, "parabola distance",
                           base + [H("Focus = directrix distance"), S("Every point of a parabola is as far from the focus as from the directrix."),
                                   S("Distance to x = \(fr(-p, 2)):  \(x0) + \(fr(p, 2))"), R("PF = \(fr(2 * x0 + p, 2))")], fig)
            }
        case 4:
            // Ellipse x²/a² + y²/b² = 1.
            let (a, b) = r.pick([(5, 3), (5, 4), (13, 5), (10, 6), (10, 8), (3, 2), (4, 2), (6, 4), (17, 8), (4, 3)])
            let c2 = a * a - b * b
            let c = exact(1, rad: c2, den: 1)
            let what = r.int(0...2)
            let eq = "x²/\(a * a) + y²/\(b * b) = 1"
            let fig = conicFigure { f in
                f.curve(0, 2 * .pi, steps: 120) { t in (Double(a) * cos(t), Double(b) * sin(t)) }
                f.point(-c.value, 0, "F₁"); f.point(c.value, 0, "F₂", highlight: what == 0)
                if what == 1 {
                    let P = f.point(Double(a) * cos(1.1), Double(b) * sin(1.1), "P")
                    f.segment(P, 0, nil, .dashed); f.segment(P, 1, nil, .dashed)
                }
            }
            let base = [H("Read a and b"), S("a² = \(a * a), b² = \(b * b):  a = \(a), b = \(b)"), S("For an ellipse c² = a² − b² = \(c2),  c = \(c.text)")]
            switch what {
            case 0:
                return ask("Find the positive x-coordinate of a focus of the ellipse  \(eq).", c.value, "ellipse foci", base + [R("F₂ = (\(c.text), 0)")], fig)
            case 1:
                return ask("P is any point on the ellipse  \(eq), with foci F₁, F₂. Find the perimeter of triangle PF₁F₂.", 2 * Double(a) + 2 * c.value, "ellipse triangle",
                           base + [H("The defining property"), S("PF₁ + PF₂ = 2a = \(2 * a) for every point of the ellipse"),
                                   S("F₁F₂ = 2c = 2·\(c.text)"), R("Perimeter = \(2 * a) + 2·\(c.text)")], fig)
            default:
                return ask("An ellipse x²/a² + y²/b² = 1 has a = \(a) and its foci at (±\(c.text), 0). Find b.", Double(b), "ellipse b",
                           [H("Foci of an ellipse"), S("c² = a² − b²"), S("\(c2) = \(a * a) − b²  ⇒  b² = \(b * b)"), R("b = \(b)")], fig)
            }
        case 5:
            // Hyperbola x²/a² − y²/b² = 1.
            let a = r.int(1...6), b = r.int(1...6)
            let c2 = a * a + b * b
            let c = exact(1, rad: c2, den: 1)
            let what = r.int(0...2)
            let eq = "x²/\(a * a) − y²/\(b * b) = 1"
            let fig = conicFigure { f in
                for side in [1.0, -1.0] {
                    f.curve(-2, 2, steps: 60) { t in (side * Double(a) * cosh(t), Double(b) * sinh(t)) }
                }
                let L = Double(Swift.max(a, b)) * 3
                f.line(-L, -L * Double(b) / Double(a), L, L * Double(b) / Double(a), .dashed)
                f.line(-L, L * Double(b) / Double(a), L, -L * Double(b) / Double(a), .dashed)
                f.point(-c.value, 0, "F₁"); f.point(c.value, 0, "F₂", highlight: what == 0)
                f.window = [-L * 0.8, L * 0.8, -L * 0.6, L * 0.6]
            }
            let base = [H("Read a and b"), S("a² = \(a * a), b² = \(b * b):  a = \(a), b = \(b)")]
            switch what {
            case 0:
                return ask("Find the positive x-coordinate of a focus of the hyperbola  \(eq).", c.value, "hyperbola foci",
                           base + [S("For a hyperbola c² = a² + b² = \(c2)"), R("c = \(c.text)")], fig)
            case 1:
                return ask("The asymptotes of the hyperbola  \(eq)  are y = ±mx. Find m.", Double(b) / Double(a), "hyperbola asymptotes",
                           base + [S("The asymptotes of x²/a² − y²/b² = 1 are y = ±(b/a)x"), R("m = \(fr(b, a))")], fig)
            default:
                return ask("P is on the hyperbola  \(eq)  with foci F₁, F₂. Find |PF₁ − PF₂|.", Double(2 * a), "hyperbola property",
                           base + [H("The defining property"), S("For every point of a hyperbola, |PF₁ − PF₂| = 2a"), R("|PF₁ − PF₂| = \(2 * a)")], fig)
            }
        case 6:
            // Apollonius: PA = k·PB is a circle.
            let k = r.pick([2, 3, 2]), d = r.pick([3, 4, 6, 8, 5])
            // A(0,0), B(d,0): centre k²d/(k²−1), radius kd/(k²−1).
            let k2 = k * k
            let askR = r.bool()
            let fig = conicFigure { f in
                let cx = Double(k2 * d) / Double(k2 - 1), rr = Double(k * d) / Double(k2 - 1)
                f.circle(cx, 0, rr, .highlight)
                f.point(0, 0, "A"); f.point(Double(d), 0, "B")
                let P = f.point(cx + rr * cos(2), rr * sin(2), "P")
                f.segment(P, 0, nil, .dashed); f.segment(P, 1, nil, .dashed)
            }
            return ask("A(0, 0) and B(\(d), 0). Point P moves so that PA = \(k)·PB. Its path is a circle; find its \(askR ? "radius" : "centre's x-coordinate").",
                       askR ? Double(k * d) / Double(k2 - 1) : Double(k2 * d) / Double(k2 - 1), "apollonius",
                       [H("Write the condition"), S("PA² = \(k2)·PB²:  x² + y² = \(k2)((x − \(d))² + y²)"),
                        H("Expand and collect"), S("\(k2 - 1)x² + \(k2 - 1)y² − \(2 * k2 * d)x + \(k2 * d * d) = 0"),
                        S("x² + y² − (\(fr(2 * k2 * d, k2 - 1)))x + \(fr(k2 * d * d, k2 - 1)) = 0", 2),
                        H("Complete the square"), S("(x − \(fr(k2 * d, k2 - 1)))² + y² = \(fr(k2 * d * d * k2, (k2 - 1) * (k2 - 1))) − \(fr(k2 * d * d, k2 - 1)) = \(fr(k2 * d * d, (k2 - 1) * (k2 - 1)))"),
                        R(askR ? "R = \(fr(k * d, k2 - 1))" : "Centre (\(fr(k2 * d, k2 - 1)), 0)")], fig)
        default:
            // Midpoints of segments from a fixed point to a circle.
            let ax = 2 * r.nonZero(-3...3), ay = 2 * r.int(-3...3), R0 = r.pick([2, 4, 6, 3, 5])
            let askR = r.bool()
            let fig = conicFigure { f in
                f.circle(0, 0, Double(R0))
                f.circle(Double(ax) / 2, Double(ay) / 2, Double(R0) / 2, .highlight)
                let A = f.point(Double(ax), Double(ay), "A")
                let Q = f.point(Double(R0) * cos(2.3), Double(R0) * sin(2.3), "Q")
                f.segment(A, Q, nil, .dashed)
                f.point((Double(ax) + Double(R0) * cos(2.3)) / 2, (Double(ay) + Double(R0) * sin(2.3)) / 2, "M", highlight: true)
            }
            return ask("Q moves on the circle x² + y² = \(R0 * R0), and A = (\(iv(ax)), \(iv(ay))). M is the midpoint of AQ. Find the \(askR ? "radius" : "centre's x-coordinate") of the path of M.",
                       askR ? Double(R0) / 2 : Double(ax) / 2, "midpoint locus",
                       [H("Write Q with M"), S("M = (x, y) is the midpoint, so Q = (2x\(sg(-ax)), 2y\(sg(-ay)))"),
                        H("Q is on the circle"), S("(2x\(sg(-ax)))² + (2y\(sg(-ay)))² = \(R0 * R0)"),
                        S("Divide by 4: \(sq("x", ax / 2)) + \(sq("y", ay / 2)) = \(fr(R0 * R0, 4))"),
                        R(askR ? "R = \(fr(R0, 2))" : "Centre (\(iv(ax / 2)), \(iv(ay / 2)))")], fig)
        }
    }

    // MARK: - Complex numbers

    /// "3 − 2i", "−i", "4", "5i".
    static func ct(_ a: Int, _ b: Int) -> String {
        let im = b == 0 ? "" : (Swift.abs(b) == 1 ? "i" : "\(Swift.abs(b))i")
        if a == 0 { return b == 0 ? "0" : (b < 0 ? "−" : "") + im }
        return iv(a) + (b == 0 ? "" : (b < 0 ? " − " : " + ") + im)
    }

    /// cos and sin of a multiple of 30° or 45° as (exact value, text).
    static func trigExact(_ angle: Int) -> (c: Double, s: Double, ct: String, st: String) {
        let d = ((angle % 360) + 360) % 360
        let table: [Int: (String, String)] = [
            0: ("1", "0"), 30: ("√3/2", "1/2"), 45: ("√2/2", "√2/2"), 60: ("1/2", "√3/2"), 90: ("0", "1"),
            120: ("−1/2", "√3/2"), 135: ("−√2/2", "√2/2"), 150: ("−√3/2", "1/2"), 180: ("−1", "0"),
            210: ("−√3/2", "−1/2"), 225: ("−√2/2", "−√2/2"), 240: ("−1/2", "−√3/2"), 270: ("0", "−1"),
            300: ("1/2", "−√3/2"), 315: ("√2/2", "−√2/2"), 330: ("√3/2", "−1/2"),
        ]
        let (c, s) = table[d] ?? (dec(cos(deg(Double(d)))), dec(sin(deg(Double(d)))))
        return (cos(deg(Double(d))), sin(deg(Double(d))), c, s)
    }

    /// r·cis θ in algebraic form for a "nice" r and θ, e.g. "1 + i√3", "−2i", "√2 + i√2".
    static func niceAlgebraic(_ r: Int, _ angle: Int) -> String {
        let d = ((angle % 360) + 360) % 360
        func part(_ v: Double) -> (Int, Int, Int)? {
            // v·r as n√m/den with m in {1, 2, 3}.
            for m in [1, 2, 3] {
                for den in [1, 2] {
                    let n = v * Double(r) * Double(den) / Double(m).squareRoot()
                    if Swift.abs(n - n.rounded()) < 1e-9 { return (Int(n.rounded()), m, den) }
                }
            }
            return nil
        }
        let t = trigExact(d)
        guard let re = part(t.c), let im = part(t.s) else { return "\(r)cis \(d)°" }
        func text(_ p: (Int, Int, Int), imaginary: Bool) -> String {
            let (n, m, den) = p
            if n == 0 { return "" }
            let g = gcd(Swift.abs(n), den)
            let nn = n / g, dd = den / g
            let mag = Swift.abs(nn)
            var body: String
            if m == 1 { body = imaginary ? (mag == 1 ? "i" : "\(mag)i") : "\(mag)" }
            else { body = imaginary ? (mag == 1 ? "i√\(m)" : "\(mag)i√\(m)") : (mag == 1 ? "√\(m)" : "\(mag)√\(m)") }
            if dd != 1 { body = "(\(body))/\(dd)" }
            return (nn < 0 ? "−" : "") + body
        }
        let a = text(re, imaginary: false), b = text(im, imaginary: true)
        if a.isEmpty { return b.isEmpty ? "0" : b }
        if b.isEmpty { return a }
        return a + (b.hasPrefix("−") ? " − " + b.dropFirst() : " + " + b)
    }

    /// k times an exact cos/sin text ("√3/2" → "4√3" for k = 8).
    static func timesTrig(_ k: Int, _ text: String) -> String {
        let negative = text.hasPrefix("−")
        let body = negative ? String(text.dropFirst()) : text
        let parts: [String: (Int, Int)] = ["0": (0, 1), "1": (1, 1), "1/2": (1, 2), "√2/2": (2, 2), "√3/2": (3, 2)]
        guard let (rad, den) = parts[body] else { return text }
        if rad == 0 { return "0" }
        return exact(negative ? -k : k, rad: rad, den: den).text
    }

    /// "y = mx + c" without the "y =": "(−3/4)x + 25/4", "2x − 1", "5".
    static func lineEq(_ mp: Int, _ mq: Int, _ cp: Int, _ cq: Int) -> String {
        var m = mp, mden = mq, c = cp, cden = cq
        if mden < 0 { m = -m; mden = -mden }
        if cden < 0 { c = -c; cden = -cden }
        let gm = gcd(Swift.abs(m), mden), gc = gcd(Swift.abs(c), cden)
        m /= gm; mden /= gm; c /= gc; cden /= gc
        var out = ""
        if m != 0 {
            if mden == 1 { out = m == 1 ? "x" : (m == -1 ? "−x" : "\(iv(m))x") }
            else { out = "(\(fr(m, mden)))x" }
        }
        if c != 0 || out.isEmpty {
            let ct = fr(Swift.abs(c), cden)
            out += out.isEmpty ? (c < 0 ? "−" : "") + ct : (c < 0 ? " − " : " + ") + ct
        }
        return out
    }

    static func argand(_ build: (inout GeoFigure) -> Void) -> GeoFigure {
        var f = GeoFigure()
        f.axes = ["Re", "Im"]
        build(&f)
        return f
    }

    static func complex(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 3, 1]
        case .medium: pool = [0, 1, 2, 3, 4]
        case .hard: pool = [2, 4, 5, 6, 7]
        case .bagrut: pool = [4, 5, 6, 7, 1]
        }
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], _ fig: GeoFigure?, tol: Double? = nil) -> QuizProblem {
            var q = number(.complex, level, seed, prompt, value, topic: "complex:\(topic)", steps: steps, tolerance: tol)
            q.figure = fig
            return q
        }
        func pick(_ prompt: String, _ correct: String, _ wrong: [String], _ topic: String, _ steps: [SolutionStep], _ fig: GeoFigure?) -> QuizProblem? {
            guard Set(wrong + [correct]).count == wrong.count + 1 else { return nil }
            var q = blank(.complex, level, seed, prompt, .number(0), topic: "complex:\(topic)")
            q.answer = shuffled(QuizOption(text: correct), wrong.map { QuizOption(text: $0) }, &r)
            q.steps = steps
            q.figure = fig
            return q
        }

        let which = choose(pool, cases, &r)
        switch which {
        case 0:
            // Multiply or divide; read the real or imaginary part.
            let a = r.nonZero(-5...5), b = r.nonZero(-5...5), c = r.nonZero(-4...4), d = r.nonZero(-4...4)
            let divide = r.bool() && level != .easy
            let wantRe = r.bool()
            if divide {
                let den = c * c + d * d
                let re = a * c + b * d, im = b * c - a * d
                return ask("z = (\(ct(a, b)))/(\(ct(c, d))). Find \(wantRe ? "Re z" : "Im z").", Double(wantRe ? re : im) / Double(den), "divide",
                           [H("Multiply by the conjugate of the denominator"), S("(\(ct(a, b)))(\(ct(c, -d))) / ((\(ct(c, d)))(\(ct(c, -d))))"),
                            S("Top: \(ct(re, im)),  bottom: \(c * c) + \(d * d) = \(den)"),
                            S("z = \(fr(re, den))\(im < 0 ? " − " : " + ")\(fr(Swift.abs(im), den))i"),
                            R(wantRe ? "Re z = \(fr(re, den))" : "Im z = \(fr(im, den))")], nil)
            }
            let re = a * c - b * d, im = a * d + b * c
            return ask("z = (\(ct(a, b)))(\(ct(c, d))). Find \(wantRe ? "Re z" : "Im z").", Double(wantRe ? re : im), "multiply",
                       [H("Multiply out (i² = −1)"), S("\(iv(a * c))\(signedTerm(a * d, "i"))\(signedTerm(b * c, "i"))\(signedTerm(b * d, "i²"))"),
                        S("= \(iv(a * c))\(sg(-b * d))\(signedTerm(a * d + b * c, "i"))", 2), R(wantRe ? "Re z = \(iv(re))" : "Im z = \(iv(im))")], nil)
        case 1:
            // z + k·z̄ = w.
            let x = r.nonZero(-5...5), y = r.nonZero(-5...5), k = r.pick([2, 3, -2, -3, 4])
            let wr = (1 + k) * x, wi = (1 - k) * y
            let kz = k == -1 ? "−" : (k == 1 ? "" : iv(k))
            return pick("Solve:  z + \(kz)z̄ = \(ct(wr, wi))   (z̄ is the conjugate of z)", ct(x, y), [ct(x, -y), ct(y, x), ct(wr, wi)], "conjugate equation",
                        [H("Write z = x + yi"), S("z̄ = x − yi"),
                         S("x + yi + \(kz)(x − yi) = \(coef(1 + k))x\(signedTerm(1 - k, "yi"))", 2),
                         H("Compare real and imaginary parts"), S("\(coef(1 + k))x = \(iv(wr))  ⇒  x = \(iv(x))"), S("\(coef(1 - k))y = \(iv(wi))  ⇒  y = \(iv(y))"),
                         R("z = \(ct(x, y))")],
                        argand { f in f.point(Double(x), Double(y), "z", highlight: true); f.point(Double(x), -Double(y), "z̄") })
        case 2:
            // z² + bz + c = 0 with complex roots p ± qi.
            let p = r.int(-4...4), q = r.int(1...5)
            let b = -2 * p, c = p * p + q * q
            let eq = "z²\(signedTerm(b, "z"))\(sg(c)) = 0"
            let correct = p == 0 ? "z = ±\(q == 1 ? "" : "\(q)")i" : "z = \(iv(p)) ± \(q == 1 ? "" : "\(q)")i"
            let wrong = [p == 0 ? "z = ±\(q)" : "z = \(iv(-p)) ± \(q == 1 ? "" : "\(q)")i", "z = \(iv(p)) ± \(q * q)i", "z = \(iv(p + q)), z = \(iv(p - q))"]
            return pick("Solve:  \(eq)", correct, wrong, "quadratic",
                        [H("The quadratic formula"), S("Discriminant = \(pv(b))² − 4·\(c) = \(iv(b * b - 4 * c)) < 0"),
                         S("√(\(iv(b * b - 4 * c))) = \(2 * q)i"),
                         S("z = (\(iv(-b)) ± \(2 * q)i)/2"), R(correct)],
                        argand { f in f.point(Double(p), Double(q), "z₁", highlight: true); f.point(Double(p), -Double(q), "z₂", highlight: true) })
        case 3:
            // Modulus and argument.
            let m = r.pick([1, 2, 3, 4]), th = r.pick([30, 45, 60, 120, 135, 150, 210, 225, 240, 300, 315, 330, 90, 270])
            let z = niceAlgebraic(m, th)
            let askArg = r.bool()
            let t = trigExact(th)
            return ask("z = \(z). Find \(askArg ? "its argument θ in degrees (0° ≤ θ < 360°)" : "|z|").", askArg ? Double(th) : Double(m), "polar form",
                       [H("Modulus"), S("|z| = √(Re² + Im²) = \(m)"),
                        H("Argument"), S("cos θ = Re/|z| = \(t.ct),  sin θ = Im/|z| = \(t.st)"),
                        S("The point is in quadrant \(th < 90 ? "I" : (th < 180 ? "II" : (th < 270 ? "III" : "IV"))) (or on an axis)."),
                        S("z = \(m)cis \(th)°"), R(askArg ? "θ = \(th)°" : "|z| = \(m)")],
                       argand { f in
                           let P = f.point(Double(m) * t.c, Double(m) * t.s, "z", highlight: true)
                           let O = f.point(0, 0, "", dot: false)
                           f.segment(O, P, askArg ? nil : "?", .arrow)
                           let X = f.point(Double(m), 0, "", dot: false)
                           f.angle(O, X, P, askArg ? "?" : "θ")
                       })
        case 4:
            // De Moivre.
            let (m, th) = r.pick([(1, 45), (2, 30), (2, 60), (1, 60), (2, 45), (1, 120), (2, 150), (1, 30), (2, 135)])
            let n = r.int(3...8)
            let total = n * th
            let t = trigExact(total)
            let mod = Int(pow(Double(m), Double(n)))
            let z = niceAlgebraic(m, th)
            let wantRe = r.bool() || Swift.abs(t.s) < 1e-9
            let value = Double(mod) * (wantRe ? t.c : t.s)
            let valueText = niceAlgebraic(mod, total)
            return ask("z = \(z). Find \(wantRe ? "Re" : "Im")(z^\(n)).", value, "de moivre",
                       [H("Polar form"), S("|z| = \(m),  arg z = \(th)°:  z = \(m)cis \(th)°"),
                        H("De Moivre"), S("z^\(n) = \(m)^\(n)·cis(\(n)·\(th)°) = \(mod)cis \(total)°"),
                        S("\(total)° is the same direction as \(((total % 360) + 360) % 360)°: cos = \(t.ct), sin = \(t.st)"),
                        S("z^\(n) = \(valueText)"), R("\(wantRe ? "Re" : "Im")(z^\(n)) = \(timesTrig(mod, wantRe ? t.ct : t.st))")],
                       argand { f in
                           let O = f.point(0, 0, "", dot: false)
                           let P = f.point(Double(m) * cos(deg(Double(th))), Double(m) * sin(deg(Double(th))), "z")
                           f.segment(O, P, nil, .arrow)
                       }, tol: 1e-6)
        case 5, 6:
            // zⁿ = w: the roots, and the regular polygon they make.
            let n = r.pick([3, 4, 6, 3, 4]), R0 = r.pick([1, 2, 3, 2])
            let phi = r.pick([0, 90, 180, 270, 60, 120])
            let w = niceAlgebraic(Int(pow(Double(R0), Double(n))), phi)
            let args = (0..<n).map { (phi + 360 * $0) / n }
            let roots: [(Double, Double)] = (0..<n).map { k in
                let a: Double = deg(Double(phi + 360 * k) / Double(n))
                return (Double(R0) * cos(a), Double(R0) * sin(a))
            }
            let fig = argand { f in
                let ids = roots.enumerated().map { i, p in f.point(p.0, p.1, "z\(sub(i + 1))") }
                f.polygon(ids, .highlight)
                f.circle(0, 0, Double(R0), .faint)
            }
            let base = [H("Polar form of the right side"), S("\(w) = \(Int(pow(Double(R0), Double(n))))cis \(phi)°"),
                        H("The roots"), S("|z| = \(Int(pow(Double(R0), Double(n))))^(1/\(n)) = \(R0)"),
                        S("arg z = (\(phi)° + 360°k)/\(n),  k = 0, …, \(n - 1):  " + args.map { "\($0)°" }.joined(separator: ", "))]
            let exactArgs = (0..<n).allSatisfy { (phi + 360 * $0) % n == 0 }
            if which == 6, exactArgs {
                let inQ1 = args.filter { $0 > 0 && $0 < 90 }.count
                if r.bool() {
                    return ask("Solve z^\(n) = \(w). What is the argument (in degrees, 0° ≤ θ < 360°) of the root with the largest argument?", Double(args.max()!),
                               "roots argument", base + [R("θ = \(args.max()!)°")], fig)
                }
                return ask("Solve z^\(n) = \(w). How many of the roots are strictly inside the first quadrant?", Double(inQ1), "roots quadrant",
                           base + [S("Strictly between 0° and 90°: \(args.filter { $0 > 0 && $0 < 90 }.map { "\($0)°" }.joined(separator: ", "))"),
                                   R("\(inQ1) root\(inQ1 == 1 ? "" : "s")")], fig)
            }
            let area: (Double, String)
            switch n {
            case 3: area = (3 * 3.0.squareRoot() / 4 * Double(R0 * R0), exact(3 * R0 * R0, rad: 3, den: 4).text)
            case 4: area = (2 * Double(R0 * R0), "\(2 * R0 * R0)")
            default: area = (3 * 3.0.squareRoot() / 2 * Double(R0 * R0), exact(3 * R0 * R0, rad: 3, den: 2).text)
            }
            return ask("The solutions of z^\(n) = \(w) are the vertices of a polygon. Find its area.", area.0, "roots polygon",
                       base + [H("A regular \(n)-gon"), S("The roots are equally spaced on the circle |z| = \(R0): \(n) triangles from the centre, each with angle \(360 / n)°"),
                               S("Area = \(n)·½·\(R0)²·sin \(360 / n)°"), R("Area = \(area.1)")], fig)
        default:
            // |z − z₀| = R: the largest or smallest |z|.
            let (a, b) = r.pick([(3, 4), (4, 3), (-3, 4), (5, 12), (-6, 8), (8, -6), (0, 5), (-4, -3)])
            let d = Int(Double(a * a + b * b).squareRoot().rounded())
            let R0 = r.int(1...(d + 4))
            guard R0 != d else { return nil }
            let largest = r.bool()
            let value = largest ? d + R0 : Swift.abs(d - R0)
            return ask("z moves on the circle |z − (\(ct(a, b)))| = \(R0). Find the \(largest ? "largest" : "smallest") possible value of |z|.", Double(value), "loci",
                       [H("What the equation means"), S("All points at distance \(R0) from z₀ = \(ct(a, b)): a circle with centre z₀ and radius \(R0)."),
                        H("Distance from the origin"), S("|z₀| = √(\(a * a) + \(b * b)) = \(d)"),
                        S(largest ? "The farthest point is on the line through 0 and z₀, beyond z₀: \(d) + \(R0)"
                                  : (R0 < d ? "The origin is outside the circle; the nearest point is \(d) − \(R0) away." : "The origin is inside the circle; the nearest point is \(R0) − \(d) away.")),
                        R("|z| \(largest ? "max" : "min") = \(value)")],
                       argand { f in
                           f.circle(Double(a), Double(b), Double(R0), .highlight)
                           let C = f.point(Double(a), Double(b), "z₀")
                           let O = f.point(0, 0, "0")
                           f.segment(O, C, nil, .dashed)
                       })
        }
    }
}
