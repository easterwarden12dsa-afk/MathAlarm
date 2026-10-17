import Foundation

/// Differentiation problems: nested chain-rule layers combined with product
/// and quotient rules, e.g. sin(ln(x² + 1)) / (x² + eˣ). Candidates that are
/// undefined or blow up anywhere on the interval are rejected by `Validator`.
enum DerivativeGenerator {
    private static let x = Expr.x
    private static func lin(_ k: Int) -> Expr { .scaled(k, 1, .x) }

    static func candidate(level: Level, rng r: inout SeededRandom, seed: UInt64) -> CalculusProblem? {
        // Each piece is built in its own statement (never two `&r` in one call).
        // Bagrut 5 units: hardest structures, but only syllabus functions.
        let syllabus = level == .bagrut
        func w(_ u: Expr) -> Expr { wrap(u, &r, syllabus: syllabus) }
        func inner(_ r: inout SeededRandom) -> Expr { Self.inner(&r, syllabus: syllabus) }
        func factor(_ r: inout SeededRandom) -> Expr { Self.factor(&r, syllabus: syllabus) }
        let f: Expr
        let technique: String
        let shape = r.int(0...2)
        // Bagrut questions go up to two chain layers combined with a product or
        // quotient; deeper nesting isn't Bagrut style.
        let structureLevel: Level = syllabus ? (shape == 2 ? .hard : .medium) : level
        switch (structureLevel, shape) {
        case (.easy, 0):
            let g = inner(&r)
            f = w(g)
            technique = "Chain rule"
        case (.easy, 1):
            let p = power(&r)
            let g = simpleInner(&r)
            f = .mul(p, w(g))
            technique = "Product + chain rule"
        case (.easy, _):
            let g = simpleInner(&r)
            let top = w(g)
            let bottom = nonZeroFactor(&r)
            f = .div(top, bottom)
            technique = "Quotient rule"
        case (.medium, 0):
            let g = inner(&r)
            let h = w(g)
            f = w(h)
            technique = "Chain rule (two layers)"
        case (.medium, 1):
            let t = factor(&r)
            let g = inner(&r)
            f = .mul(t, w(g))
            technique = "Product + chain rule"
        case (.medium, _):
            let g = inner(&r)
            let top = w(g)
            let bottom = nonZeroFactor(&r)
            f = .div(top, bottom)
            technique = "Quotient + chain rule"
        case (.hard, 0):
            let g = inner(&r)
            let h = w(g)
            let top = w(h)
            let bottom = nonZeroFactor(&r)
            f = .div(top, bottom)
            technique = "Quotient + nested chain rule"
        case (.hard, 1):
            let g = inner(&r)
            let h = w(g)
            let left = w(h)
            let g2 = simpleInner(&r)
            let right = w(g2)
            f = .mul(left, right)
            technique = "Product + nested chain rule"
        case (_, _):
            let t = factor(&r)
            let g = inner(&r)
            let top = Expr.mul(t, w(g))
            let bottom = nonZeroFactor(&r)
            f = .div(top, bottom)
            technique = "Product + quotient + chain rule"
        }
        guard f.size >= 5, f.size <= 28 else { return nil }
        let domainHigh: Double = f.usesTan ? 1.2 : 2
        return CalculusProblem(kind: .derivative, level: level, display: f, reference: f.derivative(),
                               domainLow: -domainHigh, domainHigh: domainHigh, technique: technique, seed: seed)
    }

    // MARK: Building blocks

    /// Innermost layer g(x).
    static func inner(_ r: inout SeededRandom, syllabus: Bool = false) -> Expr {
        switch r.int(0...5) {
        case 0: return .sum([.scaled(r.int(1...3), 1, .p(x, 2)), .n(r.int(1...5))])        // a x² + b
        case 1: return .sum([lin(r.nonZero(-4...4)), .n(r.int(-3...3))])                   // a x + b
        case 2: return .sum([.p(x, 3), .scaled(-r.int(1...3), 1, x)])                     // x³ − a x
        case 3: return .sum([.p(x, 2), .scaled(r.nonZero(-3...3), 1, x), .n(r.int(1...4))]) // x² + b x + c
        case 4: return r.bool() ? .sin(lin(r.int(1...3))) : .cos(lin(r.int(1...3)))
        default: return .exp(lin(r.pick([1, -1, 2])))
        }
    }

