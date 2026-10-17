import Foundation

/// One line of a worked solution: an explanation, optionally followed by a
/// typeset formula. With `prime` set the formula is drawn as (prime)′ = math.
public struct SolutionStep: Codable, Hashable, Sendable {
    public var text: String
    /// Drawn before the formula, e.g. "u =".
    public var label: String?
    /// Expression being differentiated: drawn as "(prime)′ =" before `math`.
    public var prime: Expr?
    public var math: Expr?
    /// Nesting level (sub-steps of the chain/product/quotient rule are indented).
    public var depth: Int

    public init(_ text: String, label: String? = nil, prime: Expr? = nil, math: Expr? = nil, depth: Int = 0) {
        self.text = text
        self.label = label
        self.prime = prime
        self.math = math
        self.depth = depth
    }
}

// MARK: - Step-by-step differentiation

/// Explains a derivative rule by rule: sum, constant multiple, product,
/// quotient, power and chain rule, with each part worked out underneath.
public enum DerivativeSteps {
    public static func explain(_ f: Expr, resultLabel: String = "f′(x) =") -> [SolutionStep] {
        var steps: [SolutionStep] = []
        let result = walk(f, depth: 0, into: &steps)
        steps.append(SolutionStep("Result:", label: resultLabel, math: result))
        return steps
    }

    /// Appends the steps for d/dx `f` and returns the (simplified) derivative.
    @discardableResult
    static func walk(_ f: Expr, depth: Int, into steps: inout [SolutionStep]) -> Expr {
        let result = f.derivative()
        if !f.containsX {
            if depth == 0 { steps.append(SolutionStep("A constant has derivative 0.", prime: f, math: 0, depth: depth)) }
            return 0
        }

        switch f {
        case .x:
            steps.append(SolutionStep("d/dx x = 1", prime: f, math: 1, depth: depth))

        case .neg(let a):
            steps.append(SolutionStep("Take the minus sign outside.", depth: depth))
            walk(a, depth: depth + 1, into: &steps)
            steps.append(SolutionStep("So:", prime: f, math: result, depth: depth))

        case .add(let a, let b), .sub(let a, let b):
            steps.append(SolutionStep("Sum rule: differentiate each term separately.", depth: depth))
            walk(a, depth: depth + 1, into: &steps)
            walk(b, depth: depth + 1, into: &steps)
            steps.append(SolutionStep("Adding the terms:", prime: f, math: result, depth: depth))

        case .mul(let a, let b) where !a.containsX || !b.containsX:
            let (k, u) = a.containsX ? (b, a) : (a, b)
            steps.append(SolutionStep("Constant multiple: keep the constant, differentiate the rest.", label: "constant =", math: k, depth: depth))
            walk(u, depth: depth + 1, into: &steps)
            steps.append(SolutionStep("Multiply by the constant:", prime: f, math: result, depth: depth))

        case .mul(let u, let v):
            steps.append(SolutionStep("Product rule: (u·v)′ = u′·v + u·v′", depth: depth))
            steps.append(SolutionStep("", label: "u =", math: u, depth: depth + 1))
            steps.append(SolutionStep("", label: "v =", math: v, depth: depth + 1))
            let du = walk(u, depth: depth + 1, into: &steps)
            let dv = walk(v, depth: depth + 1, into: &steps)
            let assembled = Expr.add(.mul(du, v), .mul(u, dv)).simplified()
            steps.append(SolutionStep("Put together u′v + uv′:", prime: f, math: assembled, depth: depth))

        case .div(let u, let v) where !v.containsX:
            steps.append(SolutionStep("Dividing by a constant: differentiate the top, keep the bottom.", depth: depth))
            walk(u, depth: depth + 1, into: &steps)
            steps.append(SolutionStep("So:", prime: f, math: result, depth: depth))

        case .div(let u, let v):
            steps.append(SolutionStep("Quotient rule: (u/v)′ = (u′·v − u·v′) / v²", depth: depth))
            steps.append(SolutionStep("", label: "u =", math: u, depth: depth + 1))
            steps.append(SolutionStep("", label: "v =", math: v, depth: depth + 1))
            let du = walk(u, depth: depth + 1, into: &steps)
            let dv = walk(v, depth: depth + 1, into: &steps)
            let assembled = Expr.div(.sub(.mul(du, v), .mul(u, dv)), .pow(v, 2)).simplified()
            steps.append(SolutionStep("Put together (u′v − uv′)/v²:", prime: f, math: assembled, depth: depth))

        case .pow(let u, let n) where !n.containsX:
            if u == .x {
                steps.append(SolutionStep("Power rule: (xⁿ)′ = n·xⁿ⁻¹", prime: f, math: result, depth: depth))
            } else {
                steps.append(SolutionStep("Chain rule on a power: (uⁿ)′ = n·uⁿ⁻¹·u′", label: "u =", math: u, depth: depth))
                walk(u, depth: depth + 1, into: &steps)
                steps.append(SolutionStep("Multiply n·uⁿ⁻¹ by u′:", prime: f, math: result, depth: depth))
            }

        case .pow(let a, let v) where !a.containsX:
            steps.append(SolutionStep("Exponential: (aᵛ)′ = aᵛ·ln(a)·v′", label: "v =", math: v, depth: depth))
            if v != .x { walk(v, depth: depth + 1, into: &steps) }
            steps.append(SolutionStep("So:", prime: f, math: result, depth: depth))

        case .pow(let u, let v):
            steps.append(SolutionStep("Variable base and exponent: write uᵛ = e^(v·ln u) and use the chain rule.", depth: depth))
            walk(.exp(.mul(v, .ln(u))), depth: depth + 1, into: &steps)
            steps.append(SolutionStep("So:", prime: f, math: result, depth: depth))

        case .fn(let fn, let u):
            let outer = Expr.fn(fn, .x).derivative()
            if u == .x {
                steps.append(SolutionStep("Standard derivative of \(fn.displayName):", prime: f, math: result, depth: depth))
            } else {
                steps.append(SolutionStep("Chain rule: (outer)′ at the inner function, times (inner)′. Outer: \(fn.displayName)(□), its derivative:",
                                          math: outer, depth: depth))
                steps.append(SolutionStep("Inner function:", label: "u =", math: u, depth: depth + 1))
                walk(u, depth: depth + 1, into: &steps)
                steps.append(SolutionStep("Multiply:", prime: f, math: result, depth: depth))
            }

        default:
            steps.append(SolutionStep("", prime: f, math: result, depth: depth))
        }
        return result
    }
}

