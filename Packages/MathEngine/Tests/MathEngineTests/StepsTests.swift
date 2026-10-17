import XCTest
@testable import MathEngine

final class StepsTests: XCTestCase {
    let x = Expr.x

    func testDerivativeStepsEndWithTheRightAnswer() {
        let f = Expr.div(.sin(.ln(.add(.p(x, 2), 1))), .add(.p(x, 2), .exp(x)))
        let steps = DerivativeSteps.explain(f)
        XCTAssertTrue(steps.contains { $0.text.contains("Quotient rule") })
        XCTAssertTrue(steps.contains { $0.text.contains("Chain rule") })
        guard let last = steps.last?.math else { return XCTFail("no result") }
        for t in [-1.0, 0.3, 1.4] {
            XCTAssertEqual(last.evaluate(at: t), NumericDerivative.at(t, of: f), accuracy: 1e-6)
        }
    }

    /// Every intermediate "(…)′ = …" line in a worked derivative must be true.
    func testEveryDerivativeStepIsCorrect() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(40) {
                let p = ProblemFactory.make(.derivative, level: level, seed: seed &* 31_337)
                for step in p.solutionSteps {
                    guard let lhs = step.prime, let rhs = step.math else { continue }
                    for t in Validator.samplePoints(in: p.domain, count: 7) {
                        let want = NumericDerivative.at(t, of: lhs)
                        let got = rhs.evaluate(at: t)
                        guard want.isFinite, got.isFinite else { continue }
                        XCTAssertTrue(Checker.close(got, want, tolerance: 1e-5), "step \(step.text): (\(lhs))' ≠ \(rhs)")
                    }
                }
            }
        }
    }

    func testIntegralProblemsHaveSteps() {
        for level in Level.allCases {
            for seed in UInt64(1)...UInt64(40) {
                let p = ProblemFactory.make(.integral, level: level, seed: seed &* 7_777)
                XCTAssertFalse(p.steps.isEmpty, "no steps for \(p.display)")
                XCTAssertNotNil(p.solutionSteps.last?.math)
            }
        }
    }

    func testDiagnosisFindsAPoint() {
        let p = CalculusProblem(kind: .integral, level: .medium, display: .mul(x, .exp(x)),
                                reference: .mul(.sub(x, 1), .exp(x)), domainLow: -2, domainHigh: 2,
                                technique: "", seed: 1)
        let d = Checker.diagnose(.mul(x, .exp(x)), for: p)
        XCTAssertNotNil(d)
        XCTAssertNotNil(d?.yourDerivative)
        XCTAssertFalse(d?.steps.isEmpty ?? true)
        XCTAssertNil(Checker.diagnose(.mul(.sub(x, 1), .exp(x)), for: p))
    }

    func testNoRepeats() {
        var seen = Set<String>()
        for i in UInt64(1)...UInt64(30) {
            let p = ProblemFactory.make(.integral, level: .medium, seed: i &* 99_991, avoiding: seen)
            XCTAssertFalse(seen.contains(p.signature), "repeated \(p.signature)")
            seen.insert(p.signature)
        }
    }

    func testOldSavedProblemStillDecodes() throws {
        let json = #"{"kind":"integral","level":"easy","display":{"x":{}},"reference":{"x":{}},"domainLow":-2,"domainHigh":2,"technique":"t","seed":3}"#
        _ = try JSONDecoder().decode(CalculusProblem.self, from: Data(json.utf8))
    }
}
