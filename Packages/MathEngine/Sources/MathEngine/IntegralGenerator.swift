import Foundation

/// Integration problems built from technique templates. Every template
/// produces an integrand together with a known antiderivative (so the
/// reference answer is right by construction, and is still verified
/// numerically by `Validator`) and a worked solution.
enum IntegralGenerator {
    typealias Made = (f: Expr, F: Expr, lo: Double, hi: Double, technique: String, steps: [SolutionStep])
    typealias Template = (inout SeededRandom) -> Made?

    static func candidate(level: Level, rng: inout SeededRandom, seed: UInt64) -> CalculusProblem? {
        let templates: [Template]
        switch level {
        case .easy: templates = easy
        case .medium: templates = medium
        case .hard: templates = hard
        case .bagrut: templates = bagrut
        }
        guard let made = rng.pick(templates)(&rng) else { return nil }
        return CalculusProblem(kind: .integral, level: level, display: made.f, reference: made.F,
                               domainLow: made.lo, domainHigh: made.hi, technique: made.technique,
                               seed: seed, steps: made.steps)
    }

    // MARK: Shorthands

    private static let x = Expr.x
    private static func lin(_ k: Int) -> Expr { .scaled(k, 1, .x) }          // k·x
    private static func xPow(_ n: Int) -> Expr { n == 1 ? .x : .p(.x, n) }
    private static func S(_ text: String, _ label: String? = nil, _ math: Expr? = nil) -> SolutionStep {
        SolutionStep(text, label: label, math: math)
    }

    // MARK: Template lists

    static let easy: [Template] = [easy1, easy2, easy3, easy4, easy5, easy6, easy7]
    static let medium: [Template] = [medium1, medium2, medium3, medium4, medium5, medium6, medium7, medium8, medium9, medium10]
    static let hard: [Template] = [hard1, hard2, hard3, hard4, hard5, hard6, hard7, hard8, hard9, hard10, hard11, hard12, hard13]
    static let bagrut: [Template] = [bag1, bag2, bag3, bag4, bag5, bag6, bag7, bag8, bag9, bag10, bag11, bag12]

    // MARK: - Easy

