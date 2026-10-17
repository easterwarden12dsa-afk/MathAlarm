import SwiftUI
import MathEngine

/// The custom math keyboard. Two pages: numbers/operators and functions.
struct MathKeypad: View {
    @Binding var editor: MathEditor
    /// Show the "C" (constant of integration) key.
    var allowConstantC: Bool
    var keyHeight: CGFloat = 46

    @State private var page = 0

    var body: some View {
        VStack(spacing: 6) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row) { key in
                        KeyButton(key: key, height: keyHeight) { perform(key.action) }
                    }
                }
            }
        }
    }

    // MARK: Layout

    private var rows: [[Key]] {
        page == 0 ? mainPage : functionPage
    }

    private var mainPage: [[Key]] {
        [
            [.sym("x", .token(.x), .variable), .sym("x²", .square, .op), .sym("xⁿ", .power, .op), .sym("a/b", .divide, .op), .icon("delete.left", .backspace, .action)],
            [.digit(7), .digit(8), .digit(9), .sym("(", .paren, .op), .sym(")", .close, .op)],
            [.digit(4), .digit(5), .digit(6), .sym("×", .token(.times), .op), .sym("|x|", .function(.abs), .function)],
            [.digit(1), .digit(2), .digit(3), .sym("+", .token(.plus), .op), .sym("−", .token(.minus), .op)],
            [.digit(0), .sym(".", .token(.dot), .number), .sym("π", .token(.pi), .variable), .sym("e", .token(.e), .variable), .sym("eˣ", .function(.exp), .function)],
            [.icon("arrow.left", .left, .action), .icon("arrow.right", .right, .action), .sym("f(x)", .page, .action), .sym("√", .function(.sqrt), .function), .sym("Clear", .clear, .danger)],
        ]
    }

    private var functionPage: [[Key]] {
        [
            [.sym("sin", .function(.sin), .function), .sym("cos", .function(.cos), .function), .sym("tan", .function(.tan), .function), .sym("ln", .function(.ln), .function), .icon("delete.left", .backspace, .action)],
            [.sym("sec", .function(.sec), .function), .sym("csc", .function(.csc), .function), .sym("cot", .function(.cot), .function), .sym("log", .function(.log), .function), .sym("|x|", .function(.abs), .function)],
            [.sym("arcsin", .function(.asin), .function), .sym("arccos", .function(.acos), .function), .sym("arctan", .function(.atan), .function), .sym("√", .function(.sqrt), .function),
             allowConstantC ? .sym("C", .token(.c), .variable) : .sym("eˣ", .function(.exp), .function)],
            [.sym("sinh", .function(.sinh), .function), .sym("cosh", .function(.cosh), .function), .sym("tanh", .function(.tanh), .function), .sym("(", .paren, .op), .sym(")", .close, .op)],
            [.sym("x", .token(.x), .variable), .sym("x²", .square, .op), .sym("xⁿ", .power, .op), .sym("a/b", .divide, .op), .sym("π", .token(.pi), .variable)],
            [.icon("arrow.left", .left, .action), .icon("arrow.right", .right, .action), .sym("123", .page, .action), .sym("−", .token(.minus), .op), .sym("Clear", .clear, .danger)],
        ]
    }

    // MARK: Actions

    private func perform(_ action: KeyAction) {
        Haptics.tap()
        switch action {
        case .token(let t): editor.insert(t)
        case .function(let f): editor.insertFunction(f)
        case .square: editor.insertSquare()
        case .power: editor.insertPower()
        case .fraction: editor.insertFraction()
        case .divide: editor.divide()
        case .paren: editor.insertParen()
        case .close: editor.closeGroup()
        case .left: editor.moveLeft()
        case .right: editor.moveRight()
        case .backspace: editor.backspace()
        case .clear: editor.clear()
        case .page: page = page == 0 ? 1 : 0
        }
    }
}

enum KeyAction {
    case token(Token)
    case function(Fn)
    case square, power, fraction, divide, paren, close
    case left, right, backspace, clear, page
}

struct Key: Identifiable {
    enum Kind { case number, variable, op, function, action, danger }
    var id: String { label + (symbol ?? "") }
    let label: String
    let symbol: String?
    let action: KeyAction
    let kind: Kind

    static func sym(_ label: String, _ action: KeyAction, _ kind: Kind) -> Key {
        Key(label: label, symbol: nil, action: action, kind: kind)
    }

    static func icon(_ symbol: String, _ action: KeyAction, _ kind: Kind) -> Key {
        Key(label: "", symbol: symbol, action: action, kind: kind)
    }

    static func digit(_ n: Int) -> Key {
        Key(label: String(n), symbol: nil, action: .token(.digit(n)), kind: .number)
    }
}

private struct KeyButton: View {
    let key: Key
    let height: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                if let symbol = key.symbol {
                    Image(systemName: symbol).font(.system(size: 22, weight: .semibold))
                } else {
                    Text(key.label)
                        .font(font)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .background(background, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle(scale: 0.88))
    }

    private var font: Font {
        switch key.kind {
        case .number: .system(size: 26, weight: .medium, design: .rounded)
        case .variable: .system(size: 26, weight: .regular, design: .serif).italic()
        case .function: .system(size: key.label.count > 4 ? 15 : 20, weight: .medium, design: .serif)
        case .op: .system(size: 24, weight: .medium, design: .serif)
        case .action, .danger: .system(size: 17, weight: .semibold)
        }
    }

    private var background: Color {
        switch key.kind {
        case .number: Color(white: 0.22)
        case .variable: Color(white: 0.30)
        case .op: Color(red: 0.25, green: 0.27, blue: 0.36)
        case .function: Color(red: 0.16, green: 0.30, blue: 0.42)
        case .action: Color(white: 0.38)
        case .danger: Color(red: 0.45, green: 0.16, blue: 0.16)
        }
    }

    private var foreground: Color { .white }
}
