import Foundation

/// Elementary functions the engine understands.
public enum Fn: String, Codable, CaseIterable, Sendable {
    case sin, cos, tan, sec, csc, cot
    case asin, acos, atan
    case sinh, cosh, tanh
    case ln, log, exp, sqrt, abs

    /// Name as written in front of an argument, e.g. "sin", "arcsin", "log".
    public var displayName: String {
        switch self {
        case .asin: "arcsin"
        case .acos: "arccos"
        case .atan: "arctan"
        default: rawValue
        }
    }
}

/// A mathematical expression in one variable `x`.
/// `constC` is the constant of integration ("+ C").
public indirect enum Expr: Hashable, Codable, Sendable {
    case num(Double)
    case x
    case pi
    case e
    case constC
    case neg(Expr)
    case add(Expr, Expr)
    case sub(Expr, Expr)
    case mul(Expr, Expr)
    case div(Expr, Expr)
    case pow(Expr, Expr)
    case fn(Fn, Expr)
}

extension Expr: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init(integerLiteral value: Int) { self = .num(Double(value)) }
    public init(floatLiteral value: Double) { self = .num(value) }
}

// MARK: - Building expressions

public extension Expr {
    static func + (a: Expr, b: Expr) -> Expr { .add(a, b) }
    static func - (a: Expr, b: Expr) -> Expr { .sub(a, b) }
    static func * (a: Expr, b: Expr) -> Expr { .mul(a, b) }
    static func / (a: Expr, b: Expr) -> Expr { .div(a, b) }
    static prefix func - (a: Expr) -> Expr { .neg(a) }

    static func n(_ v: Int) -> Expr { .num(Double(v)) }

    /// p/q reduced; an integer when it divides evenly.
    static func q(_ p: Int, _ q: Int) -> Expr {
        precondition(q != 0)
        var p = p, q = q
        if q < 0 { p = -p; q = -q }
        let g = gcd(Swift.abs(p), q)
        p /= g; q /= g
        if q == 1 { return .n(p) }
        if p < 0 { return .neg(.div(.n(-p), .n(q))) }
        return .div(.n(p), .n(q))
    }

    static func p(_ base: Expr, _ k: Int) -> Expr { .pow(base, .n(k)) }

    static func sin(_ u: Expr) -> Expr { .fn(.sin, u) }
    static func cos(_ u: Expr) -> Expr { .fn(.cos, u) }
    static func tan(_ u: Expr) -> Expr { .fn(.tan, u) }
    static func sec(_ u: Expr) -> Expr { .fn(.sec, u) }
    static func csc(_ u: Expr) -> Expr { .fn(.csc, u) }
    static func cot(_ u: Expr) -> Expr { .fn(.cot, u) }
    static func asin(_ u: Expr) -> Expr { .fn(.asin, u) }
    static func acos(_ u: Expr) -> Expr { .fn(.acos, u) }
    static func atan(_ u: Expr) -> Expr { .fn(.atan, u) }
    static func sinh(_ u: Expr) -> Expr { .fn(.sinh, u) }
    static func cosh(_ u: Expr) -> Expr { .fn(.cosh, u) }
    static func tanh(_ u: Expr) -> Expr { .fn(.tanh, u) }
    static func ln(_ u: Expr) -> Expr { .fn(.ln, u) }
    static func log(_ u: Expr) -> Expr { .fn(.log, u) }
    static func exp(_ u: Expr) -> Expr { .fn(.exp, u) }
    static func sqrt(_ u: Expr) -> Expr { .fn(.sqrt, u) }
    static func abs(_ u: Expr) -> Expr { .fn(.abs, u) }

    /// k·e with k = p/q, written the way a person would (1·e → e, −1·e → −e).
    static func scaled(_ p: Int, _ q: Int, _ e: Expr) -> Expr {
        precondition(q != 0)
        var p = p, q = q
        if q < 0 { p = -p; q = -q }
        let g = gcd(Swift.abs(p), q)
        p /= g; q /= g
        if p == 0 { return 0 }
        if e == 1 { return .q(p, q) }
        let negative = p < 0
        let a = Swift.abs(p)
        let body: Expr
        if q == 1 {
            body = a == 1 ? e : .mul(.n(a), e)
        } else {
            body = .mul(.div(.n(a), .n(q)), e)
        }
        return negative ? .neg(body) : body
    }

    /// Joins terms with + and −, turning "+ (−t)" into "− t".
    static func sum(_ terms: [Expr]) -> Expr {
        let nonZero = terms.filter { $0 != 0 }
        guard var acc = nonZero.first else { return 0 }
        for t in nonZero.dropFirst() {
            if case .neg(let inner) = t {
                acc = .sub(acc, inner)
            } else if case .num(let v) = t, v < 0 {
                acc = .sub(acc, .num(-v))
            } else {
                acc = .add(acc, t)
            }
        }
        return acc
    }
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var a = a, b = b
    while b != 0 { (a, b) = (b, a % b) }
    return Swift.max(a, 1)
}

// MARK: - Queries

public extension Expr {
    /// True if the expression depends on x.
    var containsX: Bool {
        switch self {
        case .x: true
        case .num, .pi, .e, .constC: false
        case .neg(let a), .fn(_, let a): a.containsX
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b),
             .div(let a, let b), .pow(let a, let b): a.containsX || b.containsX
        }
    }

    var containsC: Bool {
        switch self {
        case .constC: true
        case .num, .pi, .e, .x: false
        case .neg(let a), .fn(_, let a): a.containsC
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b),
             .div(let a, let b), .pow(let a, let b): a.containsC || b.containsC
        }
    }

    /// Number of nodes (used to keep generated problems a sensible size).
    var size: Int {
        switch self {
        case .num, .x, .pi, .e, .constC: 1
        case .neg(let a), .fn(_, let a): 1 + a.size
        case .add(let a, let b), .sub(let a, let b), .mul(let a, let b),
             .div(let a, let b), .pow(let a, let b): 1 + a.size + b.size
        }
    }

    /// The value if the expression contains no x and no C.
    var constantValue: Double? {
        guard !containsX, !containsC else { return nil }
        let v = evaluate(at: 0)
        return v.isFinite ? v : nil
    }
}

// MARK: - Plain-text form (for logs and tests)

extension Expr: CustomStringConvertible {
    public var description: String {
        switch self {
        case .num(let v): return v == v.rounded() && Swift.abs(v) < 1e15 ? String(Int(v)) : String(v)
        case .x: return "x"
        case .pi: return "π"
        case .e: return "e"
        case .constC: return "C"
        case .neg(let a): return "-(\(a))"
        case .add(let a, let b): return "(\(a) + \(b))"
        case .sub(let a, let b): return "(\(a) - \(b))"
        case .mul(let a, let b): return "\(a)*\(b)"
        case .div(let a, let b): return "(\(a))/(\(b))"
        case .pow(let a, let b): return "(\(a))^(\(b))"
        case .fn(let f, let a): return "\(f.displayName)(\(a))"
        }
    }
}
