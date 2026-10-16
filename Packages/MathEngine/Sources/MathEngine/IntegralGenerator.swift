import Foundation

/// Integration problems built from technique templates. Every template
/// produces an integrand together with a known antiderivative, so the
/// reference answer is right by construction (and is still verified
/// numerically by `Validator` before use).
enum IntegralGenerator {
    typealias Made = (f: Expr, F: Expr, lo: Double, hi: Double, technique: String)
    typealias Template = (inout SeededRandom) -> Made?

    static func candidate(level: Level, rng: inout SeededRandom, seed: UInt64) -> CalculusProblem? {
        let templates: [Template]
        switch level {
        case .easy: templates = easy
        case .medium: templates = medium
        case .hard: templates = hard
        }
        guard let made = rng.pick(templates)(&rng) else { return nil }
        return CalculusProblem(kind: .integral, level: level, display: made.f, reference: made.F,
                               domainLow: made.lo, domainHigh: made.hi, technique: made.technique, seed: seed)
    }

    // Shorthands
    private static let x = Expr.x
    private static func lin(_ k: Int) -> Expr { .scaled(k, 1, .x) }          // k·x
    private static func xPow(_ n: Int) -> Expr { n == 1 ? .x : .p(.x, n) }

    // MARK: Template lists

    static let easy: [Template] = [easy1, easy2, easy3, easy4, easy5, easy6, easy7]
    static let medium: [Template] = [medium1, medium2, medium3, medium4, medium5, medium6, medium7, medium8, medium9, medium10]
    static let hard: [Template] = [hard1, hard2, hard3, hard4, hard5, hard6, hard7, hard8, hard9, hard10, hard11, hard12, hard13]

    // MARK: Templates

