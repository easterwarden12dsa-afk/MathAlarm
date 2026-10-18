import Foundation

// Bagrut 5-unit topics beyond calculus: probability, trigonometry in the
// plane and min/max word problems. Answers are typed numbers: exact forms
// (√7, 5√2, 2/e, 3/10) are checked exactly; "to 2 decimal places" answers
// get a tolerance.

extension QuizFactory {
    // MARK: Formatting

    /// 0.3, 12, 2.25 — short decimals without trailing zeros.
    static func dec(_ v: Double) -> String {
        if Swift.abs(v - v.rounded()) < 1e-9 { return "\(Int(v.rounded()))".replacingOccurrences(of: "-", with: "−") }
        var t = String(format: "%.4f", v)
        while t.hasSuffix("0") { t.removeLast() }
        return t.replacingOccurrences(of: "-", with: "−")
    }

    static func dp(_ v: Double, _ places: Int = 2) -> String {
        String(format: "%.\(places)f", v).replacingOccurrences(of: "-", with: "−")
    }

    /// √n simplified: (k, m) with √n = k√m.
    static func surd(_ n: Int) -> (Int, Int) {
        var k = 1, m = n, f = 2
        while f * f <= m {
            if m % (f * f) == 0 { m /= f * f; k *= f } else { f += 1 }
        }
        return (k, m)
    }

    /// n·√rad / den, reduced and written out ("5√2", "7√3/3", "4").
    static func exact(_ n: Int, rad: Int, den: Int) -> (value: Double, text: String) {
        let (k, m) = surd(rad)
        var num = n * k, d = den
        let g = Swift.max(1, gcd(Swift.abs(num), Swift.abs(d)))
        num /= g; d /= g
        if d < 0 { num = -num; d = -d }
        let value = Double(num) * Double(m).squareRoot() / Double(d)
        var t = m == 1 ? "\(num)" : (num == 1 ? "√\(m)" : (num == -1 ? "−√\(m)" : "\(num)√\(m)"))
        if d != 1 { t += "/\(d)" }
        return (value, t.replacingOccurrences(of: "-", with: "−"))
    }

    static func sqrtText(_ n: Int) -> String { exact(1, rad: n, den: 1).text }

    static func binomial(_ n: Int, _ k: Int) -> Int {
        guard k >= 0, k <= n else { return 0 }
        var c = 1
        for i in 0..<k { c = c * (n - i) / (i + 1) }
        return c
    }

    static func number(_ kind: QuizKind, _ level: Level, _ seed: UInt64, _ prompt: String, _ value: Double,
                       topic: String, steps: [SolutionStep], tolerance: Double? = nil) -> QuizProblem {
        var q = blank(kind, level, seed, prompt, .number(value), topic: topic)
        q.steps = steps
        q.tolerance = tolerance
        return q
    }

    // MARK: - Probability

