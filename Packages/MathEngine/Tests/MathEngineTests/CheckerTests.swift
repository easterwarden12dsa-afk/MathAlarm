import XCTest
@testable import MathEngine

final class CheckerTests: XCTestCase {
    let x = Expr.x

    func integral(_ f: Expr, _ F: Expr, _ lo: Double = -2, _ hi: Double = 2) -> CalculusProblem {
        CalculusProblem(kind: .integral, level: .medium, display: f, reference: F,
                        domainLow: lo, domainHigh: hi, technique: "", seed: 42)
    }

    func derivative(_ f: Expr, _ lo: Double = -2, _ hi: Double = 2) -> CalculusProblem {
        CalculusProblem(kind: .derivative, level: .medium, display: f, reference: f.derivative(),
                        domainLow: lo, domainHigh: hi, technique: "", seed: 42)
    }

    // ∫ x eˣ dx

    func testIntegralOfXeX() {
        let p = integral(.mul(x, .exp(x)), .mul(.sub(x, 1), .exp(x)))
        XCTAssertEqual(Checker.check(.mul(.sub(x, 1), .exp(x)), for: p), .correct)                       // (x−1)eˣ
        XCTAssertEqual(Checker.check(.add(.sub(.mul(x, .exp(x)), .exp(x)), 7), for: p), .correct)        // x eˣ − eˣ + 7
        XCTAssertEqual(Checker.check(.add(.mul(.sub(x, 1), .exp(x)), .constC), for: p), .correct)        // + C
        XCTAssertEqual(Checker.check(.mul(.sub(x, 1), .pow(.e, x)), for: p), .correct)                   // e as a power
        XCTAssertEqual(Checker.check(.mul(x, .exp(x)), for: p), .incorrect)                              // x eˣ
        XCTAssertEqual(Checker.check(.mul(.add(x, 1), .exp(x)), for: p), .incorrect)                     // sign error
        XCTAssertEqual(Checker.check(.mul(.mul(2, .sub(x, 1)), .exp(x)), for: p), .incorrect)            // extra factor
        XCTAssertEqual(Checker.check(.constC, for: p), .incorrect)
    }

    func testIntegralLnRule() {
        // ∫ 1/x dx on x > 0: ln x and ln|x| both accepted.
        let p = integral(.div(1, x), .ln(x), 0.5, 4)
        XCTAssertEqual(Checker.check(.ln(x), for: p), .correct)
        XCTAssertEqual(Checker.check(.ln(.abs(x)), for: p), .correct)
        XCTAssertEqual(Checker.check(.add(.ln(.mul(3, x)), .constC), for: p), .correct) // ln(3x) differs by a constant
        XCTAssertEqual(Checker.check(.ln(.p(x, 2)), for: p), .incorrect)                 // 2 ln x
        // Partial-fractions style answer on x > 3.
        let pf = integral(.div(1, .mul(.sub(x, 1), .sub(x, 3))),
                          .mul(.q(1, 2), .sub(.ln(.sub(x, 3)), .ln(.sub(x, 1)))), 3.5, 7)
        XCTAssertEqual(Checker.check(.mul(.q(1, 2), .ln(.div(.abs(.sub(x, 3)), .abs(.sub(x, 1))))), for: pf), .correct)
    }

    func testIntegralUndefinedAnswer() {
        // √(x − 5) isn't defined on [−2, 2].
        let p = integral(.mul(2, x), .p(x, 2))
        XCTAssertEqual(Checker.check(.sqrt(.sub(x, 5)), for: p), .undefined)
    }

    // d/dx sin(x²)

    func testDerivativeOfSinX2() {
        let p = derivative(.sin(.p(x, 2)))
        XCTAssertEqual(Checker.check(.mul(.mul(2, x), .cos(.p(x, 2))), for: p), .correct)               // 2x cos(x²)
        XCTAssertEqual(Checker.check(.add(.mul(x, .cos(.p(x, 2))), .mul(x, .cos(.p(x, 2)))), for: p), .correct) // unsimplified
        XCTAssertEqual(Checker.check(.cos(.p(x, 2)), for: p), .incorrect)                               // missing inner derivative
        XCTAssertEqual(Checker.check(.neg(.mul(.mul(2, x), .cos(.p(x, 2)))), for: p), .incorrect)       // sign error
        XCTAssertEqual(Checker.check(.mul(x, .cos(.p(x, 2))), for: p), .incorrect)                      // missing factor 2
        XCTAssertEqual(Checker.check(.mul(.mul(2, x), .cos(.p(x, 3))), for: p), .incorrect)             // wrong power
    }

    func testDerivativeQuotientExample() {
        let f = Expr.div(.sin(.ln(.add(.p(x, 2), 1))), .add(.p(x, 2), .exp(x)))
        let p = derivative(f)
        // Textbook quotient-rule form, typed out by hand.
        let u = Expr.sin(.ln(.add(.p(x, 2), 1)))
        let du = Expr.mul(.cos(.ln(.add(.p(x, 2), 1))), .div(.mul(2, x), .add(.p(x, 2), 1)))
        let v = Expr.add(.p(x, 2), .exp(x))
        let dv = Expr.add(.mul(2, x), .exp(x))
        let answer = Expr.div(.sub(.mul(du, v), .mul(u, dv)), .p(v, 2))
        XCTAssertEqual(Checker.check(answer, for: p), .correct)
        // Classic mistake: u'v + uv' on top.
        let wrong = Expr.div(.add(.mul(du, v), .mul(u, dv)), .p(v, 2))
        XCTAssertEqual(Checker.check(wrong, for: p), .incorrect)
    }

    /// Even if the generator's symbolic derivative were wrong, a correct
    /// answer must still pass because of the numerical cross-check.
    func testBrokenReferenceCannotRejectCorrectAnswer() {
        var p = derivative(.sin(.p(x, 2)))
        p.reference = .cos(.p(x, 2)) // deliberately wrong reference
        XCTAssertEqual(Checker.check(.mul(.mul(2, x), .cos(.p(x, 2))), for: p), .correct)
    }
}
