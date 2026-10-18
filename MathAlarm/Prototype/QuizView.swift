import SwiftUI
import MathEngine

/// A quick Bagrut-style question: tap an option, tap + / − for each
/// interval, or type a number or a function.
struct QuizView: View {
    let quiz: QuizProblem
    @Binding var editor: MathEditor
    /// Ringing screen: viewing the steps (or a wrong tap) brings a new question.
    var onSolutionViewed: (() -> Void)? = nil
    var onWrong: () -> Void = {}
    var onSolved: () -> Void

    @State private var solved = false
    @State private var picked: Int?
    @State private var signs: [Bool?] = []
    @State private var feedback: String?
    @State private var feedbackColor: Color = .red
    @State private var wrongCount = 0
    @State private var revealCorrect = false
    @State private var showSteps = false
    @State private var confirmSteps = false
    @State private var shakes: CGFloat = 0

    private var inAlarm: Bool { onSolutionViewed != nil }

    var body: some View {
        Group {
            switch quiz.answer {
            case .number, .function:
                ViewThatFits(in: .vertical) {
                    typedLayout(keyHeight: 42, graphHeight: 150)
                    typedLayout(keyHeight: 36, graphHeight: 120)
                    typedLayout(keyHeight: 31, graphHeight: 96)
                    typedLayout(keyHeight: 28, graphHeight: 0)
                }
            case .choice, .signs:
                VStack(spacing: 10) {
                    ScrollView {
                        VStack(spacing: 10) {
                            questionCard(graphHeight: 170)
                            tapAnswers
                        }
                    }
                    feedbackLine
                    if case .signs = quiz.answer { checkButton(height: 50) }
                }
            }
        }
        .onAppear {
            if case .signs(let iv, _) = quiz.answer, signs.count != iv.count { signs = Array(repeating: nil, count: iv.count) }
        }
        .sheet(isPresented: $showSteps, onDismiss: { if inAlarm { onSolutionViewed?() } }) {
            QuizStepsSheet(quiz: quiz, warning: inAlarm ? "After you close this, you'll get a new question." : nil)
        }
        .confirmationDialog("Show the solution?", isPresented: $confirmSteps, titleVisibility: .visible) {
            Button("Show solution (new question after)") { showSteps = true }
            Button("Keep trying", role: .cancel) {}
        }
    }

    // MARK: Layouts