    static func probability(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 2]
        case .medium: pool = [2, 3, 4, 1]
        case .hard: pool = [4, 5, 6, 7]
        case .bagrut: pool = [5, 6, 7, 8, 9]
        }
        let threeDP = "Give the answer exactly or to 3 decimal places."
        let tol3 = 0.0006
        let H = SolutionStep.heading, S = { (t: String) in SolutionStep(t, depth: 1) }, R = { (t: String) in SolutionStep.result(t) }

        switch choose(pool, cases, &r) {
        case 0:
            // Two independent events.
            let ps = [0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
            let a = r.pick(ps), b = r.pick(ps)
            let ask = r.int(0...2)
            let names = r.pick([("Dana passes the test", "Yossi passes the test"),
                                ("the bus is late", "it rains"),
                                ("the first light is green", "the second light is green")])
            let value: Double, what: String, steps: [SolutionStep]
            switch ask {
            case 0:
                value = 1 - (1 - a) * (1 - b)
                what = "at least one of the two happens"
                steps = [H("Complement"), S("\"At least one\" is the opposite of \"neither\"."),
                         S("P(neither) = (1 − \(dec(a)))·(1 − \(dec(b))) = \(dec((1 - a) * (1 - b)))"),
                         R("P(at least one) = 1 − \(dec((1 - a) * (1 - b))) = \(dec(value))")]
            case 1:
                value = a * (1 - b) + (1 - a) * b
                what = "exactly one of the two happens"
                steps = [H("Two separate cases"), S("Only the first: \(dec(a))·\(dec(1 - b)) = \(dec(a * (1 - b)))"),
                         S("Only the second: \(dec(1 - a))·\(dec(b)) = \(dec((1 - a) * b))"),
                         R("P(exactly one) = \(dec(value))")]
            default:
                value = a * b
                what = "both happen"
                steps = [H("Independent events multiply"), S("For independent events, P(A and B) = P(A)·P(B)."), R("P(both) = \(dec(a))·\(dec(b)) = \(dec(value))")]
            }
            return number(.probability, level, seed,
                          "The probability that \(names.0) is \(dec(a)); the probability that \(names.1) is \(dec(b)), independently. Find the probability that \(what).",
                          value, topic: "probability:independent", steps: steps)
        case 1:
            // Two draws without replacement.
            let red = r.int(3...7), blue = r.int(2...6), n = red + blue
            let ask = r.int(0...2)
            let rr = red * (red - 1), bb = blue * (blue - 1), all = n * (n - 1)
            let (num, what): (Int, String) = {
                switch ask {
                case 0: return (rr, "both are red")
                case 1: return (rr + bb, "both are the same colour")
                default: return (2 * red * blue, "one is red and one is blue")
                }
            }()
            var steps = [H("Draw one, then another (no return)"),
                         S("P(red, red) = \(red)/\(n) · \(red - 1)/\(n - 1) = \(Solver.frac(rr, all))")]
            if ask >= 1 { steps.append(S("P(blue, blue) = \(blue)/\(n) · \(blue - 1)/\(n - 1) = \(Solver.frac(bb, all))")) }
            if ask == 2 { steps = [H("Two orders"), S("Red then blue: \(red)/\(n) · \(blue)/\(n - 1)"), S("Blue then red: \(blue)/\(n) · \(red)/\(n - 1)")] }
            steps.append(R("P = \(Solver.frac(num, all))"))
            var q = number(.probability, level, seed,
                           "A bag has \(red) red and \(blue) blue balls. Two are taken out, one after the other, without putting back. Find the probability that \(what).",
                           Double(num) / Double(all), topic: "probability:draws", steps: steps)
            q.diagram = QuizDiagram(.bag, numbers: [Double(red), Double(blue)])
            return q
        case 2:
            // Two-way table.
            let ctx = r.pick([(["Boys", "Girls"], ["Passed", "Failed"], "a student"),
                              (["Grade 11", "Grade 12"], ["Plays sport", "Doesn't"], "a student"),
                              (["Morning", "Evening"], ["On time", "Late"], "a train")])
            let c = (0..<4).map { _ in r.int(6...40) }
            let total = c.reduce(0, +)
            let ask = r.int(0...2)
            let i = r.int(0...1), j = r.int(0...1)
            let cell = c[i * 2 + j], rowT = c[i * 2] + c[i * 2 + 1], colT = c[j] + c[2 + j]
            let (num, den, what, why): (Int, Int, String, String) = {
                switch ask {
                case 0: return (cell, rowT, "\"\(ctx.1[j])\", given it is in \"\(ctx.0[i])\"", "Only the \"\(ctx.0[i])\" row counts: \(rowT) in all")
                case 1: return (cell, colT, "in \"\(ctx.0[i])\", given it is \"\(ctx.1[j])\"", "Only the \"\(ctx.1[j])\" column counts: \(colT) in all")
                default: return (cell, total, "in \"\(ctx.0[i])\" and \"\(ctx.1[j])\"", "All \(total) count")
                }
            }()
            var q = number(.probability, level, seed,
                           "The table shows counts. \(ctx.2.capitalized) is picked at random. Find the probability that it is \(what).",
                           Double(num) / Double(den), topic: "probability:table",
                           steps: [H(ask == 2 ? "Out of everyone" : "Conditional probability: shrink the sample"), S(why),
                                   S("Of those, \(cell) are in the cell asked about"), R("P = \(cell)/\(den) = \(Solver.frac(num, den))")])
            q.table = QuizTable(columns: [""] + ctx.1, rows: [[ctx.0[0], "\(c[0])", "\(c[1])"], [ctx.0[1], "\(c[2])", "\(c[3])"]])
            return q
        case 3, 5:
            // Binomial: exactly k (or at least k on harder levels).
            let (pn, pd) = r.pick([(1, 2), (1, 3), (2, 3), (1, 4), (3, 4), (1, 5), (2, 5)])
            let p = Double(pn) / Double(pd)
            let n = r.int(4...7), k = r.int(1...(n - 1))
            let atLeast = level == .hard || level == .bagrut
            let context = r.pick(["A basketball player scores a free throw with probability \(pn)/\(pd).",
                                  "A seed sprouts with probability \(pn)/\(pd).",
                                  "A die-like game is won with probability \(pn)/\(pd)."])
            func term(_ i: Int) -> Double { Double(binomial(n, i)) * pow(p, Double(i)) * pow(1 - p, Double(n - i)) }
            if atLeast && k >= 2 {
                let lo = (0..<k).map(term).reduce(0, +)
                let useComplement = k <= n / 2 + 1
                let value = 1 - lo
                var steps = [H("Is it binomial?"), S("\(n) independent tries with the same p: X ~ B(\(n), \(pn)/\(pd))."), S("P(X = i) = C(\(n), i)·(\(pn)/\(pd))ⁱ·(\(pd - pn)/\(pd))^(\(n) − i)")]
                if useComplement {
                    steps.append(SolutionStep.heading("Complement: 1 − P(X ≤ \(k - 1))"))
                    for i in 0..<k { steps.append(S("P(X = \(i)) = \(binomial(n, i))·(\(pn)/\(pd))^\(i)·(\(pd - pn)/\(pd))^\(n - i) ≈ \(dp(term(i), 4))")) }
                    steps.append(R("P(X ≥ \(k)) = 1 − \(dp(lo, 4)) ≈ \(dp(value, 3))"))
                } else {
                    steps.append(SolutionStep.heading("Add P(X = \(k)) up to P(X = \(n))"))
                    for i in k...n { steps.append(S("P(X = \(i)) = \(binomial(n, i))·(\(pn)/\(pd))^\(i)·(\(pd - pn)/\(pd))^\(n - i) ≈ \(dp(term(i), 4))")) }
                    steps.append(R("P(X ≥ \(k)) ≈ \(dp(value, 3))"))
                }
                return number(.probability, level, seed, "\(context) In \(n) independent tries, find the probability of at least \(k) successes. \(threeDP)",
                              value, topic: "probability:binomial", steps: steps, tolerance: tol3)
            }
            let value = term(k)
            return number(.probability, level, seed, "\(context) In \(n) independent tries, find the probability of exactly \(k) successes. \(threeDP)",
                          value, topic: "probability:binomial",
                          steps: [H("Is it binomial?"), S("\(n) independent tries with the same p = \(pn)/\(pd) each time: X ~ B(\(n), \(pn)/\(pd))."),
                                  H("The formula"), S("P(X = k) = C(n, k)·pᵏ·(1 − p)ⁿ⁻ᵏ"),
                                  S("C(\(n), \(k)) = \(binomial(n, k)) ways to choose which tries succeed"),
                                  H("Substitute k = \(k)"),
                                  R("P = \(binomial(n, k))·(\(pn)/\(pd))^\(k)·(\(pd - pn)/\(pd))^\(n - k) ≈ \(dp(value, 3))")],
                          tolerance: tol3)
        case 4, 8:
            // Tree diagram / Bayes.
            let share = r.pick([0.3, 0.4, 0.5, 0.6, 0.7])
            let d1 = r.pick([0.02, 0.05, 0.1, 0.04]), d2 = r.pick([0.01, 0.03, 0.08, 0.06])
            let ctx = r.pick([("Machine A makes", "of a factory's parts; machine B makes the rest", "defective", "made by machine A"),
                              ("Route A is taken on", "of days; route B on the others", "late", "on route A")])
            let pd = share * d1 + (1 - share) * d2
            let bayes = level == .bagrut || r.bool()
            let value = bayes ? share * d1 / pd : pd
            let prompt = "\(ctx.0) \(dec(share * 100))% \(ctx.1). With A, \(dec(d1 * 100))% are \(ctx.2); with B, \(dec(d2 * 100))%. "
                + (bayes ? "One is found \(ctx.2). Find the probability it was \(ctx.3). " : "Find the probability that one picked at random is \(ctx.2). ") + threeDP
            var steps = [H("Tree diagram"), S("A and \(ctx.2): \(dec(share))·\(dec(d1)) = \(dec(share * d1))"),
                         S("B and \(ctx.2): \(dec(1 - share))·\(dec(d2)) = \(dec((1 - share) * d2))"),
                         SolutionStep("P(\(ctx.2)) = \(dec(pd))", depth: 1, style: bayes ? nil : .result)]
            if bayes {
                steps += [H("Conditional probability"), S("P(A | \(ctx.2)) = P(A and \(ctx.2)) / P(\(ctx.2))"),
                          R("= \(dec(share * d1))/\(dec(pd)) ≈ \(dp(value, 3))")]
            }
            var q = number(.probability, level, seed, prompt, value, topic: bayes ? "probability:bayes" : "probability:tree", steps: steps, tolerance: tol3)
            q.diagram = QuizDiagram(.tree, numbers: [share, d1, d2], labels: ["A", "B", ctx.2, "not \(ctx.2)"])
            return q
        case 6:
            // How many tries for "at least one" to pass a threshold.
            let (pn, pd) = r.pick([(1, 3), (1, 4), (1, 5), (1, 6), (1, 10), (2, 5)])
            let t = r.pick([0.9, 0.95, 0.99, 0.8])
            let p = Double(pn) / Double(pd)
            let n = Int(ceil(log(1 - t) / log(1 - p) - 1e-9))
            return number(.probability, level, seed,
                          "Each try succeeds with probability \(pn)/\(pd). What is the smallest number of tries so that the probability of at least one success is more than \(dec(t))?",
                          Double(n), topic: "probability:how many",
                          steps: [H("At least one success in n tries"), S("P = 1 − (\(pd - pn)/\(pd))ⁿ"),
                                  S("1 − (\(pd - pn)/\(pd))ⁿ > \(dec(t))  ⇔  (\(pd - pn)/\(pd))ⁿ < \(dec(1 - t))"),
                                  S("Take ln (ln of a number below 1 is negative, so the inequality flips): n > ln \(dec(1 - t)) / ln(\(pd - pn)/\(pd)) ≈ \(dp(log(1 - t) / log(1 - p)))"),
                                  R("n = \(n)")])
        case 7:
            // First success on try k.
            let (pn, pd) = r.pick([(1, 2), (1, 3), (1, 4), (2, 5), (1, 6)])
            let p = Double(pn) / Double(pd), k = r.int(2...5)
            let atMost = r.bool()
            let value = atMost ? 1 - pow(1 - p, Double(k)) : pow(1 - p, Double(k - 1)) * p
            return number(.probability, level, seed,
                          "A player keeps trying until the first success; each try succeeds with probability \(pn)/\(pd). Find the probability that " +
                          (atMost ? "it takes at most \(k) tries. " : "the first success is on try \(k). ") + threeDP,
                          value, topic: "probability:first success",
                          steps: atMost
                            ? [H("Opposite: all \(k) fail"), S("\"At most \(k) tries\" means a success somewhere in the first \(k); its opposite is \(k) failures in a row."), S("P(all fail) = (\(pd - pn)/\(pd))^\(k)"), R("P = 1 − (\(pd - pn)/\(pd))^\(k) ≈ \(dp(value, 3))")]
                            : [H("Fail \(k - 1) times, then succeed"), S("The tries are independent: multiply (1 − p) for each failure, then p for the success."), R("P = (\(pd - pn)/\(pd))^\(k - 1)·\(pn)/\(pd) ≈ \(dp(value, 3))")],
                          tolerance: tol3)
        default:
            // Conditional on "at least one".
            let (pn, pd) = r.pick([(1, 2), (1, 3), (2, 3), (1, 4)])
            let p = Double(pn) / Double(pd), n = r.int(3...5), k = r.int(1...(n - 1))
            let exactly = Double(binomial(n, k)) * pow(p, Double(k)) * pow(1 - p, Double(n - k))
            let atLeastOne = 1 - pow(1 - p, Double(n))
            let value = exactly / atLeastOne
            return number(.probability, level, seed,
                          "A shot hits with probability \(pn)/\(pd); \(n) independent shots are fired. Given that at least one hit, find the probability of exactly \(k) hits. \(threeDP)",
                          value, topic: "probability:conditional binomial",
                          steps: [H("Conditional probability"), S("P(exactly \(k) | at least 1) = P(exactly \(k)) / P(at least 1) (exactly \(k) is inside \"at least 1\")"),
                                  H("The two probabilities"),
                                  S("P(exactly \(k)) = \(binomial(n, k))·(\(pn)/\(pd))^\(k)·(\(pd - pn)/\(pd))^\(n - k) ≈ \(dp(exactly, 4))"),
                                  S("P(at least 1) = 1 − (\(pd - pn)/\(pd))^\(n) ≈ \(dp(atLeastOne, 4))"),
                                  R("P ≈ \(dp(exactly, 4))/\(dp(atLeastOne, 4)) ≈ \(dp(value, 3))")],
                          tolerance: tol3)
        }
    }

    // MARK: - Trigonometry in the plane

    /// sin of a "nice" angle as k·√m / 2.
    private static let niceSin: [Int: (k: Int, m: Int, text: String)] = [
        30: (1, 1, "1/2"), 45: (1, 2, "√2/2"), 60: (1, 3, "√3/2"), 90: (2, 1, "1"),
        120: (1, 3, "√3/2"), 135: (1, 2, "√2/2"), 150: (1, 1, "1/2"),
    ]

    /// The figure for a triangle with sides a = BC, b = CA, c = AB (vertices A, B, C).
    static func figure(a: Double, b: Double, c: Double, sides: [String?], angles: [String?]) -> TriangleFigure {
        let x = (a * a + c * c - b * b) / (2 * a)
        let y = Swift.max(0.05 * a, (Swift.max(0, c * c - x * x)).squareRoot())
        return TriangleFigure(points: [x, y, 0, 0, a, 0], vertexLabels: ["A", "B", "C"], sideLabels: sides, angleLabels: angles)
    }

    static func deg(_ d: Double) -> Double { d * .pi / 180 }

    static func triangle(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 0, 1]
        case .medium: pool = [2, 3, 4, 0]
        case .hard: pool = [5, 6, 7, 3]
        case .bagrut: pool = [7, 8, 9, 6]
        }
        let H = SolutionStep.heading, S = { (t: String) in SolutionStep(t, depth: 1) }, R = { (t: String) in SolutionStep.result(t) }
        let twoDP = "Give the answer to 2 decimal places."

        func make(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], _ fig: TriangleFigure, tol: Double? = nil) -> QuizProblem {
            var q = number(.triangle, level, seed, prompt, value, topic: "triangle:\(topic)", steps: steps, tolerance: tol)
            q.triangle = fig
            return q
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Law of cosines with 60°, 90° or 120°.
            let A = r.pick([60, 120, 90]), b = r.int(2...9), c = r.int(2...9)
            let cross = A == 60 ? -b * c : (A == 120 ? b * c : 0)
            let a2 = b * b + c * c + cross
            let a = Double(a2).squareRoot()
            let cosText = A == 60 ? "1/2" : (A == 120 ? "−1/2" : "0")
            return make("In triangle ABC, AB = \(c), AC = \(b) and ∠A = \(A)°. Find BC.", a, "law of cosines",
                        [H("What is given"), S("Two sides and the angle between them (SAS): the law of cosines finds the third side."),
                         H("Law of cosines"), S("BC² = AB² + AC² − 2·AB·AC·cos A"),
                         S("BC² = \(c * c) + \(b * b) − 2·\(c)·\(b)·(\(cosText)) = \(a2)"), R("BC = \(sqrtText(a2))")],
                        figure(a: a, b: Double(b), c: Double(c), sides: ["\(c)", "?", "\(b)"], angles: ["\(A)°", nil, nil]))
        case 1:
            // Area ½·b·c·sin A.
            let A = r.pick([30, 45, 60, 90, 120, 135, 150]), b = r.int(2...10), c = r.int(2...10)
            let s = niceSin[A]!
            let area = exact(b * c * s.k, rad: s.m, den: 4)
            let aSide = (Double(b * b + c * c) - 2 * Double(b * c) * cos(deg(Double(A)))).squareRoot()
            return make("In triangle ABC, AB = \(c), AC = \(b) and ∠A = \(A)°. Find the area of the triangle.", area.value, "area",
                        [H("What is given"), S("Two sides and the angle between them: the area is ½·(side)·(side)·sin(angle between)."),
                         H("Area formula"), S("S = ½·AB·AC·sin A"),
                         S("sin \(A)° = \(s.text)"), R("S = ½·\(c)·\(b)·\(s.text) = \(area.text)")],
                        figure(a: aSide, b: Double(b), c: Double(c), sides: ["\(c)", nil, "\(b)"], angles: ["\(A)°", nil, nil]))
        case 2:
            // Law of sines with nice angles.
            let pairs = [(30, 45), (45, 30), (30, 60), (60, 30), (45, 60), (60, 45), (30, 120), (120, 30), (45, 90), (30, 90), (60, 90), (135, 30), (45, 120)]
            let (A, B) = r.pick(pairs)
            let a = r.int(2...12)
            let sa = niceSin[A]!, sb = niceSin[B]!
            // b = a·sinB/sinA = a·kB√mB / (kA√mA) = a·kB·√(mA·mB) / (kA·mA)
            let b = exact(a * sb.k, rad: sa.m * sb.m, den: sa.k * sa.m)
            let C = 180 - A - B
            let cSide = Double(a) * sin(deg(Double(C))) / sin(deg(Double(A)))
            return make("In triangle ABC, BC = \(a), ∠A = \(A)° and ∠B = \(B)°. Find AC.", b.value, "law of sines",
                        [H("What is given"), S("Two angles and a side opposite one of them: the law of sines."),
                         H("Law of sines"), S("BC / sin A = AC / sin B"),
                         S("AC = BC·sin B / sin A = \(a)·(\(sb.text)) / (\(sa.text))"), R("AC = \(b.text)")],
                        figure(a: Double(a), b: b.value, c: cSide, sides: [nil, "\(a)", "?"], angles: ["\(A)°", "\(B)°", nil]))
        case 3:
            // An angle from three sides.
            let list: [(Int, Int, Int, Int)] = [(3, 8, 7, 60), (5, 8, 7, 60), (7, 15, 13, 60), (8, 15, 13, 60), (5, 21, 19, 60),
                                                (3, 5, 7, 120), (7, 8, 13, 120), (5, 16, 19, 120), (9, 15, 21, 120),
                                                (3, 4, 5, 90), (5, 12, 13, 90), (8, 15, 17, 90)]
            let (p, q, s, angle) = r.pick(list)
            let k = level == .easy ? 1 : r.int(1...2)
            let P = p * k, Q = q * k, Sd = s * k
            let cosText = Solver.frac(P * P + Q * Q - Sd * Sd, 2 * P * Q)
            // ∠C is opposite AB = s; CA = p, BC = q.
            return make("In triangle ABC, CA = \(P), BC = \(Q) and AB = \(Sd). Find ∠C in degrees.", Double(angle), "angle from sides",
                        [H("What is given"), S("All three sides (SSS): the law of cosines gives any angle."),
                         H("Law of cosines, solved for the angle"), S("AB² = CA² + BC² − 2·CA·BC·cos C"),
                         S("cos C = (\(P * P) + \(Q * Q) − \(Sd * Sd)) / (2·\(P)·\(Q)) = \(cosText)"), R("∠C = \(angle)°")],
                        figure(a: Double(Q), b: Double(P), c: Double(Sd), sides: ["\(Sd)", "\(Q)", "\(P)"], angles: [nil, nil, "?"]))
        case 4:
            // Circumradius R = a / (2 sin A).
            let A = r.pick([30, 45, 60, 90, 120, 135, 150]), a = r.int(2...12)
            let s = niceSin[A]!
            // R = a / (2·k√m/2) = a / (k√m) = a√m / (k·m)
            let R0 = exact(a, rad: s.m, den: s.k * s.m)
            let B = Double(r.int(10...(170 - A) / 2 + 5)), C = 180 - Double(A) - B
            let scale = Double(a) / sin(deg(Double(A)))
            return make("In triangle ABC, BC = \(a) and ∠A = \(A)°. Find the radius R of the circle through A, B and C.", R0.value, "circumradius",
                        [H("What is given"), S("A side and the angle opposite it: that is exactly what the extended law of sines needs."),
                         H("Extended law of sines"), S("BC / sin A = 2R"), S("2R = \(a) / (\(s.text))"), R("R = \(R0.text)")],
                        figure(a: Double(a), b: scale * sin(deg(B)), c: scale * sin(deg(C)), sides: [nil, "\(a)", nil], angles: ["\(A)°", nil, nil]))
        case 5:
            // Any angle: law of cosines, 2 decimal places.
            let A = Double(r.int(25...140)), b = Double(r.int(3...12)), c = Double(r.int(3...12))
            let a2 = b * b + c * c - 2 * b * c * cos(deg(A))
            let a = a2.squareRoot()
            return make("In triangle ABC, AB = \(dec(c)), AC = \(dec(b)) and ∠A = \(dec(A))°. Find BC. \(twoDP)", a, "law of cosines",
                        [H("What is given"), S("Two sides and the angle between them (SAS): the law of cosines."),
                         H("Law of cosines"), S("BC² = AB² + AC² − 2·AB·AC·cos A"), S("BC² = \(dec(c * c)) + \(dec(b * b)) − 2·\(dec(c))·\(dec(b))·cos \(dec(A))° ≈ \(dp(a2, 3))"),
                         R("BC ≈ \(dp(a))")],
                        figure(a: a, b: b, c: c, sides: [dec(c), "?", dec(b)], angles: ["\(dec(A))°", nil, nil]), tol: 0.006)
        case 6:
            // Two steps: the third side, then an angle (or the area).
            let B = Double(r.int(30...130)), aS = Double(r.int(4...12)), cS = Double(r.int(4...12))
            let b2 = aS * aS + cS * cS - 2 * aS * cS * cos(deg(B))
            let b = b2.squareRoot()
            let cosA = (b * b + cS * cS - aS * aS) / (2 * b * cS)
            let A = acos(cosA) * 180 / .pi
            return make("In triangle ABC, AB = \(dec(cS)), BC = \(dec(aS)) and ∠B = \(dec(B))°. Find ∠A in degrees. \(twoDP)", A, "two steps",
                        [H("Step 1 · The third side"), S("AC² = AB² + BC² − 2·AB·BC·cos B ≈ \(dp(b2, 3))"), S("AC ≈ \(dp(b, 3))"),
                         H("Step 2 · The angle"), S("cos A = (AC² + AB² − BC²) / (2·AC·AB) ≈ \(dp(cosA, 4))"),
                         S("(The law of cosines gives the angle without the sine rule's two possible answers.)"), R("∠A ≈ \(dp(A))°")],
                        figure(a: aS, b: b, c: cS, sides: [dec(cS), dec(aS), nil], angles: ["?", "\(dec(B))°", nil]), tol: 0.006)
        case 7:
            // A median.
            let B = Double(r.int(35...125)), aS = Double(r.int(4...12)), cS = Double(r.int(4...12))
            let b2 = aS * aS + cS * cS - 2 * aS * cS * cos(deg(B))
            let b = b2.squareRoot()
            let cosA = (b * b + cS * cS - aS * aS) / (2 * b * cS)
            let m2 = cS * cS + (b / 2) * (b / 2) - 2 * cS * (b / 2) * cosA
            let m = m2.squareRoot()
            var fig = figure(a: aS, b: b, c: cS, sides: [dec(cS), dec(aS), nil], angles: [nil, "\(dec(B))°", nil])
            let pA = (fig.points[0], fig.points[1]), pC = (fig.points[4], fig.points[5])
            fig.extra = [0, 0, (pA.0 + pC.0) / 2, (pA.1 + pC.1) / 2]
            fig.extraLabel = "?"
            fig.extraPoint = "M"
            return make("In triangle ABC, AB = \(dec(cS)), BC = \(dec(aS)) and ∠B = \(dec(B))°. BM is the median to AC. Find BM. \(twoDP)", m, "median",
                        [H("Step 1 · AC"), S("AC² = AB² + BC² − 2·AB·BC·cos B ≈ \(dp(b2, 3)),  AC ≈ \(dp(b, 3))"),
                         H("Step 2 · ∠A"), S("cos A = (AC² + AB² − BC²) / (2·AC·AB) ≈ \(dp(cosA, 4))"),
                         H("Step 3 · Triangle ABM"), S("AM = AC/2 ≈ \(dp(b / 2, 3))"),
                         S("BM² = AB² + AM² − 2·AB·AM·cos A ≈ \(dp(m2, 3))"), R("BM ≈ \(dp(m))")],
                        fig, tol: 0.006)
        case 8:
            // A height, then the area.
            let B = Double(r.int(30...80)), C = Double(r.int(30...80)), aS = Double(r.int(5...14))
            let A = 180 - B - C
            let c = aS * sin(deg(C)) / sin(deg(A)), b = aS * sin(deg(B)) / sin(deg(A))
            let h = c * sin(deg(B))
            let askArea = r.bool()
            var fig = figure(a: aS, b: b, c: c, sides: [nil, dec(aS), nil], angles: [nil, "\(dec(B))°", "\(dec(C))°"])
            fig.extra = [fig.points[0], fig.points[1], fig.points[0], 0]
            fig.extraLabel = askArea ? nil : "?"
            fig.extraPoint = "D"
            let steps = [H("Step 1 · AB by the law of sines"), S("∠A = 180° − \(dec(B))° − \(dec(C))° = \(dec(A))°"),
                         S("AB = BC·sin C / sin A ≈ \(dp(c, 3))"),
                         H("Step 2 · The height in the right triangle ABD"), S("AD = AB·sin B ≈ \(dp(h, 3))")]
                + (askArea ? [S("S = ½·BC·AD"), R("S ≈ \(dp(aS * h / 2))")] : [R("AD ≈ \(dp(h))")])
            return make("In triangle ABC, BC = \(dec(aS)), ∠B = \(dec(B))° and ∠C = \(dec(C))°. AD is the height to BC. Find \(askArea ? "the area of the triangle" : "AD"). \(twoDP)",
                        askArea ? aS * h / 2 : h, askArea ? "area" : "height", steps, fig, tol: 0.006)
        default:
            // Isosceles triangle: base from legs and apex angle, then the radius.
            let apex = Double(r.int(30...140)), leg = Double(r.int(4...12))
            let base = 2 * leg * sin(deg(apex / 2))
            let R0 = base / (2 * sin(deg(apex)))
            return make("In isosceles triangle ABC, AB = AC = \(dec(leg)) and ∠A = \(dec(apex))°. Find the radius of the circle through A, B and C. \(twoDP)", R0, "circumradius",
                        [H("Step 1 · The base"), S("BC² = AB² + AC² − 2·AB·AC·cos A,  BC ≈ \(dp(base, 3))"),
                         H("Step 2 · Law of sines"), S("BC / sin A = 2R"), R("R ≈ \(dp(base, 3)) / (2·sin \(dec(apex))°) ≈ \(dp(R0))")],
                        figure(a: base, b: leg, c: leg, sides: [dec(leg), nil, dec(leg)], angles: ["\(dec(apex))°", nil, nil]), tol: 0.006)
        }
    }

    // MARK: - Min and max problems

    static func optimization(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 0, 1]
        case .medium: pool = [2, 3, 4, 1]
        case .hard: pool = [5, 6, 7, 4]
        case .bagrut: pool = [8, 9, 10, 7, 6]
        }
        let H = SolutionStep.heading, S = { (t: String) in SolutionStep(t, depth: 1) }, R = { (t: String) in SolutionStep.result(t) }
        var diagram: QuizDiagram?, graph: SketchProblem?
        func q(_ prompt: String, _ v: Double, _ topic: String, _ steps: [SolutionStep], tol: Double? = nil) -> QuizProblem {
            var p = number(.optimization, level, seed, prompt, v, topic: "optimization:\(topic)", steps: steps, tolerance: tol)
            p.diagram = diagram
            p.graph = graph
            return p
        }
        func plot(_ e: Expr, _ lo: Double, _ hi: Double) -> SketchProblem? {
            SketchFactory.finish(e, lo, hi, piBased: false, level: level, seed: seed)
        }
        let maxCheck = { (fn: String, at: String) in S("\(fn) changes from + to − at \(at), so it is a maximum.") }
        let minCheck = { (fn: String, at: String) in S("\(fn) changes from − to + at \(at), so it is a minimum.") }

        switch choose(pool, cases, &r) {
        case 0:
            let Sm = 2 * r.int(3...15)
            let askX = r.bool()
            return q("Two positive numbers add up to \(Sm). " + (askX ? "Find the larger of the two numbers when their product is as large as possible." : "Find the largest possible product."),
                     askX ? Double(Sm / 2) : Double(Sm * Sm / 4), "product",
                     [H("Set up"), S("Numbers x and \(Sm) − x, 0 < x < \(Sm)"), S("P(x) = x(\(Sm) − x) = \(Sm)x − x²"),
                      H("Differentiate"), S("P′(x) = \(Sm) − 2x = 0  ⇒  x = \(Sm / 2)"), maxCheck("P′", "x = \(Sm / 2)"),
                      R(askX ? "Both numbers are \(Sm / 2)" : "P max = \(Sm / 2)·\(Sm / 2) = \(Sm * Sm / 4)")])
        case 1:
            let L = 4 * r.int(5...30)
            let askX = r.bool()
            diagram = QuizDiagram(.fence, labels: ["x", "\(L) − 2x"])
            return q("A farmer fences a rectangle along a long wall, using \(L) m of fence for the other three sides. " +
                     (askX ? "Find the length of each side perpendicular to the wall for the largest area." : "Find the largest possible area (m²)."),
                     askX ? Double(L / 4) : Double(L * L / 8), "fence",
                     [H("Set up"), S("Sides x (twice, perpendicular to the wall) and \(L) − 2x"), S("A(x) = x(\(L) − 2x) = \(L)x − 2x²,  0 < x < \(L / 2)"),
                      H("Differentiate"), S("A′(x) = \(L) − 4x = 0  ⇒  x = \(L / 4)"), maxCheck("A′", "x = \(L / 4)"),
                      R(askX ? "x = \(L / 4) m" : "A max = \(L / 4)·\(L / 2) = \(L * L / 8) m²")])
        case 2:
            let s = 6 * r.int(1...6)
            let x = s / 6, V = x * (s - 2 * x) * (s - 2 * x)
            let askX = r.bool()
            diagram = QuizDiagram(.box, labels: ["\(s)", "x"])
            return q("From a square sheet of side \(s), equal squares of side x are cut from the corners and the sides folded up into an open box. " +
                     (askX ? "Find x for the largest volume." : "Find the largest possible volume."),
                     askX ? Double(x) : Double(V), "box",
                     [H("Set up"), S("Base (\(s) − 2x) by (\(s) − 2x), height x, 0 < x < \(s / 2)"), S("V(x) = x(\(s) − 2x)²"),
                      H("Differentiate (product rule)"), S("V′(x) = (\(s) − 2x)² − 4x(\(s) − 2x) = (\(s) − 2x)(\(s) − 6x)"),
                      S("V′ = 0 inside the domain at x = \(x)"), maxCheck("V′", "x = \(x)"),
                      R(askX ? "x = \(x)" : "V max = \(x)·\(s - 2 * x)² = \(V)")])
        case 3:
            let Sm = 3 * r.int(1...8)
            let y = 2 * Sm / 3, x = Sm / 3
            return q("x and y are positive and x + y = \(Sm). Find the largest possible value of x·y².", Double(x * y * y), "product",
                     [H("One variable"), S("x = \(Sm) − y,  P(y) = (\(Sm) − y)·y² = \(Sm)y² − y³,  0 < y < \(Sm)"),
                      H("Differentiate"), S("P′(y) = \(2 * Sm)y − 3y² = y(\(2 * Sm) − 3y) = 0  ⇒  y = \(y)"), maxCheck("P′", "y = \(y)"),
                      R("x = \(x), y = \(y),  P max = \(x)·\(y * y) = \(x * y * y)")])
        case 4:
            let k = r.int(2...6)
            let askX = r.bool()
            // Area 2x(k² − x²), max at x = k/√3, area 4k³/(3√3) = 4k³√3/9.
            let xs = exact(k, rad: 3, den: 3), area = exact(4 * k * k * k, rad: 3, den: 9)
            graph = plot(.sub(.n(k * k), .p(.x, 2)), -Double(k) - 0.6, Double(k) + 0.6)
            diagram = QuizDiagram(.rectangleUnder, numbers: [-Double(k) / 2, Double(k) / 2, Double(k) / 2])
            return q("A rectangle has two vertices on the x-axis and two on the parabola y = \(k * k) − x² (above the axis), symmetric about the y-axis. " +
                     (askX ? "Find the x of its right-hand vertices when its area is largest." : "Find its largest possible area."),
                     askX ? xs.value : area.value, "rectangle in parabola",
                     [H("Set up"), S("Right vertices at x and the height is \(k * k) − x², so the width is 2x"), S("A(x) = 2x(\(k * k) − x²) = \(2 * k * k)x − 2x³,  0 < x < \(k)"),
                      H("Differentiate"), S("A′(x) = \(2 * k * k) − 6x² = 0  ⇒  x² = \(Solver.frac(k * k, 3)),  x = \(xs.text)"), maxCheck("A′", "x = \(xs.text)"),
                      R(askX ? "x = \(xs.text)" : "A max = 2·\(xs.text)·(\(k * k) − \(Solver.frac(k * k, 3))) = \(area.text)")])
        case 5:
            let a = r.int(1...8)
            // Closest point on y = √x to (a, 0): d² = (x − a)² + x, min at x = a − ½, d = √(a − ¼) = √(4a − 1)/2.
            let d = exact(1, rad: 4 * a - 1, den: 2)
            return q("Find the shortest distance from the point (\(a), 0) to the graph of y = √x.", d.value, "distance",
                     [H("Distance squared (easier, same minimum)"), S("A point on the graph: (x, √x),  d² = (x − \(a))² + x"),
                      H("Differentiate"), S("(d²)′ = 2(x − \(a)) + 1 = 0  ⇒  x = \(Solver.frac(2 * a - 1, 2))"), minCheck("(d²)′", "x = \(Solver.frac(2 * a - 1, 2))"),
                      R("d min = √(\(Solver.frac(1, 4)) + \(Solver.frac(2 * a - 1, 2))) = \(d.text)")])
        case 6:
            let k = r.int(1...4)
            let askT = r.bool()
            let kt = k == 1 ? "t" : "\(k)t"
            graph = plot(.exp(.scaled(-k, 1, .x)), -0.3 / Double(k), 3.5 / Double(k))
            diagram = QuizDiagram(.rectangleUnder, numbers: [0, 1.6 / Double(k), 1.6 / Double(k)])
            return q("A rectangle has vertices (0, 0), (t, 0), (t, e^(−\(kt))) and (0, e^(−\(kt))), t > 0. " +
                     (askT ? "Find t for the largest area." : "Find the largest area (exactly, e.g. with e)."),
                     askT ? 1 / Double(k) : 1 / (Double(k) * M_E), "rectangle under exp",
                     [H("Set up"), S("A(t) = t·e^(−\(kt))"), H("Differentiate (product rule)"), S("A′(t) = e^(−\(kt))(1 − \(kt))"),
                      S("e^(−\(kt)) > 0, so A′ = 0 at t = \(Solver.frac(1, k))"), maxCheck("A′", "t = \(Solver.frac(1, k))"),
                      R(askT ? "t = \(Solver.frac(1, k))" : "A max = \(Solver.frac(1, k))·e^(−1) = 1/\(k == 1 ? "" : "\(k)")e")])
        case 7:
            let A = r.pick([2, 3, 5, 6, 7, 8, 10, 12, 18, 20, 24])
            let P = exact(4, rad: A, den: 1)
            return q("A rectangle has area \(A). Find its smallest possible perimeter.", P.value, "perimeter",
                     [H("Set up"), S("Sides x and \(A)/x,  P(x) = 2x + \(2 * A)/x,  x > 0"),
                      H("Differentiate"), S("P′(x) = 2 − \(2 * A)/x² = 0  ⇒  x = \(sqrtText(A))"), minCheck("P′", "x = \(sqrtText(A))"),
                      R("It is a square: P min = 4·\(sqrtText(A)) = \(P.text)")])
        case 8:
            // Triangle under the tangent to y = a·e^(−x): area ½·a·(t + 1)²·e^(−t), max at t = 1: 2a/e.
            let a = r.int(1...5)
            let askT = r.bool()
            let fa = a == 1 ? "" : "\(a)"
            let half = a == 1 ? "½" : "(\(a)/2)"
            graph = plot(.scaled(a, 1, .exp(.neg(.x))), -0.4, 3.2)
            diagram = QuizDiagram(.tangentTriangle, numbers: [0.6])
            return q("The tangent to y = \(fa)e^(−x) at the point with x = t (t > 0) forms a triangle with the axes. " +
                     (askT ? "Find t for which the triangle's area is largest." : "Find the largest possible area (exactly, e.g. with e)."),
                     askT ? 1 : 2 * Double(a) / M_E, "tangent triangle",
                     [H("Step 1 · The tangent"), S("y′ = −\(fa)e^(−x),  tangent: y − \(fa)e^(−t) = −\(fa)e^(−t)(x − t)"),
                      S("y = 0 at x = t + 1;  x = 0 at y = \(fa)(t + 1)e^(−t)"),
                      H("Step 2 · The area"), S("S(t) = ½·(t + 1)·\(fa)(t + 1)e^(−t) = \(half)(t + 1)²e^(−t)"),
                      S("S′(t) = \(half)e^(−t)(t + 1)(2 − (t + 1)) = \(half)e^(−t)(t + 1)(1 − t)"),
                      S("S′ = 0 at t = 1 (t > 0)"), maxCheck("S′", "t = 1"),
                      R(askT ? "t = 1" : "S max = \(half)·4·e^(−1) = \(Solver.frac(2 * a, 1))/e")])
        case 9:
            // Isosceles trapezoid with three sides s: largest area 3√3·s²/4 at 60°.
            let s = r.int(2...10)
            let askAngle = r.bool()
            let area = exact(3 * s * s, rad: 3, den: 4)
            diagram = QuizDiagram(.trapezoid, labels: ["\(s)", "θ"])
            return q("A trapezoid has a base and two legs all of length \(s); the legs make equal angles θ with the longer base. " +
                     (askAngle ? "Find θ in degrees for the largest area." : "Find the largest possible area."),
                     askAngle ? 60 : area.value, "trapezoid",
                     [H("Set up with the angle"), S("Height \(s)·sin θ, longer base \(s) + 2·\(s)·cos θ"),
                      S("S(θ) = ½(\(s) + \(s) + 2·\(s)cos θ)·\(s)sin θ = \(s * s)(1 + cos θ)·sin θ,  0 < θ < 90°"),
                      H("Differentiate"), S("S′(θ) = \(s * s)(cos θ + cos²θ − sin²θ) = \(s * s)(2cos²θ + cos θ − 1)"),
                      S("2cos²θ + cos θ − 1 = (2cos θ − 1)(cos θ + 1) = 0  ⇒  cos θ = ½,  θ = 60°"), maxCheck("S′", "θ = 60°"),
                      R(askAngle ? "θ = 60°" : "S max = \(s * s)·(3/2)·(√3/2) = \(area.text)")])
        default:
            // Cone with slant height L: largest volume at h = L/√3, V = 2πL³/(9√3) = 2√3·πL³/27.
            let L = r.pick([3, 6, 9, 3, 6])
            let askH = r.bool()
            let h = exact(L, rad: 3, den: 3)
            let vCoef = exact(2 * L * L * L, rad: 3, den: 27)
            diagram = QuizDiagram(.cone, labels: ["\(L)", "h", "r"])
            return q("A cone has slant height \(L). " + (askH ? "Find its height when its volume is largest." : "Find its largest possible volume (exactly, with π)."),
                     askH ? h.value : vCoef.value * .pi, "cone",
                     [H("Set up"), S("r² + h² = \(L * L),  V = (π/3)r²h = (π/3)(\(L * L) − h²)h,  0 < h < \(L)"),
                      H("Differentiate"), S("V′(h) = (π/3)(\(L * L) − 3h²) = 0  ⇒  h = \(h.text)"), maxCheck("V′", "h = \(h.text)"),
                      R(askH ? "h = \(h.text)" : "V max = (π/3)·(\(L * L) − \(Solver.frac(L * L, 3)))·\(h.text) = \(vCoef.text)·π")])
        }
    }
}
