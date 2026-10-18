import Foundation

/// Recognises classic derivative mistakes: the answer is compared with what
/// you'd get by making one specific mistake.
public enum MistakeFinder {
    public enum Mistake: String, CaseIterable, Sendable {
        case forgotChain, quotientOrder, productAsProduct, powerOffByOne, droppedMinus, constantFactor

        public var explanation: String {
            switch self {
            case .forgotChain:
                "It looks like you forgot the chain rule: after differentiating the outer function, multiply by the derivative of the inside."
            case .quotientOrder:
                "It looks like the quotient rule's subtraction is the wrong way round: it's (u′v − uv′)/v², u′v first."
            case .productAsProduct:
                "It looks like you used (uv)′ = u′v′. The product rule is u′v + uv′."
            case .powerOffByOne:
                "It looks like a power slip: (xⁿ)′ = n·xⁿ⁻¹ — the power goes down by one."
            case .droppedMinus:
                "Your answer has the wrong sign everywhere — check a minus (e.g. (cos x)′ = −sin x, (1/x)′ = −1/x²)."
            case .constantFactor:
                "Your answer is off by a constant factor — check a number in front (a chain-rule factor or a coefficient)."
            }
        }
    }

    /// The mistake the answer matches, if any (nil if it's right or unrecognised).
    public static func diagnose(_ answer: Expr, derivativeOf f: Expr, in range: ClosedRange<Double> = -2...2) -> Mistake? {
        let truth = f.derivative()
        let xs = (0..<12).map { range.lowerBound + (range.upperBound - range.lowerBound) * (Double($0) + 0.37) / 12 }
        func same(_ g: Expr) -> Bool {
            var n = 0
            for x in xs {
                let a = answer.evaluate(at: x), b = g.evaluate(at: x)
                guard a.isFinite, b.isFinite else { continue }
                if Swift.abs(a - b) > 1e-6 * Swift.max(1, Swift.abs(b)) { return false }
                n += 1
            }
            return n >= 5
        }
        if same(truth) { return nil }
        for m in [Mistake.forgotChain, .quotientOrder, .productAsProduct, .powerOffByOne] {
            let wrong = mistaken(f, m).simplified()
            if !same(truth) && same(wrong) { return m }
        }
        if same(.neg(truth)) { return .droppedMinus }
        // A constant multiple of the truth.
        var ratio: Double?
        for x in xs {
            let a = answer.evaluate(at: x), b = truth.evaluate(at: x)
            guard a.isFinite, b.isFinite, Swift.abs(b) > 1e-6 else { continue }
            let k = a / b
            if let r = ratio { if Swift.abs(k - r) > 1e-6 * Swift.max(1, Swift.abs(r)) { return nil } } else { ratio = k }
        }
        if let r = ratio, Swift.abs(r - 1) > 1e-6, Swift.abs(r) > 1e-9 { return .constantFactor }
        return nil
    }

    /// d/dx with one deliberate mistake.
    static func mistaken(_ e: Expr, _ m: Mistake) -> Expr {
        func d(_ e: Expr) -> Expr { mistaken(e, m) }
        switch e {
        case .num, .pi, .e, .constC: return 0
        case .x: return 1
        case .neg(let a): return .neg(d(a))
        case .add(let a, let b): return .add(d(a), d(b))
        case .sub(let a, let b): return .sub(d(a), d(b))
        case .mul(let a, let b):
            if !a.containsX { return .mul(a, d(b)) }
            if !b.containsX { return .mul(d(a), b) }
            if m == .productAsProduct { return .mul(d(a), d(b)) }
            return .add(.mul(d(a), b), .mul(a, d(b)))
        case .div(let a, let b):
            if !b.containsX { return .div(d(a), b) }
            if m == .quotientOrder { return .div(.sub(.mul(a, d(b)), .mul(d(a), b)), .pow(b, 2)) }
            return .div(.sub(.mul(d(a), b), .mul(a, d(b))), .pow(b, 2))
        case .pow(let u, let v) where !v.containsX:
            let inner: Expr = m == .forgotChain ? 1 : d(u)
            if m == .powerOffByOne { return .mul(.mul(v, .pow(u, v)), inner) }
            return .mul(.mul(v, .pow(u, .sub(v, 1))), inner)
        case .fn(let f, let u) where u != .x:
            // Outer derivative evaluated at u, times u′ (or not, for the chain-rule mistake).
            let outer = Expr.fn(f, .x).derivative().substitutingX(with: u)
            return m == .forgotChain ? outer : .mul(outer, d(u))
        default:
            return e.derivative()
        }
    }
}
