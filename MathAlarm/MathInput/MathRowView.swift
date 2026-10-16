import SwiftUI
import MathEngine

extension VerticalAlignment {
    /// The math axis: the line through the middle of ordinary symbols and
    /// through fraction bars. Everything in a formula aligns on it.
    private enum MathAxis: AlignmentID {
        static func defaultValue(in d: ViewDimensions) -> CGFloat { d[VerticalAlignment.center] }
    }
    static let mathAxis = VerticalAlignment(MathAxis.self)
}

/// Typesets a row of the structured editor (also used for problems, via
/// `ExprDisplay`). Draws the caret when `cursor` points into this row.
struct MathRowView: View {
    let row: Row
    var path: [Cursor.Step] = []
    var cursor: Cursor? = nil
    var size: CGFloat = 28
    /// Problem display: draw sin(x)² as sin²(x).
    var mergeFunctionPowers = false

    private var caretIndex: Int? {
        guard let cursor, cursor.path == path else { return nil }
        return cursor.index
    }

    var body: some View {
        HStack(alignment: .mathAxis, spacing: size * 0.04) {
            if row.atoms.isEmpty {
                placeholder
            } else {
                ForEach(elements, id: \.index) { element in
                    if caretIndex == element.index { Caret(size: size) }
                    element.view
                }
                if caretIndex == row.atoms.count { Caret(size: size) }
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
            .foregroundStyle(caretIndex != nil ? Color.orange : Color.white.opacity(0.45))
            .frame(width: size * 0.62, height: size * 0.85)
            .overlay { if caretIndex != nil { Caret(size: size * 0.8) } }
    }

    private struct Element {
        let index: Int
        let view: AnyView
    }

    private var elements: [Element] {
        var result: [Element] = []
        var i = 0
        let atoms = row.atoms
        while i < atoms.count {
            let index = i
            let basePath = path
            let childPath = { (child: Int) in basePath + [Cursor.Step(atom: index, child: child)] }
            if mergeFunctionPowers, case .function(let f, let arg) = atoms[i],
               i + 1 < atoms.count, case .power(let exponent) = atoms[i + 1] {
                result.append(Element(index: i, view: AnyView(
                    FunctionView(name: f.displayName, exponent: exponent, argument: arg, size: size,
                                 merge: mergeFunctionPowers)
                )))
                i += 2
                continue
            }
            result.append(Element(index: i, view: AnyView(
                AtomView(atom: atoms[i], childPath: childPath, cursor: cursor, size: size,
                         merge: mergeFunctionPowers)
            )))
            i += 1
        }
        return result
    }
}

private struct Caret: View {
    let size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.orange)
            .frame(width: 2.5, height: size * 1.05)
    }
}

private struct AtomView: View {
    let atom: Atom
    let childPath: (Int) -> [Cursor.Step]
    let cursor: Cursor?
    let size: CGFloat
    let merge: Bool

    var body: some View {
        switch atom {
        case .token(let t):
            TokenView(token: t, size: size)
        case .function(let f, let arg):
            HStack(alignment: .mathAxis, spacing: size * 0.06) {
                Text(f.displayName).font(MathFont.upright(size))
                Bracketed(open: "(", close: ")", size: size) {
                    MathRowView(row: arg, path: childPath(0), cursor: cursor, size: size, mergeFunctionPowers: merge)
                }
            }
        case .fraction(let num, let den):
            VStack(spacing: size * 0.12) {
                MathRowView(row: num, path: childPath(0), cursor: cursor, size: size * 0.86, mergeFunctionPowers: merge)
                Rectangle()
                    .fill(Color.white)
                    .frame(height: Swift.max(1.5, size * 0.06))
                    .frame(maxWidth: .infinity)
                    .alignmentGuide(.mathAxis) { d in d[VerticalAlignment.center] }
                MathRowView(row: den, path: childPath(1), cursor: cursor, size: size * 0.86, mergeFunctionPowers: merge)
            }
            .padding(.horizontal, size * 0.08)
            .fixedSize()
        case .power(let exponent):
            MathRowView(row: exponent, path: childPath(0), cursor: cursor, size: Swift.max(12, size * 0.68), mergeFunctionPowers: merge)
                .alignmentGuide(.mathAxis) { d in d[.bottom] + size * 0.12 }
        case .sqrt(let r):
            MathRowView(row: r, path: childPath(0), cursor: cursor, size: size, mergeFunctionPowers: merge)
                .padding(.leading, size * 0.62)
                .padding(.top, size * 0.16)
                .padding(.trailing, size * 0.06)
                .overlay(RadicalShape(hookWidth: size * 0.55).stroke(Color.white, style: StrokeStyle(lineWidth: Swift.max(1.5, size * 0.06), lineJoin: .round)))
        case .abs(let r):
            MathRowView(row: r, path: childPath(0), cursor: cursor, size: size, mergeFunctionPowers: merge)
                .padding(.horizontal, size * 0.22)
                .padding(.vertical, size * 0.04)
                .overlay(AbsBars().stroke(Color.white, lineWidth: Swift.max(1.5, size * 0.06)))
        case .paren(let r):
            Bracketed(open: "(", close: ")", size: size) {
                MathRowView(row: r, path: childPath(0), cursor: cursor, size: size, mergeFunctionPowers: merge)
            }
        }
    }
}

