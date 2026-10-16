import XCTest
@testable import MathEngine

final class DifferentiatorTests: XCTestCase {
    let x = Expr.x

    /// Symbolic derivative must match a numerical derivative everywhere it's defined.
    func assertDerivativeMatchesNumeric(_ f: Expr, in range: ClosedRange<Double> = -2...2,
                                        file: StaticString = #filePath, line: UInt = #line) {
        let df = f.derivative()
        var compared = 0
        for i in 0..<41 {
            let t = range.lowerBound + (range.upperBound - range.lowerBound) * (Double(i) + 0.37) / 41.4
            let sym = df.evaluate(at: t)
            let num = NumericDerivative.at(t, of: f)
            guard sym.isFinite, num.isFinite, f.evaluate(at: t).isFinite else { continue }
            compared += 1
            XCTAssertTrue(Checker.close(sym, num, tolerance: 1e-5),
                          "d/dx \(f) at \(t): symbolic \(sym) vs numeric \(num)", file: file, line: line)
        }
        XCTAssertGreaterThan(compared, 20, "too few comparable points for \(f)", file: file, line: line)
    }

    func testEveryFunction() {
        for f in Fn.allCases {
            let range: ClosedRange<Double>
            switch f {
            case .asin, .acos: range = -0.9...0.9
            case .ln, .log, .sqrt: range = 0.2...3
            case .tan, .sec: range = -1.2...1.2
            case .csc, .cot: range = 0.3...2.8
            default: range = -2...2
            }
            assertDerivativeMatchesNumeric(.fn(f, x), in: range)
            assertDerivativeMatchesNumeric(.fn(f, .mul(0.5, x)), in: range)
        }
    }

    func testRules() {
        assertDerivativeMatchesNumeric(.mul(.p(x, 3), .sin(x)))                         // product
        assertDerivativeMatchesNumeric(.div(.sin(x), .add(.p(x, 2), 1)))                // quotient
        assertDerivativeMatchesNumeric(.div(3, .add(.p(x, 2), 1)))                      // constant / u
        assertDerivativeMatchesNumeric(.sin(.ln(.add(.p(x, 2), 1))))                    // nested chain
        assertDerivativeMatchesNumeric(.div(.sin(.ln(.add(.p(x, 2), 1))), .add(.p(x, 2), .exp(x)))) // the brief's example
        assertDerivativeMatchesNumeric(.pow(2, x))                                      // a^x
        assertDerivativeMatchesNumeric(.pow(.e, .p(x, 2)))                              // e^(x²) as a power
        assertDerivativeMatchesNumeric(.pow(x, x), in: 0.2...3)                         // x^x
        assertDerivativeMatchesNumeric(.pow(x, .q(3, 2)), in: 0.1...3)                  // fractional power
        assertDerivativeMatchesNumeric(.sqrt(.add(.p(x, 2), 4)))
        assertDerivativeMatchesNumeric(.abs(.sub(.p(x, 3), 2)))
        assertDerivativeMatchesNumeric(.neg(.cos(.mul(3, x))))
        assertDerivativeMatchesNumeric(.sub(.exp(.sin(x)), .mul(.constC, 0)))
    }

    func testSimplifyKeepsValue() {
        let samples: [Expr] = [
            .mul(.mul(2, .mul(3, x)), 1),
            .add(.add(0, x), .neg(.neg(x))),
            .sub(0, .mul(.num(-1), x)),
            .div(.neg(x), 1),
            .pow(.add(x, 0), 1),
        ]
        for e in samples {
            for t in stride(from: -2.0, through: 2.0, by: 0.5) {
                XCTAssertEqual(e.evaluate(at: t), e.simplified().evaluate(at: t), accuracy: 1e-12)
            }
        }
        XCTAssertEqual(Expr.mul(2, .mul(3, x)).simplified(), .mul(6, x))
    }
}
