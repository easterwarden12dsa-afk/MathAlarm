import Foundation

/// Converts an expression into editor atoms so problems and answers are
/// drawn by the same typesetting view the keypad uses.
public enum ExprDisplay {
    public static func row(_ e: Expr) -> Row { Row(atoms(e)) }

    private static func atoms(_ e: Expr) -> [Atom] {
        switch e {
        case .num(let v):
            if v < 0 { return [.token(.minus)] + numberAtoms(-v) }
            return numberAtoms(v)
        case .x: return [.token(.x)]
        case .pi: return [.token(.pi)]
        case .e: return [.token(.e)]
        case .constC: return [.token(.c)]

        case .neg(let a):
            return [.token(.minus)] + wrapped(a, when: isSum(a))

        case .add(let a, let b):
            if case .neg(let inner) = b { return atoms(a) + [.token(.minus)] + wrapped(inner, when: isSum(inner)) }
            if case .num(let v) = b, v < 0 { return atoms(a) + [.token(.minus)] + numberAtoms(-v) }
            return atoms(a) + [.token(.plus)] + atoms(b)

        case .sub(let a, let b):
            return atoms(a) + [.token(.minus)] + wrapped(b, when: isSum(b) || isNegative(b))

        case .mul(let a, let b):
            // Write constants first: x·3 → 3x
            if case .num = b, !isNumberLike(a) { return atoms(.mul(b, a)) }
            let left = wrapped(a, when: isSum(a) || isNegative(a))
            let right = wrapped(b, when: isSum(b) || isNegative(b))
            if needsTimesSign(left: a, right: b) {
                return left + [.token(.times)] + right
            }
            return left + right

        case .div(let a, let b):
            return [.fraction(row(a), row(b))]

        case .pow(let base, let exponent):
            let exp = Atom.power(row(exponent))
            if case .fn(let f, _) = base, f != .sqrt, f != .abs, f != .exp {
                // Function powers: the view draws sin(x)² as sin²(x).
                return atoms(base) + [exp]
            }
            return wrapped(base, when: !isAtomic(base)) + [exp]

        case .fn(let f, let a):
            switch f {
            case .exp: return [.token(.e), .power(row(a))]
            case .sqrt: return [.sqrt(row(a))]
            case .abs: return [.abs(row(a))]
            default: return [.function(f, row(a))]
            }
        }
    }

    private static func numberAtoms(_ v: Double) -> [Atom] {
        let text: String
        if v == v.rounded(), Swift.abs(v) < 1e15 {
            text = String(Int(v))
        } else {
            text = String(format: "%.6g", v)
        }
        return text.compactMap { ch -> Atom? in
            guard let t = Token(rawValue: String(ch)) else { return nil }
            return .token(t)
        }
    }

    private static func wrapped(_ e: Expr, when condition: Bool) -> [Atom] {
        condition ? [.paren(row(e))] : atoms(e)
    }

    private static func isSum(_ e: Expr) -> Bool {
        switch e {
        case .add, .sub: true
        default: false
        }
    }

    private static func isNegative(_ e: Expr) -> Bool {
        switch e {
        case .neg: true
        case .num(let v): v < 0
        default: false
        }
    }

    private static func isNumberLike(_ e: Expr) -> Bool {
        switch e {
        case .num: true
        case .div(.num, .num): true
        default: false
        }
    }

    private static func isAtomic(_ e: Expr) -> Bool {
        switch e {
        case .num(let v): v >= 0 && v == v.rounded()
        case .x, .pi, .e, .constC: true
        case .fn(let f, _): f == .sqrt || f == .abs
        default: false
        }
    }

    /// × is needed when juxtaposition would merge digits (2·3) or read as a
    /// mixed number (2 ½).
    private static func needsTimesSign(left: Expr, right: Expr) -> Bool {
        let rightStartsWithDigit: Bool = {
            if case .num = right { return true }
            if case .mul(let r, _) = right, case .num = r { return true }
            if case .pow(.num, _) = right { return true }
            if case .div = right { return true }
            return false
        }()
        if rightStartsWithDigit { return true }
        if case .div = left, case .div = right { return true }
        return false
    }
}

/// The parts of a function worth copying into an answer: the whole thing,
/// every inner function of the chain rule, bases, numerators, denominators.
public enum ExprPieces {
    public static func pieces(of e: Expr, limit: Int = 10) -> [Expr] {
        var out: [Expr] = []
        func add(_ s: Expr) {
            guard s.containsX, s != .x, !out.contains(s) else { return }
            out.append(s)
        }
        func walk(_ s: Expr) {
            switch s {
            case .fn(_, let u): add(s); walk(u)
            case .pow(let b, let n): add(s); walk(b); walk(n)
            case .div(let a, let b): add(s); walk(a); walk(b)
            case .mul(let a, let b): walk(a); walk(b)
            case .add(let a, let b), .sub(let a, let b): add(s); walk(a); walk(b)
            case .neg(let a): walk(a)
            default: break
            }
        }
        add(e)
        walk(e)
        // Whole function first, then the biggest parts.
        guard let first = out.first else { return [] }
        return [first] + out.dropFirst().sorted { $0.size > $1.size }.prefix(limit - 1)
    }
}

/// The parts of a function worth copying into an answer: the whole thing,
/// every inner function of the chain rule, bases, numerators, denominators.
public enum ExprPieces {
    public static func pieces(of e: Expr, limit: Int = 10) -> [Expr] {
        var out: [Expr] = []
        func add(_ s: Expr) {
            guard s.containsX, s != .x, !out.contains(s) else { return }
            out.append(s)
        }
        func walk(_ s: Expr) {
            switch s {
            case .fn(_, let u): add(s); walk(u)
            case .pow(let b, let n): add(s); walk(b); walk(n)
            case .div(let a, let b): add(s); walk(a); walk(b)
            case .mul(let a, let b): walk(a); walk(b)
            case .add(let a, let b), .sub(let a, let b): add(s); walk(a); walk(b)
            case .neg(let a): walk(a)
            default: break
            }
        }
        add(e)
        walk(e)
        // Whole function first, then the biggest parts.
        guard let first = out.first else { return [] }
        return [first] + out.dropFirst().sorted { $0.size > $1.size }.prefix(limit - 1)
    }
}
