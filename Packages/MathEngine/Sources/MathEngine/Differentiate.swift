import Foundation

public extension Expr {
    /// Symbolic d/dx, lightly simplified.
    func derivative() -> Expr {
        rawDerivative().simplified()
    }

    private func rawDerivative() -> Expr {
        switch self {
        case .num, .pi, .e, .constC:
            return 0
        case .x:
            return 1
        case .neg(let a):
            return .neg(a.rawDerivative())
        case .add(let a, let b):
            return .add(a.rawDerivative(), b.rawDerivative())
        case .sub(let a, let b):
            return .sub(a.rawDerivative(), b.rawDerivative())
        case .mul(let a, let b):
            if !a.containsX { return .mul(a, b.rawDerivative()) }
            if !b.containsX { return .mul(a.rawDerivative(), b) }
            return .add(.mul(a.rawDerivative(), b), .mul(a, b.rawDerivative()))
        case .div(let a, let b):
            if !b.containsX { return .div(a.rawDerivative(), b) }
            if !a.containsX {
                // (k / v)' = −k·v' / v²
                return .neg(.div(.mul(a, b.rawDerivative()), .pow(b, 2)))
            }
            return .div(.sub(.mul(a.rawDerivative(), b), .mul(a, b.rawDerivative())), .pow(b, 2))
        case .pow(let u, let v):
            if !v.containsX {
                // Power rule: v·u^(v−1)·u'
                return .mul(.mul(v, .pow(u, .sub(v, 1))), u.rawDerivative())
            }
            if !u.containsX {
                // Exponential: u^v · ln(u) · v'
                let lnU: Expr = (u == .e) ? 1 : .fn(.ln, u)
                return .mul(.mul(.pow(u, v), lnU), v.rawDerivative())
            }
            // General: u^v · (v'·ln u + v·u'/u)
            return .mul(.pow(u, v),
                        .add(.mul(v.rawDerivative(), .fn(.ln, u)),
                             .div(.mul(v, u.rawDerivative()), u)))
        case .fn(let f, let u):
            let du = u.rawDerivative()
            let outer: Expr
            switch f {
            case .sin: outer = .cos(u)
            case .cos: outer = .neg(.sin(u))
            case .tan: outer = .pow(.sec(u), 2)
            case .sec: outer = .mul(.sec(u), .tan(u))
            case .csc: outer = .neg(.mul(.csc(u), .cot(u)))
            case .cot: outer = .neg(.pow(.csc(u), 2))
            case .asin: outer = .div(1, .sqrt(.sub(1, .pow(u, 2))))
            case .acos: outer = .neg(.div(1, .sqrt(.sub(1, .pow(u, 2)))))
            case .atan: outer = .div(1, .add(1, .pow(u, 2)))
            case .sinh: outer = .cosh(u)
            case .cosh: outer = .sinh(u)
            case .tanh: outer = .div(1, .pow(.cosh(u), 2))
            case .ln: outer = .div(1, u)
            case .log: outer = .div(1, .mul(u, .ln(10)))
            case .exp: outer = .exp(u)
            case .sqrt: outer = .div(1, .mul(2, .sqrt(u)))
            case .abs: outer = .div(u, .abs(u))
            }
            return .mul(outer, du)
        }
    }
}

// MARK: - Light simplification

public extension Expr {
    /// Folds constants and removes 0/1 identities. Never changes the value.
    func simplified() -> Expr {
        switch self {
        case .num, .x, .pi, .e, .constC:
            return self

        case .neg(let a):
            let s = a.simplified()
            if case .num(let v) = s { return .num(-v) }
            if case .neg(let inner) = s { return inner }
            return .neg(s)

        case .add(let a, let b):
            let sa = a.simplified(), sb = b.simplified()
            if case .num(let x) = sa, case .num(let y) = sb { return .num(x + y) }
            if sa == 0 { return sb }
            if sb == 0 { return sa }
            if case .neg(let nb) = sb { return .sub(sa, nb) }
            if case .num(let y) = sb, y < 0 { return .sub(sa, .num(-y)) }
            return .add(sa, sb)

        case .sub(let a, let b):
            let sa = a.simplified(), sb = b.simplified()
            if case .num(let x) = sa, case .num(let y) = sb { return .num(x - y) }
            if sb == 0 { return sa }
            if sa == 0 { return Expr.neg(sb).simplified() }
            if case .neg(let nb) = sb { return .add(sa, nb) }
            return .sub(sa, sb)

        case .mul(let a, let b):
            let sa = a.simplified(), sb = b.simplified()
            if sa == 0 || sb == 0 { return 0 }
            if sa == 1 { return sb }
            if sb == 1 { return sa }
            if sa == .num(-1) { return Expr.neg(sb).simplified() }
            if sb == .num(-1) { return Expr.neg(sa).simplified() }
            if case .num(let x) = sa, case .num(let y) = sb { return .num(x * y) }
            // Constant to the front: (expr)·3 → 3·(expr)
            if case .num = sb, sa.containsX { return Expr.mul(sb, sa).simplified() }
            // 2·(3·u) → 6·u
            if case .num(let x) = sa, case .mul(.num(let y), let rest) = sb {
                return Expr.mul(.num(x * y), rest).simplified()
            }
            // Pull signs out: (−a)·b → −(a·b)
            if case .neg(let na) = sa { return Expr.neg(.mul(na, sb)).simplified() }
            if case .neg(let nb) = sb { return Expr.neg(.mul(sa, nb)).simplified() }
            if case .num(let x) = sa, x < 0 { return Expr.neg(.mul(.num(-x), sb)).simplified() }
            return .mul(sa, sb)

        case .div(let a, let b):
            let sa = a.simplified(), sb = b.simplified()
            if sa == 0 { return 0 }
            if sb == 1 { return sa }
            if case .num(let x) = sa, case .num(let y) = sb, y != 0 {
                let r = x / y
                if r == r.rounded() { return .num(r) }
            }
            if case .neg(let na) = sa { return Expr.neg(.div(na, sb)).simplified() }
            return .div(sa, sb)

        case .pow(let a, let b):
            let sa = a.simplified(), sb = b.simplified()
            if sb == 0 { return 1 }
            if sb == 1 { return sa }
            if sa == 1 { return 1 }
            if case .num(let x) = sa, case .num(let y) = sb, y == y.rounded(), Swift.abs(y) <= 6 {
                let r = Foundation.pow(x, y)
                if r == r.rounded(), Swift.abs(r) < 1e6 { return .num(r) }
            }
            return .pow(sa, sb)

        case .fn(let f, let a):
            let sa = a.simplified()
            if f == .ln, sa == .e { return 1 }
            if f == .exp, sa == 0 { return 1 }
            return .fn(f, sa)
        }
    }
}