/// "sin²(x)" style rendering for problems.
private struct FunctionView: View {
    let name: String
    let exponent: Row
    let argument: Row
    let size: CGFloat
    let merge: Bool

    var body: some View {
        HStack(alignment: .mathAxis, spacing: size * 0.04) {
            Text(name).font(MathFont.upright(size))
            MathRowView(row: exponent, size: Swift.max(12, size * 0.68), mergeFunctionPowers: merge)
                .alignmentGuide(.mathAxis) { d in d[.bottom] + size * 0.12 }
            Bracketed(open: "(", close: ")", size: size) {
                MathRowView(row: argument, size: size, mergeFunctionPowers: merge)
            }
        }
    }
}

private struct TokenView: View {
    let token: Token
    let size: CGFloat

    var body: some View {
        switch token {
        case .x, .c:
            Text(token.rawValue).font(MathFont.italic(size))
        case .plus, .minus, .times:
            Text(token.rawValue).font(MathFont.upright(size)).padding(.horizontal, size * 0.12)
        default:
            Text(token.rawValue).font(MathFont.upright(size))
        }
    }
}

enum MathFont {
    static func upright(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif) }
    static func italic(_ size: CGFloat) -> Font { .system(size: size, weight: .regular, design: .serif).italic() }
}

/// Round brackets that stretch to the height of their content.
private struct Bracketed<Content: View>: View {
    let open: String
    let close: String
    let size: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(.horizontal, size * 0.3)
            .padding(.vertical, size * 0.02)
            .overlay(ParenShape().stroke(Color.white, style: StrokeStyle(lineWidth: Swift.max(1.4, size * 0.055), lineCap: .round)))
    }
}

private struct ParenShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = Swift.min(rect.height * 0.18, 10)
        let inset: CGFloat = 1
        // Left (
        p.move(to: CGPoint(x: rect.minX + w + inset, y: rect.minY + 1))
        p.addQuadCurve(to: CGPoint(x: rect.minX + w + inset, y: rect.maxY - 1),
                       control: CGPoint(x: rect.minX + inset - w * 0.4, y: rect.midY))
        // Right )
        p.move(to: CGPoint(x: rect.maxX - w - inset, y: rect.minY + 1))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - w - inset, y: rect.maxY - 1),
                       control: CGPoint(x: rect.maxX - inset + w * 0.4, y: rect.midY))
        return p
    }
}

private struct AbsBars: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + 2, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX - 2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 2, y: rect.maxY))
        return p
    }
}

private struct RadicalShape: Shape {
    let hookWidth: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.minY + 1
        p.move(to: CGPoint(x: rect.minX + 1, y: rect.minY + rect.height * 0.62))
        p.addLine(to: CGPoint(x: rect.minX + hookWidth * 0.3, y: rect.minY + rect.height * 0.52))
        p.addLine(to: CGPoint(x: rect.minX + hookWidth * 0.62, y: rect.maxY - 1))
        p.addLine(to: CGPoint(x: rect.minX + hookWidth, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: top))
        return p
    }
}

/// Shows an expression, shrinking it until it fits the available width.
struct FittedMath<Content: View>: View {
    let sizes: [CGFloat]
    let content: (CGFloat) -> Content

    init(sizes: [CGFloat] = [32, 28, 24, 20, 17, 14], @ViewBuilder content: @escaping (CGFloat) -> Content) {
        self.sizes = sizes
        self.content = content
    }

    private func size(_ i: Int) -> CGFloat { sizes[Swift.min(i, sizes.count - 1)] }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            content(size(0)).fixedSize()
            content(size(1)).fixedSize()
            content(size(2)).fixedSize()
            content(size(3)).fixedSize()
            content(size(4)).fixedSize()
            content(size(5)).fixedSize()
            ScrollView(.horizontal, showsIndicators: true) {
                content(sizes.last ?? 14).fixedSize().padding(.horizontal, 4)
            }
        }
    }
}