    static func simpleInner(_ r: inout SeededRandom) -> Expr {
        switch r.int(0...2) {
        case 0: return lin(r.int(2...5))
        case 1: return .sum([.p(x, 2), .n(r.int(1...4))])
        default: return .p(x, 2)
        }
    }

    /// Wraps u in an outer function. ln and √ are only used where they can be
    /// defined; anything undefined on the interval is rejected later anyway.
    static func wrap(_ u: Expr, _ r: inout SeededRandom, syllabus: Bool = false) -> Expr {
        // Bagrut syllabus: sin, cos, e^u, ln, √, powers (no arctan).
        let choice = r.int(0...7)
        switch syllabus && choice == 6 ? 0 : choice {
        case 0: return .sin(u)
        case 1: return .cos(u)
        case 2: return .exp(u)
        case 3: return .ln(.sum([.p(u, 2), .n(r.int(1...3))]))   // ln(u² + c): always defined
        case 4: return .sqrt(.sum([.p(u, 2), .n(r.int(1...4))]))  // √(u² + c)
        case 5:
            // (x²)ⁿ or (eˣ)ⁿ are just xᵐ / e^(nx): use a different layer.
            if case .pow = u { return .cos(u) }
            if case .fn(.exp, _) = u { return .cos(u) }
            return .p(u, r.int(2...4))
        case 6: return .atan(u)
        default:
            // ln(e^u) would cancel, so ln only goes on positive polynomials.
            if u.isAlwaysPositive, !u.isExp { return .ln(u) }
            return .sin(u)
        }
    }

    static func power(_ r: inout SeededRandom) -> Expr {
        let n = r.int(1...3)
        return n == 1 ? x : .p(x, n)
    }

    static func factor(_ r: inout SeededRandom, syllabus: Bool = false) -> Expr {
        switch r.int(0...3) {
        case 0: return power(&r)
        case 1: return .exp(lin(r.pick([1, -1, 2])))
        case 2: return .sin(lin(r.int(1...3)))
        default: return .sum([.p(x, 2), .n(r.nonZero(-3...3))])
        }
    }

    /// A denominator that is never zero.
    static func nonZeroFactor(_ r: inout SeededRandom) -> Expr {
        switch r.int(0...4) {
        case 0: return .sum([.p(x, 2), .n(r.int(1...4))])
        case 1: return .sum([.p(x, 2), .exp(x)])
        case 2: return .sum([.n(2), .sin(x)])
        case 3: return .sum([.n(r.int(2...4)), .cos(lin(r.int(1...2)))])
        default: return .sum([.exp(x), .n(r.int(1...3))])
        }
    }
}

extension Expr {
    var usesTan: Bool {
        switch self {
        case .fn(let f, let a): return f == .tan || a.usesTan
        case .num, .x, .pi, .e, .constC: return false
        case .neg(let a): return a.usesTan
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b),
             .div(let a, let b), .pow(let a, let b): return a.usesTan || b.usesTan
        }
    }

    var isExp: Bool {
        if case .fn(.exp, _) = self { return true }
        return false
    }

    /// Conservative structural check for positivity (used for ln(u)).
    var isAlwaysPositive: Bool {
        switch self {
        case .fn(.exp, _): return true
        case .add(.pow(_, .num(let k)), .num(let c)): return Int(k) % 2 == 0 && c > 0
        case .add(.mul(.num(let a), .pow(_, .num(let k))), .num(let c)): return a > 0 && Int(k) % 2 == 0 && c > 0
        default: return false
        }
    }
}
