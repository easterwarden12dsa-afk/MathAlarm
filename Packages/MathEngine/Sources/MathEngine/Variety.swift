import Foundation

// Limits and tangents built from random parts (like the derivative and
// integral generators), so two questions rarely look alike.

extension QuizFactory {
    // MARK: Small exact-arithmetic helpers

    static func polyMul(_ a: [Int], _ b: [Int]) -> [Int] {
        var out = Array(repeating: 0, count: a.count + b.count - 1)
        for (i, x) in a.enumerated() { for (j, y) in b.enumerated() { out[i + j] += x * y } }
        return out
    }

    static func polyEval(_ c: [Int], _ x: Int) -> Int { c.reduce(0) { $0 * x + $1 } }

    /// "(x − 2)", "x" — for products.
    static func paren(_ c: [Int]) -> String {
        let t = Solver.polyText(c)
        return c.filter { $0 != 0 }.count > 1 ? "(\(t))" : t
    }

    /// A double as a fraction with a small denominator, if it is one.
    static func rational(_ v: Double, maxDen: Int = 60) -> (Int, Int)? {
        guard v.isFinite else { return nil }
        for d in 1...maxDen {
            let n = (v * Double(d)).rounded()
            if Swift.abs(n / Double(d) - v) < 1e-9 * Swift.max(1, Swift.abs(v)) { return (Int(n), d) }
        }
        return nil
    }

    static func ratText(_ v: Double) -> String {
        guard let (n, d) = rational(v) else { return num(v) }
        return frac(n, d)
    }

    // MARK: - Limits

