import XCTest
@testable import MathEngine

final class EditorTests: XCTestCase {
    func value(_ editor: MathEditor, at x: Double) throws -> Double {
        try RowParser.parse(editor).evaluate(at: x)
    }

    func testTypingAPolynomial() throws {
        var ed = MathEditor()
        ed.insert(.d3); ed.insert(.x); ed.insertSquare(); ed.insert(.plus); ed.insert(.d2); ed.insert(.x)
        XCTAssertEqual(try value(ed, at: 2), 16, accuracy: 1e-12) // 3·4 + 4
    }

    func testDivideTakesOperandAsNumerator() throws {
        // 1 ÷ 2x → 1/(2x)
        var ed = MathEditor()
        ed.insert(.d1); ed.divide(); ed.insert(.d2); ed.insert(.x)
        XCTAssertEqual(try value(ed, at: 4), 1.0 / 8.0, accuracy: 1e-12)

        // x + 1 ÷ 2 → x + 1/2 (only the last operand moves up)
        var ed2 = MathEditor()
        ed2.insert(.x); ed2.insert(.plus); ed2.insert(.d1); ed2.divide(); ed2.insert(.d2)
        XCTAssertEqual(try value(ed2, at: 3), 3.5, accuracy: 1e-12)
    }

    func testFunctionPowerVersusArgumentPower() throws {
        // sin(x)² : power typed after the function box
        var a = MathEditor()
        a.insertFunction(.sin); a.insert(.x); a.moveRight(); a.insertSquare()
        XCTAssertEqual(try value(a, at: 1), pow(sin(1.0), 2), accuracy: 1e-12)

        // sin(x²) : power typed inside the box
        var b = MathEditor()
        b.insertFunction(.sin); b.insert(.x); b.insertSquare()
        XCTAssertEqual(try value(b, at: 1.3), sin(1.69), accuracy: 1e-12)
    }

    func testExpKeyAndImplicitMultiplication() throws {
        var ed = MathEditor()
        ed.insert(.x); ed.insertFunction(.exp); ed.insert(.d2); ed.insert(.x)   // x·e^(2x)
        ed.moveRight()
        ed.insertFunction(.cos); ed.insert(.x)                                   // · cos(x)
        XCTAssertEqual(try value(ed, at: 0.5), 0.5 * exp(1.0) * cos(0.5), accuracy: 1e-12)
    }

    func testUnaryMinusAndPrecedence() throws {
        var ed = MathEditor()
        ed.insert(.minus); ed.insert(.x); ed.insertSquare()                     // −x² = −(x²)
        XCTAssertEqual(try value(ed, at: 3), -9, accuracy: 1e-12)
    }

    func testParenAndCloseGroup() throws {
        var ed = MathEditor()
        ed.insertParen(); ed.insert(.x); ed.insert(.plus); ed.insert(.d1); ed.closeGroup(); ed.insertSquare()
        XCTAssertEqual(try value(ed, at: 2), 9, accuracy: 1e-12)                  // (x+1)²
    }

    func testBackspaceUnwrapsStructure() throws {
        var ed = MathEditor()
        ed.insertSqrt(); ed.insert(.x)
        ed.moveLeft()          // cursor at start of √ box
        ed.backspace()         // removes √ but keeps x
        XCTAssertEqual(ed.root, Row([.token(.x)]))

        var ed2 = MathEditor()
        ed2.insertFraction()
        ed2.backspace()        // empty fraction disappears
        XCTAssertTrue(ed2.isEmpty)
    }

    func testBackspaceEntersStructureFirst() {
        var ed = MathEditor()
        ed.insertSqrt(); ed.insert(.x); ed.moveRight()  // cursor after √x
        ed.backspace()                                  // steps inside, nothing deleted yet
        XCTAssertEqual(ed.root, Row([.sqrt(Row([.token(.x)]))]))
        ed.backspace()                                  // deletes x
        XCTAssertEqual(ed.root, Row([.sqrt(Row())]))
    }

    func testCursorWalksThroughFraction() {
        var ed = MathEditor()
        ed.insertFraction(); ed.insert(.d1); ed.moveRight(); ed.insert(.d2); ed.moveRight()
        XCTAssertEqual(ed.cursor, Cursor(path: [], index: 1))
        ed.moveLeft()
        XCTAssertEqual(ed.cursor, Cursor(path: [.init(atom: 0, child: 1)], index: 1))
    }

    func testEntryErrors() {
        var ed = MathEditor()
        ed.insert(.x); ed.insert(.plus)
        XCTAssertThrowsError(try RowParser.parse(ed))
        var ed2 = MathEditor()
        ed2.insertFraction(); ed2.insert(.d1)
        XCTAssertThrowsError(try RowParser.parse(ed2)) // empty denominator
        XCTAssertThrowsError(try RowParser.parse(MathEditor()))
    }

    func testDisplayRoundTrip() throws {
        let x = Expr.x
        let samples: [Expr] = [
            .div(.sin(.ln(.add(.p(x, 2), 1))), .add(.p(x, 2), .exp(x))),
            .mul(.p(.sin(x), 2), .cos(.mul(2, x))),
            .sub(.mul(.q(3, 4), .p(x, 4)), .neg(.mul(5, x))),
            .mul(.sub(x, 1), .exp(x)),
            .neg(.div(3, .add(x, 2))),
            .mul(x, .mul(3, .sin(x))),
            .sqrt(.add(.p(x, 2), 4)),
            .atan(.div(x, 2)),
        ]
        for e in samples {
            let back = try RowParser.parse(ExprDisplay.row(e))
            for t in [0.3, 0.9, 1.7] {
                XCTAssertEqual(back.evaluate(at: t), e.evaluate(at: t), accuracy: 1e-12, "\(e)")
            }
        }
    }

    func testEditorIsCodable() throws {
        var ed = MathEditor()
        ed.insertFraction(); ed.insert(.x); ed.moveRight(); ed.insertFunction(.ln); ed.insert(.x)
        let data = try JSONEncoder().encode(ed)
        let back = try JSONDecoder().decode(MathEditor.self, from: data)
        XCTAssertEqual(back, ed)
    }
}
