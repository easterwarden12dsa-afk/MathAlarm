import SwiftUI
import MathEngine

/// Drawing canvas with labelled axes for the Graph Sketch challenge.
/// Strokes are stored in function coordinates (x, y), not screen points.
struct SketchCanvas: View {
    let problem: SketchProblem
    @Binding var strokes: [SketchStroke]
    var regions: [SketchRegion] = []
    /// Practice only: draw the true graph (never during an alarm).
    var revealTruth = false

    @State private var current: SketchStroke = []

    private let insets = EdgeInsets(top: 12, leading: 46, bottom: 30, trailing: 14)

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
                    if revealTruth { drawTruth(ctx, map) }
                    for s in strokes + [current] { drawStroke(ctx, map, s) }
                }
                labels(map)
                regionBadges(map)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        current.append(map.point(value.location))
                    }
                    .onEnded { _ in
                        if !current.isEmpty { strokes.append(current) }
                        current = []
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
        for t in yTicks {
            let y = m.screen(problem.xMin, t).y
            ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX, y: y)); $0.addLine(to: CGPoint(x: m.plot.maxX, y: y)) }, with: .color(grid))
        }
        // Frame
        ctx.stroke(Path(m.plot), with: .color(.white.opacity(0.25)), lineWidth: 1)
        // x-axis (y = 0) and y-axis (x = 0) when visible
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
        // Tick marks at the interval ends (and 0)
        for x in xTicks {
            let p = m.screen(x, problem.yMin)
            ctx.stroke(Path { $0.move(to: CGPoint(x: p.x, y: m.plot.maxY)); $0.addLine(to: CGPoint(x: p.x, y: m.plot.maxY + 6)) },
                       with: .color(.white), lineWidth: 2)
        }
        for t in yTicks {
            let y = m.screen(problem.xMin, t).y
            ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX - 6, y: y)); $0.addLine(to: CGPoint(x: m.plot.minX, y: y)) },
                       with: .color(.white), lineWidth: 2)
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

    private func drawStroke(_ ctx: GraphicsContext, _ m: Mapping, _ s: SketchStroke) {
        guard let first = s.first else { return }
        var path = Path()
        path.move(to: m.screen(first.x, first.y))
        for p in s.dropFirst() { path.addLine(to: m.screen(p.x, p.y)) }
        if s.count == 1 { path.addEllipse(in: CGRect(origin: m.screen(first.x, first.y), size: .zero).insetBy(dx: -2, dy: -2)) }
        ctx.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
    }

    private func drawTruth(_ ctx: GraphicsContext, _ m: Mapping) {
        var path = Path()
        for i in 0...200 {
            let x = problem.xMin + (problem.xMax - problem.xMin) * Double(i) / 200
            let p = m.screen(x, problem.value(at: x))
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        ctx.stroke(path, with: .color(.green.opacity(0.85)), style: StrokeStyle(lineWidth: 2.5, dash: [6, 4]))
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
            ForEach(yTicks, id: \.self) { y in
                Text(SketchFormat.number(y))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize()
                    .position(x: m.plot.minX - 24, y: m.screen(0, y).y)
            }
        }
        .allowsHitTesting(false)
    }
}

/// The Graph Sketch challenge: problem, canvas, Undo / Clear / Submit, and
/// feedback bands + hints when the sketch is off (never the true curve).
struct SketchChallengeView: View {
    let problem: SketchProblem
    @Binding var strokes: [SketchStroke]
    var tolerance: SketchTolerance = .moderate
    var allowReveal = false
    var onSolved: () -> Void

    @State private var result: SketchResult?
    @State private var solved = false
    @State private var reveal = false
    @State private var shakes: CGFloat = 0

    var body: some View {
        VStack(spacing: 8) {
            header
            SketchCanvas(problem: problem, strokes: $strokes,
                         regions: result?.passed == false ? result!.regions : [],
                         revealTruth: reveal)
                .frame(maxHeight: .infinity)
                .modifier(Shake(animatableData: shakes))

            if let result, !result.passed {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(result.regions.enumerated()), id: \.offset) { index, region in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.black)
                                .frame(width: 20, height: 20)
                                .background(SketchRegionStyle.color(region.issue), in: Circle())
                            Text(region.hint)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SketchRegionStyle.color(region.issue))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Keep editing — Undo removes your last stroke.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if solved {
                Label("Great sketch!", systemImage: "checkmark.circle.fill")
                    .font(.headline).foregroundStyle(.green)
            } else {
                Text("Draw the graph with your finger. Several strokes are fine.")
                    .font(.footnote).foregroundStyle(.white.opacity(0.6))
            }

            HStack(spacing: 10) {
                Button {
                    Haptics.tap()
                    if !strokes.isEmpty { strokes.removeLast() }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color(white: 0.25), in: RoundedRectangle(cornerRadius: 12))
                }
                Button {
                    Haptics.tap()
                    strokes = []
                    result = nil
                } label: {
                    Label("Clear", systemImage: "trash")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color(red: 0.45, green: 0.16, blue: 0.16), in: RoundedRectangle(cornerRadius: 12))
                }
                if allowReveal {
                    Button {
                        Haptics.tap()
                        reveal.toggle()
                    } label: {
                        Label(reveal ? "Hide" : "Reveal", systemImage: reveal ? "eye.slash" : "eye")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color(red: 0.16, green: 0.30, blue: 0.42), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .buttonStyle(PressableStyle())

            Button(action: submit) {
                Label(solved ? "Correct!" : "Submit sketch", systemImage: solved ? "checkmark" : "checkmark.circle")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(solved ? Color.green : Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
            .disabled(solved || strokes.isEmpty)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Sketch the graph").font(.headline).foregroundStyle(.orange)
            FittedMath(sizes: [26, 23, 20, 17, 15, 13]) { size in
                HStack(alignment: .mathAxis, spacing: size * 0.25) {
                    Text("y =").font(MathFont.italic(size))
                    MathRowView(row: ExprDisplay.row(problem.function), size: size, mergeFunctionPowers: true)
                }
                .foregroundStyle(.white)
            }
            Text("for \(problem.xLabel(problem.xMin)) ≤ x ≤ \(problem.xLabel(problem.xMax))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
    }

    private func submit() {
        let r = SketchChecker.check(strokes, for: problem, tolerance: tolerance)
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

/// Colours and arrows for each kind of sketch correction.
enum SketchRegionStyle {
    static func color(_ issue: SketchRegion.Issue) -> Color {
        switch issue {
        case .tooHigh: Color(red: 1.0, green: 0.35, blue: 0.35)
        case .tooLow: Color(red: 0.35, green: 0.65, blue: 1.0)
        case .shouldRise, .shouldFall: Color(red: 0.75, green: 0.5, blue: 1.0)
        case .missingFeature: Color(red: 1.0, green: 0.85, blue: 0.2)
        case .notDrawn: Color(white: 0.7)
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
