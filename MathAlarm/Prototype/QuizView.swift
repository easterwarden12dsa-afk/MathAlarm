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
    @State private var showPicture = false

    private var inAlarm: Bool { onSolutionViewed != nil }

    var body: some View {
        Group {
            switch quiz.answer {
            case .number, .function:
                ViewThatFits(in: .vertical) {
                    typedLayout(keyHeight: 42, graphHeight: 170)
                    typedLayout(keyHeight: 38, graphHeight: 140)
                    typedLayout(keyHeight: 33, graphHeight: 116)
                    typedLayout(keyHeight: 29, graphHeight: 96)
                    typedLayout(keyHeight: 26, graphHeight: 0)
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
        .sheet(isPresented: $showPicture) {
            QuizPictureSheet(quiz: quiz)
        }
        .confirmationDialog("Show the solution?", isPresented: $confirmSteps, titleVisibility: .visible) {
            Button("Show solution (new question after)") { showSteps = true }
            Button("Keep trying", role: .cancel) {}
        }
    }

    // MARK: Layouts

    /// Pictures matter in geometry: never hide a triangle or a sketch completely.
    private func pictureHeight(_ h: CGFloat) -> CGFloat {
        quiz.triangle != nil || quiz.figure != nil || (quiz.diagram != nil && quiz.graph == nil) ? Swift.max(h, 104) : h
    }

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
        if case .function = quiz.answer {
            switch quiz.kind {
            case .tangent, .conics: return "y ="
            case .antiderivative: return "f(x) ="
            default: return "Your answer (a function of x)"
            }
        }
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
            if let f = quiz.triangle {
                TriangleView(figure: f)
                    .frame(height: pictureHeight(graphHeight))
                    .contentShape(Rectangle())
                    .onTapGesture { showPicture = true }
            }
            if let d = quiz.diagram, quiz.graph == nil {
                QuizDiagramView(diagram: d)
                    .frame(height: pictureHeight(graphHeight))
                    .contentShape(Rectangle())
                    .onTapGesture { showPicture = true }
            }
            if let f = quiz.figure {
                GeoFigureView(figure: f)
                    .frame(height: pictureHeight(graphHeight))
                    .contentShape(Rectangle())
                    .onTapGesture { showPicture = true }
            }
            if let g = quiz.graph, graphHeight > 0 {
                QuizGraph(problem: g, shade: quiz.shade, lower: quiz.lower, hline: quiz.level_k, diagram: quiz.diagram)
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

    var body: some View { mathBody.mathDirection() }

    @ViewBuilder
    private var mathBody: some View {
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
    var diagram: QuizDiagram? = nil

    /// Rectangles and tangent triangles drawn on the graph.
    private var overlays: [[Double]] {
        guard let d = diagram else { return [] }
        switch d.kind {
        case .rectangleUnder where d.numbers.count >= 3:
            let x1 = d.numbers[0], x2 = d.numbers[1], h = problem.value(at: d.numbers[2])
            return [[x1, 0, x2, 0, x2, h, x1, h]]
        case .tangentTriangle where !d.numbers.isEmpty:
            let t = d.numbers[0], y = problem.value(at: t)
            let m = problem.function.derivative().evaluate(at: t)
            guard m != 0, y.isFinite, m.isFinite else { return [] }
            let xi = t - y / m, yi = y - m * t
            return [[0, 0, xi, 0, 0, yi], [problem.xMin, y + m * (problem.xMin - t), problem.xMax, y + m * (problem.xMax - t)]]
        default:
            return []
        }
    }

    var body: some View {
        SketchCanvas(problem: problem, strokes: .constant([]), showYScale: !compact,
                     curveColor: .white, shade: shade, shadeLower: lower, hline: hline, overlayPolygons: overlays)
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
                    if let d = quiz.diagram, quiz.graph == nil { QuizDiagramView(diagram: d).frame(height: 200) }
                    if let f = quiz.figure { GeoFigureView(figure: f).frame(height: 240) }
                    if let g = quiz.graph {
                        QuizGraph(problem: g, shade: quiz.shade, lower: quiz.lower, hline: quiz.level_k, diagram: quiz.diagram).frame(height: 200)
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
        case .function(let f): return quiz.steps.last(where: { $0.style == .result })?.text ?? "y = \(f.description)"
        case .signs(let iv, let p): return zip(iv, p).map { "\($0): \($1 ? "+" : "−")" }.joined(separator: ", ")
        }
    }
}

/// A labelled triangle (trigonometry in the plane), scaled to fit.
struct TriangleView: View {
    let figure: TriangleFigure

    var body: some View { mathBody.mathDirection() }

    @ViewBuilder
    private var mathBody: some View {
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

/// The question's picture, big (tap a triangle or sketch to open it).
struct QuizPictureSheet: View {
    let quiz: QuizProblem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(quiz.prompt)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let f = quiz.triangle { TriangleView(figure: f).frame(maxHeight: .infinity) }
                if let d = quiz.diagram, quiz.graph == nil { QuizDiagramView(diagram: d).frame(maxHeight: .infinity) }
                if let f = quiz.figure { GeoFigureView(figure: f).frame(maxHeight: .infinity) }
            }
            .padding()
            .background(Color.black)
            .navigationTitle(quiz.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

/// Sketches for word problems: a fenced field, a sheet folded into a box,
/// a trapezoid, a cone, a probability tree and a bag of balls.
struct QuizDiagramView: View {
    let diagram: QuizDiagram

    private func label(_ i: Int) -> String { diagram.labels[safe: i] ?? "" }

    var body: some View { mathBody.mathDirection() }

    @ViewBuilder
    private var mathBody: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func text(_ s: String, _ p: CGPoint, _ color: Color = .white, size: CGFloat = 15, bold: Bool = true) {
                ctx.draw(ctx.resolve(Text(s).font(.system(size: size, weight: bold ? .bold : .regular, design: .serif)).foregroundColor(color)), at: p)
            }
            func line(_ a: CGPoint, _ b: CGPoint, _ color: Color = .white, width: CGFloat = 2.2, dash: [CGFloat] = []) {
                ctx.stroke(Path { $0.move(to: a); $0.addLine(to: b) }, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
            }
            switch diagram.kind {
            case .fence:
                // The wall on top, the fence on the other three sides.
                let r = CGRect(x: w * 0.2, y: h * 0.22, width: w * 0.6, height: h * 0.55)
                ctx.fill(Path(CGRect(x: w * 0.08, y: r.minY - 12, width: w * 0.84, height: 10)), with: .color(.gray.opacity(0.6)))
                text("wall", CGPoint(x: w * 0.5, y: r.minY - 24), .gray, size: 13, bold: false)
                ctx.fill(Path(r), with: .color(.green.opacity(0.15)))
                var fence = Path()
                fence.move(to: CGPoint(x: r.minX, y: r.minY)); fence.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                fence.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); fence.addLine(to: CGPoint(x: r.maxX, y: r.minY))
                ctx.stroke(fence, with: .color(.orange), style: StrokeStyle(lineWidth: 3, dash: [8, 4]))
                text(label(0), CGPoint(x: r.minX - 14, y: r.midY), .yellow)
                text(label(0), CGPoint(x: r.maxX + 14, y: r.midY), .yellow)
                text(label(1), CGPoint(x: r.midX, y: r.maxY + 16), .yellow)
            case .box:
                let side = min(w, h) * 0.78
                let r = CGRect(x: (w - side) / 2, y: (h - side) / 2, width: side, height: side)
                let c = side * 0.18
                ctx.fill(Path(r), with: .color(.white.opacity(0.08)))
                ctx.stroke(Path(r), with: .color(.white), lineWidth: 2)
                for (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)] {
                    let sq = CGRect(x: r.minX + CGFloat(dx) * (side - c), y: r.minY + CGFloat(dy) * (side - c), width: c, height: c)
                    ctx.fill(Path(sq), with: .color(.red.opacity(0.35)))
                    ctx.stroke(Path(sq), with: .color(.red), lineWidth: 1.5)
                }
                let inner = r.insetBy(dx: c, dy: c)
                ctx.stroke(Path(inner), with: .color(.orange), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                text(label(0), CGPoint(x: r.midX, y: r.maxY + 12), .yellow)
                text(label(1), CGPoint(x: r.minX + c / 2, y: r.minY + c / 2), .yellow, size: 13)
                text("fold", CGPoint(x: inner.midX, y: inner.midY), .orange, size: 12, bold: false)
            case .trapezoid:
                let s = min(w * 0.3, h * 0.55)
                let angle = Double.pi / 3.2
                let base = CGPoint(x: w / 2 - s / 2 - s * CGFloat(cos(angle)), y: h * 0.78)
                let p1 = base, p4 = CGPoint(x: w / 2 + s / 2 + s * CGFloat(cos(angle)), y: base.y)
                let p2 = CGPoint(x: w / 2 - s / 2, y: base.y - s * CGFloat(sin(angle)))
                let p3 = CGPoint(x: w / 2 + s / 2, y: p2.y)
                var path = Path()
                path.move(to: p1); path.addLine(to: p2); path.addLine(to: p3); path.addLine(to: p4); path.closeSubpath()
                ctx.fill(path, with: .color(.orange.opacity(0.15)))
                ctx.stroke(path, with: .color(.white), lineWidth: 2.2)
                text(label(0), CGPoint(x: (p1.x + p2.x) / 2 - 14, y: (p1.y + p2.y) / 2), .yellow)
                text(label(0), CGPoint(x: (p2.x + p3.x) / 2, y: p2.y - 14), .yellow)
                text(label(0), CGPoint(x: (p3.x + p4.x) / 2 + 14, y: (p3.y + p4.y) / 2), .yellow)
                text(label(1), CGPoint(x: p1.x + 26, y: p1.y - 10), .orange)
                text(label(1), CGPoint(x: p4.x - 26, y: p4.y - 10), .orange)
                line(p2, CGPoint(x: p2.x, y: base.y), .cyan, width: 1.5, dash: [5, 4])
            case .cone:
                let top = CGPoint(x: w / 2, y: h * 0.1), bl = CGPoint(x: w / 2 - h * 0.45, y: h * 0.8), br = CGPoint(x: w / 2 + h * 0.45, y: h * 0.8)
                let centre = CGPoint(x: w / 2, y: h * 0.8)
                ctx.stroke(Path(ellipseIn: CGRect(x: bl.x, y: bl.y - h * 0.07, width: br.x - bl.x, height: h * 0.14)), with: .color(.white.opacity(0.6)), lineWidth: 1.5)
                var path = Path()
                path.move(to: bl); path.addLine(to: top); path.addLine(to: br)
                ctx.stroke(path, with: .color(.white), lineWidth: 2.2)
                line(top, centre, .cyan, width: 1.6, dash: [5, 4])
                line(centre, br, .orange, width: 1.8, dash: [5, 4])
                text(label(0), CGPoint(x: (top.x + br.x) / 2 + 14, y: (top.y + br.y) / 2 - 6), .yellow)
                text(label(1), CGPoint(x: top.x - 12, y: (top.y + centre.y) / 2), .cyan)
                text(label(2), CGPoint(x: (centre.x + br.x) / 2, y: centre.y + 14), .orange)
            case .tree:
                let n = diagram.numbers
                guard n.count >= 3 else { return }
                func fmt(_ v: Double) -> String { String(format: "%g", (v * 1000).rounded() / 1000) }
                let root = CGPoint(x: w * 0.08, y: h / 2)
                let a = CGPoint(x: w * 0.42, y: h * 0.27), b = CGPoint(x: w * 0.42, y: h * 0.73)
                let leaves = [CGPoint(x: w * 0.82, y: h * 0.12), CGPoint(x: w * 0.82, y: h * 0.38),
                              CGPoint(x: w * 0.82, y: h * 0.62), CGPoint(x: w * 0.82, y: h * 0.88)]
                ctx.fill(Path(ellipseIn: CGRect(x: root.x - 4, y: root.y - 4, width: 8, height: 8)), with: .color(.white))
                line(root, a); line(root, b)
                text(fmt(n[0]), CGPoint(x: (root.x + a.x) / 2 - 6, y: (root.y + a.y) / 2 - 10), .yellow, size: 13)
                text(fmt(1 - n[0]), CGPoint(x: (root.x + b.x) / 2 - 6, y: (root.y + b.y) / 2 + 10), .yellow, size: 13)
                text(label(0), CGPoint(x: a.x, y: a.y - 14), .orange); text(label(1), CGPoint(x: b.x, y: b.y + 14), .orange)
                let probs = [n[1], 1 - n[1], n[2], 1 - n[2]]
                for (i, leaf) in leaves.enumerated() {
                    let from = i < 2 ? a : b
                    line(from, leaf, .white.opacity(0.85), width: 1.8)
                    text(fmt(probs[i]), CGPoint(x: (from.x + leaf.x) / 2, y: (from.y + leaf.y) / 2 - 9), .yellow, size: 12)
                    text(i % 2 == 0 ? label(2) : label(3), CGPoint(x: leaf.x + 4, y: leaf.y + 13), i % 2 == 0 ? .red : .green, size: 11, bold: false)
                }
            case .bag:
                let red = Int(diagram.numbers[safe: 0] ?? 0), blue = Int(diagram.numbers[safe: 1] ?? 0)
                let bag = Path(roundedRect: CGRect(x: w * 0.2, y: h * 0.12, width: w * 0.6, height: h * 0.8), cornerRadius: 26)
                ctx.fill(bag, with: .color(.brown.opacity(0.25)))
                ctx.stroke(bag, with: .color(.brown), lineWidth: 2.5)
                let total = red + blue
                let cols = max(1, Int(ceil(sqrt(Double(total) * 1.6))))
                let rows = Int(ceil(Double(total) / Double(cols)))
                let cell = min(w * 0.52 / CGFloat(cols), h * 0.66 / CGFloat(max(rows, 1)))
                for i in 0..<total {
                    let row = i / cols, col = i % cols
                    let x = w / 2 - CGFloat(cols) * cell / 2 + (CGFloat(col) + 0.5) * cell
                    let y = h * 0.2 + (CGFloat(row) + 0.5) * cell
                    let r = cell * 0.4
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)), with: .color(i < red ? .red : .blue))
                }
                text("\(red) red · \(blue) blue", CGPoint(x: w / 2, y: h * 0.96), .white, size: 13, bold: false)
            case .rectangleUnder, .tangentTriangle:
                break
            }
        }
        .accessibilityLabel("Sketch of the situation")
    }
}

/// Geometry drawings: circles with chords and tangents, solids in space
/// (already projected), conics on axes and the complex plane. Same scale on
/// both axes so angles and circles look right.
struct GeoFigureView: View {
    let figure: GeoFigure

    var body: some View { mathBody.mathDirection() }

    private func color(_ s: GeoFigure.Style) -> Color {
        switch s {
        case .solid: .white
        case .dashed: .white.opacity(0.75)
        case .arrow: .cyan
        case .highlight: .yellow
        case .faint: .gray.opacity(0.55)
        }
    }

    private var bounds: CGRect {
        if let w = figure.window, w.count == 4 { return CGRect(x: w[0], y: w[2], width: w[1] - w[0], height: w[3] - w[2]) }
        var xs = figure.points.map(\.x), ys = figure.points.map(\.y)
        for c in figure.circles { xs += [c.cx - c.r, c.cx + c.r]; ys += [c.cy - c.r, c.cy + c.r] }
        for c in figure.curves {
            for i in stride(from: 0, to: c.xy.count - 1, by: 2) { xs.append(c.xy[i]); ys.append(c.xy[i + 1]) }
        }
        if figure.axes != nil { xs.append(0); ys.append(0) }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { return CGRect(x: -1, y: -1, width: 2, height: 2) }
        let w = max(x1 - x0, 1e-3), h = max(y1 - y0, 1e-3)
        return CGRect(x: x0 - 0.08 * w, y: y0 - 0.08 * h, width: w * 1.16, height: h * 1.16)
    }

    @ViewBuilder
    private var mathBody: some View {
        Canvas { ctx, size in
            let b = bounds
            let pad: CGFloat = 22
            let scale = min((size.width - 2 * pad) / b.width, (size.height - 2 * pad) / b.height)
            let ox = (size.width - b.width * scale) / 2, oy = (size.height - b.height * scale) / 2
            func map(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + (x - b.minX) * scale, y: size.height - oy - (y - b.minY) * scale) }
            let pts = figure.points.map { map($0.x, $0.y) }
            let centre = pts.isEmpty ? CGPoint(x: size.width / 2, y: size.height / 2)
                : CGPoint(x: pts.map(\.x).reduce(0, +) / CGFloat(pts.count), y: pts.map(\.y).reduce(0, +) / CGFloat(pts.count))
            func away(_ q: CGPoint, from c: CGPoint, by d: CGFloat) -> CGPoint {
                let dx = q.x - c.x, dy = q.y - c.y, l = hypot(dx, dy)
                guard l > 1e-3 else { return CGPoint(x: q.x + d * 0.7, y: q.y - d * 0.7) }
                return CGPoint(x: q.x + dx / l * d, y: q.y + dy / l * d)
            }
            func text(_ s: String, _ at: CGPoint, _ c: Color, size: CGFloat = 14, bold: Bool = true) {
                ctx.draw(ctx.resolve(Text(verbatim: s).font(.system(size: size, weight: bold ? .bold : .semibold, design: .serif)).foregroundColor(c)), at: at)
            }
            func stroke(_ path: Path, _ s: GeoFigure.Style, width: CGFloat = 2) {
                let dash: [CGFloat] = s == .dashed || s == .faint ? [6, 4] : []
                ctx.stroke(path, with: .color(color(s)), style: StrokeStyle(lineWidth: s == .faint ? 1.2 : width, lineCap: .round, lineJoin: .round, dash: dash))
            }
            func arrowHead(_ from: CGPoint, _ to: CGPoint, _ c: Color) {
                let a = atan2(to.y - from.y, to.x - from.x), l: CGFloat = 10
                var head = Path()
                head.move(to: to)
                head.addLine(to: CGPoint(x: to.x - l * cos(a - 0.4), y: to.y - l * sin(a - 0.4)))
                head.addLine(to: CGPoint(x: to.x - l * cos(a + 0.4), y: to.y - l * sin(a + 0.4)))
                head.closeSubpath()
                ctx.fill(head, with: .color(c))
            }

            // Axes.
            if let names = figure.axes {
                let gray = Color.white.opacity(0.35)
                let left = map(b.minX, 0), right = map(b.maxX, 0), bottom = map(0, b.minY), top = map(0, b.maxY)
                ctx.stroke(Path { $0.move(to: left); $0.addLine(to: right) }, with: .color(gray), lineWidth: 1)
                ctx.stroke(Path { $0.move(to: bottom); $0.addLine(to: top) }, with: .color(gray), lineWidth: 1)
                arrowHead(left, right, gray); arrowHead(bottom, top, gray)
                text(names[safe: 0] ?? "x", CGPoint(x: right.x - 10, y: right.y + 12), gray, size: 12)
                text(names[safe: 1] ?? "y", CGPoint(x: top.x + 14, y: top.y + 8), gray, size: 12)
                // Unit ticks when they are not too dense.
                let unit = scale
                if unit >= 9 {
                    var t = ceil(b.minX)
                    while t <= b.maxX { if t != 0 { let p = map(t, 0); ctx.stroke(Path { $0.move(to: CGPoint(x: p.x, y: p.y - 3)); $0.addLine(to: CGPoint(x: p.x, y: p.y + 3)) }, with: .color(gray), lineWidth: 1) }; t += 1 }
                    t = ceil(b.minY)
                    while t <= b.maxY { if t != 0 { let p = map(0, t); ctx.stroke(Path { $0.move(to: CGPoint(x: p.x - 3, y: p.y)); $0.addLine(to: CGPoint(x: p.x + 3, y: p.y)) }, with: .color(gray), lineWidth: 1) }; t += 1 }
                }
            }
            // Filled regions first, then curves.
            for c in figure.curves where c.xy.count >= 4 {
                var path = Path()
                path.move(to: map(c.xy[0], c.xy[1]))
                for i in stride(from: 2, to: c.xy.count - 1, by: 2) { path.addLine(to: map(c.xy[i], c.xy[i + 1])) }
                if c.fill {
                    path.closeSubpath()
                    ctx.fill(path, with: .color(.orange.opacity(0.22)))
                } else {
                    stroke(path, c.style, width: c.style == .highlight ? 2.4 : 2)
                    if let l = c.label { text(l, map(c.xy[c.xy.count - 2], c.xy[c.xy.count - 1]), color(c.style), size: 12) }
                }
            }
            for c in figure.circles {
                let p = map(c.cx, c.cy), r = c.r * scale
                stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), c.style, width: 2.2)
            }
            for s in figure.segments {
                guard let a = pts[safe: s.a], let e = pts[safe: s.b] else { continue }
                stroke(Path { $0.move(to: a); $0.addLine(to: e) }, s.style, width: s.style == .highlight ? 3 : 2.2)
                if s.style == .arrow { arrowHead(a, e, color(.arrow)) }
                if let l = s.label {
                    let mid = CGPoint(x: (a.x + e.x) / 2, y: (a.y + e.y) / 2)
                    // Beside the segment, on the side away from the middle of the drawing.
                    let nx = -(e.y - a.y), ny = e.x - a.x, nl = max(hypot(nx, ny), 1e-3)
                    var off = CGPoint(x: nx / nl * 13, y: ny / nl * 13)
                    if (mid.x + off.x - centre.x) * off.x + (mid.y + off.y - centre.y) * off.y < 0 { off = CGPoint(x: -off.x, y: -off.y) }
                    text(l, CGPoint(x: mid.x + off.x, y: mid.y + off.y), l == "?" ? .yellow : .white)
                }
            }
            for a in figure.angles {
                guard let v = pts[safe: a.vertex], let p1 = pts[safe: a.from], let p2 = pts[safe: a.to] else { continue }
                let a1 = atan2(p1.y - v.y, p1.x - v.x), a2 = atan2(p2.y - v.y, p2.x - v.x)
                var d = a2 - a1
                while d > .pi { d -= 2 * .pi }
                while d <= -.pi { d += 2 * .pi }
                let r: CGFloat = min(20, 0.4 * min(hypot(p1.x - v.x, p1.y - v.y), hypot(p2.x - v.x, p2.y - v.y)))
                let c: Color = a.label == "?" ? .yellow : .orange
                if a.label == "90°" {
                    let u1 = CGPoint(x: cos(a1) * 10, y: sin(a1) * 10), u2 = CGPoint(x: cos(a2) * 10, y: sin(a2) * 10)
                    ctx.stroke(Path { $0.move(to: CGPoint(x: v.x + u1.x, y: v.y + u1.y)); $0.addLine(to: CGPoint(x: v.x + u1.x + u2.x, y: v.y + u1.y + u2.y)); $0.addLine(to: CGPoint(x: v.x + u2.x, y: v.y + u2.y)) },
                               with: .color(c), lineWidth: 1.6)
                    continue
                }
                var arc = Path()
                for i in 0...16 {
                    let t = a1 + d * Double(i) / 16
                    let q = CGPoint(x: v.x + r * cos(t), y: v.y + r * sin(t))
                    if i == 0 { arc.move(to: q) } else { arc.addLine(to: q) }
                }
                ctx.stroke(arc, with: .color(c), lineWidth: 1.8)
                let mid = a1 + d / 2
                text(a.label, CGPoint(x: v.x + (r + 14) * cos(mid), y: v.y + (r + 14) * sin(mid)), c, size: 13)
            }
            for (i, p) in figure.points.enumerated() {
                let q = pts[i]
                let c: Color = p.highlight ? .yellow : .white
                if p.dot { ctx.fill(Path(ellipseIn: CGRect(x: q.x - 3.5, y: q.y - 3.5, width: 7, height: 7)), with: .color(c)) }
                if !p.label.isEmpty { text(p.label, away(q, from: centre, by: 14), p.dot ? c : .gray, size: p.dot ? 15 : 12) }
            }
        }
        .accessibilityLabel("Drawing of the question")
    }
}