    // Power rule: a xⁿ + b xᵐ + c
    static func easy1(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5), m = r.int(1...(n - 1))
        let a = r.nonZero(-6...6), b = r.nonZero(-6...6), c = r.int(-6...6)
        let f = Expr.sum([.scaled(a, 1, xPow(n)), .scaled(b, 1, xPow(m)), .n(c)])
        let F = Expr.sum([.scaled(a, n + 1, xPow(n + 1)), .scaled(b, m + 1, xPow(m + 1)), .scaled(c, 1, x)])
        return (f, F, -2, 2, "Power rule", [
            S("Integrate term by term with the power rule ∫xⁿ dx = xⁿ⁺¹/(n+1); a constant c integrates to c·x."),
        ])
    }

    // a·cos(kx) or a·sin(kx)
    static func easy2(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), k = r.int(2...5)
        if r.bool() {
            return (.scaled(a, 1, .cos(lin(k))), .scaled(a, k, .sin(lin(k))), -2, 2, "Basic trig integral", [
                S("∫cos(kx) dx = sin(kx)/k — the inner kx gives the factor 1/k.", "k =", .n(k)),
            ])
        }
        return (.scaled(a, 1, .sin(lin(k))), .scaled(-a, k, .cos(lin(k))), -2, 2, "Basic trig integral", [
            S("∫sin(kx) dx = −cos(kx)/k — the inner kx gives the factor 1/k.", "k =", .n(k)),
        ])
    }

    // a·e^(kx)
    static func easy3(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), k = r.nonZero(-3...3)
        return (.scaled(a, 1, .exp(lin(k))), .scaled(a, k, .exp(lin(k))), -1.5, 1.5, "Exponential", [
            S("∫e^(kx) dx = e^(kx)/k.", "k =", .n(k)),
        ])
    }

    // a / (x + b)
    static func easy4(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), b = r.int(-3...3)
        let inner = Expr.sum([x, .n(b)])
        let f: Expr = a > 0 ? .div(.n(a), inner) : .neg(.div(.n(-a), inner))
        let lo = Double(-b) + 0.5
        return (f, .scaled(a, 1, .ln(inner)), lo, lo + 3.5, "Logarithm", [
            S("∫ 1/(x + b) dx = ln|x + b|. On this interval x + b > 0, so ln(x + b) is fine.", "x + b =", inner),
        ])
    }

    // a·√x
    static func easy5(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...6) * (r.bool() ? 1 : 3)
        return (.scaled(a, 1, .sqrt(x)), .scaled(2 * a, 3, .pow(x, .q(3, 2))), 0.2, 4, "Power rule", [
            S("Write √x as a power:", "√x =", .pow(x, .q(1, 2))),
            S("Power rule: ∫x^(1/2) dx = x^(3/2) / (3/2) = (2/3)·x^(3/2)."),
        ])
    }

    // a·sec²(x)
    static func easy6(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5)
        return (.scaled(a, 1, .p(.sec(x), 2)), .scaled(a, 1, .tan(x)), -1.2, 1.2, "Standard integral", [
            S("(tan x)′ = sec²x, so ∫sec²x dx = tan x."),
        ])
    }

    // a / (x² + 1)
    static func easy7(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...6)
        return (.div(.n(a), .sum([.p(x, 2), 1])), .scaled(a, 1, .atan(x)), -2, 2, "Standard integral", [
            S("(arctan x)′ = 1/(x² + 1), so ∫ 1/(x² + 1) dx = arctan x."),
        ])
    }

    // MARK: - Medium

    // u-substitution: k·x·(x² + a)ⁿ
    static func medium1(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5), a = r.int(1...5), k = r.int(1...4)
        let u = Expr.sum([.p(x, 2), .n(a)])
        let f = Expr.mul(.scaled(k, 1, x), .p(u, n))
        return (f, .scaled(k, 2 * (n + 1), .p(u, n + 1)), -1.5, 1.5, "Substitution", [
            S("Substitute the inside of the power:", "u =", u),
            S("Then du = 2x dx, so x dx = du/2.", "du =", .mul(2, x)),
            S("The integral becomes (k/2)·∫uⁿ du = (k/2)·uⁿ⁺¹/(n+1).", "k/2 =", .q(k, 2)),
            S("Substitute u back."),
        ])
    }

    // x·e^(a x²)
    static func medium2(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, 3, -1, -2])
        let inner = Expr.scaled(a, 1, .p(x, 2))
        return (.mul(x, .exp(inner)), .scaled(1, 2 * a, .exp(inner)), -1.3, 1.3, "Substitution", [
            S("Substitute the exponent:", "u =", inner),
            S("du = 2a·x dx, so x dx = du/(2a).", "2a =", .n(2 * a)),
            S("∫ eᵘ du/(2a) = eᵘ/(2a). Substitute u back."),
        ])
    }

    // sinⁿ(x)·cos(x)  or  cosⁿ(x)·sin(x)
    static func medium3(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5)
        if r.bool() {
            return (.mul(.p(.sin(x), n), .cos(x)), .scaled(1, n + 1, .p(.sin(x), n + 1)), -2, 2, "Substitution", [
                S("Substitute:", "u =", .sin(x)),
                S("du = cos x dx, so the integral is ∫uⁿ du = uⁿ⁺¹/(n+1).", "n =", .n(n)),
            ])
        }
        return (.mul(.p(.cos(x), n), .sin(x)), .scaled(-1, n + 1, .p(.cos(x), n + 1)), -2, 2, "Substitution", [
            S("Substitute:", "u =", .cos(x)),
            S("du = −sin x dx, so the integral is −∫uⁿ du = −uⁿ⁺¹/(n+1).", "n =", .n(n)),
        ])
    }

    // k(2x + b) / (x² + bx + c), never zero
    static func medium4(_ r: inout SeededRandom) -> Made? {
        let b = r.nonZero(-4...4), k = r.int(1...3)
        let c = (b * b) / 4 + r.int(1...4)
        let den = Expr.sum([.p(x, 2), .scaled(b, 1, x), .n(c)])
        let num = Expr.sum([.scaled(2 * k, 1, x), .n(k * b)])
        return (.div(num, den), .scaled(k, 1, .ln(den)), -2, 2, "Substitution (f′/f)", [
            S("The numerator is a multiple of the derivative of the denominator:", "(denominator)′ =", .sum([.mul(2, x), .n(b)])),
            S("∫ f′/f dx = ln|f|, and the denominator is always positive here.", "multiple =", .n(k)),
        ])
    }

    // e^x / (e^x + a)
    static func medium5(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...5)
        let den = Expr.sum([.exp(x), .n(a)])
        return (.div(.exp(x), den), .ln(den), -2, 2, "Substitution (f′/f)", [
            S("The numerator eˣ is exactly the derivative of the denominator:", "f =", den),
            S("∫ f′/f dx = ln|f|, and f > 0."),
        ])
    }

    // By parts: x·e^(ax)
    static func medium6(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, 3, -1, -2])
        let F = Expr.mul(.exp(lin(a)), .sum([.scaled(1, a, x), .scaled(-1, a * a, 1)]))
        return (.mul(x, .exp(lin(a))), F, -1.5, 1.5, "Integration by parts", [
            S("Integration by parts: ∫u dv = u·v − ∫v du."),
            S("Choose u = x (it gets simpler) and dv = e^(ax) dx:", "u =", x),
            S("Then du = dx and", "v =", .scaled(1, a, .exp(lin(a)))),
            S("u·v − ∫v du:", "=", .sub(.mul(x, .scaled(1, a, .exp(lin(a)))), .scaled(1, a * a, .exp(lin(a))))),
        ])
    }

    // By parts: x·sin(ax) / x·cos(ax)
    static func medium7(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...4)
        if r.bool() {
            let F = Expr.sum([.scaled(-1, a, .mul(x, .cos(lin(a)))), .scaled(1, a * a, .sin(lin(a)))])
            return (.mul(x, .sin(lin(a))), F, -2, 2, "Integration by parts", [
                S("Integration by parts: ∫u dv = u·v − ∫v du, with u = x, dv = sin(ax) dx."),
                S("du = dx and", "v =", .scaled(-1, a, .cos(lin(a)))),
                S("u·v − ∫v du = −x·cos(ax)/a + ∫cos(ax)/a dx = −x·cos(ax)/a + sin(ax)/a²."),
            ])
        }
        let F = Expr.sum([.scaled(1, a, .mul(x, .sin(lin(a)))), .scaled(1, a * a, .cos(lin(a)))])
        return (.mul(x, .cos(lin(a))), F, -2, 2, "Integration by parts", [
            S("Integration by parts: ∫u dv = u·v − ∫v du, with u = x, dv = cos(ax) dx."),
            S("du = dx and", "v =", .scaled(1, a, .sin(lin(a)))),
            S("u·v − ∫v du = x·sin(ax)/a − ∫sin(ax)/a dx = x·sin(ax)/a + cos(ax)/a²."),
        ])
    }

    // By parts: ln(x)  or  x·ln(x)
    static func medium8(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.ln(x), .sub(.mul(x, .ln(x)), x), 0.5, 4, "Integration by parts", [
                S("Write ln x = 1·ln x and use parts with u = ln x, dv = dx."),
                S("du = dx/x and v = x, so ∫ln x dx = x·ln x − ∫ x·(1/x) dx = x·ln x − x."),
            ])
        }
        let F = Expr.sum([.mul(.scaled(1, 2, .p(x, 2)), .ln(x)), .scaled(-1, 4, .p(x, 2))])
        return (.mul(x, .ln(x)), F, 0.5, 4, "Integration by parts", [
            S("Parts with u = ln x (it simplifies when differentiated), dv = x dx."),
            S("du = dx/x and", "v =", .scaled(1, 2, .p(x, 2))),
            S("u·v − ∫v du = (x²/2)·ln x − ∫ x/2 dx = (x²/2)·ln x − x²/4."),
        ])
    }

    // Trig identity: sin²(ax), cos²(ax)
    static func medium9(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...3)
        let sign = r.bool() ? -1 : 1
        let f: Expr = sign < 0 ? .p(.sin(lin(a)), 2) : .p(.cos(lin(a)), 2)
        let F = Expr.sum([.scaled(1, 2, x), .scaled(sign, 4 * a, .sin(lin(2 * a)))])
        let identity: Expr = sign < 0
            ? .div(.sub(1, .cos(lin(2 * a))), 2)
            : .div(.add(1, .cos(lin(2 * a))), 2)
        return (f, F, -2, 2, "Trig identity", [
            S("Use the double-angle identity to remove the square:", "=", identity),
            S("Integrate: ∫½ dx = x/2 and ∫cos(2ax) dx = sin(2ax)/(2a)."),
        ])
    }

    // a / (x² + k²)
    static func medium10(_ r: inout SeededRandom) -> Made? {
        let k = r.int(2...4), a = r.nonZero(1...6)
        let f = Expr.div(.n(a), .sum([.p(x, 2), .n(k * k)]))
        return (f, .scaled(a, k, .atan(.div(x, .n(k)))), -2, 2, "Arctangent", [
            S("Standard form: ∫ 1/(x² + k²) dx = (1/k)·arctan(x/k).", "k =", .n(k)),
        ])
    }

    // MARK: - Hard

    // Partial fractions: (px + q) / ((x − a)(x − b))
    static func hard1(_ r: inout SeededRandom) -> Made? {
        let a = r.int(-3...3)
        var b = r.int(-3...3)
        while b == a { b = r.int(-3...3) }
        let A = r.nonZero(-4...4), B = r.nonZero(-4...4)
        let num = Expr.sum([.scaled(A + B, 1, x), .n(-(A * b + B * a))])
        let den = Expr.sum([.p(x, 2), .scaled(-(a + b), 1, x), .n(a * b)])
        let xa = Expr.sum([x, .n(-a)]), xb = Expr.sum([x, .n(-b)])
        let F = Expr.sum([.scaled(A, 1, .ln(xa)), .scaled(B, 1, .ln(xb))])
        let lo = Double(Swift.max(a, b)) + 0.5
        return (.div(num, den), F, lo, lo + 3.5, "Partial fractions", [
            S("Factor the denominator:", "=", .mul(xa, xb)),
            S("Split into A/(x − a) + B/(x − b) and match the numerators."),
            S("Solving gives", "A =", .n(A)),
            S("and", "B =", .n(B)),
            S("Each piece integrates to a logarithm; on this interval both brackets are positive."),
        ])
    }

    // By parts twice: x²·e^(ax)
    static func hard2(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, -1])
        let F = Expr.mul(.exp(lin(a)), .sum([.scaled(1, a, .p(x, 2)), .scaled(-2, a * a, x), .scaled(2, a * a * a, 1)]))
        return (.mul(.p(x, 2), .exp(lin(a))), F, -1.5, 1.5, "Integration by parts (twice)", [
            S("Parts with u = x², dv = e^(ax) dx: du = 2x dx, v = e^(ax)/a."),
            S("∫x²e^(ax) dx = x²e^(ax)/a − (2/a)·∫x·e^(ax) dx."),
            S("Parts again on ∫x·e^(ax) dx (u = x):", "=", .mul(.exp(lin(a)), .sum([.scaled(1, a, x), .scaled(-1, a * a, 1)]))),
            S("Combine and factor out e^(ax)."),
        ])
    }

    // e^(ax)·sin(bx) / e^(ax)·cos(bx)
    static func hard3(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, -1]), b = r.int(1...3)
        let d = a * a + b * b
        let isSin = r.bool()
        let f: Expr = isSin ? .mul(.exp(lin(a)), .sin(lin(b))) : .mul(.exp(lin(a)), .cos(lin(b)))
        let F: Expr = isSin
            ? .mul(.exp(lin(a)), .sum([.scaled(a, d, .sin(lin(b))), .scaled(-b, d, .cos(lin(b)))]))
            : .mul(.exp(lin(a)), .sum([.scaled(a, d, .cos(lin(b))), .scaled(b, d, .sin(lin(b)))]))
        return (f, F, -1.5, 1.5, "Integration by parts (cyclic)", [
            S("Call the integral I. Integrate by parts twice (u = the trig part each time)."),
            S("The second time, the original integral I appears again on the right-hand side."),
            S("Move it to the left: (1 + b²/a²)·I = …, so I has the factor 1/(a² + b²).", "a² + b² =", .n(d)),
        ])
    }

    // Odd trig powers: sin³(x), cos³(x)
    static func hard4(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.p(.sin(x), 3), .sum([.neg(.cos(x)), .scaled(1, 3, .p(.cos(x), 3))]), -2, 2, "Trig powers", [
                S("Split off one sine:", "sin³x =", .mul(.sub(1, .p(.cos(x), 2)), .sin(x))),
                S("Substitute u = cos x, du = −sin x dx: −∫(1 − u²) du = −u + u³/3."),
            ])
        }
        return (.p(.cos(x), 3), .sum([.sin(x), .scaled(-1, 3, .p(.sin(x), 3))]), -2, 2, "Trig powers", [
            S("Split off one cosine:", "cos³x =", .mul(.sub(1, .p(.sin(x), 2)), .cos(x))),
            S("Substitute u = sin x, du = cos x dx: ∫(1 − u²) du = u − u³/3."),
        ])
    }

    // sin²(x)·cos²(x)
    static func hard5(_ r: inout SeededRandom) -> Made? {
        (.mul(.p(.sin(x), 2), .p(.cos(x), 2)),
         .sum([.scaled(1, 8, x), .scaled(-1, 32, .sin(lin(4)))]), -2, 2, "Trig identities", [
            S("sin x·cos x = sin(2x)/2, so the integrand is sin²(2x)/4."),
            S("Then sin²(2x) = (1 − cos 4x)/2, giving", "=", .div(.sub(1, .cos(lin(4))), 8)),
            S("Integrate: x/8 − sin(4x)/32."),
         ])
    }

    // e^(sin x)·cos x  /  e^(cos x)·sin x
    static func hard6(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.mul(.exp(.sin(x)), .cos(x)), .exp(.sin(x)), -2, 2, "Substitution", [
                S("Substitute:", "u =", .sin(x)),
                S("du = cos x dx, so the integral is ∫eᵘ du = eᵘ."),
            ])
        }
        return (.mul(.exp(.cos(x)), .sin(x)), .neg(.exp(.cos(x))), -2, 2, "Substitution", [
            S("Substitute:", "u =", .cos(x)),
            S("du = −sin x dx, so the integral is −∫eᵘ du = −eᵘ."),
        ])
    }

    // lnⁿ(x) / x
    static func hard7(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...4)
        return (.div(.p(.ln(x), n), x), .scaled(1, n + 1, .p(.ln(x), n + 1)), 0.5, 4, "Substitution", [
            S("Substitute:", "u =", .ln(x)),
            S("du = dx/x, so the integral is ∫uⁿ du = uⁿ⁺¹/(n+1).", "n =", .n(n)),
        ])
    }

    // sin(ln x)/x, cos(ln x)/x
    static func hard8(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.div(.sin(.ln(x)), x), .neg(.cos(.ln(x))), 0.5, 4, "Substitution", [
                S("Substitute:", "u =", .ln(x)),
                S("du = dx/x, so the integral is ∫sin u du = −cos u."),
            ])
        }
        return (.div(.cos(.ln(x)), x), .sin(.ln(x)), 0.5, 4, "Substitution", [
            S("Substitute:", "u =", .ln(x)),
            S("du = dx/x, so the integral is ∫cos u du = sin u."),
        ])
    }

    // k·x / √(x² + a)
    static func hard9(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...9), k = r.int(1...4)
        let u = Expr.sum([.p(x, 2), .n(a)])
        return (.div(.scaled(k, 1, x), .sqrt(u)), .scaled(k, 1, .sqrt(u)), -2, 2, "Substitution", [
            S("Substitute:", "u =", u),
            S("du = 2x dx, so the integral is (k/2)·∫u^(−1/2) du = (k/2)·2√u = k√u.", "k =", .n(k)),
        ])
    }

    // tan(x)  /  sec(x)
    static func hard10(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.tan(x), .neg(.ln(.cos(x))), -1.2, 1.2, "Substitution", [
                S("Write tan x = sin x / cos x and substitute u = cos x, du = −sin x dx."),
                S("−∫du/u = −ln|u| = −ln(cos x)  (cos x > 0 here)."),
            ])
        }
        return (.sec(x), .ln(.add(.sec(x), .tan(x))), -1.2, 1.2, "Standard integral", [
            S("Multiply top and bottom by (sec x + tan x)."),
            S("The numerator becomes the derivative of the denominator sec x + tan x, so the integral is ln|sec x + tan x|."),
        ])
    }

    // x²·ln(x)
    static func hard11(_ r: inout SeededRandom) -> Made? {
        (.mul(.p(x, 2), .ln(x)),
         .sum([.mul(.scaled(1, 3, .p(x, 3)), .ln(x)), .scaled(-1, 9, .p(x, 3))]), 0.5, 4, "Integration by parts", [
            S("Parts with u = ln x, dv = x² dx: du = dx/x and", "v =", .scaled(1, 3, .p(x, 3))),
            S("u·v − ∫v du = (x³/3)·ln x − ∫ x²/3 dx = (x³/3)·ln x − x³/9."),
         ])
    }

    // arctan(x)
    static func hard12(_ r: inout SeededRandom) -> Made? {
        (.atan(x), .sum([.mul(x, .atan(x)), .scaled(-1, 2, .ln(.sum([.p(x, 2), 1])))]), -2, 2, "Integration by parts", [
            S("Parts with u = arctan x, dv = dx: du = dx/(1 + x²), v = x."),
            S("x·arctan x − ∫ x/(1 + x²) dx, and that last integral is ½·ln(1 + x²) (f′/f)."),
        ])
    }

    // x³·e^(x²)
    static func hard13(_ r: inout SeededRandom) -> Made? {
        (.mul(.p(x, 3), .exp(.p(x, 2))),
         .mul(.scaled(1, 2, .exp(.p(x, 2))), .sum([.p(x, 2), -1])), -1.3, 1.3, "Substitution + by parts", [
            S("Substitute t = x², dt = 2x dx: the integral becomes ½·∫t·eᵗ dt."),
            S("By parts: ∫t·eᵗ dt = eᵗ(t − 1). Substitute t = x² back."),
         ])
    }

    // MARK: - Bagrut 5 units (hardest questions, syllabus only)

    // Sum of a log term, an exponential and a root:  a/(bx + c) + k e^(mx) − p√x
    static func bag1(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...6), b = r.int(1...3), c = r.int(1...4), k = r.nonZero(-4...4)
        let m = r.nonZero(-2...2), p = r.int(1...3) * 3
        let lin1 = Expr.sum([lin(b), .n(c)])
        let f = Expr.sum([.div(.n(a), lin1), .scaled(k, 1, .exp(lin(m))), .scaled(-p, 1, .sqrt(x))])
        let F = Expr.sum([.scaled(a, b, .ln(lin1)), .scaled(k, m, .exp(lin(m))), .scaled(-2 * p, 3, .pow(x, .q(3, 2)))])
        return (f, F, 0.2, 3, "Sum of standard integrals", [
            S("Integrate each term separately."),
            S("∫ a/(bx + c) dx = (a/b)·ln(bx + c)  (bx + c > 0 here).", "bx + c =", lin1),
            S("∫ k·e^(mx) dx = (k/m)·e^(mx).", "m =", .n(m)),
            S("∫ √x dx = (2/3)·x^(3/2)."),
        ])
    }

    // (ax + b)ⁿ plus a polynomial term
    static func bag2(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-3...3), b = r.nonZero(-4...4), n = r.int(3...6), c = r.nonZero(-5...5)
        let inner = Expr.sum([lin(a), .n(b)])
        let f = Expr.sum([.p(inner, n), .scaled(c, 1, x)])
        let F = Expr.sum([.scaled(1, a * (n + 1), .p(inner, n + 1)), .scaled(c, 2, .p(x, 2))])
        return (f, F, -1.5, 1.5, "Linear inner function", [
            S("For a linear inside ax + b:  ∫(ax + b)ⁿ dx = (ax + b)ⁿ⁺¹ / (a·(n+1)).", "a =", .n(a)),
            S("The second term is a plain power."),
        ])
    }

    // k·x/(x² + a) + m/x²
    static func bag3(_ r: inout SeededRandom) -> Made? {
        let k = r.nonZero(1...6) * 2, a = r.int(1...6), m = r.nonZero(-5...5)
        let u = Expr.sum([.p(x, 2), .n(a)])
        let f = Expr.sum([.div(.scaled(k, 1, x), u), .div(.n(m), .p(x, 2))])
        let F = Expr.sum([.scaled(k, 2, .ln(u)), .scaled(-m, 1, .div(1, x))])
        return (f, F, 0.5, 3.5, "f′/f and power rule", [
            S("First term: the derivative of x² + a is 2x, so it is (k/2)·f′/f.", "f =", u),
            S("∫ f′/f dx = ln f  (f > 0)."),
            S("Second term: m/x² = m·x⁻², which integrates to −m/x."),
        ])
    }

    // 1/√(ax + b) + cos(kx)
    static func bag4(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...4), b = r.int(1...5), c = r.nonZero(1...4), k = r.int(2...4), d = r.nonZero(-4...4)
        let inner = Expr.sum([lin(a), .n(b)])
        let f = Expr.sum([.div(.n(c), .sqrt(inner)), .scaled(d, 1, .cos(lin(k)))])
        let F = Expr.sum([.scaled(2 * c, a, .sqrt(inner)), .scaled(d, k, .sin(lin(k)))])
        return (f, F, 0, 3, "Linear inner function", [
            S("1/√(ax + b) = (ax + b)^(−1/2), which integrates to 2√(ax + b)/a.", "ax + b =", inner),
            S("∫cos(kx) dx = sin(kx)/k.", "k =", .n(k)),
        ])
    }

    // (2x + b)·e^(x² + bx)  — f′·e^f
    static func bag5(_ r: inout SeededRandom) -> Made? {
        let b = r.nonZero(-3...3), k = r.int(1...3)
        let g = Expr.sum([.p(x, 2), .scaled(b, 1, x)])
        let f = Expr.mul(.sum([.scaled(2 * k, 1, x), .n(k * b)]), .exp(g))
        return (f, .scaled(k, 1, .exp(g)), -1.2, 1.0, "f′·e^f", [
            S("The factor in front is k times the derivative of the exponent:", "exponent =", g),
            S("∫ f′(x)·e^(f(x)) dx = e^(f(x)).", "k =", .n(k)),
        ])
    }

    // lnⁿ(x)/x + a/x
    static func bag6(_ r: inout SeededRandom) -> Made? {
        let n = r.int(1...3), a = r.nonZero(-4...4)
        let lnPow: Expr = n == 1 ? .ln(x) : .p(.ln(x), n)
        let f = Expr.sum([.div(lnPow, x), .div(.n(a), x)])
        let F = Expr.sum([.scaled(1, n + 1, .p(.ln(x), n + 1)), .scaled(a, 1, .ln(x))])
        return (f, F, 0.5, 4, "f′·fⁿ", [
            S("With f = ln x, f′ = 1/x, so lnⁿ(x)/x = f′·fⁿ, which integrates to fⁿ⁺¹/(n+1).", "n =", .n(n)),
            S("∫ a/x dx = a·ln x  (x > 0)."),
        ])
    }

    // cos(x)·sinⁿ(x) + sin(kx)
    static func bag7(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...4), k = r.int(2...3), c = r.nonZero(-3...3)
        let f = Expr.sum([.mul(.cos(x), .p(.sin(x), n)), .scaled(c, 1, .sin(lin(k)))])
        let F = Expr.sum([.scaled(1, n + 1, .p(.sin(x), n + 1)), .scaled(-c, k, .cos(lin(k)))])
        return (f, F, -2, 2, "f′·fⁿ", [
            S("With f = sin x, f′ = cos x: cos x·sinⁿx = f′·fⁿ → fⁿ⁺¹/(n+1).", "n =", .n(n)),
            S("∫sin(kx) dx = −cos(kx)/k.", "k =", .n(k)),
        ])
    }

    // a/cos²(x) + b·sin(x)  — tan via 1/cos²
    static func bag8(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-4...4), b = r.nonZero(-4...4), k = r.int(1...2)
        let f = Expr.sum([.div(.n(a), .p(.cos(lin(k)), 2)), .scaled(b, 1, .sin(x))])
        let F = Expr.sum([.scaled(a, k, .tan(lin(k))), .scaled(-b, 1, .cos(x))])
        return (f, F, -0.6, 0.6, "Standard integrals", [
            S("(tan(kx))′ = k/cos²(kx), so ∫ 1/cos²(kx) dx = tan(kx)/k.", "k =", .n(k)),
            S("∫sin x dx = −cos x."),
        ])
    }

    // x·√(x² + a)
    static func bag9(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...8), k = r.int(1...3) * 3
        let u = Expr.sum([.p(x, 2), .n(a)])
        return (.mul(.scaled(k, 1, x), .sqrt(u)), .scaled(k, 3, .pow(u, .q(3, 2))), -2, 2, "f′·fⁿ", [
            S("With f = x² + a, f′ = 2x, so x·√f = ½·f′·f^(1/2).", "f =", u),
            S("∫ f′·f^(1/2) dx = (2/3)·f^(3/2); with the ½ and the factor k this gives (k/3)·f^(3/2).", "k =", .n(k)),
        ])
    }

    // (eˣ + a)² — expand first
    static func bag10(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-3...3), m = r.int(1...2)
        let f = Expr.p(.sum([.exp(lin(m)), .n(a)]), 2)
        let F = Expr.sum([.scaled(1, 2 * m, .exp(lin(2 * m))), .scaled(2 * a, m, .exp(lin(m))), .scaled(a * a, 1, x)])
        return (f, F, -1.5, 1.5, "Expand, then integrate", [
            S("Expand the square:", "=", .sum([.exp(lin(2 * m)), .scaled(2 * a, 1, .exp(lin(m))), .n(a * a)])),
            S("Integrate each term: ∫e^(kx) dx = e^(kx)/k and a² integrates to a²x."),
        ])
    }

    // (x² + bx + c)/x — divide first
    static func bag11(_ r: inout SeededRandom) -> Made? {
        let b = r.nonZero(-5...5), c = r.nonZero(-6...6)
        let f = Expr.div(.sum([.p(x, 2), .scaled(b, 1, x), .n(c)]), x)
        let F = Expr.sum([.scaled(1, 2, .p(x, 2)), .scaled(b, 1, x), .scaled(c, 1, .ln(x))])
        return (f, F, 0.5, 4, "Divide, then integrate", [
            S("Divide each term by x:", "=", .sum([x, .n(b), .div(.n(c), x)])),
            S("Integrate: x²/2 + b·x + c·ln x  (x > 0)."),
        ])
    }

    // (√x + a)² / x — expand and divide
    static func bag12(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...4)
        let f = Expr.div(.p(.sum([.sqrt(x), .n(a)]), 2), x)
        let F = Expr.sum([x, .scaled(4 * a, 1, .sqrt(x)), .scaled(a * a, 1, .ln(x))])
        return (f, F, 0.5, 4, "Expand, divide, integrate", [
            S("Expand: (√x + a)² = x + 2a√x + a²."),
            S("Divide by x:", "=", .sum([1, .scaled(2 * a, 1, .pow(x, .q(-1, 2))), .div(.n(a * a), x)])),
            S("Integrate: x + 4a√x + a²·ln x."),
        ])
    }
}
