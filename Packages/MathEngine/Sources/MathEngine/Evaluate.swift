import Foundation

public extension Expr {
    /// Numeric value at `x`. Returns NaN outside the function's domain
    /// (e.g. ln of a negative number). `c` is the value used for "+ C".
    func evaluate(at x: Double, c: Double = 0) -> Double {
        switch self {
        case .num(let v): return v
        case .x: return x
        case .pi: return Double.pi
        case .e: return M_E
        case .constC: return c
        case .neg(let a): return -a.evaluate(at: x, c: c)
        case .add(let a, let b): return a.evaluate(at: x, c: c) + b.evaluate(at: x, c: c)
        case .sub(let a, let b): return a.evaluate(at: x, c: c) - b.evaluate(at: x, c: c)
        case .mul(let a, let b): return a.evaluate(at: x, c: c) * b.evaluate(at: x, c: c)
        case .div(let a, let b):
            let d = b.evaluate(at: x, c: c)
            if d == 0 { return .nan }
            return a.evaluate(at: x, c: c) / d
        case .pow(let a, let b):
            return Self.power(a.evaluate(at: x, c: c), b.evaluate(at: x, c: c), exponentExpr: b)
        case .fn(let f, let a):
            return Self.apply(f, a.evaluate(at: x, c: c))
        }
    }

    /// Real power. Negative bases are allowed for integer exponents and for
    /// odd-denominator rational exponents such as 1/3.
    private static func power(_ base: Double, _ exponent: Double, exponentExpr: Expr) -> Double {
        if base >= 0 { return Foundation.pow(base, exponent) }
        if exponent == exponent.rounded() { return Foundation.pow(base, exponent) }
        if case .div(.num(let p), .num(let q)) = exponentExpr,
           p == p.rounded(), q == q.rounded(), Int(q) % 2 != 0 {
            let magnitude = Foundation.pow(-base, exponent)
            return Int(p) % 2 == 0 ? magnitude : -magnitude
        }
        return .nan
    }

    static func apply(_ f: Fn, _ v: Double) -> Double {
        switch f {
        case .sin: return Foundation.sin(v)
        case .cos: return Foundation.cos(v)
        case .tan:
            let c = Foundation.cos(v)
            return Swift.abs(c) < 1e-12 ? .nan : Foundation.sin(v) / c
        case .sec:
            let c = Foundation.cos(v)
            return Swift.abs(c) < 1e-12 ? .nan : 1 / c
        case .csc:
            let s = Foundation.sin(v)
            return Swift.abs(s) < 1e-12 ? .nan : 1 / s
        case .cot:
            let s = Foundation.sin(v)
            return Swift.abs(s) < 1e-12 ? .nan : Foundation.cos(v) / s
        case .asin: return Swift.abs(v) > 1 ? .nan : Foundation.asin(v)
        case .acos: return Swift.abs(v) > 1 ? .nan : Foundation.acos(v)
        case .atan: return Foundation.atan(v)
        case .sinh: return Foundation.sinh(v)
        case .cosh: return Foundation.cosh(v)
        case .tanh: return Foundation.tanh(v)
        case .ln: return v <= 0 ? .nan : Foundation.log(v)
        case .log: return v <= 0 ? .nan : Foundation.log10(v)
        case .exp: return Foundation.exp(v)
        case .sqrt: return v < 0 ? .nan : Foundation.sqrt(v)
        case .abs: return Swift.abs(v)
        }
    }
}

public enum NumericDerivative {
    /// Five-point central difference; error is roughly h⁴·f⁽⁵⁾.
    public static func at(_ x: Double, c: Double = 0, of f: Expr) -> Double {
        let h = 1e-3 * Swift.max(1, Swift.abs(x))
        let f2 = f.evaluate(at: x + 2 * h, c: c)
        let f1 = f.evaluate(at: x + h, c: c)
        let m1 = f.evaluate(at: x - h, c: c)
        let m2 = f.evaluate(at: x - 2 * h, c: c)
        return (-f2 + 8 * f1 - 8 * m1 + m2) / (12 * h)
    }
}
