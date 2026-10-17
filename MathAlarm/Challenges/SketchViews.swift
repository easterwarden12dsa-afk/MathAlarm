import SwiftUI
import MathEngine

enum SketchTool: String, CaseIterable, Identifiable {
    case draw, erase
    var id: String { rawValue }
}

/// Drawing canvas with labelled axes for Graph Sketch and Change.
/// Strokes are stored in function coordinates (x, y), not screen points.
struct SketchCanvas: View {
    let problem: SketchProblem
    @Binding var strokes: [SketchStroke]
    var tool: SketchTool = .draw
    var regions: [SketchRegion] = []
    /// Practice only: draw the true graph (never during an alarm).
    var revealTruth = false
    /// Show the true graph only inside these x-ranges (per-correction reveal).
    var revealRanges: [ClosedRange<Double>] = []
    /// Change challenge: the given graph f, drawn faintly behind.
    var reference: SketchProblem? = nil
    var showYScale = true
    /// Called before each drawing/erasing gesture changes the strokes (for Undo).
    var willChange: () -> Void = {}

    @State private var current: SketchStroke = []
    @State private var eraserAt: CGPoint?
    @State private var gestureActive = false

    private let insets = EdgeInsets(top: 12, leading: 46, bottom: 30, trailing: 14)
    private let eraserRadius: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let plot = CGRect(x: insets.leading, y: insets.top,
                              width: geo.size.width - insets.leading - insets.trailing,
                              height: geo.size.height - insets.top - insets.bottom)
            let map = Mapping(problem: problem, plot: plot)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawAxes(ctx, map)
                    for r in regions { drawRegion(ctx, map, r) }
                    if let reference { drawCurve(ctx, map, reference, color: .white.opacity(0.45), dash: [], width: 2.5) }
                    if revealTruth { drawCurve(ctx, map, problem, color: .green.opacity(0.85), dash: [6, 4], width: 2.5) }
                    for r in revealRanges { drawCurve(ctx, map, problem, color: .green, dash: [6, 4], width: 3, within: r) }
                    for s in strokes + [current] { drawStroke(ctx, map, s) }
                    if let eraserAt {
                        let circle = Path(ellipseIn: CGRect(x: eraserAt.x - eraserRadius, y: eraserAt.y - eraserRadius,
                                                            width: 2 * eraserRadius, height: 2 * eraserRadius))
                        ctx.fill(circle, with: .color(.white.opacity(0.12)))
                        ctx.stroke(circle, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
                    }
                }
                labels(map)
                regionBadges(map)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !gestureActive {
                            gestureActive = true
                            willChange()
                        }
                        switch tool {
                        case .draw:
                            current.append(map.point(value.location))
                        case .erase:
                            eraserAt = value.location
                            let rx = Double(eraserRadius / plot.width) * (problem.xMax - problem.xMin)
                            let ry = Double(eraserRadius / plot.height) * (problem.yMax - problem.yMin)
                            strokes = SketchEraser.erase(strokes, around: map.point(value.location), rx: rx, ry: ry)
                        }
                    }
                    .onEnded { _ in
                        gestureActive = false
                        if !current.isEmpty { strokes.append(current) }
                        current = []
                        eraserAt = nil
                    }
            )
        }
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Drawing area for the graph")
    }

    // MARK: Coordinates

    struct Mapping {
        let problem: SketchProblem
        let plot: CGRect

        func screen(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: plot.minX + (x - problem.xMin) / (problem.xMax - problem.xMin) * plot.width,
                    y: plot.minY + (problem.yMax - y) / (problem.yMax - problem.yMin) * plot.height)
        }

        func point(_ p: CGPoint) -> SketchPoint {
            SketchPoint(x: problem.xMin + Double((p.x - plot.minX) / plot.width) * (problem.xMax - problem.xMin),
                        y: problem.yMax - Double((p.y - plot.minY) / plot.height) * (problem.yMax - problem.yMin))
        }
    }

    // MARK: Drawing

    private func drawAxes(_ ctx: GraphicsContext, _ m: Mapping) {
        let grid = Color.white.opacity(0.08)
        for i in 0...8 {
            let x = m.plot.minX + m.plot.width * CGFloat(i) / 8
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: m.plot.minY)); $0.addLine(to: CGPoint(x: x, y: m.plot.maxY)) }, with: .color(grid))
        }
        if showYScale {
            for t in yTicks {
                let y = m.screen(problem.xMin, t).y
                ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX, y: y)); $0.addLine(to: CGPoint(x: m.plot.maxX, y: y)) }, with: .color(grid))
            }
        }
        ctx.stroke(Path(m.plot), with: .color(.white.opacity(0.25)), lineWidth: 1)
        if problem.yMin < 0 && problem.yMax > 0 {
            let y = m.screen(0, 0).y
            ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX, y: y)); $0.addLine(to: CGPoint(x: m.plot.maxX, y: y)) },
                       with: .color(.white.opacity(0.75)), lineWidth: 1.5)
        }
        if problem.xMin < 0 && problem.xMax > 0 {
            let x = m.screen(0, 0).x
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: m.plot.minY)); $0.addLine(to: CGPoint(x: x, y: m.plot.maxY)) },
                       with: .color(.white.opacity(0.75)), lineWidth: 1.5)
        }
        for x in xTicks {
            let p = m.screen(x, problem.yMin)
            ctx.stroke(Path { $0.move(to: CGPoint(x: p.x, y: m.plot.maxY)); $0.addLine(to: CGPoint(x: p.x, y: m.plot.maxY + 6)) },
                       with: .color(.white), lineWidth: 2)
        }
        if showYScale {
            for t in yTicks {
                let y = m.screen(problem.xMin, t).y
                ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX - 6, y: y)); $0.addLine(to: CGPoint(x: m.plot.minX, y: y)) },
                           with: .color(.white), lineWidth: 2)
            }
        }
    }

    private func regionRect(_ m: Mapping, _ r: SketchRegion) -> CGRect {
        let x1 = m.screen(Swift.max(r.lo, problem.xMin), 0).x
        let x2 = m.screen(Swift.min(r.hi, problem.xMax), 0).x
        return CGRect(x: x1, y: m.plot.minY, width: Swift.max(6, x2 - x1), height: m.plot.height)
    }

    private func drawRegion(_ ctx: GraphicsContext, _ m: Mapping, _ r: SketchRegion) {
        let rect = regionRect(m, r)
        let color = SketchRegionStyle.color(r.issue)
        ctx.fill(Path(rect), with: .color(color.opacity(0.2)))
        ctx.stroke(Path(rect), with: .color(color.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
    }

    private func drawStroke(_ ctx: GraphicsContext, _ m: Mapping, _ s: SketchStroke) {
        guard let first = s.first else { return }
        var path = Path()
        path.move(to: m.screen(first.x, first.y))
        for p in s.dropFirst() { path.addLine(to: m.screen(p.x, p.y)) }
        if s.count == 1 { path.addEllipse(in: CGRect(origin: m.screen(first.x, first.y), size: .zero).insetBy(dx: -2, dy: -2)) }
        ctx.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }

    private func drawCurve(_ ctx: GraphicsContext, _ m: Mapping, _ p: SketchProblem, color: Color, dash: [CGFloat], width: CGFloat,
                           within range: ClosedRange<Double>? = nil) {
        var path = Path()
        var started = false
        let lo = Swift.max(p.xMin, range?.lowerBound ?? p.xMin), hi = Swift.min(p.xMax, range?.upperBound ?? p.xMax)
        guard hi > lo else { return }
        for i in 0...240 {
            let x = lo + (hi - lo) * Double(i) / 240
            let y = p.value(at: x)
            guard y.isFinite else { started = false; continue }
            let pt = m.screen(x, y)
            if started { path.addLine(to: pt) } else { path.move(to: pt); started = true }
        }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
    }

    /// Number badge + arrow in each band, matching the numbered hint list.
    private func regionBadges(_ m: Mapping) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(regions.enumerated()), id: \.offset) { index, r in
                let rect = regionRect(m, r)
                VStack(spacing: 4) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                        .frame(width: 22, height: 22)
                        .background(SketchRegionStyle.color(r.issue), in: Circle())
                    Image(systemName: SketchRegionStyle.symbol(r.issue))
                        .font(.title3.bold())
                        .foregroundStyle(SketchRegionStyle.color(r.issue))
                }
                .position(x: rect.midX, y: rect.minY + 30)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Labels

    private var xTicks: [Double] {
        var ticks = [problem.xMin, problem.xMax]
        if problem.xMin < 0 && problem.xMax > 0 { ticks.append(0) }
        let mid = (problem.xMin + problem.xMax) / 2
        if !(problem.xMin < 0 && problem.xMax > 0) || Swift.abs(mid) > 1e-9 { ticks.append(mid) }
        return ticks
    }

    private var yTicks: [Double] {
        let lo = problem.yMin, hi = problem.yMax
        let raw = (hi - lo) / 4
        let mag = pow(10, floor(log10(raw)))
        let step = [1.0, 2, 2.5, 5, 10].map { $0 * mag }.first { $0 >= raw } ?? raw
        var ticks: [Double] = []
        var t = (lo / step).rounded(.up) * step
        while t <= hi + 1e-9 { ticks.append(Swift.abs(t) < step * 1e-6 ? 0 : t); t += step }
        return ticks
    }

    private func labels(_ m: Mapping) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(xTicks, id: \.self) { x in
                Text(problem.xLabel(x))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .fixedSize()
                    .position(x: m.screen(x, 0).x, y: m.plot.maxY + 18)
            }
            if showYScale {
                ForEach(yTicks, id: \.self) { y in
                    Text(SketchFormat.number(y))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                        .fixedSize()
                        .position(x: m.plot.minX - 24, y: m.screen(0, y).y)
                }
            } else if problem.yMin < 0 && problem.yMax > 0 {
                Text("0")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .position(x: m.plot.minX - 12, y: m.screen(0, 0).y)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Graph Sketch / Change: header, canvas, a Liquid Glass toolbar
/// (Draw / Erase, Undo, Clear) and a row with Steps, Submit and Reveal. Corrections are numbered; the true curve is never shown during
/// an alarm.
struct SketchChallengeView<Header: View>: View {
    let problem: SketchProblem
    @Binding var strokes: [SketchStroke]
    var mode: SketchMode = .standard
    var reference: SketchProblem? = nil
    var allowReveal = false
    /// Worked "how to draw it" solution (computed only when opened).
    var steps: (() -> [SolutionStep])? = nil
    /// Ringing screen: viewing the steps swaps in a new problem afterwards.
    var onSolutionViewed: (() -> Void)? = nil
    /// Each correction gets a "show the correct graph here" button.
    var allowZoneReveal = true
    var onSolved: () -> Void
    @ViewBuilder var header: Header

    @State private var result: SketchResult?
    @State private var solved = false
    @State private var reveal = false
    @State private var shakes: CGFloat = 0
    @State private var tool: SketchTool = .draw
    @State private var history: [[SketchStroke]] = []
    @State private var showSteps = false
    @State private var confirmSteps = false
    @State private var revealed: [ClosedRange<Double>] = []

    var body: some View {
        VStack(spacing: 8) {
            header
            // The canvas takes whatever height is left, so the controls below never get pushed off screen.
            SketchCanvas(problem: problem, strokes: $strokes, tool: tool,
                         regions: result?.passed == false ? result!.regions : [],
                         revealTruth: reveal, revealRanges: revealed, reference: reference, showYScale: mode.showsYScale,
                         willChange: { history.append(strokes); if history.count > 60 { history.removeFirst() } })
                .frame(minHeight: 140, maxHeight: .infinity)
                .layoutPriority(-1)
                .modifier(Shake(animatableData: shakes))

            feedback

            GlassEffectContainer(spacing: 8) {
                VStack(spacing: 8) {
                    toolbar
                    submitRow
                }
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showSteps, onDismiss: { onSolutionViewed?() }) {
            GraphSolutionSheet(problem: problem, reference: reference, steps: steps?() ?? [],
                               warning: onSolutionViewed == nil ? nil : "After you close this, you'll get a new problem of the same kind to draw.")
        }
        .confirmationDialog("Show how to draw it?", isPresented: $confirmSteps, titleVisibility: .visible) {
            Button("Show steps (new problem after)") { showSteps = true }
            Button("Keep trying", role: .cancel) {}
        } message: {
            Text("The alarm still needs a solved problem, so you'll get a fresh one afterwards.")
        }
    }

    // MARK: Toolbar

    /// Draw / Erase on the left, Undo / Clear on the right. Falls back to
    /// icons only if the labelled version doesn't fit the width.
    private var toolbar: some View {
        ViewThatFits(in: .horizontal) {
            toolRow(labelled: true)
            toolRow(labelled: false)
        }
    }

    private func toolRow(labelled: Bool) -> some View {
        HStack(spacing: 8) {
            toolButton(.draw, "pencil.tip", "Draw", labelled: labelled)
            toolButton(.erase, "eraser", "Erase", labelled: labelled)
            Spacer(minLength: 0)
            iconButton("arrow.uturn.backward", "Undo") {
                if let last = history.popLast() { strokes = last } else if !strokes.isEmpty { strokes.removeLast() }
            }
            .disabled(history.isEmpty && strokes.isEmpty)
            iconButton("trash", "Clear") {
                history.append(strokes)
                strokes = []
                result = nil
                revealed = []
            }
            .disabled(strokes.isEmpty)
        }
    }

    /// Steps (left), Submit (wide, middle), Reveal (right).
    private var submitRow: some View {
        HStack(spacing: 8) {
            if steps != nil {
                iconButton("list.number", "How to draw it") {
                    if onSolutionViewed == nil { showSteps = true } else { confirmSteps = true }
                }
            }
            Button(action: submit) {
                Label(solved ? "Correct!" : "Submit", systemImage: solved ? "checkmark" : "checkmark.circle")
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(.glassProminent)
            .tint(solved ? .green : .orange)
            .controlSize(.large)
            .disabled(solved || strokes.isEmpty)
            if allowReveal {
                iconButton(reveal ? "eye.slash" : "eye", reveal ? "Hide graph" : "Show graph") { reveal.toggle() }
            }
        }
    }

    @ViewBuilder
    private func toolButton(_ t: SketchTool, _ symbol: String, _ title: String, labelled: Bool) -> some View {
        let selected = tool == t
        let button = Button {
            Haptics.tap()
            tool = t
        } label: {
            Group {
                if labelled {
                    Label(title, systemImage: symbol)
                } else {
                    Image(systemName: symbol)
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 24, minHeight: 30)
        }
        .controlSize(.large)
        .accessibilityLabel(title)
        if selected {
            button.buttonStyle(.glassProminent).tint(.orange).accessibilityAddTraits(.isSelected)
        } else {
            button.buttonStyle(.glass)
        }
    }

    private func iconButton(_ symbol: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .accessibilityLabel(title)
    }

    // MARK: Feedback

    @ViewBuilder
    private var feedback: some View {
        if let result, !result.passed {
            let rows = VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(result.regions.enumerated()), id: \.offset) { index, region in
                    hintRow(index, region)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // More than two corrections scroll instead of squeezing the canvas away.
            if result.regions.count > 2 {
                ScrollView { rows }
                    .frame(height: 112)
                    .scrollIndicators(.visible)
            } else {
                rows
            }
        } else if solved {
            Label("Great sketch!", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.green)
        } else {
            Text("\(mode.title): \(mode.summary)")
                .font(.footnote).foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func hintRow(_ index: Int, _ region: SketchRegion) -> some View {
        HStack(spacing: 6) {
            Text("\(index + 1)")
                .font(.caption.bold())
                .foregroundStyle(.black)
                .frame(width: 20, height: 20)
                .background(SketchRegionStyle.color(region.issue), in: Circle())
            Text(region.hint)
                .font(.footnote)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            // Fix this zone: erase just here, and optionally peek at the right curve here.
            Button {
                Haptics.tap()
                history.append(strokes)
                strokes = SketchEraser.erase(strokes, xFrom: region.lo, to: region.hi)
            } label: {
                Image(systemName: "eraser").font(.footnote.weight(.semibold)).frame(width: 18, height: 18)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Erase zone \(index + 1)")
            if allowZoneReveal {
                let range = region.lo...region.hi
                let shown = revealed.contains(range)
                Button {
                    Haptics.tap()
                    if shown { revealed.removeAll { $0 == range } } else { revealed.append(range) }
                } label: {
                    Image(systemName: shown ? "eye.slash" : "eye").font(.footnote.weight(.semibold)).frame(width: 18, height: 18)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .tint(shown ? Color.green : nil)
                .accessibilityLabel(shown ? "Hide correct graph in zone \(index + 1)" : "Show correct graph in zone \(index + 1)")
            }
        }
    }

    private func submit() {
        let r = SketchChecker.check(strokes, for: problem, mode: mode)
        withAnimation { result = r }
        if r.passed {
            solved = true
            Haptics.success()
            Task {
                try? await Task.sleep(nanoseconds: 800_000_000)
                onSolved()
            }
        } else {
            Haptics.error()
            withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        }
    }
}

/// Header for a plain Graph Sketch problem: a quiet caption, the formula
/// as the hero, and the interval — no coloured card.
struct SketchHeader: View {
    let problem: SketchProblem

    var body: some View {
        VStack(spacing: 2) {
            FittedMath(sizes: [26, 23, 20, 18, 16, 14]) { size in
                HStack(alignment: .mathAxis, spacing: size * 0.25) {
                    Text("y =").font(MathFont.italic(size))
                    MathRowView(row: ExprDisplay.row(problem.function), size: size, mergeFunctionPowers: true)
                }
                .foregroundStyle(.white)
            }
            Text("Sketch for \(problem.xLabel(problem.xMin)) ≤ x ≤ \(problem.xLabel(problem.xMax))")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Header for a "Change" problem: what to draw is the hero; f's formula
/// (if shown) is secondary.
struct ChangeHeader: View {
    let change: ChangeProblem
    let display: AppSettings.ChangeDisplay

    var body: some View {
        VStack(spacing: 2) {
            Text(change.transform.formula)
                .font(.system(size: 24, weight: .medium, design: .serif))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if display.showsFormula {
                FittedMath(sizes: [18, 16, 14, 13, 12, 11]) { size in
                    HStack(alignment: .mathAxis, spacing: size * 0.25) {
                        Text("where f(x) =").font(MathFont.italic(size))
                        MathRowView(row: ExprDisplay.row(change.base.function), size: size, mergeFunctionPowers: true)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            Text(display.showsGraph
                 ? "Grey = f · draw g for \(change.target.xLabel(change.target.xMin)) ≤ x ≤ \(change.target.xLabel(change.target.xMax))"
                 : "Draw g for \(change.target.xLabel(change.target.xMin)) ≤ x ≤ \(change.target.xLabel(change.target.xMax))")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// System colours and arrows for each kind of sketch correction.
enum SketchRegionStyle {
    static func color(_ issue: SketchRegion.Issue) -> Color {
        switch issue {
        case .tooHigh: .red
        case .tooLow: .blue
        case .shouldRise, .shouldFall: .purple
        case .missingFeature: .yellow
        case .notDrawn: .gray
        }
    }

    static func symbol(_ issue: SketchRegion.Issue) -> String {
        switch issue {
        case .tooHigh: "arrow.down"
        case .tooLow: "arrow.up"
        case .shouldRise: "arrow.up.right"
        case .shouldFall: "arrow.down.right"
        case .missingFeature: "scope"
        case .notDrawn: "pencil.and.scribble"
        }
    }
}

/// "How to draw it": the investigation steps plus the finished graph.
struct GraphSolutionSheet: View {
    let problem: SketchProblem
    var reference: SketchProblem? = nil
    let steps: [SolutionStep]
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
                    StepsList(steps: steps)
                    Text("The finished graph (green\(reference == nil ? "" : "; f in grey")):")
                        .font(.subheadline.weight(.semibold))
                    SketchCanvas(problem: problem, strokes: .constant([]), revealTruth: true, reference: reference)
                        .frame(height: 260)
                        .allowsHitTesting(false)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("How to draw it")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}
