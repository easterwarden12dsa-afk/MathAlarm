import Foundation

// Bagrut 571, chapter 2: sequences (arithmetic, geometric, infinite series,
// recursive rules, word problems) and proofs by induction.

extension QuizFactory {
    /// a₁₂-style subscripts.
    static func sub(_ n: Int) -> String {
        let digits = Array("₀₁₂₃₄₅₆₇₈₉")
        return String(String(n).map { $0 == "-" ? "₋" : digits[Int(String($0))!] })
    }

    static func a(_ n: Int) -> String { "a" + sub(n) }

    /// A number, in brackets when negative: "3", "(−3)".
    static func pv(_ n: Int) -> String { n < 0 ? "(\(iv(n)))" : iv(n) }
    /// A coefficient in front of a letter: "", "−", "3", "−3".
    static func coef(_ n: Int) -> String { n == 1 ? "" : (n == -1 ? "−" : iv(n)) }

    /// p/q as text with a real minus sign ("−3/4", "5").
    static func fr(_ p: Int, _ q: Int) -> String { Solver.frac(p, q).replacingOccurrences(of: "-", with: "−") }

    // MARK: - Sequences

    static func sequence(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 2, 6, 8, 4]
        case .medium: pool = [1, 3, 4, 9, 10, 6]
        case .hard: pool = [1, 3, 5, 7, 9, 10]
        case .bagrut: pool = [5, 7, 9, 10, 1, 3]
        }
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], tol: Double? = nil) -> QuizProblem {
            number(.sequence, level, seed, prompt, value, topic: "sequence:\(topic)", steps: steps, tolerance: tol)
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Arithmetic: two terms given; find d, a₁ or a later term.
            let a1 = r.int(-10...15), d = r.nonZero(-5...6)
            let m = r.int(2...5), n = m + r.int(3...8), k = n + r.int(2...10)
            func t(_ i: Int) -> Int { a1 + (i - 1) * d }
            let what = r.int(0...2)
            let target = what == 0 ? "the first term a₁" : (what == 1 ? "the difference d" : "\(a(k))")
            var steps = [H("Write both terms with a₁ and d"), S("aₙ = a₁ + (n − 1)d"),
                         S("\(a(m)) = a₁ + \(m - 1)d = \(iv(t(m)))"), S("\(a(n)) = a₁ + \(n - 1)d = \(iv(t(n)))"),
                         H("Subtract the equations"), S("\(n - m)d = \(iv(t(n))) − \(pv(t(m))) = \(iv(t(n) - t(m)))"), S("d = \(iv(d))")]
            if what != 1 { steps += [H("Find a₁"), S("a₁ = \(iv(t(m))) − \(m - 1)·(\(iv(d))) = \(iv(a1))")] }
            if what == 2 { steps += [H("The term asked for"), S("\(a(k)) = a₁ + \(k - 1)d = \(iv(a1)) + \(k - 1)·(\(iv(d)))")] }
            steps.append(R(what == 0 ? "a₁ = \(iv(a1))" : (what == 1 ? "d = \(iv(d))" : "\(a(k)) = \(iv(t(k)))")))
            return ask("In an arithmetic sequence \(a(m)) = \(iv(t(m))) and \(a(n)) = \(iv(t(n))). Find \(target).",
                       Double(what == 0 ? a1 : (what == 1 ? d : t(k))), "arithmetic term", steps)
        case 1:
            // Arithmetic sum: Sₙ, or n from a given sum (reject the other root).
            let a1 = r.int(-6...12), d = r.nonZero(-3...5), n = r.int(6...20)
            let sum = n * (2 * a1 + (n - 1) * d) / 2
            if r.bool() || level == .easy {
                return ask("An arithmetic sequence has a₁ = \(iv(a1)) and d = \(iv(d)). Find the sum of its first \(n) terms.", Double(sum), "arithmetic sum",
                           [H("The sum formula"), S("Sₙ = n/2·(2a₁ + (n − 1)d)"),
                            H("Substitute n = \(n)"), S("S\(sub(n)) = \(n)/2·(2·(\(iv(a1))) + \(n - 1)·(\(iv(d)))) = \(n)/2·\(iv(2 * a1 + (n - 1) * d))"),
                            R("S\(sub(n)) = \(iv(sum))")])
            }
            // d·n² + (2a₁ − d)·n − 2S = 0; the other root is −(2a₁ − d)/d − n.
            let b = 2 * a1 - d
            let otherNum = -b - n * d   // other root = otherNum / d
            if otherNum % d == 0, otherNum / d > 0 { return nil }
            let disc = b * b + 8 * d * sum
            let root = Int(Double(disc).squareRoot().rounded())
            guard root * root == disc else { return nil }
            return ask("In an arithmetic sequence a₁ = \(iv(a1)) and d = \(iv(d)). How many terms must be added for the sum to be \(iv(sum))?", Double(n),
                       "arithmetic n",
                       [H("Set up the equation"), S("n/2·(2·(\(iv(a1))) + (n − 1)·(\(iv(d)))) = \(iv(sum))"),
                        S("\(d == 1 ? "" : (d == -1 ? "−" : iv(d)))n²\(b == 0 ? "" : signedTerm(b, "n"))\(sg(-2 * sum)) = 0"),
                        H("Solve the quadratic"), S("Discriminant = (\(iv(b)))² + 8·(\(iv(d)))·(\(iv(sum))) = \(disc),  √\(disc) = \(root)"),
                        S("n = (\(iv(-b)) ± \(root))/\(d < 0 ? "(\(iv(2 * d)))" : iv(2 * d))   ⇒   n = \(n)  or  n = \(fr(otherNum, d))"),
                        S("n counts terms, so it must be a positive whole number: n = \(fr(otherNum, d)) is rejected."),
                        R("n = \(n)")])
        case 10:
            // 2N terms: the odd-place and even-place sums.
            let N = r.int(5...12), a1 = r.int(-5...12), d = r.nonZero(-4...5)
            let odd = N * (2 * a1 + (N - 1) * 2 * d) / 2
            let even = N * (2 * (a1 + d) + (N - 1) * 2 * d) / 2
            let findA = r.bool()
            var steps = [H("Two sequences inside one"), S("The odd places a₁, a₃, a₅, … and the even places a₂, a₄, a₆, … each have \(N) terms and difference 2d."),
                         S("Each even-place term is the odd-place term before it plus d: a₂ = a₁ + d, a₄ = a₃ + d, …"),
                         H("Subtract the sums"), S("S(even) − S(odd) = \(N)·d  ⇒  \(iv(even)) − \(pv(odd)) = \(N)d"), S("d = \(iv(d))")]
            if findA {
                steps += [H("Find a₁ from the odd-place sum"), S("S(odd) = \(N)/2·(2a₁ + \(N - 1)·2d) = \(iv(odd))"),
                          S("2a₁ + \(2 * (N - 1))·(\(iv(d))) = \(fr(2 * odd, N))  ⇒  a₁ = \(iv(a1))")]
            }
            steps.append(R(findA ? "a₁ = \(iv(a1))" : "d = \(iv(d))"))
            return ask("An arithmetic sequence has \(2 * N) terms. The sum of the terms in the odd places is \(iv(odd)), and the sum of the terms in the even places is \(iv(even)). Find \(findA ? "a₁" : "the difference d").",
                       Double(findA ? a1 : d), "odd and even places", steps)
        case 2:
            // Geometric: two terms given.
            let q = r.pick([2, 3, -2, -3, 2, 3]), a1 = r.nonZero(-4...5)
            let m = r.int(1...3), gap = r.int(2...3), n = m + gap, k = n + r.int(1...2)
            func t(_ i: Int) -> Int { a1 * Int(pow(Double(q), Double(i - 1))) }
            let what = r.int(0...2)
            let hint = gap % 2 == 0 ? (q > 0 ? " with a positive ratio," : " with a negative ratio,") : ""
            var steps = [H("Write both terms with a₁ and q"), S("aₙ = a₁·qⁿ⁻¹"),
                         S("\(a(m)) = a₁·q^\(m - 1) = \(iv(t(m)))"), S("\(a(n)) = a₁·q^\(n - 1) = \(iv(t(n)))"),
                         H("Divide the equations"), S("q^\(gap) = \(iv(t(n)))/\(t(m) < 0 ? "(\(iv(t(m))))" : iv(t(m))) = \(iv(t(n) / t(m)))")]
            steps.append(S(gap % 2 == 0 ? "q = ±\(Swift.abs(q)), and the question says q \(q > 0 ? "> 0" : "< 0"): q = \(iv(q))" : "q = \(iv(q))"))
            if what != 1 { steps += [H("Find a₁"), S("a₁ = \(iv(t(m)))/(\(iv(q)))^\(m - 1) = \(iv(a1))")] }
            if what == 2 { steps += [H("The term asked for"), S("\(a(k)) = a₁·q^\(k - 1)")] }
            steps.append(R(what == 0 ? "a₁ = \(iv(a1))" : (what == 1 ? "q = \(iv(q))" : "\(a(k)) = \(iv(t(k)))")))
            return ask("In a geometric sequence\(hint) \(a(m)) = \(iv(t(m))) and \(a(n)) = \(iv(t(n))). Find \(what == 0 ? "a₁" : (what == 1 ? "the ratio q" : a(k))).",
                       Double(what == 0 ? a1 : (what == 1 ? q : t(k))), "geometric term", steps)
        case 3:
            // Geometric sum, or n from the sum.
            let q = r.pick([2, 3, -2, 2, 3]), a1 = r.int(1...5), n = r.int(4...(q == 3 ? 7 : 9))
            let qn = Int(pow(Double(q), Double(n)))
            let sum = a1 * (qn - 1) / (q - 1)
            if r.bool() || level == .easy {
                return ask("A geometric sequence has a₁ = \(a1) and q = \(iv(q)). Find the sum of its first \(n) terms.", Double(sum), "geometric sum",
                           [H("The sum formula"), S("Sₙ = a₁·(qⁿ − 1)/(q − 1)"),
                            H("Substitute n = \(n)"), S("\(pv(q))^\(n) = \(iv(qn))"),
                            S("S\(sub(n)) = \(a1)·(\(iv(qn)) − 1)/(\(iv(q)) − 1) = \(a1)·\(iv(qn - 1))\(q - 1 == 1 ? "" : "/" + pv(q - 1))"), R("S\(sub(n)) = \(iv(sum))")])
            }
            guard q > 0 else { return nil }
            return ask("A geometric sequence has a₁ = \(a1) and q = \(q). How many terms give a sum of \(sum)?", Double(n), "geometric n",
                       [H("Set up the equation"), S("\(a1)·(\(q)ⁿ − 1)/(\(q) − 1) = \(sum)"),
                        S("\(q)ⁿ − 1 = \(sum * (q - 1) / a1)  ⇒  \(q)ⁿ = \(qn)"),
                        H("Solve for n"), S("\(qn) = \(q)^\(n) (or n = ln \(qn) / ln \(q))"), R("n = \(n)")])
        case 4:
            // Infinite geometric series: the sum.
            let (p, s) = r.pick([(1, 2), (1, 3), (2, 3), (1, 4), (3, 4), (-1, 2), (-1, 3), (2, 5), (-2, 3), (3, 5)])
            let a1 = r.nonZero(-6...12)
            // S = a₁ / (1 − p/s) = a₁·s / (s − p)
            let first3 = [Solver.frac(a1, 1), Solver.frac(a1 * p, s), Solver.frac(a1 * p * p, s * s)].map { $0.replacingOccurrences(of: "-", with: "−") }
            return ask("Find the sum of the infinite geometric series  \(first3[0]) + (\(first3[1])) + (\(first3[2])) + …", Double(a1 * s) / Double(s - p),
                       "infinite sum",
                       [H("Find q"), S("q = \(first3[1]) ÷ \(first3[0]) = \(fr(p, s))"),
                        H("Does it converge?"), S("|q| = \(fr(Swift.abs(p), s)) < 1, so the infinite sum exists."),
                        H("The sum formula"), S("S = a₁/(1 − q) = \(iv(a1))/(1 − (\(fr(p, s)))) = \(iv(a1))/(\(fr(s - p, s)))"),
                        R("S = \(fr(a1 * s, s - p))")])
        case 5:
            switch r.int(0...2) {
            case 0:
                // q from S and a₁.
                let (p, s) = r.pick([(1, 2), (1, 3), (2, 3), (1, 4), (3, 4), (-1, 2), (-1, 3), (1, 5), (2, 5)])
                let k = r.int(1...4)
                let a1 = k * (s - p), total = k * s   // total = a₁/(1 − q)
                return ask("An infinite geometric series has first term \(a1) and sum \(total). Find its ratio q.", Double(p) / Double(s), "find q",
                           [H("The sum formula"), S("S = a₁/(1 − q)  ⇒  \(total) = \(a1)/(1 − q)"),
                            H("Solve for q"), S("1 − q = \(a1)/\(total) = \(fr(a1, total))"), S("q = 1 − \(fr(a1, total)) = \(fr(p, s))"),
                            H("Check"), S("|q| < 1, so the series really converges."), R("q = \(fr(p, s))")])
            case 1:
                // Odd places are k times the even places: q = 1/k.
                let k = r.int(2...5), a1 = r.int(2...12)
                let findA = r.bool()
                var steps = [H("Odd and even places"), S("Odd places: a₁ + a₁q² + a₁q⁴ + …  = a₁/(1 − q²)"),
                             S("Even places: a₁q + a₁q³ + …  = a₁q/(1 − q²)"),
                             H("Divide"), S("S(odd)/S(even) = 1/q = \(k)  ⇒  q = 1/\(k)")]
                if findA {
                    steps += [H("Find a₁"), S("S = a₁/(1 − 1/\(k)) = \(k)a₁/\(k - 1) = \(fr(a1 * k, k - 1))"), S("a₁ = \(fr(a1 * k, k - 1))·\(k - 1)/\(k)")]
                }
                steps.append(R(findA ? "a₁ = \(a1)" : "q = 1/\(k)"))
                return ask("In an infinite geometric series with positive terms, the sum of the terms in the odd places is \(k) times the sum of the terms in the even places." +
                           (findA ? " The sum of the whole series is \(fr(a1 * k, k - 1)). Find a₁." : " Find q."),
                           findA ? Double(a1) : 1 / Double(k), "odd and even series", steps)
            default:
                // 1 + kx + k²x² + … = S: find x.
                let k = r.pick([2, 3, 4, 5]), (sp, sq) = r.pick([(2, 1), (3, 1), (4, 1), (3, 2), (5, 1), (5, 2), (4, 3)])
                // 1/(1 − kx) = S  ⇒  x = (S − 1)/(kS) = (sp − sq)/(k·sp)
                return ask("The series  1 + \(k)x + \(k * k)x² + \(k * k * k)x³ + …  converges, and its sum is \(fr(sp, sq)). Find x.",
                           Double(sp - sq) / Double(k * sp), "series in x",
                           [H("It is geometric"), S("a₁ = 1,  q = \(k)x"),
                            H("The sum formula"), S("1/(1 − \(k)x) = \(fr(sp, sq))  ⇒  1 − \(k)x = \(fr(sq, sp))"),
                            S("\(k)x = \(fr(sp - sq, sp))  ⇒  x = \(fr(sp - sq, k * sp))"),
                            H("Check convergence"), S("q = \(k)x = \(fr(sp - sq, sp)), and |q| < 1 ✓"),
                            R("x = \(fr(sp - sq, k * sp))")])
            }
        case 6:
            // A recursive rule: compute terms one by one.
            let rule = r.int(0...2)
            let a1 = r.int(-3...6)
            var terms = [a1]
            let p = r.pick([2, 3, -1, -2]), c = r.nonZero(-5...5), m = r.nonZero(-3...3)
            let ruleText: String
            for n in 1..<6 {
                let prev = terms[n - 1]
                switch rule {
                case 0: terms.append(p * prev + c)
                case 1: terms.append(prev + m * n)
                default: terms.append((n % 2 == 1 ? 1 : -1) * prev + c)
                }
            }
            switch rule {
            case 0: ruleText = "aₙ₊₁ = \(p == -1 ? "−" : iv(p))aₙ\(sg(c))"
            case 1: ruleText = "aₙ₊₁ = aₙ \(m < 0 ? "−" : "+") \(Swift.abs(m) == 1 ? "" : "\(Swift.abs(m))")n"
            default: ruleText = "aₙ₊₁ = (−1)ⁿ⁺¹·aₙ\(sg(c))"
            }
            guard terms.allSatisfy({ Swift.abs($0) < 2_000 }) else { return nil }
            let k = r.int(5...6)
            return ask("A sequence is defined by a₁ = \(iv(a1)) and \(ruleText) for every n ≥ 1. Find \(a(k)).", Double(terms[k - 1]), "recursive terms",
                       [H("Apply the rule step by step"), S("Put n = 1, 2, 3, … into the rule; each term is built from the one before.")]
                       + (1..<k).map { n in S("n = \(n):  \(a(n + 1)) = \(iv(terms[n]))") }
                       + [R("\(a(k)) = \(iv(terms[k - 1]))")])
        case 7:
            // aₙ₊₁ = p·aₙ + c: bₙ = aₙ − L is geometric.
            let p = r.pick([2, 3, 2]), L = r.nonZero(-4...4)
            let c = L * (1 - p)
            let b1 = r.nonZero(-3...3)
            let a1 = L + b1
            let N = r.int(5...8)
            let aN = L + b1 * Int(pow(Double(p), Double(N - 1)))
            return ask("A sequence is defined by a₁ = \(iv(a1)) and aₙ₊₁ = \(p)aₙ\(sg(c)). For which n does aₙ = \(iv(aN))?", Double(N), "recursive formula",
                       [H("Find a sequence that is geometric"), S("Try bₙ = aₙ − L, where L solves L = \(p)L\(sg(c)):  L = \(iv(L))"),
                        S("bₙ₊₁ = aₙ₊₁ − \(L < 0 ? "(\(iv(L)))" : iv(L)) = \(p)aₙ\(sg(c))\(sg(-L)) = \(p)(aₙ\(sg(-L))) = \(p)bₙ"),
                        S("So bₙ is geometric with q = \(p) and b₁ = \(iv(a1))\(sg(-L)) = \(iv(b1))."),
                        H("A formula for aₙ"), S("bₙ = \(iv(b1))·\(p)ⁿ⁻¹,  so  aₙ = \(iv(b1))·\(p)ⁿ⁻¹\(sg(L))"),
                        H("Solve"), S("\(iv(b1))·\(p)ⁿ⁻¹\(sg(L)) = \(iv(aN))  ⇒  \(p)ⁿ⁻¹ = \(Int(pow(Double(p), Double(N - 1))))"),
                        S("n − 1 = \(N - 1)"), R("n = \(N)")])
        case 8:
            // Arithmetic word problems.
            if r.bool() {
                let first = r.pick([100, 150, 200, 250, 300]), more = r.pick([20, 25, 30, 50]), n = r.int(10...24)
                let total = n * (2 * first + (n - 1) * more) / 2
                return ask("Noa saves \(first) ₪ in the first month, and every month she saves \(more) ₪ more than the month before. How much has she saved after \(n) months?",
                           Double(total), "savings",
                           [H("It is an arithmetic sequence"), S("Monthly amounts: \(first), \(first + more), \(first + 2 * more), …   a₁ = \(first),  d = \(more)"),
                            H("Add the first \(n) terms"), S("S\(sub(n)) = \(n)/2·(2·\(first) + \(n - 1)·\(more))"), R("S\(sub(n)) = \(total) ₪")])
            }
            let first = r.int(12...24), more = r.int(1...3), rows = r.int(15...30)
            let last = first + (rows - 1) * more
            let total = rows * (first + last) / 2
            return ask("A hall has \(rows) rows. The first row has \(first) seats and each row has \(more) more seat\(more == 1 ? "" : "s") than the row in front of it. How many seats are there?",
                       Double(total), "seats",
                       [H("It is an arithmetic sequence"), S("a₁ = \(first),  d = \(more),  n = \(rows)"),
                        H("The last row"), S("a\(sub(rows)) = \(first) + \(rows - 1)·\(more) = \(last)"),
                        H("Add them up"), S("S = n(a₁ + aₙ)/2 = \(rows)·(\(first) + \(last))/2"), R("S = \(total) seats")])
        default:
            // Geometric word problems: a bouncing ball, or a growing salary.
            if r.bool() || level == .easy {
                let (p, s) = r.pick([(1, 2), (2, 3), (3, 4), (3, 5), (4, 5)])
                let h = r.pick([2, 3, 4, 5, 6, 8, 10, 12])
                let total = r.bool()
                if total {
                    // h + 2hq/(1 − q) = h(1 + q)/(1 − q) = h(s + p)/(s − p)
                    return ask("A ball is dropped from a height of \(h) m. After each bounce it rises to \(fr(p, s)) of the height before. What total distance does it travel until it stops?",
                               Double(h * (s + p)) / Double(s - p), "bouncing ball",
                               [H("Down and up"), S("It falls \(h) m; then each bounce goes up and comes down the same height."),
                                S("Heights after the bounces: \(h)·\(fr(p, s)), \(h)·(\(fr(p, s)))², …  a geometric series with q = \(fr(p, s))"),
                                H("Add the infinite series"), S("Up-and-down part: 2·(\(fr(h * p, s)))/(1 − \(fr(p, s))) = \(fr(2 * h * p, s - p))"),
                                R("Total = \(h) + \(fr(2 * h * p, s - p)) = \(fr(h * (s + p), s - p)) m")])
                }
                let n = r.int(2...4)
                let num = h * Int(pow(Double(p), Double(n))), den = Int(pow(Double(s), Double(n)))
                return ask("A ball is dropped from a height of \(h) m. After each bounce it rises to \(fr(p, s)) of the height before. How high does it rise after the \(["", "first", "second", "third", "fourth"][n]) bounce?",
                           Double(num) / Double(den), "bounce height",
                           [H("A geometric sequence"), S("The heights after each bounce: \(h)·\(fr(p, s)), \(h)·(\(fr(p, s)))², …"),
                            R("After bounce \(n): \(h)·(\(fr(p, s)))^\(n) = \(fr(num, den)) m")])
            }
            let salary = r.pick([6000, 8000, 10000, 12000]), pct = r.pick([2, 3, 4, 5]), years = r.int(5...12)
            let q = 1 + Double(pct) / 100
            let total = Double(salary) * 12 * (pow(q, Double(years)) - 1) / (q - 1)
            return ask("A monthly salary of \(salary) ₪ rises by \(pct)% at the start of every year. How much is earned in total in \(years) years? Give the answer to the nearest shekel.",
                       total, "salary", [H("Yearly pay is geometric"), S("Year 1: 12·\(salary) = \(12 * salary),  then ×\(dec(q)) every year: q = \(dec(q))"),
                                         H("Add \(years) years"), S("S = \(12 * salary)·(\(dec(q))^\(years) − 1)/(\(dec(q)) − 1)"),
                                         R("S ≈ \(Int(total.rounded())) ₪")], tol: 1)
        }
    }

    // MARK: - Induction

    /// One sum formula: the n-th term and the closed form, at n = k + o.
    struct SumFormula {
        var term: (Int) -> String
        var rhs: (Int) -> String
        /// The first terms of the left side, written out.
        var left: String
        /// rhs(k) + term(k + 1) = … = rhs(k + 1).
        var algebra: [String]
        var value: (Int) -> Int
    }

    /// "k", "k + 2", "k − 1".
    static func kk(_ c: Int) -> String { c == 0 ? "k" : "k" + sg(c) }
    /// The same, in brackets unless it is just k.
    static func pk(_ c: Int) -> String { c == 0 ? "k" : "(\(kk(c)))" }

    static let sumFormulas: [SumFormula] = [
        SumFormula(term: { kk($0) }, rhs: { "\(pk($0))\(pk($0 + 1))/2" }, left: "1 + 2 + 3 + … + n", algebra: [
            "k(k + 1)/2 + (k + 1) = (k + 1)(k/2 + 1)", "= (k + 1)(k + 2)/2",
        ], value: { $0 * ($0 + 1) / 2 }),
        SumFormula(term: { o in "2k" + sg(2 * o - 1) }, rhs: { "\(pk($0))²" }, left: "1 + 3 + 5 + … + (2n − 1)", algebra: [
            "k² + (2k + 1)", "= (k + 1)²",
        ], value: { $0 * $0 }),
        SumFormula(term: { "\(pk($0))²" }, rhs: { o in "\(pk(o))\(pk(o + 1))(2k\(sg(2 * o + 1)))/6" }, left: "1² + 2² + 3² + … + n²", algebra: [
            "k(k + 1)(2k + 1)/6 + (k + 1)² = (k + 1)·[k(2k + 1) + 6(k + 1)]/6", "= (k + 1)(2k² + 7k + 6)/6", "= (k + 1)(k + 2)(2k + 3)/6",
        ], value: { $0 * ($0 + 1) * (2 * $0 + 1) / 6 }),
        SumFormula(term: { "\(pk($0))\(pk($0 + 1))" }, rhs: { "\(pk($0))\(pk($0 + 1))\(pk($0 + 2))/3" }, left: "1·2 + 2·3 + 3·4 + … + n(n + 1)", algebra: [
            "k(k + 1)(k + 2)/3 + (k + 1)(k + 2) = (k + 1)(k + 2)(k/3 + 1)", "= (k + 1)(k + 2)(k + 3)/3",
        ], value: { $0 * ($0 + 1) * ($0 + 2) / 3 }),
        SumFormula(term: { o in "1/(\(pk(o))\(pk(o + 1)))" }, rhs: { "\(pk($0))/\(pk($0 + 1))" }, left: "1/(1·2) + 1/(2·3) + … + 1/(n(n + 1))", algebra: [
            "k/(k + 1) + 1/((k + 1)(k + 2)) = [k(k + 2) + 1]/((k + 1)(k + 2))", "= (k + 1)²/((k + 1)(k + 2))", "= (k + 1)/(k + 2)",
        ], value: { $0 }),
        SumFormula(term: { o in o == 1 ? "2^k" : "2^(\(kk(o - 1)))" }, rhs: { o in o == 0 ? "2^k − 1" : "2^(\(kk(o))) − 1" }, left: "1 + 2 + 4 + … + 2^(n − 1)", algebra: [
            "2^k − 1 + 2^k = 2·2^k − 1", "= 2^(k + 1) − 1",
        ], value: { (1 << $0) - 1 }),
        SumFormula(term: { "\(pk($0))·\(pk($0))!" }, rhs: { "\(pk($0 + 1))! − 1" }, left: "1·1! + 2·2! + … + n·n!", algebra: [
            "(k + 1)! − 1 + (k + 1)·(k + 1)! = (k + 1)!·(1 + k + 1) − 1", "= (k + 2)·(k + 1)! − 1 = (k + 2)! − 1",
        ], value: { n in (1...(n + 1)).reduce(1, *) - 1 }),
    ]

    static func induction(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 2, 0]
        case .medium: pool = [0, 1, 3, 2]
        case .hard: pool = [1, 3, 4]
        case .bagrut: pool = [1, 3, 4, 3]
        }
        func pickOne(_ prompt: String, _ correct: String, _ wrong: [String], _ topic: String, _ steps: [SolutionStep]) -> QuizProblem? {
            guard Set(wrong + [correct]).count == wrong.count + 1 else { return nil }
            var q = blank(.induction, level, seed, prompt, .number(0), topic: "induction:\(topic)")
            q.answer = shuffled(QuizOption(text: correct), wrong.map { QuizOption(text: $0) }, &r)
            q.steps = steps
            return q
        }
        func proof(_ f: SumFormula) -> [SolutionStep] {
            [H("Check n = 1"), S("Left side: the first term, \(f.value(1)).  Right side: \(f.value(1)).  ✓"),
             H("Assume it is true for n = k"), S("\(f.left.replacingOccurrences(of: "n", with: "k")) = \(f.rhs(0))"),
             H("Prove it for n = k + 1"), S("The left side for k + 1 is the left side for k plus one more term: \(f.term(1))"),
             S("By the assumption it equals  \(f.rhs(0)) + \(f.term(1))")]
            + f.algebra.map { S($0, 2) }
            + [S("This is the right side for n = k + 1: \(f.rhs(1))  ✓"),
               H("Conclusion"), S("True for n = 1, and true for k + 1 whenever true for k: true for every n ≥ 1.")]
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Which term is added in the step?
            let f = r.pick(sumFormulas)
            return pickOne("We prove  \(f.left) = \(f.rhs(0).replacingOccurrences(of: "k", with: "n"))  by induction. Going from n = k to n = k + 1, which term is added to the left side?",
                           f.term(1), [f.term(0), f.term(2), f.rhs(1)], "added term", proof(f) + [R("The added term is \(f.term(1))")])
        case 1:
            // What must the right side become?
            let f = r.pick(sumFormulas)
            return pickOne("We prove  \(f.left) = \(f.rhs(0).replacingOccurrences(of: "k", with: "n"))  by induction. In the step, assuming it for n = k, what must the left side for n = k + 1 be shown to equal?",
                           f.rhs(1), [f.rhs(0), f.rhs(2), "\(f.rhs(0)) + \(f.term(0))"], "target", proof(f) + [R("Show it equals \(f.rhs(1))")])
        case 2:
            // Check the formula at n = N.
            let f = r.pick(sumFormulas), N = r.int(3...5)
            var q = number(.induction, level, seed,
                           "Check the formula  \(f.left) = \(f.rhs(0).replacingOccurrences(of: "k", with: "n"))  for n = \(N): what do both sides equal?",
                           Double(f.value(N)), topic: "induction:check",
                           steps: [H("Left side for n = \(N)"), S("Add the first \(N) terms of the sum."),
                                   H("Right side for n = \(N)"), S("Put n = \(N) into the formula."),
                                   R("Both sides equal \(f.value(N))")] + proof(f))
            if f.rhs(0).contains("/(") && f.left.hasPrefix("1/") {
                q.prompt = "Check the formula  \(f.left) = n/(n + 1)  for n = \(N): what is the right side?"
                q.answer = .number(Double(N) / Double(N + 1))
                q.steps[4] = R("Both sides equal \(N)/\(N + 1)")
            }
            return q
        case 3:
            // Divisibility: the key rewriting in the step.
            switch r.int(0...3) {
            case 0:
                let a = r.int(3...11), d = a - 1
                let steps = [H("Check n = 1"), S("\(a)¹ − 1 = \(d), divisible by \(d)  ✓"),
                             H("Assume for n = k"), S("\(a)^k − 1 = \(d)m for a whole number m"),
                             H("Prove for n = k + 1"), S("\(a)^(k + 1) − 1 = \(a)·\(a)^k − 1 = \(a)(\(a)^k − 1) + \(a) − 1"),
                             S("= \(a)(\(a)^k − 1) + \(d) = \(a)·\(d)m + \(d) = \(d)(\(a)m + 1)  ✓", 2),
                             R("\(a)^(k + 1) − 1 = \(a)(\(a)^k − 1) + \(d)")]
                return pickOne("We prove by induction that \(a)ⁿ − 1 is divisible by \(d) for every n ≥ 1. Which way of writing \(a)^(k + 1) − 1 makes the step work?",
                               "\(a)(\(a)^k − 1) + \(d)", ["\(a)(\(a)^k − 1) + 1", "(\(a)^k − 1) + \(a)", "\(a)(\(a)^k − 1) − \(d)"], "divisibility", steps)
            case 1:
                let a = r.int(4...9), b = r.int(1...(a - 2))
                let steps = [H("Check n = 1"), S("\(a) − \(b) = \(a - b)  ✓"),
                             H("Assume for n = k"), S("\(a)^k − \(b)^k = \(a - b)m"),
                             H("Prove for n = k + 1"), S("Add and take away \(a)·\(b)^k:"),
                             S("\(a)^(k + 1) − \(b)^(k + 1) = \(a)(\(a)^k − \(b)^k) + \(a)·\(b)^k − \(b)·\(b)^k", 2),
                             S("= \(a)(\(a)^k − \(b)^k) + \(b)^k(\(a) − \(b)) = \(a)·\(a - b)m + \(a - b)·\(b)^k  ✓", 2),
                             R("\(a)(\(a)^k − \(b)^k) + \(a - b)·\(b)^k")]
                return pickOne("We prove that \(a)ⁿ − \(b)ⁿ is divisible by \(a - b) for every n ≥ 1. Which expression equals \(a)^(k + 1) − \(b)^(k + 1) and shows the step?",
                               "\(a)(\(a)^k − \(b)^k) + \(a - b)·\(b)^k",
                               ["\(a)(\(a)^k − \(b)^k) + \(a - b)", "\(a)(\(a)^k − \(b)^k) − \(b)^k", "(\(a)^k − \(b)^k) + \(a - b)·\(a)^k"], "divisibility", steps)
            case 2:
                let steps = [H("Check n = 1"), S("4 + 15 − 1 = 18 = 9·2  ✓"),
                             H("Assume for n = k"), S("4^k + 15k − 1 = 9m"),
                             H("Prove for n = k + 1"), S("4^(k + 1) + 15(k + 1) − 1 = 4·4^k + 15k + 14"),
                             S("= 4(4^k + 15k − 1) − 60k + 4 + 15k + 14 = 4(4^k + 15k − 1) − 45k + 18", 2),
                             S("= 4·9m − 9(5k − 2) = 9(4m − 5k + 2)  ✓", 2), R("4(4^k + 15k − 1) − 9(5k − 2)")]
                return pickOne("We prove that 4ⁿ + 15n − 1 is divisible by 9. Which expression equals 4^(k + 1) + 15(k + 1) − 1?",
                               "4(4^k + 15k − 1) − 9(5k − 2)", ["4(4^k + 15k − 1) + 15", "4(4^k + 15k − 1) − 9(5k + 2)", "(4^k + 15k − 1) + 3·4^k + 15"],
                               "divisibility", steps)
            default:
                let steps = [H("Check n = 1"), S("3³ + 2³ = 27 + 8 = 35 = 7·5  ✓"),
                             H("Assume for n = k"), S("3^(2k + 1) + 2^(k + 2) = 7m"),
                             H("Prove for n = k + 1"), S("3^(2k + 3) + 2^(k + 3) = 9·3^(2k + 1) + 2·2^(k + 2)"),
                             S("= 9(3^(2k + 1) + 2^(k + 2)) − 9·2^(k + 2) + 2·2^(k + 2) = 9·7m − 7·2^(k + 2)  ✓", 2),
                             R("9(3^(2k + 1) + 2^(k + 2)) − 7·2^(k + 2)")]
                return pickOne("We prove that 3^(2n + 1) + 2^(n + 2) is divisible by 7. Which expression equals 3^(2k + 3) + 2^(k + 3)?",
                               "9(3^(2k + 1) + 2^(k + 2)) − 7·2^(k + 2)",
                               ["9(3^(2k + 1) + 2^(k + 2)) + 7·2^(k + 2)", "3(3^(2k + 1) + 2^(k + 2)) − 7·2^(k + 2)", "9(3^(2k + 1) + 2^(k + 2)) − 2^(k + 2)"],
                               "divisibility", steps)
            }
        default:
            // Inequalities: from which n is it always true?
            struct Ineq {
                var text: String
                /// Both sides at n, written out ("2⁴ = 16", "4² = 16").
                var sides: (Int) -> (Double, Double, String, String)
                var stepText: [String]
                func holds(_ n: Int) -> Bool { let s = sides(n); return s.0 > s.1 }
            }
            func fact(_ n: Int) -> Double { (1...Swift.max(1, n)).reduce(1.0) { $0 * Double($1) } }
            func pw(_ b: Int, _ e: Int) -> Double { pow(Double(b), Double(e)) }
            let all = [
                Ineq(text: "2ⁿ > n²", sides: { n in (pw(2, n), Double(n * n), "2^\(n)", "\(n)²") },
                     stepText: ["2^(k + 1) = 2·2^k > 2k²", "2k² ≥ (k + 1)²  ⇔  k² − 2k − 1 ≥ 0, true for k ≥ 3", "So 2^(k + 1) > (k + 1)²"]),
                Ineq(text: "3ⁿ > n³", sides: { n in (pw(3, n), pw(n, 3), "3^\(n)", "\(n)³") },
                     stepText: ["3^(k + 1) = 3·3^k > 3k³", "3k³ ≥ (k + 1)³  ⇔  (1 + 1/k)³ ≤ 3, true for k ≥ 3", "So 3^(k + 1) > (k + 1)³"]),
                Ineq(text: "n! > 2ⁿ", sides: { n in (fact(n), pw(2, n), "\(n)!", "2^\(n)") },
                     stepText: ["(k + 1)! = (k + 1)·k! > (k + 1)·2^k", "k + 1 > 2 for k ≥ 2", "So (k + 1)! > 2·2^k = 2^(k + 1)"]),
                Ineq(text: "n! > 3ⁿ", sides: { n in (fact(n), pw(3, n), "\(n)!", "3^\(n)") },
                     stepText: ["(k + 1)! = (k + 1)·k! > (k + 1)·3^k", "k + 1 > 3 for k ≥ 3", "So (k + 1)! > 3·3^k = 3^(k + 1)"]),
                Ineq(text: "2ⁿ > 2n + 1", sides: { n in (pw(2, n), Double(2 * n + 1), "2^\(n)", "2·\(n) + 1") },
                     stepText: ["2^(k + 1) = 2·2^k > 2(2k + 1) = 4k + 2", "4k + 2 > 2k + 3  ⇔  k > ½", "So 2^(k + 1) > 2(k + 1) + 1"]),
                Ineq(text: "2ⁿ > 5n", sides: { n in (pw(2, n), Double(5 * n), "2^\(n)", "5·\(n)") },
                     stepText: ["2^(k + 1) = 2·2^k > 10k", "10k ≥ 5k + 5  ⇔  k ≥ 1", "So 2^(k + 1) > 5(k + 1)"]),
            ]
            let f = r.pick(all)
            // The smallest n₀ with the inequality true for all n ≥ n₀ (checked to n = 40).
            var n0 = 40
            while n0 > 1 && f.holds(n0 - 1) { n0 -= 1 }
            let fails = n0 - 1
            func shown(_ n: Int) -> String {
                let s = f.sides(n)
                return "n = \(n):  \(s.2) = \(dec(s.0)),  \(s.3) = \(dec(s.1))"
            }
            return number(.induction, level, seed,
                          "The inequality \(f.text) is proved by induction for every n ≥ n₀. Find the smallest such whole number n₀ ≥ 1 (it must be true from n₀ on).",
                          Double(n0), topic: "induction:inequality",
                          steps: [H("Try small values"), S(shown(fails) + "  ✗"), S(shown(n0) + "  ✓"),
                                  S("So n₀ = \(n0) is the base case; the step shows it stays true from there on."),
                                  H("Assume for n = k ≥ \(n0)")]
                            + f.stepText.map { S($0) }
                            + [H("Conclusion"), S("True for n = \(n0), and true for k + 1 whenever true for k ≥ \(n0)."), R("n₀ = \(n0)")])
        }
    }
}

extension QuizProblem {
    /// For small edits after building.
    func with(_ change: (inout QuizProblem) -> Void) -> QuizProblem {
        var q = self
        change(&q)
        return q
    }
}
