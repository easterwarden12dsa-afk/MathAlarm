import Foundation

public enum ProblemKind: String, Codable, CaseIterable, Sendable {
    case integral, derivative
}

public enum Level: String, Codable, CaseIterable, Sendable {
    case easy, medium, hard
    /// The hardest questions of the Israeli Bagrut, 5 units — using only
    /// that syllabus: polynomials, roots, eˣ, ln, sin/cos/tan; chain,
    /// product and quotient rules; integrals by linear inner functions,
    /// f′/f, f′·fⁿ and f′·e^f. No integration by parts or partial fractions.
    case bagrut
}

/// One calculus challenge.
/// - Integral: `display` is the integrand f, `reference` an antiderivative F.
/// - Derivative: `display` is f, `reference` is f'.
/// Answers are checked at points in `domainLow...domainHigh`.
public struct CalculusProblem: Codable, Hashable, Sendable {
    public var kind: ProblemKind
    public var level: Level
    public var display: Expr
    public var reference: Expr
    public var domainLow: Double
    public var domainHigh: Double
    /// Short description of the technique, e.g. "Integration by parts".
    public var technique: String
    public var seed: UInt64
    /// Worked solution for integrals (derivatives are explained on demand).
    public var steps: [SolutionStep]

    public init(kind: ProblemKind, level: Level, display: Expr, reference: Expr,
                domainLow: Double, domainHigh: Double, technique: String, seed: UInt64,
                steps: [SolutionStep] = []) {
        self.kind = kind
        self.level = level
        self.display = display
        self.reference = reference
        self.domainLow = domainLow
        self.domainHigh = domainHigh
        self.technique = technique
        self.seed = seed
        self.steps = steps
    }

    enum CodingKeys: String, CodingKey {
        case kind, level, display, reference, domainLow, domainHigh, technique, seed, steps
    }

    // Tolerant decoding so problems saved by older versions still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(ProblemKind.self, forKey: .kind)
        level = (try? c.decode(Level.self, forKey: .level)) ?? .medium
        display = try c.decode(Expr.self, forKey: .display)
        reference = try c.decode(Expr.self, forKey: .reference)
        domainLow = try c.decode(Double.self, forKey: .domainLow)
        domainHigh = try c.decode(Double.self, forKey: .domainHigh)
        technique = (try? c.decode(String.self, forKey: .technique)) ?? ""
        seed = (try? c.decode(UInt64.self, forKey: .seed)) ?? 1
        steps = (try? c.decode([SolutionStep].self, forKey: .steps)) ?? []
    }

    /// The full worked solution.
    public var solutionSteps: [SolutionStep] {
        switch kind {
        case .derivative:
            return DerivativeSteps.explain(display)
        case .integral:
            var all = steps
            all.append(SolutionStep("Result (any constant C can be added):", label: "∫ f dx =", math: reference))
            all.append(SolutionStep("Check: differentiating the result gives back the integrand.", prime: reference, math: display))
            return all
        }
    }

    /// Identifies the problem's content, used to avoid repeats.
    public var signature: String { "\(kind.rawValue):\(display.description)" }

    public var domain: ClosedRange<Double> { domainLow...domainHigh }

    /// True when answers are only checked on part of the real line, so the
    /// interval should be shown next to the problem.
    public var hasRestrictedDomain: Bool { domainLow > -1.99 || domainHigh < 1.99 }
}

public enum ProblemFactory {
    /// Builds a problem from a seed. Each candidate is verified numerically
    /// and rejected if anything about it is off, so this always returns a
    /// problem whose reference answer is correct.
    /// Like `make`, but tries further seeds until the problem isn't one of
    /// `avoiding` (signatures of recently shown problems).
    public static func make(_ kind: ProblemKind, level: Level, seed: UInt64, avoiding: Set<String>) -> CalculusProblem {
        var s = seed
        var problem = make(kind, level: level, seed: s)
        var tries = 0
        while avoiding.contains(problem.signature) && tries < 60 {
            tries += 1
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            problem = make(kind, level: level, seed: s)
        }
        return problem
    }

    public static func make(_ kind: ProblemKind, level: Level, seed: UInt64) -> CalculusProblem {
        var rng = SeededRandom(seed: seed)
        for _ in 0..<500 {
            let candidate: CalculusProblem?
            switch kind {
            case .integral: candidate = IntegralGenerator.candidate(level: level, rng: &rng, seed: seed)
            case .derivative: candidate = DerivativeGenerator.candidate(level: level, rng: &rng, seed: seed)
            }
            if let candidate, Validator.isValid(candidate) {
                return candidate
            }
        }
        // Unreachable in practice; a guaranteed-valid fallback just in case.
        return kind == .integral
            ? CalculusProblem(kind: .integral, level: level, display: .mul(.x, .exp(.x)),
                              reference: .mul(.sub(.x, 1), .exp(.x)), domainLow: -2, domainHigh: 2,
                              technique: "Integration by parts", seed: seed)
            : CalculusProblem(kind: .derivative, level: level, display: .sin(.p(.x, 2)),
                              reference: .mul(.mul(2, .x), .cos(.p(.x, 2))), domainLow: -2, domainHigh: 2,
                              technique: "Chain rule", seed: seed)
    }

    public static func randomSeed() -> UInt64 {
        UInt64.random(in: 1...UInt64.max)
    }
}

/// Checks a generated problem before it is ever shown.
enum Validator {
    static let samplePoints = 60

    static func isValid(_ p: CalculusProblem) -> Bool {
        guard p.domainHigh > p.domainLow else { return false }
        let xs = samplePoints(in: p.domain, count: samplePoints)

        switch p.kind {
        case .integral:
            // d/dx(F) must equal f, both symbolically and numerically.
            let f = p.display
            let F = p.reference
            let dF = F.derivative()
            var maxAbs = 0.0
            for x in xs {
                let fx = f.evaluate(at: x)
                let sym = dF.evaluate(at: x)
                let num = NumericDerivative.at(x, of: F)
                guard fx.isFinite, sym.isFinite, num.isFinite, F.evaluate(at: x).isFinite else { return false }
                guard Checker.close(sym, fx, tolerance: 1e-9), Checker.close(num, fx, tolerance: 1e-5) else { return false }
                maxAbs = Swift.max(maxAbs, Swift.abs(fx))
            }
            return maxAbs < 1e4 && maxAbs > 1e-3

        case .derivative:
            // Reference f' must match a numerical derivative of f everywhere.
            let f = p.display
            let df = p.reference
            var maxAbs = 0.0
            var differsFromF = false
            for x in xs {
                let fx = f.evaluate(at: x)
                let d = df.evaluate(at: x)
                if Swift.abs(d - fx) > 1e-3 { differsFromF = true }
                let num = NumericDerivative.at(x, of: f)
                guard fx.isFinite, d.isFinite, num.isFinite else { return false }
                guard Checker.close(d, num, tolerance: 1e-5) else { return false }
                maxAbs = Swift.max(maxAbs, Swift.abs(d))
            }
            // Reject trivial ones like eˣ whose derivative is itself.
            return differsFromF && maxAbs < 2e3 && maxAbs > 1e-2
        }
    }

    static func samplePoints(in domain: ClosedRange<Double>, count: Int) -> [Double] {
        let lo = domain.lowerBound, hi = domain.upperBound
        return (0..<count).map { i in lo + (hi - lo) * (Double(i) + 0.5) / Double(count) }
    }
}