// MARK: - Explaining a wrong answer

public struct Diagnosis: Sendable {
    /// A point where the answer goes wrong.
    public var x: Double
    /// Integral: d/dx of your answer at x.  Derivative: your answer at x.
    public var yours: Double
    /// Integral: the integrand at x.  Derivative: the true derivative at x.
    public var expected: Double
    /// Integral only: what your answer differentiates to.
    public var yourDerivative: Expr?
    /// Integral only: your answer differentiated step by step.
    public var steps: [SolutionStep]
}

public extension Checker {
    /// Finds a point that shows why an answer is wrong (nil if it's right).
    static func diagnose(_ answer: Expr, for problem: CalculusProblem) -> Diagnosis? {
        let lo = problem.domainLow, hi = problem.domainHigh
        // Prefer simple x values so the numbers are easy to check by hand.
        var candidates: [Double] = [1, 0.5, 2, -1, 1.5, -0.5, 3, -2, 0.25, 2.5, 4]
        candidates += (0..<40).map { lo + (hi - lo) * (Double($0) + 0.5) / 40 }
        let dAnswer = answer.derivative()

        for x in candidates where x > lo && x < hi {
            let yours: Double
            let expected: Double
            switch problem.kind {
            case .integral:
                yours = dAnswer.evaluate(at: x, c: 0)
                expected = problem.display.evaluate(at: x)
            case .derivative:
                yours = answer.evaluate(at: x)
                let r = problem.reference.evaluate(at: x)
                expected = r.isFinite ? r : NumericDerivative.at(x, of: problem.display)
            }
            guard expected.isFinite else { continue }
            if !yours.isFinite || !close(yours, expected) {
                return Diagnosis(
                    x: x, yours: yours, expected: expected,
                    yourDerivative: problem.kind == .integral ? dAnswer : nil,
                    steps: problem.kind == .integral ? DerivativeSteps.explain(answer, resultLabel: "(your answer)′ =") : [])
            }
        }
        return nil
    }
}