    // Power rule: a xⁿ + b xᵐ + c
    static func easy1(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5), m = r.int(1...(n - 1))
        let a = r.nonZero(-6...6), b = r.nonZero(-6...6), c = r.int(-6...6)
        let f = Expr.sum([.scaled(a, 1, xPow(n)), .scaled(b, 1, xPow(m)), .n(c)])
        let F = Expr.sum([.scaled(a, n + 1, xPow(n + 1)), .scaled(b, m + 1, xPow(m + 1)), .scaled(c, 1, x)])
        return (f, F, -2, 2, "Power rule")
    }

    // a·cos(kx) or a·sin(kx)
    static func easy2(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), k = r.int(2...5)
        if r.bool() {
            return (.scaled(a, 1, .cos(lin(k))), .scaled(a, k, .sin(lin(k))), -2, 2, "Basic trig integral")
        } else {
            return (.scaled(a, 1, .sin(lin(k))), .scaled(-a, k, .cos(lin(k))), -2, 2, "Basic trig integral")
        }
    }

    // a·e^(kx)
    static func easy3(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), k = r.nonZero(-3...3)
        return (.scaled(a, 1, .exp(lin(k))), .scaled(a, k, .exp(lin(k))), -1.5, 1.5, "Exponential")
    }

    // a / (x + b)
    static func easy4(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5), b = r.int(-3...3)
        let inner = Expr.sum([x, .n(b)])
        let f: Expr = a > 0 ? .div(.n(a), inner) : .neg(.div(.n(-a), inner))
        let lo = Double(-b) + 0.5
        return (f, .scaled(a, 1, .ln(inner)), lo, lo + 3.5, "Logarithm")
    }

    // a·√x
    static func easy5(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...6) * (r.bool() ? 1 : 3)
        return (.scaled(a, 1, .sqrt(x)), .scaled(2 * a, 3, .pow(x, .q(3, 2))), 0.2, 4, "Power rule")
    }

    // a·sec²(x)
    static func easy6(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(-5...5)
        return (.scaled(a, 1, .p(.sec(x), 2)), .scaled(a, 1, .tan(x)), -1.2, 1.2, "Standard integral")
    }

    // a / (x² + 1)
    static func easy7(_ r: inout SeededRandom) -> Made? {
        let a = r.nonZero(1...6)
        return (.div(.n(a), .sum([.p(x, 2), 1])), .scaled(a, 1, .atan(x)), -2, 2, "Standard integral")
    }

    // u-substitution: k·x·(x² + a)ⁿ
    static func medium1(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5), a = r.int(1...5), k = r.int(1...4)
        let u = Expr.sum([.p(x, 2), .n(a)])
        let f = Expr.mul(.scaled(k, 1, x), .p(u, n))
        return (f, .scaled(k, 2 * (n + 1), .p(u, n + 1)), -1.5, 1.5, "Substitution")
    }

    // x·e^(a x²)
    static func medium2(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, 3, -1, -2])
        let inner = Expr.scaled(a, 1, .p(x, 2))
        return (.mul(x, .exp(inner)), .scaled(1, 2 * a, .exp(inner)), -1.3, 1.3, "Substitution")
    }

    // sinⁿ(x)·cos(x)  or  cosⁿ(x)·sin(x)
    static func medium3(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...5)
        if r.bool() {
            return (.mul(.p(.sin(x), n), .cos(x)), .scaled(1, n + 1, .p(.sin(x), n + 1)), -2, 2, "Substitution")
        } else {
            return (.mul(.p(.cos(x), n), .sin(x)), .scaled(-1, n + 1, .p(.cos(x), n + 1)), -2, 2, "Substitution")
        }
    }

    // k(2x + b) / (x² + bx + c), never zero
    static func medium4(_ r: inout SeededRandom) -> Made? {
        let b = r.nonZero(-4...4), k = r.int(1...3)
        let c = (b * b) / 4 + r.int(1...4)
        let den = Expr.sum([.p(x, 2), .scaled(b, 1, x), .n(c)])
        let num = Expr.sum([.scaled(2 * k, 1, x), .n(k * b)])
        return (.div(num, den), .scaled(k, 1, .ln(den)), -2, 2, "Substitution")
    }

    // e^x / (e^x + a)
    static func medium5(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...5)
        let den = Expr.sum([.exp(x), .n(a)])
        return (.div(.exp(x), den), .ln(den), -2, 2, "Substitution")
    }

    // By parts: x·e^(ax)
    static func medium6(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, 3, -1, -2])
        let F = Expr.mul(.exp(lin(a)), .sum([.scaled(1, a, x), .scaled(-1, a * a, 1)]))
        return (.mul(x, .exp(lin(a))), F, -1.5, 1.5, "Integration by parts")
    }

    // By parts: x·sin(ax) / x·cos(ax)
    static func medium7(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...4)
        if r.bool() {
            let F = Expr.sum([.scaled(-1, a, .mul(x, .cos(lin(a)))), .scaled(1, a * a, .sin(lin(a)))])
            return (.mul(x, .sin(lin(a))), F, -2, 2, "Integration by parts")
        } else {
            let F = Expr.sum([.scaled(1, a, .mul(x, .sin(lin(a)))), .scaled(1, a * a, .cos(lin(a)))])
            return (.mul(x, .cos(lin(a))), F, -2, 2, "Integration by parts")
        }
    }

    // By parts: ln(x)  or  x·ln(x)
    static func medium8(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.ln(x), .sub(.mul(x, .ln(x)), x), 0.5, 4, "Integration by parts")
        } else {
            let F = Expr.sum([.mul(.scaled(1, 2, .p(x, 2)), .ln(x)), .scaled(-1, 4, .p(x, 2))])
            return (.mul(x, .ln(x)), F, 0.5, 4, "Integration by parts")
        }
    }

    // Trig identity: sin²(ax), cos²(ax)
    static func medium9(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...3)
        let sign = r.bool() ? -1 : 1
        let f: Expr = sign < 0 ? .p(.sin(lin(a)), 2) : .p(.cos(lin(a)), 2)
        let F = Expr.sum([.scaled(1, 2, x), .scaled(sign, 4 * a, .sin(lin(2 * a)))])
        return (f, F, -2, 2, "Trig identity")
    }

    // a / (x² + k²)
    static func medium10(_ r: inout SeededRandom) -> Made? {
        let k = r.int(2...4), a = r.nonZero(1...6)
        let f = Expr.div(.n(a), .sum([.p(x, 2), .n(k * k)]))
        return (f, .scaled(a, k, .atan(.div(x, .n(k)))), -2, 2, "Arctangent")
    }

    // Partial fractions: (px + q) / ((x − a)(x − b))
    static func hard1(_ r: inout SeededRandom) -> Made? {
        let a = r.int(-3...3)
        var b = r.int(-3...3)
        while b == a { b = r.int(-3...3) }
        let A = r.nonZero(-4...4), B = r.nonZero(-4...4)
        let num = Expr.sum([.scaled(A + B, 1, x), .n(-(A * b + B * a))])
        let den = Expr.sum([.p(x, 2), .scaled(-(a + b), 1, x), .n(a * b)])
        let F = Expr.sum([.scaled(A, 1, .ln(.sum([x, .n(-a)]))), .scaled(B, 1, .ln(.sum([x, .n(-b)])))])
        let lo = Double(Swift.max(a, b)) + 0.5
        return (.div(num, den), F, lo, lo + 3.5, "Partial fractions")
    }

    // By parts twice: x²·e^(ax)
    static func hard2(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, -1])
        let F = Expr.mul(.exp(lin(a)), .sum([.scaled(1, a, .p(x, 2)), .scaled(-2, a * a, x), .scaled(2, a * a * a, 1)]))
        return (.mul(.p(x, 2), .exp(lin(a))), F, -1.5, 1.5, "Integration by parts (twice)")
    }

    // e^(ax)·sin(bx) / e^(ax)·cos(bx)
    static func hard3(_ r: inout SeededRandom) -> Made? {
        let a = r.pick([1, 2, -1]), b = r.int(1...3)
        let d = a * a + b * b
        if r.bool() {
            let F = Expr.mul(.exp(lin(a)), .sum([.scaled(a, d, .sin(lin(b))), .scaled(-b, d, .cos(lin(b)))]))
            return (.mul(.exp(lin(a)), .sin(lin(b))), F, -1.5, 1.5, "Integration by parts (cyclic)")
        } else {
            let F = Expr.mul(.exp(lin(a)), .sum([.scaled(a, d, .cos(lin(b))), .scaled(b, d, .sin(lin(b)))]))
            return (.mul(.exp(lin(a)), .cos(lin(b))), F, -1.5, 1.5, "Integration by parts (cyclic)")
        }
    }

    // Odd trig powers: sin³(x), cos³(x)
    static func hard4(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.p(.sin(x), 3), .sum([.neg(.cos(x)), .scaled(1, 3, .p(.cos(x), 3))]), -2, 2, "Trig powers")
        } else {
            return (.p(.cos(x), 3), .sum([.sin(x), .scaled(-1, 3, .p(.sin(x), 3))]), -2, 2, "Trig powers")
        }
    }

    // sin²(x)·cos²(x)
    static func hard5(_ _: inout SeededRandom) -> Made? {
        return (.mul(.p(.sin(x), 2), .p(.cos(x), 2)),
        .sum([.scaled(1, 8, x), .scaled(-1, 32, .sin(lin(4)))]), -2, 2, "Trig identities")
    }

    // e^(sin x)·cos x  /  e^(cos x)·sin x
    static func hard6(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.mul(.exp(.sin(x)), .cos(x)), .exp(.sin(x)), -2, 2, "Substitution")
        } else {
            return (.mul(.exp(.cos(x)), .sin(x)), .neg(.exp(.cos(x))), -2, 2, "Substitution")
        }
    }

    // lnⁿ(x) / x
    static func hard7(_ r: inout SeededRandom) -> Made? {
        let n = r.int(2...4)
        return (.div(.p(.ln(x), n), x), .scaled(1, n + 1, .p(.ln(x), n + 1)), 0.5, 4, "Substitution")
    }

    // sin(ln x)/x, cos(ln x)/x
    static func hard8(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.div(.sin(.ln(x)), x), .neg(.cos(.ln(x))), 0.5, 4, "Substitution")
        } else {
            return (.div(.cos(.ln(x)), x), .sin(.ln(x)), 0.5, 4, "Substitution")
        }
    }

    // k·x / √(x² + a)
    static func hard9(_ r: inout SeededRandom) -> Made? {
        let a = r.int(1...9), k = r.int(1...4)
        let u = Expr.sum([.p(x, 2), .n(a)])
        return (.div(.scaled(k, 1, x), .sqrt(u)), .scaled(k, 1, .sqrt(u)), -2, 2, "Substitution")
    }

    // tan(x)  /  sec(x)
    static func hard10(_ r: inout SeededRandom) -> Made? {
        if r.bool() {
            return (.tan(x), .neg(.ln(.cos(x))), -1.2, 1.2, "Substitution")
        } else {
            return (.sec(x), .ln(.add(.sec(x), .tan(x))), -1.2, 1.2, "Standard integral")
        }
    }

    // x²·ln(x)
    static func hard11(_ _: inout SeededRandom) -> Made? {
        return (.mul(.p(x, 2), .ln(x)),
        .sum([.mul(.scaled(1, 3, .p(x, 3)), .ln(x)), .scaled(-1, 9, .p(x, 3))]), 0.5, 4, "Integration by parts")
    }

    // arctan(x)
    static func hard12(_ _: inout SeededRandom) -> Made? {
        return (.atan(x), .sum([.mul(x, .atan(x)), .scaled(-1, 2, .ln(.sum([.p(x, 2), 1])))]), -2, 2, "Integration by parts")
    }

    // x³·e^(x²)
    static func hard13(_ _: inout SeededRandom) -> Made? {
        return (.mul(.p(x, 3), .exp(.p(x, 2))),
        .mul(.scaled(1, 2, .exp(.p(x, 2))), .sum([.p(x, 2), -1])), -1.3, 1.3, "Substitution + by parts")
    }
}
