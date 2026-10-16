import Foundation

public struct EntryError: Error, Equatable, Sendable {
    public var message: String
}

/// Turns an editor row into an expression tree. Fractions, powers, roots,
/// brackets and function arguments are already explicit boxes, so the only
/// rules left are ordinary precedence (powers, then × and juxtaposition,
/// then + and −).
public enum RowParser {
    public static func parse(_ row: Row) throws -> Expr {
        var parser = Parser(atoms: row.atoms)
        return try parser.parseWhole()
    }

    public static func parse(_ editor: MathEditor) throws -> Expr {
        try parse(editor.root)
    }

    private struct Parser {
        let atoms: [Atom]
        var pos = 0

        mutating func parseWhole() throws -> Expr {
            guard !atoms.isEmpty else { throw EntryError(message: "There's an empty box.") }
            let e = try parseSum()
            guard pos == atoms.count else { throw EntryError(message: "Something doesn't fit together.") }
            return e
        }

        var peek: Atom? { pos < atoms.count ? atoms[pos] : nil }

        mutating func parseSum() throws -> Expr {
            var lhs = try parseProduct()
            while case .token(let t)? = peek, t == .plus || t == .minus {
                pos += 1
                guard peek != nil else { throw EntryError(message: "Something is missing after \(t.rawValue).") }
                let rhs = try parseProduct()
                lhs = t == .plus ? .add(lhs, rhs) : .sub(lhs, rhs)
            }
            return lhs
        }

        mutating func parseProduct() throws -> Expr {
            var lhs = try parseUnary()
            while let next = peek {
                if case .token(.times) = next {
                    pos += 1
                    guard peek != nil else { throw EntryError(message: "Something is missing after ×.") }
                    lhs = .mul(lhs, try parseUnary())
                } else if startsOperand(next) {
                    // Juxtaposition: 2x, x·sin(x), (x+1)(x−1)
                    lhs = .mul(lhs, try parsePostfix())
                } else {
                    break
                }
            }
            return lhs
        }

        mutating func parseUnary() throws -> Expr {
            if case .token(let t)? = peek, t == .minus || t == .plus {
                pos += 1
                guard peek != nil else { throw EntryError(message: "Something is missing after \(t.rawValue).") }
                let operand = try parseUnary()
                return t == .minus ? .neg(operand) : operand
            }
            return try parsePostfix()
        }

        mutating func parsePostfix() throws -> Expr {
            var base = try parsePrimary()
            while case .power(let exponent)? = peek {
                pos += 1
                let ex = try RowParser.parse(exponent)
                base = (base == .e) ? .fn(.exp, ex) : .pow(base, ex)
            }
            return base
        }

        func startsOperand(_ atom: Atom) -> Bool {
            switch atom {
            case .token(let t): return !t.isOperator
            case .power: return false
            default: return true
            }
        }

        mutating func parsePrimary() throws -> Expr {
            guard let atom = peek else { throw EntryError(message: "Something is missing at the end.") }
            switch atom {
            case .token(let t):
                if t.isDigit { return try parseNumber() }
                pos += 1
                switch t {
                case .x: return .x
                case .pi: return .pi
                case .e: return .e
                case .c: return .constC
                default: throw EntryError(message: "\(t.rawValue) needs something before it.")
                }
            case .function(let f, let arg):
                pos += 1
                return .fn(f, try RowParser.parse(arg))
            case .fraction(let n, let d):
                pos += 1
                return .div(try RowParser.parse(n), try RowParser.parse(d))
            case .sqrt(let r):
                pos += 1
                return .fn(.sqrt, try RowParser.parse(r))
            case .abs(let r):
                pos += 1
                return .fn(.abs, try RowParser.parse(r))
            case .paren(let r):
                pos += 1
                return try RowParser.parse(r)
            case .power:
                throw EntryError(message: "A power needs something before it.")
            }
        }

        mutating func parseNumber() throws -> Expr {
            var text = ""
            while case .token(let t)? = peek, t.isDigit {
                text += t.rawValue
                pos += 1
            }
            guard text.filter({ $0 == "." }).count <= 1, text != ".", let v = Double(text) else {
                throw EntryError(message: "\(text) isn't a number.")
            }
            return .num(v)
        }
    }
}