    private func typedLayout(keyHeight: CGFloat, graphHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            questionCard(graphHeight: graphHeight)
            VStack(alignment: .leading, spacing: 2) {
                Text(answerCaption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                AnswerField(editor: $editor)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .modifier(Shake(animatableData: shakes))
            feedbackLine
            MathKeypad(editor: $editor, allowConstantC: false, keyHeight: keyHeight)
            checkButton(height: keyHeight + 6)
        }
        .onChange(of: editor) { _, _ in if !solved { feedback = nil } }
    }

    private var answerCaption: String {
        if case .function = quiz.answer { return quiz.kind == .tangent ? "y =" : "Your answer (a function of x)" }
        if quiz.tolerance != nil { return "Your answer — a decimal is fine (or an exact form)" }
        return "Your answer — exact forms like ln 3, √2, 3/10 are fine"
    }

    private func questionCard(graphHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(quiz.kind.title, systemImage: quiz.kind.symbol)
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    Haptics.tap()
                    if inAlarm { confirmSteps = true } else { showSteps = true }
                } label: {
                    Label("Steps", systemImage: "list.number").font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PressableStyle())
                .tint(.cyan)
            }
            Text(quiz.prompt)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            QuizFormula(quiz: quiz)
            if let t = quiz.table { QuizTableView(table: t) }
            if let f = quiz.triangle, graphHeight > 0 {
                TriangleView(figure: f).frame(height: graphHeight)
            }
            if let g = quiz.graph, graphHeight > 0 {
                QuizGraph(problem: g, shade: quiz.shade, lower: quiz.lower, hline: quiz.level_k)
                    .frame(height: graphHeight)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var tapAnswers: some View {
        switch quiz.answer {
        case .choice(let options, let correct):
            let graphs = options.contains { $0.graph != nil }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, option in
                    Button {
                        choose(i, correct: correct)
                    } label: {
                        optionLabel(option, letter: "ABCD".map(String.init)[safe: i] ?? "", graphs: graphs)
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(optionBorder(i, correct: correct), lineWidth: 3))
                    }
                    .buttonStyle(PressableStyle(scale: 0.96))
                    .disabled(solved || revealCorrect)
                }
            }
            .modifier(Shake(animatableData: shakes))
        case .signs(let intervals, let positive):
            VStack(spacing: 8) {
                ForEach(Array(intervals.enumerated()), id: \.offset) { i, interval in
                    HStack(spacing: 8) {
                        Text(interval)
                            .font(.system(.subheadline, design: .serif).weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        signButton(i, plus: true, truth: positive[safe: i])
                        signButton(i, plus: false, truth: positive[safe: i])
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                Text("f′ > 0: f increases ↗   ·   f′ < 0: f decreases ↘")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .modifier(Shake(animatableData: shakes))
        default:
            EmptyView()
        }
    }

    private func signButton(_ i: Int, plus: Bool, truth: Bool?) -> some View {
        let chosen = signs[safe: i] ?? nil
        let on = chosen == plus
        let showTruth = revealCorrect && truth == plus
        return Button {
            Haptics.tap()
            guard i < signs.count else { return }
            signs[i] = plus
            feedback = nil
        } label: {
            Text(plus ? "+" : "−")
                .font(.title2.bold())
                .foregroundStyle(on ? .black : .white)
                .frame(width: 52, height: 40)
                .background(on ? (plus ? Color.green : Color.red) : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(showTruth ? Color.yellow : .clear, lineWidth: 3))
        }
        .buttonStyle(PressableStyle())
        .disabled(solved || revealCorrect)
        .accessibilityLabel(plus ? "Positive" : "Negative")
    }

    private func optionLabel(_ o: QuizOption, letter: String, graphs: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(letter).font(.caption.bold()).foregroundStyle(.orange)
            if let g = o.graph {
                QuizGraph(problem: g, compact: true).frame(height: 120)
            } else if let m = o.math {
                FittedMath(sizes: [22, 19, 16, 13]) { size in
                    MathRowView(row: ExprDisplay.row(m), size: size, mergeFunctionPowers: true).foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            if let t = o.text {
                Text(t)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: graphs ? 0 : 44)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }

    private func optionBorder(_ i: Int, correct: Int) -> Color {
        if (solved || revealCorrect) && i == correct { return .green }
        if picked == i && i != correct { return .red }
        return .clear
    }

    @ViewBuilder
    private var feedbackLine: some View {
        if let feedback {
            Text(feedback)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(feedbackColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func checkButton(height: CGFloat) -> some View {
        Button(action: checkTyped) {
            Label(solved ? "Correct!" : "Check answer", systemImage: solved ? "checkmark" : "checkmark.circle")
                .font(.title3.bold())
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: height)
                .background(solved ? Color.green : Color.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
        .disabled(solved || revealCorrect)
    }

    // MARK: Checking

    private func choose(_ i: Int, correct: Int) {
        picked = i
        if i == correct { success() } else { miss(lockOut: true) }
    }

    private func checkTyped() {
        switch quiz.answer {
        case .signs(_, let positive):
            guard signs.allSatisfy({ $0 != nil }) else {
                feedbackColor = .yellow
                feedback = "Choose + or − for every interval."
                Haptics.warning()
                return
            }
            if zip(signs, positive).allSatisfy({ $0 == $1 }) { success() } else { miss(lockOut: true) }
        case .number, .function:
            do {
                let typed = try RowParser.parse(editor)
                if QuizChecker.check(typed, for: quiz) { success() } else { miss(lockOut: false) }
            } catch let error as EntryError {
                feedbackColor = .yellow
                feedback = "Not finished yet: \(error.message)"
                Haptics.warning()
            } catch {
                feedbackColor = .yellow
                feedback = "Check your entry."
                Haptics.warning()
            }
        case .choice:
            break
        }
    }

    private func success() {
        solved = true
        feedbackColor = .green
        withAnimation { feedback = "Correct!" }
        Haptics.success()
        Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            onSolved()
        }
    }

    /// Tap answers can't be retried (guessing would be too easy): the right
    /// one is shown, and in an alarm a new question follows.
    private func miss(lockOut: Bool) {
        wrongCount += 1
        Haptics.error()
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        onWrong()
        feedbackColor = .red
        if lockOut {
            withAnimation { revealCorrect = true }
            feedback = inAlarm ? "Not this one — the right answer is marked. New question coming…" : "Not this one — the right answer is marked. Tap Steps to see why."
            if inAlarm {
                Task {
                    try? await Task.sleep(nanoseconds: 2_600_000_000)
                    onSolutionViewed?()
                }
            }
        } else {
            feedback = wrongCount >= 2 ? "Not quite — the Steps button shows the method." : "Not quite — try again."
        }
    }
}

/// "f(x) =" and the formula, typeset, or plain text with a parameter.
struct QuizFormula: View {
    let quiz: QuizProblem

    var body: some View {
        if let f = quiz.formula {
            FittedMath(sizes: [26, 22, 19, 16, 13]) { size in
                HStack(alignment: .mathAxis, spacing: size * 0.25) {
                    if let label = quiz.formulaLabel {
                        Text(label).font(MathFont.italic(size))
                    }
                    MathRowView(row: ExprDisplay.row(f), size: size, mergeFunctionPowers: true)
                }
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
        } else if let t = quiz.formulaText {
            Text(t)
                .font(.system(.title3, design: .serif).weight(.semibold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
        }
    }
}

/// A graph to look at (not drawn on).
struct QuizGraph: View {
    let problem: SketchProblem
    var shade: ClosedRange<Double>? = nil
    var lower: SketchProblem? = nil
    var hline: Double? = nil
    var compact = false

    var body: some View {
        SketchCanvas(problem: problem, strokes: .constant([]), showYScale: !compact,
                     curveColor: .white, shade: shade, shadeLower: lower, hline: hline)
            .allowsHitTesting(false)
            .accessibilityLabel("Graph")
    }
}

struct QuizStepsSheet: View {
    let quiz: QuizProblem
    var warning: String? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let warning {
                        Label(warning, systemImage: "arrow.triangle.2.circlepath")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    Text(quiz.prompt).font(.headline)
                    QuizFormula(quiz: quiz)
                    if let t = quiz.table { QuizTableView(table: t) }
                    if let f = quiz.triangle { TriangleView(figure: f).frame(height: 220) }
                    if let g = quiz.graph {
                        QuizGraph(problem: g, shade: quiz.shade, lower: quiz.lower, hline: quiz.level_k).frame(height: 200)
                    }
                    StepsList(steps: quiz.steps)
                    Text("Answer: \(answerText)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle(quiz.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var answerText: String {
        switch quiz.answer {
        case .choice(let o, let c): return "option " + ("ABCD".map(String.init)[safe: c] ?? "?") + (o[safe: c]?.text.map { " (\($0))" } ?? "")
        case .number(let v): return SketchFormat.number(v)
        case .function(let f): return "y = \(f.description)"
        case .signs(let iv, let p): return zip(iv, p).map { "\($0): \($1 ? "+" : "−")" }.joined(separator: ", ")
        }
    }
}

/// A labelled triangle (trigonometry in the plane), scaled to fit.
struct TriangleView: View {
    let figure: TriangleFigure

    var body: some View {
        Canvas { ctx, size in
            let p = figure.points
            guard p.count == 6 else { return }
            var pts = [CGPoint(x: p[0], y: p[1]), CGPoint(x: p[2], y: p[3]), CGPoint(x: p[4], y: p[5])]
            if let e = figure.extra, e.count == 4 { pts += [CGPoint(x: e[0], y: e[1]), CGPoint(x: e[2], y: e[3])] }
            let minX = pts.map(\.x).min()!, maxX = pts.map(\.x).max()!
            let minY = pts.map(\.y).min()!, maxY = pts.map(\.y).max()!
            let pad: CGFloat = 26
            let scale = min((size.width - 2 * pad) / max(maxX - minX, 1e-6), (size.height - 2 * pad) / max(maxY - minY, 1e-6))
            let ox = (size.width - (maxX - minX) * scale) / 2, oy = (size.height - (maxY - minY) * scale) / 2
            func map(_ q: CGPoint) -> CGPoint { CGPoint(x: ox + (q.x - minX) * scale, y: size.height - oy - (q.y - minY) * scale) }
            let v = pts.prefix(3).map(map)
            let centre = CGPoint(x: (v[0].x + v[1].x + v[2].x) / 3, y: (v[0].y + v[1].y + v[2].y) / 3)
            func away(_ q: CGPoint, from c: CGPoint, by d: CGFloat) -> CGPoint {
                let dx = q.x - c.x, dy = q.y - c.y, l = max(hypot(dx, dy), 1e-6)
                return CGPoint(x: q.x + dx / l * d, y: q.y + dy / l * d)
            }
            func text(_ s: String, _ at: CGPoint, _ color: Color, bold: Bool = false) {
                let t = ctx.resolve(Text(s).font(.system(size: bold ? 16 : 14, weight: bold ? .bold : .semibold, design: .serif)).foregroundColor(color))
                ctx.draw(t, at: at)
            }

            var tri = Path()
            tri.move(to: v[0]); tri.addLine(to: v[1]); tri.addLine(to: v[2]); tri.closeSubpath()
            ctx.fill(tri, with: .color(.orange.opacity(0.12)))
            ctx.stroke(tri, with: .color(.white), style: StrokeStyle(lineWidth: 2.2, lineJoin: .round))

            if let e = figure.extra, e.count == 4 {
                let a = map(CGPoint(x: e[0], y: e[1])), b = map(CGPoint(x: e[2], y: e[3]))
                ctx.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(.cyan), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                ctx.fill(Path(ellipseIn: CGRect(x: b.x - 3, y: b.y - 3, width: 6, height: 6)), with: .color(.cyan))
                if let name = figure.extraPoint { text(name, away(b, from: centre, by: 14), .cyan, bold: true) }
                if let l = figure.extraLabel {
                    let mid = CGPoint(x: (a.x + b.x) / 2 + 12, y: (a.y + b.y) / 2)
                    text(l, mid, .yellow, bold: true)
                }
            }
            for i in 0..<3 {
                // Vertex names outside, angles inside.
                if let name = figure.vertexLabels[safe: i] { text(name, away(v[i], from: centre, by: 15), .white, bold: true) }
                if let angle = figure.angleLabels[safe: i] ?? nil {
                    let inside = away(v[i], from: centre, by: -min(30, hypot(v[i].x - centre.x, v[i].y - centre.y) * 0.45))
                    text(angle, inside, angle == "?" ? .yellow : .orange)
                }
                if let side = figure.sideLabels[safe: i] ?? nil {
                    let j = (i + 1) % 3
                    let mid = CGPoint(x: (v[i].x + v[j].x) / 2, y: (v[i].y + v[j].y) / 2)
                    text(side, away(mid, from: centre, by: 13), side == "?" ? .yellow : .white)
                }
            }
        }
        .accessibilityLabel("Triangle diagram")
    }
}

/// A two-way table of counts with row and column totals.
struct QuizTableView: View {
    let table: QuizTable

    private var numbers: [[Int]] { table.rows.map { $0.dropFirst().map { Int($0) ?? 0 } } }

    var body: some View {
        let n = numbers
        let colTotals = (0..<(n.first?.count ?? 0)).map { c in n.reduce(0) { $0 + ($1[safe: c] ?? 0) } }
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                ForEach(Array((table.columns + ["Total"]).enumerated()), id: \.offset) { _, h in cell(h, header: true) }
            }
            ForEach(Array(table.rows.enumerated()), id: \.offset) { i, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { j, v in cell(v, header: j == 0) }
                    cell("\(n[i].reduce(0, +))", header: false, total: true)
                }
            }
            GridRow {
                cell("Total", header: true)
                ForEach(Array(colTotals.enumerated()), id: \.offset) { _, t in cell("\(t)", header: false, total: true) }
                cell("\(colTotals.reduce(0, +))", header: false, total: true)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2)))
    }

    private func cell(_ s: String, header: Bool, total: Bool = false) -> some View {
        Text(s)
            .font(header ? .caption.weight(.bold) : .body.monospacedDigit().weight(total ? .regular : .semibold))
            .foregroundStyle(total ? .white.opacity(0.6) : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(header ? Color.white.opacity(0.1) : Color.clear)
            .border(Color.white.opacity(0.08), width: 0.5)
    }
}
