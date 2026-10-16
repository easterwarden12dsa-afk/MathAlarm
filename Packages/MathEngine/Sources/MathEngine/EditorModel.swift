import Foundation

/// Single-character keys of the math keypad.
public enum Token: String, Codable, Hashable, Sendable {
    case d0 = "0", d1 = "1", d2 = "2", d3 = "3", d4 = "4"
    case d5 = "5", d6 = "6", d7 = "7", d8 = "8", d9 = "9"
    case dot = "."
    case x = "x"
    case pi = "π"
    case e = "e"
    case c = "C"
    case plus = "+"
    case minus = "−"
    case times = "×"

    public var isDigit: Bool { ("0"..."9").contains(rawValue) || self == .dot }
    public var isOperator: Bool { self == .plus || self == .minus || self == .times }

    public static func digit(_ n: Int) -> Token { Token(rawValue: String(n)) ?? .d0 }
}

/// One item in a row of the structured editor. Structures own child rows
/// ("boxes"), so a fraction's numerator and denominator are explicit and
/// nothing has to be guessed from a flat string.
public indirect enum Atom: Codable, Hashable, Sendable {
    case token(Token)
    case function(Fn, Row)    // sin(…), ln(…) — the argument box
    case fraction(Row, Row)   // numerator, denominator
    case power(Row)           // superscript applying to what's before it
    case sqrt(Row)
    case abs(Row)
    case paren(Row)

    public var children: [Row] {
        switch self {
        case .token: []
        case .function(_, let r), .power(let r), .sqrt(let r), .abs(let r), .paren(let r): [r]
        case .fraction(let n, let d): [n, d]
        }
    }

    func replacingChild(_ index: Int, with row: Row) -> Atom {
        switch self {
        case .token: self
        case .function(let f, _): .function(f, row)
        case .power: .power(row)
        case .sqrt: .sqrt(row)
        case .abs: .abs(row)
        case .paren: .paren(row)
        case .fraction(let n, let d): index == 0 ? .fraction(row, d) : .fraction(n, row)
        }
    }

    public var isEmptyStructure: Bool {
        !children.isEmpty && children.allSatisfy { $0.atoms.isEmpty }
    }
}

public struct Row: Codable, Hashable, Sendable {
    public var atoms: [Atom]
    public init(_ atoms: [Atom] = []) { self.atoms = atoms }
    public var isEmpty: Bool { atoms.isEmpty }
}

/// Where the cursor is: a path of (atom, child) steps from the root row
/// down to the row being edited, plus a position inside that row.
public struct Cursor: Codable, Hashable, Sendable {
    public struct Step: Codable, Hashable, Sendable {
        public var atom: Int
        public var child: Int
        public init(atom: Int, child: Int) {
            self.atom = atom
            self.child = child
        }
    }
    public var path: [Step] = []
    public var index: Int = 0

    public init(path: [Step] = [], index: Int = 0) {
        self.path = path
        self.index = index
    }
}

/// The structured math editor: an expression tree being built key by key.
public struct MathEditor: Codable, Hashable, Sendable {
    public private(set) var root = Row()
    public private(set) var cursor = Cursor()

    public init() {}

    public var isEmpty: Bool { root.isEmpty }

    // MARK: Row access

    func row(at path: [Cursor.Step]) -> Row {
        var row = root
        for step in path {
            row = row.atoms[step.atom].children[step.child]
        }
        return row
    }

    private mutating func setRow(_ newRow: Row, at path: [Cursor.Step]) {
        root = Self.replacing(in: root, path: path[...], with: newRow)
    }

    private static func replacing(in row: Row, path: ArraySlice<Cursor.Step>, with newRow: Row) -> Row {
        guard let step = path.first else { return newRow }
        var row = row
        let atom = row.atoms[step.atom]
        let child = replacing(in: atom.children[step.child], path: path.dropFirst(), with: newRow)
        row.atoms[step.atom] = atom.replacingChild(step.child, with: child)
        return row
    }

    private var currentRow: Row { row(at: cursor.path) }

    // MARK: Typing

    public mutating func insert(_ token: Token) {
        insertAtom(.token(token))
    }

    /// Inserts a structure and puts the cursor in its first box.
    public mutating func insertFunction(_ f: Fn) {
        switch f {
        case .sqrt: insertStructure(.sqrt(Row()))
        case .abs: insertStructure(.abs(Row()))
        case .exp:
            insertAtom(.token(.e))
            insertStructure(.power(Row()))
        default: insertStructure(.function(f, Row()))
        }
    }

    public mutating func insertParen() { insertStructure(.paren(Row())) }
    public mutating func insertSqrt() { insertStructure(.sqrt(Row())) }
    public mutating func insertAbs() { insertStructure(.abs(Row())) }
    public mutating func insertPower() { insertStructure(.power(Row())) }

    /// The x² key: a superscript 2, cursor stays after it.
    public mutating func insertSquare() {
        insertAtom(.power(Row([.token(.d2)])))
    }

