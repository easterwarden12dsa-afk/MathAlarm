import XCTest
@testable import MathEngine

final class GeneratorTests: XCTestCase {
    func testEveryGeneratedProblemIsSolvableAndRejectsNearMisses() {
        for kind in ProblemKind.allCases {
            for level in Level.allCases {
                var techniques = Set<String>()
                for seed in UInt64(1)...UInt64(150) {
                    let p = ProblemFactory.make(kind, level: level, seed: seed &* 2_654_435_761)
                    techniques.insert(p.technique)
                    XCTAssertTrue(Validator.isValid(p), "invalid \(kind) \(level) seed \(seed): \(p.display)")

                    // The reference answer passes.
                    XCTAssertEqual(Checker.check(p.reference, for: p), .correct,
                                   "reference rejected: \(kind) \(level) \(p.display) → \(p.reference)")

                    // What the user actually sees (display → parse) is the same function.
                    let shown = try? RowParser.parse(ExprDisplay.row(p.display))
                    XCTAssertNotNil(shown, "display didn't parse back: \(p.display)")
                    if let shown {
                        for t in Validator.samplePoints(in: p.domain, count: 15) {
                            XCTAssertTrue(Checker.close(shown.evaluate(at: t), p.display.evaluate(at: t), tolerance: 1e-9),
                                          "display mismatch for \(p.display) at \(t)")
                        }
                    }

                    // Near misses fail.
                    switch kind {
                    case .integral:
                        XCTAssertNotEqual(Checker.check(.mul(2, p.reference), for: p), .correct)
                        XCTAssertNotEqual(Checker.check(.add(p.reference, .x), for: p), .correct)
                        XCTAssertNotEqual(Checker.check(.neg(p.reference), for: p), .correct)
                    case .derivative:
                        XCTAssertNotEqual(Checker.check(.mul(2, p.reference), for: p), .correct)
                        XCTAssertNotEqual(Checker.check(.add(p.reference, 1), for: p), .correct)
                        XCTAssertNotEqual(Checker.check(p.display, for: p), .correct)
                    }
                }
                XCTAssertGreaterThan(techniques.count, 1, "\(kind) \(level) has no variety")
            }
        }
    }

    func testSameSeedSameProblem() {
        for kind in ProblemKind.allCases {
            let a = ProblemFactory.make(kind, level: .hard, seed: 987_654_321)
            let b = ProblemFactory.make(kind, level: .hard, seed: 987_654_321)
            XCTAssertEqual(a, b)
        }
    }

    func testHardDerivativesAreLayered() {
        // Hard problems should be bigger than easy ones on average.
        func averageSize(_ level: Level) -> Double {
            let sizes = (1...60).map { ProblemFactory.make(.derivative, level: level, seed: UInt64($0) * 7919).display.size }
            return Double(sizes.reduce(0, +)) / Double(sizes.count)
        }
        XCTAssertGreaterThan(averageSize(.hard), averageSize(.easy))
    }
}

final class SampleOutputTests: XCTestCase {
    /// Prints a few problems per kind and level so the CI log can be eyeballed.
    func testPrintSamples() {
        for kind in ProblemKind.allCases {
            for level in Level.allCases {
                for seed in UInt64(1)...UInt64(4) {
                    let p = ProblemFactory.make(kind, level: level, seed: seed * 104_729)
                    print("SAMPLE \(kind) \(level) [\(p.technique)] f = \(p.display)   ref = \(p.reference)")
                }
            }
        }
    }
}
