import Foundation

// Growth and decay word problems (572, chapter 2) and finding a function
// from its derivative and a point (571, calculus: "antiderivative through a point").

extension QuizFactory {
    /// "2x³ − x + 4" from coefficients, highest power first.
    static func polyT(_ c: [Int]) -> String { Solver.polyText(c).replacingOccurrences(of: "-", with: "−") }

    // MARK: - Growth and decay

    static func growth(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 2, 0]
        case .medium: pool = [0, 1, 2, 3]
        case .hard: pool = [1, 2, 3, 4, 5]
        case .bagrut: pool = [3, 4, 5, 1]
        }
        let twoDP = "Give the answer to 2 decimal places."
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], tol: Double = 0.006) -> QuizProblem {
            number(.growth, level, seed, prompt, value, topic: "growth:\(topic)", steps: steps, tolerance: tol)
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Compound growth.
            let start = r.pick([1000, 2000, 5000, 10000, 800, 1500]), p = r.pick([2, 3, 4, 5, 6, 8, 10, 12]), t = r.int(3...12)
            let q = 1 + Double(p) / 100
            let value = Double(start) * pow(q, Double(t))
            let what = r.pick(["A bank deposit of \(start) ₪ earns \(p)% a year (added to the deposit).", "A town of \(start) people grows by \(p)% every year."])
            return ask("\(what) How much will there be after \(t) years? \(twoDP)", value, "compound",
                       [H("Each year multiplies by the same factor"), S("Growth of \(p)%: q = 1 + \(p)/100 = \(dec(q))"),
                        H("After t years"), S("A(t) = A₀·qᵗ = \(start)·\(dec(q))^\(t)"), R("A(\(t)) ≈ \(dp(value))")])
        case 1:
            // Find the yearly rate.
            let start = r.pick([1000, 2000, 5000, 4000]), t = r.int(3...10), p = r.double(2...12)
            let end = (Double(start) * pow(1 + p / 100, Double(t))).rounded()
            let rate = (pow(end / Double(start), 1 / Double(t)) - 1) * 100
            return ask("An amount grew from \(start) to \(Int(end)) in \(t) years, by the same percentage every year. Find that percentage. \(twoDP)", rate, "rate",
                       [H("Set up"), S("\(start)·qᵗ = \(Int(end)) with t = \(t)"), S("q^\(t) = \(Int(end))/\(start) = \(dp(end / Double(start), 4))"),
                        H("Take the \(t)-th root"), S("q = (\(dp(end / Double(start), 4)))^(1/\(t)) ≈ \(dp(1 + rate / 100, 4))"),
                        R("p = (q − 1)·100 ≈ \(dp(rate))%")])
        case 2:
            // Half-life.
            let n0 = r.pick([80, 100, 200, 500, 640, 1000]), T = r.pick([2, 3, 4, 5, 8, 10]), t = T * r.int(1...4) + r.pick([0, 0, 1, 2])
            let value = Double(n0) * pow(0.5, Double(t) / Double(T))
            let askK = r.bool() && level != .easy
            if askK {
                return ask("A substance has a half-life of \(T) years: N(t) = N₀e^(−kt). Find k. Give it exactly (e.g. ln 2/5) or to 4 decimal places.",
                           log(2) / Double(T), "decay constant",
                           [H("Half of it is left after \(T) years"), S("N₀e^(−\(T)k) = ½N₀  ⇒  e^(−\(T)k) = ½"),
                            H("Take ln"), S("−\(T)k = ln ½ = −ln 2"), R("k = ln 2 / \(T) ≈ \(dp(log(2) / Double(T), 4))")], tol: 0.00006)
            }
            return ask("A substance has a half-life of \(T) years. There are \(n0) g now. How much is left after \(t) years? \(twoDP)", value, "half-life",
                       [H("Halve every \(T) years"), S("After t years: N = \(n0)·(½)^(t/\(T))"),
                        H("Substitute t = \(t)"), S("t/\(T) = \(fr(t, T)) (the number of half-lives)"), R("N = \(n0)·(½)^(\(fr(t, T))) ≈ \(dp(value))")])
        case 3:
            // How long until a target?
            let p = r.pick([3, 4, 5, 6, 8, 10, 12, 15]), factor = r.pick([2, 3, 1.5, 5])
            let q = 1 + Double(p) / 100
            let t = log(factor) / log(q)
            let decay = r.bool()
            if decay {
                let d = r.pick([5, 10, 12, 20, 25]), frac = r.pick([0.5, 0.25, 0.1, 0.2])
                let qd = 1 - Double(d) / 100
                let td = log(frac) / log(qd)
                return ask("A car loses \(d)% of its value every year. After how many years is it worth \(dec(frac * 100))% of the price new? \(twoDP)", td, "decay time",
                           [H("Set up"), S("Each year ×\(dec(qd)):  \(dec(qd))ᵗ = \(dec(frac))"),
                            H("Take ln"), S("t·ln \(dec(qd)) = ln \(dec(frac))"), R("t = ln \(dec(frac)) / ln \(dec(qd)) ≈ \(dp(td)) years")])
            }
            return ask("A population grows by \(p)% a year. After how many years will it be \(dec(factor)) times as big? \(twoDP)", t, "time",
                       [H("Set up"), S("A₀·\(dec(q))ᵗ = \(dec(factor))A₀  ⇒  \(dec(q))ᵗ = \(dec(factor))"),
                        H("Take ln"), S("t·ln \(dec(q)) = ln \(dec(factor))"), R("t = ln \(dec(factor)) / ln \(dec(q)) ≈ \(dp(t)) years")])
        case 4:
            // Two populations: when are they equal?
            let a0 = r.pick([1000, 2000, 3000]), b0 = a0 * r.pick([2, 3, 4]) / 1
            let pa = r.pick([8, 10, 12, 15]), pb = r.pick([1, 2, 3, 4])
            let qa = 1 + Double(pa) / 100, qb = 1 + Double(pb) / 100
            let t = log(Double(b0) / Double(a0)) / log(qa / qb)
            return ask("Town A has \(a0) people and grows by \(pa)% a year. Town B has \(b0) people and grows by \(pb)% a year. After how many years will they be equal? \(twoDP)", t,
                       "two populations",
                       [H("Set up"), S("\(a0)·\(dec(qa))ᵗ = \(b0)·\(dec(qb))ᵗ"),
                        S("(\(dec(qa))/\(dec(qb)))ᵗ = \(b0)/\(a0) = \(b0 / a0)"),
                        H("Take ln"), S("t = ln \(b0 / a0) / ln(\(dec(qa))/\(dec(qb)))"), R("t ≈ \(dp(t)) years")])
        default:
            // Find the model N(t) = N₀e^(kt) from two values.
            let n0 = r.pick([100, 200, 50, 400]), m = r.pick([2, 3, 4]), T = r.pick([2, 3, 4, 5])
            let n1 = n0 * m
            let askK = r.bool()
            if askK {
                return ask("A culture follows N(t) = N₀e^(kt). N(0) = \(n0) and N(\(T)) = \(n1). Find k (exactly, e.g. ln \(m)/\(T), or to 4 decimal places).",
                           log(Double(m)) / Double(T), "find k",
                           [H("Use both values"), S("N(0) = N₀ = \(n0)"), S("\(n0)e^(\(T)k) = \(n1)  ⇒  e^(\(T)k) = \(m)"),
                            H("Take ln"), R("k = ln \(m) / \(T) ≈ \(dp(log(Double(m)) / Double(T), 4))")], tol: 0.00006)
            }
            return ask("A culture follows N(t) = N₀e^(kt). N(0) = \(n0) and N(\(T)) = \(n1). Find N(\(2 * T)).", Double(n0 * m * m), "predict",
                       [H("Use both values"), S("N₀ = \(n0),  e^(\(T)k) = \(n1)/\(n0) = \(m)"),
                        H("Twice the time"), S("N(\(2 * T)) = \(n0)·e^(\(2 * T)k) = \(n0)·(e^(\(T)k))² = \(n0)·\(m)²"), R("N(\(2 * T)) = \(n0 * m * m)")], tol: 1e-6)
        }
    }

    // MARK: - Antiderivative through a point

    static func antiderivative(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 0, 1]
        case .medium: pool = [0, 1, 2]
        case .hard: pool = [1, 2, 3]
        case .bagrut: pool = [3, 1, 2]
        }
        let x = Expr.x
        func ask(_ prompt: String, _ derivative: Expr, _ label: String, _ F: Expr, _ topic: String, _ steps: [SolutionStep]) -> QuizProblem {
            var q = blank(.antiderivative, level, seed, prompt, .function(F), topic: "antiderivative:\(topic)")
            q.formulaLabel = label
            q.formula = derivative
            q.steps = steps
            return q
        }

        switch choose(pool, cases, &r) {
        case 0:
            // f′ a polynomial, f through a point.
            let a = r.int(-2...2), b = r.int(-3...3), c = r.int(-5...5), d = r.int(-6...6)
            guard a != 0 || b != 0 else { return nil }
            let F = [a, b, c, d]
            let dF = [3 * a, 2 * b, c]
            let x0 = r.int(-2...2)
            let y0 = polyEval(F, x0)
            let partial = polyEval([a, b, c, 0], x0)
            return ask("The graph of f passes through (\(iv(x0)), \(iv(y0))). Find f(x).", Solver.polyExpr(dF), "f′(x) =", Solver.polyExpr(F), "polynomial",
                       [H("Integrate term by term"), S("f(x) = \(polyT([a, b, c, 0])) + C"),
                        H("Use the point"), S("f(\(iv(x0))) = \(iv(partial)) + C = \(iv(y0))  ⇒  C = \(iv(d))"),
                        R("f(x) = \(polyT(F))")])
        case 1:
            if r.bool() {
                // f′ = k·e^(mx).
                let m = r.pick([1, 2, -1, 3]), c1 = r.nonZero(-3...3), y0 = r.int(-4...6)
                let k = c1 * m
                let C = y0 - c1
                let inner: Expr = .exp(.scaled(m, 1, x))
                let F = Expr.sum([.scaled(c1, 1, inner), .n(C)])
                let ex = "e^(\(m == 1 ? "" : (m == -1 ? "−" : "\(m)"))x)"
                return ask("The graph of f passes through (0, \(iv(y0))). Find f(x).", .scaled(k, 1, inner), "f′(x) =", F, "exp",
                           [H("Integrate"), S("∫\(iv(k))\(ex) dx = \(iv(k))·\(ex)/\(m < 0 ? "(\(iv(m)))" : iv(m)) + C = \(c1 == 1 ? "" : (c1 == -1 ? "−" : iv(c1)))\(ex) + C"),
                            H("Use the point"), S("f(0) = \(coef(c1))e⁰ + C = \(iv(c1)) + C = \(iv(y0))  ⇒  C = \(iv(C))"),
                            R("f(x) = \(c1 == 1 ? "" : (c1 == -1 ? "−" : iv(c1)))\(ex)\(sg(C))")])
            }
            // f′ = k/x for x > 0.
            let k = r.nonZero(-4...5), y0 = r.int(-4...6)
            let F = Expr.sum([.scaled(k, 1, .ln(x)), .n(y0)])
            return ask("For x > 0, the graph of f passes through (1, \(iv(y0))). Find f(x).", .div(.n(k), x), "f′(x) =", F, "ln",
                       [H("Integrate"), S("∫\(iv(k))/x dx = \(coef(k))ln x + C  (x > 0)"),
                        H("Use the point"), S("f(1) = \(coef(k))ln 1 + C = C = \(iv(y0))"),
                        R("f(x) = \(k == 1 ? "" : (k == -1 ? "−" : iv(k)))ln x\(sg(y0))")])
        case 2:
            // f′ = A·cos(bx) or A·sin(bx), through (0, y0).
            let b = r.pick([1, 2, 3]), c1 = r.nonZero(-3...3), y0 = r.int(-3...5)
            let A = c1 * b
            let bx: Expr = .scaled(b, 1, x)
            let arg = b == 1 ? "x" : "\(b)x"
            if r.bool() {
                let F = Expr.sum([.scaled(c1, 1, .sin(bx)), .n(y0)])
                return ask("The graph of f passes through (0, \(iv(y0))). Find f(x).", .scaled(A, 1, .cos(bx)), "f′(x) =", F, "cos",
                           [H("Integrate"), S("∫\(iv(A))cos(\(arg)) dx = \(iv(A))·sin(\(arg))/\(b) + C"),
                            H("Use the point"), S("f(0) = \(coef(c1))sin 0 + C = C = \(iv(y0))"),
                            R("f(x) = \(c1 == 1 ? "" : (c1 == -1 ? "−" : iv(c1)))sin(\(arg))\(sg(y0))")])
            }
            // ∫A sin(bx) = −c1·cos(bx) + C;  f(0) = −c1 + C.
            let C = y0 + c1
            let F = Expr.sum([.scaled(-c1, 1, .cos(bx)), .n(C)])
            return ask("The graph of f passes through (0, \(iv(y0))). Find f(x).", .scaled(A, 1, .sin(bx)), "f′(x) =", F, "sin",
                       [H("Integrate"), S("∫\(iv(A))sin(\(arg)) dx = −\(A < 0 ? "(\(iv(A)))" : iv(A))·cos(\(arg))/\(b) + C"),
                        H("Use the point"), S("f(0) = \(coef(-c1))cos 0 + C = \(iv(-c1)) + C = \(iv(y0))  ⇒  C = \(iv(C))"),
                        R("f(x) = \(-c1 == 1 ? "" : (-c1 == -1 ? "−" : iv(-c1)))cos(\(arg))\(sg(C))")])
        default:
            // f″ given, plus f′ at one point and f at another.
            let a = r.nonZero(-2...2), b = r.int(-3...3), c = r.int(-4...4), d = r.int(-5...5)
            let F = [a, b, c, d]
            let x1 = r.int(-1...2), x2 = r.int(-1...2)
            let v1 = 3 * a * x1 * x1 + 2 * b * x1 + c
            let y2 = polyEval(F, x2)
            let d2 = [6 * a, 2 * b]
            let partialC = 3 * a * x1 * x1 + 2 * b * x1
            let partialD = polyEval([a, b, c, 0], x2)
            return ask("f′(\(iv(x1))) = \(iv(v1)) and the graph of f passes through (\(iv(x2)), \(iv(y2))). Find f(x).", Solver.polyExpr(d2), "f″(x) =",
                       Solver.polyExpr(F), "second derivative",
                       [H("Integrate once: f′"), S("f′(x) = \(polyT([3 * a, 2 * b, 0])) + C₁"),
                        S("f′(\(iv(x1))) = \(iv(partialC)) + C₁ = \(iv(v1))  ⇒  C₁ = \(iv(c))"),
                        H("Integrate again: f"), S("f(x) = \(polyT([a, b, c, 0])) + C₂"),
                        S("f(\(iv(x2))) = \(iv(partialD)) + C₂ = \(iv(y2))  ⇒  C₂ = \(iv(d))"),
                        R("f(x) = \(polyT(F))")])
        }
    }
}