    /// Empty fraction, cursor in the numerator.
    public mutating func insertFraction() { insertStructure(.fraction(Row(), Row())) }

    /// The ÷ key: the operand just before the cursor (back to the previous
    /// +, − or ×) becomes the numerator and the cursor moves to the
    /// denominator. So typing 1 ÷ 2x gives 1/(2x), shown as a stacked fraction.
    public mutating func divide() {
        var row = currentRow
        var start = cursor.index
        while start > 0 {
            if case .token(let t) = row.atoms[start - 1], t.isOperator { break }
            start -= 1
        }
        let numerator = Array(row.atoms[start..<cursor.index])
        guard !numerator.isEmpty else {
            insertFraction()
            return
        }
        row.atoms.replaceSubrange(start..<cursor.index, with: [.fraction(Row(numerator), Row())])
        setRow(row, at: cursor.path)
        cursor.path.append(.init(atom: start, child: 1))
        cursor.index = 0
    }

    private mutating func insertAtom(_ atom: Atom) {
        var row = currentRow
        row.atoms.insert(atom, at: cursor.index)
        setRow(row, at: cursor.path)
        cursor.index += 1
    }

    private mutating func insertStructure(_ atom: Atom) {
        var row = currentRow
        row.atoms.insert(atom, at: cursor.index)
        setRow(row, at: cursor.path)
        cursor.path.append(.init(atom: cursor.index, child: 0))
        cursor.index = 0
    }

    // MARK: Cursor movement

    public mutating func moveLeft() {
        let row = currentRow
        if cursor.index > 0 {
            let atom = row.atoms[cursor.index - 1]
            let kids = atom.children
            if kids.isEmpty {
                cursor.index -= 1
            } else {
                let last = kids.count - 1
                cursor.path.append(.init(atom: cursor.index - 1, child: last))
                cursor.index = kids[last].atoms.count
            }
            return
        }
        guard let step = cursor.path.last else { return }
        if step.child > 0 {
            cursor.path[cursor.path.count - 1].child -= 1
            cursor.index = self.row(at: cursor.path).atoms.count
        } else {
            cursor.path.removeLast()
            cursor.index = step.atom
        }
    }

    public mutating func moveRight() {
        let row = currentRow
        if cursor.index < row.atoms.count {
            let atom = row.atoms[cursor.index]
            if atom.children.isEmpty {
                cursor.index += 1
            } else {
                cursor.path.append(.init(atom: cursor.index, child: 0))
                cursor.index = 0
            }
            return
        }
        guard let step = cursor.path.last else { return }
        let parentAtom = self.row(at: Array(cursor.path.dropLast())).atoms[step.atom]
        if step.child < parentAtom.children.count - 1 {
            cursor.path[cursor.path.count - 1].child += 1
            cursor.index = 0
        } else {
            cursor.path.removeLast()
            cursor.index = step.atom + 1
        }
    }

    /// The ")" key: jump out of the innermost bracket-like box.
    public mutating func closeGroup() {
        var path = cursor.path
        while let step = path.last {
            let parent = row(at: Array(path.dropLast())).atoms[step.atom]
            path.removeLast()
            switch parent {
            case .paren, .function, .abs, .sqrt, .power:
                cursor.path = path
                cursor.index = step.atom + 1
                return
            case .fraction, .token:
                continue
            }
        }
    }

    // MARK: Deleting

    public mutating func backspace() {
        var row = currentRow
        if cursor.index > 0 {
            let atom = row.atoms[cursor.index - 1]
            if atom.children.isEmpty || atom.isEmptyStructure {
                row.atoms.remove(at: cursor.index - 1)
                setRow(row, at: cursor.path)
                cursor.index -= 1
            } else {
                // Step inside the structure to delete its contents first.
                moveLeft()
            }
            return
        }
        // At the start of a box.
        guard let step = cursor.path.last else { return }
        let parentPath = Array(cursor.path.dropLast())
        var parentRow = self.row(at: parentPath)
        let structure = parentRow.atoms[step.atom]
        if step.child > 0 && !structure.isEmptyStructure {
            moveLeft()
            return
        }
        // Remove the structure, keeping whatever was typed inside it.
        let contents = structure.children.flatMap(\.atoms)
        parentRow.atoms.replaceSubrange(step.atom...step.atom, with: contents)
        setRow(parentRow, at: parentPath)
        cursor.path = parentPath
        cursor.index = step.atom
    }

    public mutating func clear() {
        root = Row()
        cursor = Cursor()
    }

    /// Replaces the whole content (used by tests and to show worked answers).
    public mutating func load(_ row: Row) {
        root = row
        cursor = Cursor(path: [], index: row.atoms.count)
    }

    /// Cursor position check used by views to draw the caret.
    public func cursorIsIn(path: [Cursor.Step]) -> Bool { cursor.path == path }
}
