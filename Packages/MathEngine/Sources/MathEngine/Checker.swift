import Foundation

public enum CheckResult: Equatable, Sendable {
    case correct
    case incorrect
    /// The answer isn't defined on (most of) the interval being checked.
    case undefined
}

/// Decides whether an answer is correct by comparing values at many points,
/// so any equivalent form — simplified or not, with or without "+ C" — passes.
///
/// Domain rule (shown to the user in the app): answers are checked at random
/// points of the problem's interval where the problem itself is defined. On
/// that interval ln(u) and ln|u| give the same values, so both are accepted.
public enum Checker {
    public static let defaultPoints = 40
    public static let tolerance = 1e-6

    public static func close(_ a: Double, _ b: Double, tolerance: Double = Checker.tolerance) -> Bool {
        Swift.abs(a - b) <= tolerance * Swift.max(1, Swift.abs(b))
    }

    public static func check(_ answer: Expr, for problem: CalculusProblem, points: Int = defaultPoints) -> CheckResult {
        var rng = SeededRandom(seed: 0xA11CE ^ problem.seed)
        let lo = problem.domainLow, hi = problem.domainHigh
        let margin = (hi - lo) * 0.01

        var compared = 0
        var undefinedCount = 0
        var attempts = 0

        switch problem.kind {
        case .integral:
            // Your antiderivative F must satisfy F'(x) = f(x).
            let f = problem.display
            let dAnswer = answer.derivative()
            while compared < points && attempts < points * 4 {
                attempts += 1
                let x = rng.double((lo + margin)...(hi - margin))
                let fx = f.evaluate(at: x)
                guard fx.isFinite else { continue }
                // C is a constant, so its value doesn't matter; use a non-zero one
                // to make sure it really cancels.
                let sym = dAnswer.evaluate(at: x, c: 1.7)
                let num = NumericDerivative.at(x, c: 1.7, of: answer)
                if !sym.isFinite && !num.isFinite {
                    undefinedCount += 1
                    continue
                }
                compared += 1
                let ok = (sym.isFinite && close(sym, fx)) || (num.isFinite && close(num, fx, tolerance: 1e-5))
                if !ok { return .incorrect }
            }

        case .derivative:
            // Your answer must equal f'(x). Compared against the symbolic
            // derivative AND a numerical one, so a bug in either can't reject
            // a correct answer.
            let f = problem.display
            let ref = problem.reference
            while compared < points && attempts < points * 4 {
                attempts += 1
                let x = rng.double((lo + margin)...(hi - margin))
                let r = ref.evaluate(at: x)
                let n = NumericDerivative.at(x, of: f)
                guard r.isFinite || n.isFinite else { continue }
                let a = answer.evaluate(at: x, c: 0)
                if !a.isFinite {
                    undefinedCount += 1
                    continue
                }
                compared += 1
                let ok = (r.isFinite && close(a, r)) || (n.isFinite && close(a, n, tolerance: 1e-5))
                if !ok { return .incorrect }
            }
        }

        if compared == 0 || undefinedCount * 4 > compared + undefinedCount {
            return .undefined
        }
        return .correct
    }
}