    static func limit(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 4, 0, 5]
        case .medium: pool = [0, 1, 2, 4, 5, 6]
        case .hard: pool = [2, 3, 5, 6, 7, 8, 1]
        case .bagrut: pool = [3, 6, 7, 8, 9, 0, 2]
        }
        let x = Expr.x
        let infinite = ["+∞", "−∞", "0", "Doesn't exist"].map { QuizOption(text: $0) }
        func q(_ label: String, _ e: Expr, _ answer: QuizAnswer, _ steps: [SolutionStep], _ result: String, _ topic: String) -> QuizProblem {
            var p = blank(.limit, level, seed, "Find the limit.", answer, topic: "limit:\(topic)")
            p.formulaLabel = label
            p.formula = e
            p.steps = steps + [R(result)]
            return p
        }
        func at(_ p: Int) -> String { "lim x→\(iv(p))" }
        /// " + 3/x", " − 3/x" or "".
        func over(_ v: Int, _ t: String) -> String { v == 0 ? "" : (v < 0 ? " − \(-v)/\(t)" : " + \(v)/\(t)") }

        switch choose(pool, cases, &r) {
        case 0:
            // 0/0 rational: (x − p)·A over (x − p)·B, both expanded.
            let p = r.int(-3...4)
            let hard = level == .hard || level == .bagrut
            let A: [Int] = hard && r.bool() ? [1, r.int(-4...4), r.int(-6...6)] : [r.nonZero(-3...3), r.int(-6...6)]
            let B: [Int] = hard && r.bool() ? [1, r.int(-4...4), r.int(-6...6)] : [r.nonZero(-3...3), r.int(-6...6)]
            let a = polyEval(A, p), b = polyEval(B, p)
            guard a != 0, b != 0, A != B else { return nil }
            let lin = [1, -p]
            let N = polyMul(lin, A), D = polyMul(lin, B)
            return q(at(p), .div(Solver.polyExpr(N), Solver.polyExpr(D)), .number(Double(a) / Double(b)),
                     [H("Substitute"), S("Top: \(Solver.polyText(N)) at x = \(iv(p)) gives 0.   Bottom: 0 as well."),
                      S("0/0 tells us (\(xm(p))) is a factor of both."),
                      H("Factor"), S("Top: \(Solver.polyText(N)) = (\(xm(p)))·\(paren(A))"),
                      S("Bottom: \(Solver.polyText(D)) = (\(xm(p)))·\(paren(B))"),
                      H("Cancel and substitute"), S("For x ≠ \(iv(p)) the fraction is \(paren(A)) / \(paren(B))"),
                      S("At x = \(iv(p)):  \(iv(a)) / \(iv(b))")],
                     "The limit is \(frac(a, b))", "factor")
        case 1:
            // Rational at ±∞: compare degrees.
            let dn = r.int(1...3), dd = r.int(1...3)
            func poly(_ d: Int) -> [Int] { [r.nonZero(-5...5)] + (0..<d).map { _ in r.int(-6...6) } }
            let N = poly(dn), D = poly(dd)
            let minus = (level == .hard || level == .bagrut) && r.bool()
            let label = minus ? "lim x→−∞" : "lim x→∞"
            let lead = Double(N[0]) / Double(D[0])
            var steps = [H("The form"), S("Top and bottom both grow without bound: the form ∞/∞."),
                         H("Divide by x\(Solver.sup(dd)), the highest power in the bottom"),
                         S("Every term with x left in a denominator → 0.")]
            if dn < dd {
                steps.append(S("The top becomes terms like \(N[0])/x\(dd - dn == 1 ? "" : Solver.sup(dd - dn)) → 0, the bottom → \(D[0])"))
                return q(label, .div(Solver.polyExpr(N), Solver.polyExpr(D)), .number(0), steps, "The limit is 0", "infinity:lower")
            }
            if dn == dd {
                steps.append(S("Only the leading terms are left:  \(iv(N[0]))/\(iv(D[0]))"))
                return q(label, .div(Solver.polyExpr(N), Solver.polyExpr(D)), .number(lead), steps, "The limit is \(frac(N[0], D[0]))", "infinity:equal")
            }
            // The top's degree is bigger: ±∞, decided by the leading terms.
            let k = dn - dd
            let sign = (lead > 0 ? 1 : -1) * (minus && k % 2 == 1 ? -1 : 1)
            steps.append(S("The fraction behaves like (\(frac(N[0], D[0])))·x\(k == 1 ? "" : Solver.sup(k))"))
            steps.append(S("x\(k == 1 ? "" : Solver.sup(k)) → \(minus && k % 2 == 1 ? "−∞" : "+∞") as x → \(minus ? "−∞" : "∞"), times \(frac(N[0], D[0]))"))
            return q(label, .div(Solver.polyExpr(N), Solver.polyExpr(D)), .choice(infinite, correct: sign > 0 ? 0 : 1),
                     steps, "The limit is \(sign > 0 ? "+∞" : "−∞")", "infinity:bigger")
        case 2:
            // (√(x + a) − b)/(x − p) with p + a = b²: multiply by the conjugate.
            let b = r.int(1...4), p = r.int(-3...6)
            let a = b * b - p
            let squares = r.bool() && p != 0
            let flip = r.bool()
            let root = Expr.sqrt(a == 0 ? x : .sum([x, .n(a)]))
            let top: Expr = flip ? .sub(.n(b), root) : .sub(root, .n(b))
            let den: Expr = squares ? .sub(.p(x, 2), .n(p * p)) : .sum([x, .n(-p)])
            let rootText = "√(x\(sg(a)))"
            let extra = squares ? (2 * p) : 1
            let value = Double(flip ? -1 : 1) / (Double(2 * b) * Double(extra))
            return q(at(p), .div(top, den), .number(value),
                     [H("Substitute"), S("√(\(iv(p))\(sg(a))) = √\(b * b) = \(b), so the top is 0; the bottom is 0 too: 0/0."),
                      H("Multiply by the conjugate"), S("Multiply top and bottom by \(rootText) + \(b):"),
                      S("top × (\(rootText) + \(b)) = (x\(sg(a))) − \(b * b) = \(xm(p))\(flip ? "   (times −1, because the top is \(b) − \(rootText))" : "")", 2),
                      H("Cancel"), S(squares ? "x² − \(p * p) = (\(xm(p)))(\(xm(-p))), so (\(xm(p))) cancels, leaving \(flip ? "−" : "")1 / [(\(xm(-p)))(\(rootText) + \(b))]"
                                             : "(\(xm(p))) cancels, leaving \(flip ? "−" : "")1 / (\(rootText) + \(b))"),
                      H("Substitute again"), S(squares ? "\(flip ? "−" : "")1 / [(\(iv(2 * p)))·(\(b) + \(b))]" : "\(flip ? "−" : "")1 / (\(b) + \(b))")],
                     "The limit is \(ratText(value))", "conjugate")
        case 3:
            // √(m²x² + kx + c) − mx → k/(2m).
            let m = r.int(1...3), k = r.nonZero(-8...8), c = r.int(-5...5)
            let inner = Solver.polyExpr([m * m, k, c])
            let mx: Expr = m == 1 ? x : .scaled(m, 1, x)
            return q("lim x→∞", .sub(.sqrt(inner), mx), .number(Double(k) / Double(2 * m)),
                     [H("The form"), S("Both terms → ∞: the form ∞ − ∞."),
                      H("Multiply by the conjugate"),
                      S("(√(\(Solver.polyText([m * m, k, c]))) − \(m == 1 ? "" : "\(m)")x)·(√(…) + \(m == 1 ? "" : "\(m)")x) = \(Solver.polyText([m * m, k, c])) − \(m * m == 1 ? "" : "\(m * m)")x² = \(Solver.polyText([k, c]))"),
                      S("So the expression is (\(Solver.polyText([k, c]))) / (√(\(Solver.polyText([m * m, k, c]))) + \(m == 1 ? "" : "\(m)")x)", 2),
                      H("Divide top and bottom by x"),
                      S("(\(iv(k))\(over(c, "x"))) / (√(\(m * m)\(over(k, "x"))\(over(c, "x²"))) + \(m))"),
                      S("As x → ∞ this → \(iv(k)) / (\(m) + \(m))")],
                     "The limit is \(frac(k, 2 * m))", "conjugate infinity")
        case 4:
            // At a pole: one-sided or two-sided.
            let p = r.int(-3...4), qn = r.int(-5...5)
            let top = p + qn
            guard top != 0 else { return nil }
            let squared = r.int(0...2) == 0
            let side = r.int(0...2)          // 0: from the right, 1: from the left, 2: both sides
            let N = Expr.sum([x, .n(qn)])
            let D: Expr = squared ? .p(.sum([x, .n(-p)]), 2) : .sum([x, .n(-p)])
            let label = side == 2 ? at(p) : "\(at(p))\(side == 0 ? "⁺" : "⁻")"
            var steps = [H("Substitute"), S("The top → \(iv(p))\(sg(qn)) = \(iv(top)) and the bottom → 0: the fraction grows without bound (±∞).")]
            func signText(_ positive: Bool) -> String { positive ? "positive" : "negative" }
            let rightPos = top > 0, leftPos = (top > 0) == squared
            let correct: Int
            if side == 2 && !squared {
                steps += [H("Look at both sides"),
                          S("From the right, \(xm(p)) is a tiny positive number:  \(iv(top))/(+0) → \(rightPos ? "+∞" : "−∞")"),
                          S("From the left, it is a tiny negative number:  \(iv(top))/(−0) → \(leftPos ? "+∞" : "−∞")"),
                          S("The two sides disagree, so the (two-sided) limit doesn't exist.")]
                return q(label, .div(N, D), .choice(infinite, correct: 3), steps, "The limit doesn't exist", "pole two-sided")
            }
            let positive = side == 1 ? leftPos : rightPos
            correct = positive ? 0 : 1
            if squared {
                steps += [H("The sign of the bottom"), S("(\(xm(p)))² is positive on both sides of \(iv(p)).")]
            } else {
                steps += [H("The sign of the bottom"),
                          S("x → \(iv(p))\(side == 0 ? "⁺" : "⁻") means x is a little \(side == 0 ? "more" : "less") than \(iv(p)), so \(xm(p)) is a tiny \(signText(side == 0)) number.")]
            }
            steps += [H("The sign of the fraction"), S("\(signText(top > 0)) ÷ \(signText(squared || side == 0)) = \(signText(positive))")]
            return q(label, .div(N, D), .choice(infinite, correct: correct), steps, "The limit is \(positive ? "+∞" : "−∞")", squared ? "pole squared" : "pole one-sided")
        case 5:
            // sin u / u → 1 families at 0.
            let a = r.int(1...6), b = r.int(1...5)
            let ax: Expr = .scaled(a, 1, x), bx: Expr = .scaled(b, 1, x)
            let at0 = "lim x→0"
            switch r.int(0...4) {
            case 0:
                return q(at0, .div(.sin(ax), bx), .number(Double(a) / Double(b)),
                         [H("The form"), S("sin 0 = 0: the form 0/0."), H("Make sin u / u appear"),
                          S("sin(\(a)x)/(\(b)x) = (\(a)/\(b))·sin(\(a)x)/(\(a)x)"), S("sin u / u → 1 as u = \(a)x → 0")],
                         "The limit is \(frac(a, b))", "sin u/u")
            case 1:
                return q(at0, .div(.tan(ax), bx), .number(Double(a) / Double(b)),
                         [H("The form"), S("tan 0 = 0: the form 0/0."), H("Write tan as sin/cos"),
                          S("tan(\(a)x)/(\(b)x) = (\(a)/\(b))·[sin(\(a)x)/(\(a)x)]·[1/cos(\(a)x)]"), S("The bracket → 1 and cos(\(a)x) → 1")],
                         "The limit is \(frac(a, b))", "tan u/u")
            case 2:
                guard a != b else { return nil }
                return q(at0, .div(.sin(ax), .sin(bx)), .number(Double(a) / Double(b)),
                         [H("The form"), S("0/0."), H("Divide top and bottom by x"),
                          S("= [\(a)·sin(\(a)x)/(\(a)x)] / [\(b)·sin(\(b)x)/(\(b)x)]"), S("Both brackets → 1, leaving \(a)/\(b)")],
                         "The limit is \(frac(a, b))", "sin/sin")
            case 3:
                return q(at0, .div(.sub(1, .cos(ax)), .p(x, 2)), .number(Double(a * a) / 2),
                         [H("The form"), S("1 − cos 0 = 0: the form 0/0."), H("Use 1 − cos u = 2 sin²(u/2)"),
                          S("(1 − cos(\(a)x))/x² = 2·sin²(\(a)x/2)/x² = 2·(\(a)/2)²·[sin(\(a)x/2)/(\(a)x/2)]²"),
                          S("The bracket → 1, leaving 2·\(frac(a * a, 4))")],
                         "The limit is \(frac(a * a, 2))", "1 − cos")
            default:
                return q(at0, .div(.p(.sin(ax), 2), .scaled(b, 1, .p(x, 2))), .number(Double(a * a) / Double(b)),
                         [H("The form"), S("0/0."), H("Square the special limit"),
                          S("sin²(\(a)x)/(\(b)x²) = (\(a * a)/\(b))·[sin(\(a)x)/(\(a)x)]²"), S("The bracket → 1")],
                         "The limit is \(frac(a * a, b))", "sin²")
            }
        case 6:
            // e and ln special limits at 0.
            let a = r.nonZero(-5...5), b = r.int(1...4)
            let at0 = "lim x→0"
            switch r.int(0...3) {
            case 0:
                return q(at0, .div(.sub(.exp(.scaled(a, 1, x)), 1), .scaled(b, 1, x)), .number(Double(a) / Double(b)),
                         [H("The form"), S("e⁰ − 1 = 0: the form 0/0."), H("Use (eᵘ − 1)/u → 1"),
                          S("(e^(\(a)x) − 1)/(\(b)x) = (\(iv(a))/\(b))·(e^(\(a)x) − 1)/(\(a)x)")],
                         "The limit is \(frac(a, b))", "e special")
            case 1:
                let A = Swift.abs(a)
                return q(at0, .div(.ln(.sum([1, .scaled(A, 1, x)])), .scaled(b, 1, x)), .number(Double(A) / Double(b)),
                         [H("The form"), S("ln 1 = 0: the form 0/0."), H("Use ln(1 + u)/u → 1"),
                          S("ln(1 + \(A)x)/(\(b)x) = (\(A)/\(b))·ln(1 + \(A)x)/(\(A)x)")],
                         "The limit is \(frac(A, b))", "ln special")
            case 2:
                let c = r.int(-4...4)
                guard c != a else { return nil }
                return q(at0, .div(.sub(.exp(.scaled(a, 1, x)), .exp(.scaled(c, 1, x))), x), .number(Double(a - c)),
                         [H("The form"), S("1 − 1 = 0: the form 0/0."), H("Split into two special limits"),
                          S("(e^(\(a)x) − 1)/x − (e^(\(c)x) − 1)/x"), S("→ \(iv(a)) − (\(iv(c)))")],
                         "The limit is \(iv(a - c))", "e difference")
            default:
                return q(at0, .div(.sub(.exp(.scaled(a, 1, x)), 1), .sin(.scaled(b, 1, x))), .number(Double(a) / Double(b)),
                         [H("The form"), S("0/0."), H("Divide top and bottom by x"),
                          S("[\(iv(a))·(e^(\(a)x) − 1)/(\(a)x)] / [\(b)·sin(\(b)x)/(\(b)x)]"), S("Both brackets → 1")],
                         "The limit is \(frac(a, b))", "e over sin")
            }
        case 7:
            // The 1^∞ form.
            let a = r.nonZero(-4...4), b = r.int(1...4)
            switch r.int(0...2) {
            case 0:
                let k = a * b
                return q("lim x→∞", .pow(.sum([1, .div(.n(a), x)]), .scaled(b, 1, x)), .number(exp(Double(k))),
                         [H("The form"), S("1 + \(iv(a))/x → 1 and the power → ∞: the form 1^∞ (not simply 1)."),
                          H("Make (1 + 1/n)ⁿ appear"), S("Put n = x/\(iv(a)):  (1 + \(iv(a))/x)^(\(b)x) = [(1 + 1/n)ⁿ]^(\(k))"),
                          S("(1 + 1/n)ⁿ → e")], "The limit is e^(\(iv(k)))", "1^∞")
            case 1:
                return q("lim x→0", .pow(.sum([1, .scaled(a, 1, .x)]), .div(1, .scaled(b, 1, x))), .number(exp(Double(a) / Double(b))),
                         [H("The form"), S("1 + \(iv(a))x → 1 and the power 1/(\(b)x) → ±∞: the form 1^∞."),
                          H("Make (1 + u)^(1/u) appear"), S("(1 + \(iv(a))x)^(1/(\(b)x)) = [(1 + u)^(1/u)]^(\(frac(a, b))) with u = \(iv(a))x"),
                          S("(1 + u)^(1/u) → e as u → 0")], "The limit is e^(\(frac(a, b)))", "1^∞ at 0")
            default:
                let c = r.int(-4...4)
                guard c != a else { return nil }
                return q("lim x→∞", .pow(.div(.sum([x, .n(a)]), .sum([x, .n(c)])), x), .number(exp(Double(a - c))),
                         [H("The form"), S("The base → 1 and the power → ∞: 1^∞."),
                          H("Rewrite the base"), S("(x\(sg(a)))/(x\(sg(c))) = 1 + \(iv(a - c))/(x\(sg(c)))"),
                          S("[1 + \(iv(a - c))/(x\(sg(c)))]^x → e^(\(iv(a - c))), like (1 + k/x)ˣ → eᵏ")],
                         "The limit is e^(\(iv(a - c)))", "1^∞ ratio")
            }
        case 8:
            // L'Hôpital: two functions that vanish at p.
            let p = r.pick([0, 1, 2])
            struct Part { let e: Expr; let d: (Int, Int); let text: String }
            func parts(_ k: Int) -> [Part] {
                let t = Expr.sum([x, .n(-p)])
                var list = [
                    Part(e: .sub(.exp(.scaled(k, 1, t)), 1), d: (k, 1), text: "e^(\(k)(\(xm(p)))) − 1"),
                    Part(e: .sin(.scaled(k, 1, t)), d: (k, 1), text: "sin(\(k)(\(xm(p))))"),
                    Part(e: .ln(.sum([.scaled(k, 1, t), 1])), d: (k, 1), text: "ln(\(k)(\(xm(p))) + 1)"),
                    Part(e: .sub(.p(x, 3), .n(p * p * p)), d: (3 * p * p, 1), text: "x³ − \(p * p * p)"),
                ]
                if p != 0 { list.append(Part(e: .sub(.p(x, 2), .n(p * p)), d: (2 * p, 1), text: "x² − \(p * p)")) }
                let s = r.pick([1, 4, 9])
                if s - p >= 0 { list.append(Part(e: .sub(.sqrt(.sum([x, .n(s - p)])), .n(Int(Double(s).squareRoot()))), d: (1, 2 * Int(Double(s).squareRoot())), text: "√(x\(sg(s - p))) − \(Int(Double(s).squareRoot()))")) }
                return list.filter { $0.d.0 != 0 }
            }
            let F = r.pick(parts(r.int(1...4))), G = r.pick(parts(r.int(1...4)))
            guard F.text != G.text else { return nil }
            let value = (Double(F.d.0) / Double(F.d.1)) / (Double(G.d.0) / Double(G.d.1))
            let probe = (F.e.evaluate(at: Double(p) + 1e-6) / G.e.evaluate(at: Double(p) + 1e-6))
            guard Swift.abs(probe - value) < 1e-3 * Swift.max(1, Swift.abs(value)) else { return nil }
            return q(at(p), .div(F.e, G.e), .number(value),
                     [H("Substitute"), S("Both the top and the bottom are 0 at x = \(iv(p)): the form 0/0."),
                      H("L'Hôpital: differentiate top and bottom separately"),
                      SolutionStep("Top:", label: "(\(F.text))′ =", math: F.e.derivative().simplified(), depth: 1),
                      SolutionStep("Bottom:", label: "(\(G.text))′ =", math: G.e.derivative().simplified(), depth: 1),
                      H("Substitute x = \(iv(p))"), S("\(frac(F.d.0, F.d.1)) / \(frac(G.d.0, G.d.1))")],
                     "The limit is \(ratText(value))", "l'hopital")
        default:
            // Growth: exponentials beat powers, powers beat logs.
            let n = r.int(1...4), k = r.int(1...3)
            switch r.int(0...3) {
            case 0:
                return q("lim x→∞", .mul(.p(x, n), .exp(.scaled(-k, 1, x))), .number(0),
                         [H("The form"), S("x\(Solver.sup(n)) → ∞ and e^(−\(k)x) → 0: write it as x\(Solver.sup(n))/e^(\(k)x), the form ∞/∞."),
                          H("L'Hôpital \(n) time\(n == 1 ? "" : "s")"), S("Each step lowers the power of x by one; the bottom stays a multiple of e^(\(k)x)."),
                          S("After \(n) step\(n == 1 ? "" : "s"): \(Int((1...n).reduce(1, *)))/(\(Int(pow(Double(k), Double(n))))e^(\(k)x)) → 0")],
                         "The limit is 0", "growth exp")
            case 1:
                return q("lim x→∞", .div(.ln(x), .p(x, k)), .number(0),
                         [H("The form"), S("∞/∞."), H("L'Hôpital"), S("(ln x)′/(x\(Solver.sup(k)))′ = (1/x)/(\(k)x\(k == 1 ? "⁰" : Solver.sup(k - 1))) = 1/(\(k)x\(Solver.sup(k)))"),
                          S("→ 0")], "The limit is 0", "growth ln")
            case 2:
                return q("lim x→0⁺", .mul(.p(x, k), .ln(x)), .number(0),
                         [H("The form"), S("0·(−∞)."), H("Rewrite as a fraction"), S("x\(Solver.sup(k))·ln x = ln x / x^(−\(k)): the form −∞/∞."),
                          H("L'Hôpital"), S("(1/x) / (−\(k)x^(−\(k + 1))) = −x\(Solver.sup(k))/\(k)"), S("→ 0")],
                         "The limit is 0", "x^k ln x")
            default:
                return q("lim x→∞", .div(.exp(.scaled(k, 1, x)), .p(x, n)), .choice(infinite, correct: 0),
                         [H("The form"), S("∞/∞."), H("L'Hôpital \(n) time\(n == 1 ? "" : "s")"),
                          S("The top stays a multiple of e^(\(k)x); the bottom's power drops to a constant."),
                          S("e^(\(k)x) → ∞, so the fraction → +∞")], "The limit is +∞", "growth exp over power")
            }
        }
    }

    // MARK: - Tangent and normal lines

    static func tangent(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let x = Expr.x
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 2, 0]
        case .medium: pool = [0, 1, 2]
        default: pool = [0, 1, 2, 0]
        }
        func lineText(_ m: Double, _ b: Double) -> String {
            let mt = ratText(m)
            let coefficient = mt.contains("/") ? "(\(mt))" : mt
            var s = m == 0 ? "" : (mt == "1" ? "x" : (mt == "−1" ? "−x" : "\(coefficient)x"))
            if b != 0 || s.isEmpty { s += s.isEmpty ? ratText(b) : (b < 0 ? " − \(ratText(-b))" : " + \(ratText(b))") }
            return s
        }
        func line(_ m: Double, _ b: Double) -> Expr { Expr.sum([.mul(.num(m), x), .num(b)]).simplified() }

        let pick = choose(pool, cases, &r)
        switch pick {
        case 2:
            // A tangent with a given slope: solve f′(x) = m.
            let a = r.nonZero(-2...2), x0 = r.int(-3...3), c = r.int(-5...5), m = r.int(-6...6)
            let bCoef = m - 2 * a * x0
            let f = Solver.polyExpr([a, bCoef, c])
            let y0 = Double(a * x0 * x0 + bCoef * x0 + c)
            let b = y0 - Double(m * x0)
            var q = blank(.tangent, level, seed, "Find the tangent to f that has slope \(iv(m)). Type the right side of y = …", .function(line(Double(m), b)), topic: "tangent:slope")
            q.formulaLabel = "f(x) ="; q.formula = f
            q.steps = [H("Where is the slope \(iv(m))?"), S("f′(x) = \(Solver.polyText([2 * a, bCoef]))"),
                       S("f′(x) = \(iv(m)):  \(Solver.polyText([2 * a, bCoef])) = \(iv(m))  ⇒  x = \(iv(x0))"),
                       H("The point"), S("f(\(iv(x0))) = \(num(y0)), so the point is (\(iv(x0)), \(num(y0)))"),
                       H("The line"), S("y − \(y0 < 0 ? "(\(num(y0)))" : num(y0)) = \(iv(m))(x − \(x0 < 0 ? "(\(iv(x0)))" : iv(x0)))"),
                       R("y = \(lineText(Double(m), b))")]
            return q
        default:
            // At a point, from a random derivative-style function: the tangent, or the normal.
            let normal = pick == 1
            let base = ProblemFactory.make(.derivative, level: level == .bagrut ? .hard : level, seed: seed &+ 77)
            let f = base.display
            let candidates = [0, 1, -1, 2, -2, 3].filter { Double($0) >= base.domainLow && Double($0) <= base.domainHigh }
            let fp = f.derivative()
            guard let x0 = candidates.first(where: { v in
                let y = f.evaluate(at: Double(v)), m = fp.evaluate(at: Double(v))
                return rational(y, maxDen: 12) != nil && rational(m, maxDen: 12) != nil && Swift.abs(y) < 60 && Swift.abs(m) < 60 && (!normal || m != 0)
            }) else { return nil }
            let X = Double(x0)
            let y0 = f.evaluate(at: X), m = fp.evaluate(at: X)
            let slope = normal ? -1 / m : m
            let b = y0 - slope * X
            var q = blank(.tangent, level, seed,
                          normal ? "Find the normal to f at x = \(iv(x0)) (the line perpendicular to the tangent). Type the right side of y = …"
                                 : "Find the tangent line to f at x = \(iv(x0)). Type the right side of y = …",
                          .function(line(slope, b)), topic: normal ? "tangent:normal" : "tangent:point")
            q.formulaLabel = "f(x) ="; q.formula = f
            var steps: [SolutionStep] = [H("The point"), S("f(\(iv(x0))) = \(ratText(y0)), so the point is (\(iv(x0)), \(ratText(y0)))"),
                                         H("The slope of the tangent"),
                                         SolutionStep("Differentiate:", label: "f′(x) =", math: fp.simplified(), depth: 1),
                                         S("m = f′(\(iv(x0))) = \(ratText(m))")]
            if normal {
                steps += [H("The slope of the normal"), S("Perpendicular lines: m₁·m₂ = −1, so the normal's slope is −1/(\(ratText(m))) = \(ratText(slope))")]
            }
            steps += [H("The line through the point"),
                      S("y − \(y0 < 0 ? "(\(ratText(y0)))" : ratText(y0)) = \(ratText(slope))(x − \(x0 < 0 ? "(\(iv(x0)))" : iv(x0)))"),
                      R("y = \(lineText(slope, b))")]
            q.steps = steps
            return q
        }
    }
}
