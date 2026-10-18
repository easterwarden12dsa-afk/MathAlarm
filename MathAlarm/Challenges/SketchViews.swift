import SwiftUI
import MathEngine

enum SketchTool: String, CaseIterable, Identifiable {
    case draw, erase, pan
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
    /// Per-correction reveal: the true shape in a zone, fitted to the drawing.
    var guides: [SketchStroke] = []
    /// Lettered points (Change solutions: A on f, A′ on g).
    var markers: [GraphMarker] = []
    /// Change challenge: the given graph f, drawn faintly behind.
    var reference: SketchProblem? = nil
    var showYScale = true
    /// Called before each drawing/erasing gesture changes the strokes (for Undo).
    var willChange: () -> Void = {}
    /// Whole-graph problems: the visible window (nil = the problem's own), changed by pinch, Move and the zoom buttons.
    var viewport: Binding<SketchViewport?> = .constant(nil)
    var zoomable = false
    /// Your own dashed helper lines (asymptotes etc.) — not checked.
    var guidelines: [Guideline] = []
    /// Quiz graphs: the function drawn solid in this colour.
    var curveColor: Color? = nil
    /// Quiz graphs: an area shaded between the curve and the x-axis (or `shadeLower`).
    var shade: ClosedRange<Double>? = nil
    var shadeLower: SketchProblem? = nil
    /// Quiz graphs: the line y = k.
    var hline: Double? = nil
    /// Quiz graphs: shapes drawn on top, each a flat list x0, y0, x1, y1, … (closed and filled).
    var overlayPolygons: [[Double]] = []

    @State private var zoomStart: SketchViewport?
    @State private var panStart: SketchViewport?
    @State private var zooming = false

    /// The problem as currently seen (zoomed/panned).
    private var shown: SketchProblem { viewport.wrappedValue.map { problem.windowed($0) } ?? problem }

    @State private var current: SketchStroke = []
    @State private var eraserAt: CGPoint?
    @State private var gestureActive = false

    private let insets = EdgeInsets(top: 12, leading: 46, bottom: 30, trailing: 14)
    private let eraserRadius: CGFloat = 22

    var body: some View { mathBody.mathDirection() }

    @ViewBuilder
    private var mathBody: some View {
        GeometryReader { geo in
            let plot = CGRect(x: insets.leading, y: insets.top,
                              width: geo.size.width - insets.leading - insets.trailing,
                              height: geo.size.height - insets.top - insets.bottom)
            let map = Mapping(problem: shown, plot: plot)
            ZStack(alignment: .topLeading) {
                Canvas { ctx, _ in
                    drawAxes(ctx, map)
                    var clipped = ctx
                    clipped.clip(to: Path(map.plot))
                    for r in regions { drawRegion(clipped, map, r) }
                    if let shade { drawShade(clipped, map, shade) }
                    if let shadeLower { drawCurve(clipped, map, shadeLower.windowed(shown.viewport), color: .mint, dash: [], width: 2.5) }
                    if let hline {
                        let y = map.screen(0, hline).y
                        clipped.stroke(Path { $0.move(to: CGPoint(x: map.plot.minX, y: y)); $0.addLine(to: CGPoint(x: map.plot.maxX, y: y)) },
                                       with: .color(.cyan.opacity(0.85)), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                    }
                    if let curveColor { drawCurve(clipped, map, shown, color: curveColor, dash: [], width: 2.8) }
                    for poly in overlayPolygons where poly.count >= 4 {
                        var path = Path()
                        path.move(to: map.screen(poly[0], poly[1]))
                        for i in stride(from: 2, to: poly.count - 1, by: 2) { path.addLine(to: map.screen(poly[i], poly[i + 1])) }
                        if poly.count >= 6 { path.closeSubpath() }
                        if poly.count >= 6 { clipped.fill(path, with: .color(.orange.opacity(0.22))) }
                        clipped.stroke(path, with: .color(.orange), style: StrokeStyle(lineWidth: 2, lineJoin: .round, dash: poly.count >= 6 ? [] : [6, 4]))
                    }
                    if let reference { drawCurve(clipped, map, reference.windowed(shown.viewport), color: .white.opacity(0.45), dash: [], width: 2.5) }
                    if revealTruth {
                        for c in shown.poles where c > shown.xMin && c < shown.xMax {
                            let x = map.screen(c, 0).x
                            clipped.stroke(Path { $0.move(to: CGPoint(x: x, y: map.plot.minY)); $0.addLine(to: CGPoint(x: x, y: map.plot.maxY)) },
                                           with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                        }
                        drawCurve(clipped, map, shown, color: .green.opacity(0.85), dash: [6, 4], width: 2.5)
                    }
                    for line in guidelines where !line.hidden { drawGuideline(clipped, map, line) }
                    for g in guides { drawGuide(clipped, map, g) }
                    for s in strokes + [current] { drawStroke(clipped, map, s) }
                    if let eraserAt {
                        let circle = Path(ellipseIn: CGRect(x: eraserAt.x - eraserRadius, y: eraserAt.y - eraserRadius,
                                                            width: 2 * eraserRadius, height: 2 * eraserRadius))
                        ctx.fill(circle, with: .color(.white.opacity(0.12)))
                        ctx.stroke(circle, with: .color(.white.opacity(0.8)), lineWidth: 1.5)
                    }
                }
                labels(map)
                regionBadges(map)
                markerLabels(map)
                if zoomable { zoomButtons }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if zooming { return }
                        if tool == .pan {
                            guard zoomable else { return }
                            let start = panStart ?? shown.viewport
                            panStart = start
                            let dx = -Double(value.translation.width / plot.width) * (start.xMax - start.xMin)
                            let dy = Double(value.translation.height / plot.height) * (start.yMax - start.yMin)
                            viewport.wrappedValue = start.moved(dx: dx, dy: dy)
                            return
                        }
                        if !gestureActive {
                            gestureActive = true
                            willChange()
                        }
                        switch tool {
                        case .pan:
                            break
                        case .draw:
                            current.append(map.point(value.location))
                        case .erase:
                            eraserAt = value.location
                            let rx = Double(eraserRadius / plot.width) * (shown.xMax - shown.xMin)
                            let ry = Double(eraserRadius / plot.height) * (shown.yMax - shown.yMin)
                            strokes = SketchEraser.erase(strokes, around: map.point(value.location), rx: rx, ry: ry)
                        }
                    }
                    .onEnded { _ in
                        panStart = nil
                        gestureActive = false
                        if !current.isEmpty && !zooming { strokes.append(current) }
                        current = []
                        eraserAt = nil
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        guard zoomable else { return }
                        zooming = true
                        current = []
                        let start = zoomStart ?? shown.viewport
                        zoomStart = start
                        zoom(to: start.zoomed(Double(value.magnification), around: start.center))
                    }
                    .onEnded { _ in
                        zoomStart = nil
                        zooming = false
                    }
            )
        }
        .background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("Drawing area for the graph")
    }

    // MARK: Zoom

    /// Keeps zooming between 1/8 and 8 times the starting view.
    private func zoom(to v: SketchViewport) {
        let w0 = problem.xMax - problem.xMin
        let w = v.xMax - v.xMin
        guard w > w0 / 8, w < w0 * 8 else { return }
        viewport.wrappedValue = v
    }

    private var zoomButtons: some View {
        VStack(spacing: 6) {
            zoomButton("plus.magnifyingglass", "Zoom in") { zoom(to: shown.viewport.zoomed(1.5, around: shown.viewport.center)) }
            zoomButton("minus.magnifyingglass", "Zoom out") { zoom(to: shown.viewport.zoomed(1 / 1.5, around: shown.viewport.center)) }
            zoomButton("arrow.counterclockwise", "Reset view") { viewport.wrappedValue = nil }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    private func zoomButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(.easeInOut(duration: 0.2)) { action() }
        } label: {
            Image(systemName: symbol).font(.footnote.weight(.semibold)).frame(width: 18, height: 18)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
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
                let y = m.screen(shown.xMin, t).y
                ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX, y: y)); $0.addLine(to: CGPoint(x: m.plot.maxX, y: y)) }, with: .color(grid))
            }
        }
        ctx.stroke(Path(m.plot), with: .color(.white.opacity(0.25)), lineWidth: 1)
        if shown.yMin < 0 && shown.yMax > 0 {
            let y = m.screen(0, 0).y
            ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX, y: y)); $0.addLine(to: CGPoint(x: m.plot.maxX, y: y)) },
                       with: .color(.white.opacity(0.75)), lineWidth: 1.5)
        }
        if shown.xMin < 0 && shown.xMax > 0 {
            let x = m.screen(0, 0).x
            ctx.stroke(Path { $0.move(to: CGPoint(x: x, y: m.plot.minY)); $0.addLine(to: CGPoint(x: x, y: m.plot.maxY)) },
                       with: .color(.white.opacity(0.75)), lineWidth: 1.5)
        }
        for x in xTicks {
            let p = m.screen(x, shown.yMin)
            ctx.stroke(Path { $0.move(to: CGPoint(x: p.x, y: m.plot.maxY)); $0.addLine(to: CGPoint(x: p.x, y: m.plot.maxY + 6)) },
                       with: .color(.white), lineWidth: 2)
        }
        if showYScale {
            for t in yTicks {
                let y = m.screen(shown.xMin, t).y
                ctx.stroke(Path { $0.move(to: CGPoint(x: m.plot.minX - 6, y: y)); $0.addLine(to: CGPoint(x: m.plot.minX, y: y)) },
                           with: .color(.white), lineWidth: 2)
            }
        }
    }

    private func regionRect(_ m: Mapping, _ r: SketchRegion) -> CGRect {
        let x1 = m.screen(Swift.max(r.lo, shown.xMin), 0).x
        let x2 = m.screen(Swift.min(r.hi, shown.xMax), 0).x
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
        let span = p.yMax - p.yMin
        var lastX = lo, lastY = Double.nan
        for i in 0...480 {
            let x = lo + (hi - lo) * Double(i) / 480
            let y = p.value(at: x)
            guard y.isFinite else { started = false; continue }
            // Don't join across a vertical asymptote (or any jump off the box).
            let crossesPole = p.poles.contains { ($0 - lastX) * ($0 - x) <= 0 }
            if started && (crossesPole || Swift.abs(y - lastY) > 2 * span) { started = false }
            let pt = m.screen(x, Swift.max(p.yMin - 3 * span, Swift.min(p.yMax + 3 * span, y)))
            if started { path.addLine(to: pt) } else { path.move(to: pt); started = true }
            lastX = x; lastY = y
        }
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, dash: dash))
    }

    private func drawShade(_ ctx: GraphicsContext, _ m: Mapping, _ range: ClosedRange<Double>) {
        let lo = Swift.max(range.lowerBound, shown.xMin), hi = Swift.min(range.upperBound, shown.xMax)
        guard hi > lo else { return }
        let n = 160
        var path = Path()
        for i in 0...n {
            let x = lo + (hi - lo) * Double(i) / Double(n)
            let y = shown.value(at: x)
            let pt = m.screen(x, y.isFinite ? y : 0)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        for i in stride(from: n, through: 0, by: -1) {
            let x = lo + (hi - lo) * Double(i) / Double(n)
            let y = shadeLower?.value(at: x) ?? 0
            path.addLine(to: m.screen(x, y.isFinite ? y : 0))
        }
        path.closeSubpath()
        ctx.fill(path, with: .color(.yellow.opacity(0.3)))
    }

    private func drawGuide(_ ctx: GraphicsContext, _ m: Mapping, _ g: SketchStroke) {
        guard let first = g.first else { return }
        var path = Path()
        path.move(to: m.screen(first.x, first.y))
        for p in g.dropFirst() { path.addLine(to: m.screen(p.x, p.y)) }
        ctx.stroke(path, with: .color(.green), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 4]))
    }

    private func drawGuideline(_ ctx: GraphicsContext, _ m: Mapping, _ line: Guideline) {
        let p = shown
        var path = Path()
        switch line.kind {
        case .vertical(let c):
            let x = m.screen(c, 0).x
            path.move(to: CGPoint(x: x, y: m.plot.minY)); path.addLine(to: CGPoint(x: x, y: m.plot.maxY))
        case .horizontal(let c):
            let y = m.screen(0, c).y
            path.move(to: CGPoint(x: m.plot.minX, y: y)); path.addLine(to: CGPoint(x: m.plot.maxX, y: y))
        case .slanted(let k, let c):
            path.move(to: m.screen(p.xMin, k * p.xMin + c)); path.addLine(to: m.screen(p.xMax, k * p.xMax + c))
        }
        ctx.stroke(path, with: .color(.cyan.opacity(0.8)), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        // Its equation, at the edge of the box.
        let label = ctx.resolve(Text(line.title).font(.caption2.weight(.semibold)).foregroundColor(.cyan))
        switch line.kind {
        case .vertical(let c): ctx.draw(label, at: CGPoint(x: m.screen(c, 0).x + 4, y: m.plot.minY + 8), anchor: .leading)
        case .horizontal(let c): ctx.draw(label, at: CGPoint(x: m.plot.maxX - 4, y: m.screen(0, c).y - 8), anchor: .trailing)
        case .slanted(let k, let c): ctx.draw(label, at: m.screen(p.xMax, k * p.xMax + c).applying(.init(translationX: -4, y: -8)), anchor: .trailing)
        }
    }

    private func markerLabels(_ m: Mapping) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(markers.enumerated()), id: \.offset) { _, mk in
                let p = m.screen(mk.x, mk.y)
                let color: Color = mk.onTarget ? .green : .white
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .position(p)
                Text(mk.label)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 3)
                    .background(Color.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 4))
                    .fixedSize()
                    .position(x: p.x + 11, y: p.y - 11)
            }
        }
        .allowsHitTesting(false)
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
        if zoomable { return niceTicks(shown.xMin, shown.xMax) }
        var ticks = [shown.xMin, shown.xMax]
        if shown.xMin < 0 && shown.xMax > 0 { ticks.append(0) }
        let mid = (shown.xMin + shown.xMax) / 2
        if !(shown.xMin < 0 && shown.xMax > 0) || Swift.abs(mid) > 1e-9 { ticks.append(mid) }
        return ticks
    }

    private func niceTicks(_ lo: Double, _ hi: Double) -> [Double] {
        let raw = (hi - lo) / 4
        let mag = pow(10, floor(log10(raw)))
        let step = [1.0, 2, 2.5, 5, 10].map { $0 * mag }.first { $0 >= raw } ?? raw
        var ticks: [Double] = []
        var t = (lo / step).rounded(.up) * step
        while t <= hi + 1e-9 { ticks.append(Swift.abs(t) < step * 1e-6 ? 0 : t); t += step }
        return ticks
    }

    private var yTicks: [Double] {
        let lo = shown.yMin, hi = shown.yMax
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
                Text(shown.xLabel(x))
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
            } else if shown.yMin < 0 && shown.yMax > 0 {
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
    /// Change: the solution graph shows f with lettered points and their images.
    var change: ChangeProblem? = nil
    /// A rejected drawing (alarms: escalation; practice: statistics).
    var onWrong: () -> Void = {}
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
    /// Whole-graph problems: the current view, and the stretch the last check used.
    @State private var viewport: SketchViewport?
    @State private var checked: SketchProblem?
    /// Helper lines you added (x = 2, y = 1, y = x + 1…).
    @State private var guidelines: [Guideline] = []
    @State private var showLines = false

    var body: some View {
        VStack(spacing: 8) {
            header
            // The canvas takes whatever height is left, so the controls below never get pushed off screen.
            SketchCanvas(problem: problem, strokes: $strokes, tool: tool,
                         regions: result?.passed == false ? result!.regions : [],
                         revealTruth: reveal, guides: guides, reference: reference, showYScale: mode.showsYScale,
                         willChange: { history.append(strokes); if history.count > 60 { history.removeFirst() } },
                         viewport: $viewport, zoomable: problem.isWhole, guidelines: guidelines)
                .frame(minHeight: 140, maxHeight: .infinity)
                .layoutPriority(-1)
                .modifier(Shake(animatableData: shakes))

            if !guidelines.isEmpty { lineChips }

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
            GraphSolutionSheet(problem: problem, reference: change?.base ?? reference, steps: steps?() ?? [],
                               markers: change.map { GraphSteps.markers(for: $0) } ?? [],
                               warning: onSolutionViewed == nil ? nil : "After you close this, you'll get a new problem of the same kind to draw.")
        }
        .sheet(isPresented: $showLines) {
            GuidelineSheet(lines: $guidelines, view: viewport ?? problem.viewport, zoomable: problem.isWhole)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Show how to draw it?", isPresented: $confirmSteps, titleVisibility: .visible) {
            Button("Show steps (new problem after)") { showSteps = true }
            Button("Keep trying", role: .cancel) {}
        } message: {
            Text("The alarm still needs a solved problem, so you'll get a fresh one afterwards.")
        }
    }

    /// The correct shape in each revealed zone, joined to what was drawn.
    private var guides: [SketchStroke] {
        let flagged = result?.passed == false ? result!.regions.map { $0.lo...$0.hi } : []
        return revealed.map { SketchGuide.continuation(of: strokes, for: checked ?? problem, in: $0, flagged: flagged,
                                                       fit: mode.tolerance.normalization) }
    }

    /// The helper lines you've added: tap to hide/show, ✕ to remove.
    private var lineChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "line.diagonal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .accessibilityHidden(true)
                ForEach($guidelines) { $line in
                    HStack(spacing: 4) {
                        Button {
                            Haptics.tap()
                            line.hidden.toggle()
                        } label: {
                            HStack(spacing: 3) {
                                if !line.isVisible(in: viewport ?? problem.viewport) {
                                    Image(systemName: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.orange)
                                }
                                Text(line.title)
                                    .font(.footnote.monospaced().weight(.semibold))
                                    .foregroundStyle(line.hidden ? Color.secondary : Color.cyan)
                                    .strikethrough(line.hidden)
                            }
                        }
                        .accessibilityLabel(line.hidden ? "Show \(line.title)" : "Hide \(line.title)")
                        Button {
                            Haptics.tap()
                            let id = line.id
                            withAnimation { guidelines.removeAll { $0.id == id } }
                        } label: {
                            Image(systemName: "xmark").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Remove \(line.title)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: Capsule())
                }
                if guidelines.count > 1 {
                    Button("Remove all") {
                        Haptics.tap()
                        withAnimation { guidelines.removeAll() }
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
                }
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
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
            if problem.isWhole { toolButton(.pan, "hand.draw", "Move", labelled: labelled) }
            Spacer(minLength: 0)
            iconButton("arrow.uturn.backward", "Undo") {
                if let last = history.popLast() { strokes = last } else if !strokes.isEmpty { strokes.removeLast() }
            }
            .disabled(history.isEmpty && strokes.isEmpty)
            iconButton("line.diagonal", "Helper lines (asymptotes)") { showLines = true }
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
        let r: SketchResult
        if problem.isWhole {
            let out = SketchChecker.checkWhole(strokes, for: problem, view: viewport ?? problem.viewport, mode: mode)
            r = out.result
            checked = out.checked
        } else {
            r = SketchChecker.check(strokes, for: problem, mode: mode)
            checked = problem
        }
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
            if !strokes.isEmpty { onWrong() }
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
            Text(problem.isWhole ? "Draw the whole graph — pinch, Move or ± to see more"
                                 : "Sketch for \(problem.xLabel(problem.xMin)) ≤ x ≤ \(problem.xLabel(problem.xMax))")
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
    var markers: [GraphMarker] = []
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
                    if !markers.isEmpty {
                        graph(caption: "f in grey with its key points A, B, …; g in green with the moved points A′, B′, …")
                    }
                    StepsList(steps: steps)
                    if markers.isEmpty {
                        graph(caption: "The finished graph (green\(reference == nil ? "" : "; f in grey")):")
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("How to draw it")
            .scrollIndicators(.visible)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func graph(caption: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(caption)
                .font(.subheadline.weight(.semibold))
            SketchCanvas(problem: problem, strokes: .constant([]), revealTruth: true, markers: markers, reference: reference)
                .frame(height: 280)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Helper lines

/// A dashed helper line the user adds while drawing (asymptotes and the like).
struct Guideline: Identifiable, Hashable {
    enum Kind: Hashable {
        case vertical(Double)              // x = c
        case horizontal(Double)            // y = c
        case slanted(Double, Double)       // y = m·x + b
    }
    let id = UUID()
    var kind: Kind
    var title: String
    /// Hidden lines stay in the list but aren't drawn.
    var hidden = false

    /// Does any part of the line cross the visible box?
    func isVisible(in v: SketchViewport) -> Bool {
        Self.isVisible(kind, in: v)
    }

    static func isVisible(_ kind: Kind, in v: SketchViewport) -> Bool {
        switch kind {
        case .vertical(let c): return c >= v.xMin && c <= v.xMax
        case .horizontal(let c): return c >= v.yMin && c <= v.yMax
        case .slanted(let m, let b):
            let y1 = m * v.xMin + b, y2 = m * v.xMax + b
            return !(Swift.min(y1, y2) > v.yMax || Swift.max(y1, y2) < v.yMin)
        }
    }
}

/// Reads values like 5, −2.5, 1/3, 3π/4, ln(3), e^2, √2, 1 + ln 2, 2e^(−1):
/// numbers, π, e, + − × / ^, ln, √ and brackets (missing ")" at the end are fine).
enum GuideNumber {
    static func parse(_ text: String) -> Double? {
        let cleaned = text.lowercased()
            .replacingOccurrences(of: "−", with: "-").replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "pi", with: "π").replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "·", with: "*").replacingOccurrences(of: " ", with: "")
        var p = Parser(chars: Array(cleaned))
        guard !p.chars.isEmpty, let v = p.expression(), p.atEnd, v.isFinite else { return nil }
        return v
    }

    private struct Parser {
        var chars: [Character]
        var i = 0
        var atEnd: Bool { i >= chars.count }
        var peek: Character? { atEnd ? nil : chars[i] }

        mutating func expression() -> Double? {
            guard var v = term() else { return nil }
            while let c = peek, c == "+" || c == "-" {
                i += 1
                guard let t = term() else { return nil }
                v = c == "+" ? v + t : v - t
            }
            return v
        }

        mutating func term() -> Double? {
            guard var v = power() else { return nil }
            while let c = peek {
                if c == "*" || c == "/" {
                    i += 1
                    guard let f = power() else { return nil }
                    if c == "*" { v *= f } else { guard f != 0 else { return nil }; v /= f }
                } else if c.isNumber || c == "π" || c == "e" || c == "(" || c == "√" || c == "l" || c == "." {
                    // Implicit multiplication: 2π, 3ln2, 2e^x, 2(1+π)
                    guard let f = power() else { return nil }
                    v *= f
                } else {
                    break
                }
            }
            return v
        }

        mutating func power() -> Double? {
            guard let base = unary() else { return nil }
            if peek == "^" {
                i += 1
                guard let e = power() else { return nil }
                return pow(base, e)
            }
            return base
        }

        mutating func unary() -> Double? {
            if peek == "-" { i += 1; return unary().map { -$0 } }
            if peek == "+" { i += 1; return unary() }
            return primary()
        }

        mutating func primary() -> Double? {
            guard let c = peek else { return nil }
            if c == "(" {
                i += 1
                let v = expression()
                if peek == ")" { i += 1 }   // a missing ")" at the end is fine
                return v
            }
            if c == "π" { i += 1; return .pi }
            if c == "√" {
                i += 1
                guard let v = power(), v >= 0 else { return nil }
                return v.squareRoot()
            }
            if c == "l", i + 1 < chars.count, chars[i + 1] == "n" {
                i += 2
                guard let v = power(), v > 0 else { return nil }
                return log(v)
            }
            if c == "e" { i += 1; return M_E }
            var digits = ""
            while let d = peek, d.isNumber || d == "." { digits.append(d); i += 1 }
            return Double(digits)
        }
    }
}

/// Add or remove helper lines: x = c, y = c or y = m·x + b — typed on a
/// small built-in number pad (no system keyboard).
struct GuidelineSheet: View {
    @Binding var lines: [Guideline]
    /// What's on screen right now (to warn about lines you couldn't see).
    var view: SketchViewport
    var zoomable = false
    @Environment(\.dismiss) private var dismiss
    @State private var kind = 0
    @State private var first = ""
    @State private var second = ""
    /// Which value the pad types into (0 = c or m, 1 = b).
    @State private var field = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Line", selection: $kind) {
                        Text("x = c").tag(0)
                        Text("y = c").tag(1)
                        Text("y = mx + b").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in field = 0 }

                    // The Add button sits right next to the values, so it never needs scrolling.
                    HStack(spacing: 8) {
                        if kind == 2 {
                            valueBox("m", first, index: 0)
                            valueBox("b", second, index: 1)
                        } else {
                            valueBox(kind == 0 ? "x =" : "y =", first, index: 0)
                        }
                        Button {
                            add()
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.headline)
                                .frame(minHeight: 30)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.cyan)
                        .controlSize(.large)
                        .disabled(parsed == nil)
                    }

                    if let k = parsed, !Guideline.isVisible(k, in: view) {
                        Label(outOfViewText(k), systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    pad

                    Text("Dashed helper lines for drawing — for example the asymptotes you found. They aren't checked.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !lines.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Your lines").font(.subheadline.weight(.semibold))
                                Spacer()
                                if lines.count > 1 {
                                    Button("Remove all", role: .destructive) {
                                        Haptics.tap()
                                        lines.removeAll()
                                    }
                                    .font(.subheadline)
                                }
                            }
                            ForEach(lines) { line in
                                HStack {
                                    Text(line.title).font(.body.monospaced()).foregroundStyle(.cyan)
                                    if !line.isVisible(in: view) {
                                        Label("out of view", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption).foregroundStyle(.orange)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        Haptics.tap()
                                        lines.removeAll { $0.id == line.id }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.glass)
                                    .accessibilityLabel("Remove \(line.title)")
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Helper lines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// One value; tap it to type into it with the pad.
    private func valueBox(_ name: String, _ text: String, index: Int) -> some View {
        Button {
            Haptics.tap()
            field = index
        } label: {
            HStack(spacing: 6) {
                Text(name).font(.body.weight(.semibold)).foregroundStyle(.secondary)
                Text(text.isEmpty ? " " : text)
                    .font(.title3.monospaced())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(field == index ? Color.cyan : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) \(text.isEmpty ? "empty" : text)")
    }

    private var pad: some View {
        let keys: [[String]] = [["7", "8", "9", "⌫", "C"], ["4", "5", "6", "π", "e"], ["1", "2", "3", "ln", "√"],
                                ["0", ".", "−", "+", "^"], ["(", ")", "/", "×"]]
        return VStack(spacing: 6) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            Haptics.tap()
                            press(key)
                        } label: {
                            Group {
                                if key == "⌫" { Image(systemName: "delete.left") } else { Text(key) }
                            }
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(Color(white: ["⌫", "C"].contains(key) ? 0.32 : 0.2), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(PressableStyle(scale: 0.9))
                        .accessibilityLabel(key == "⌫" ? "delete" : (key == "C" ? "clear" : key))
                    }
                }
            }
        }
    }

    private func outOfViewText(_ k: Guideline.Kind) -> String {
        func n(_ v: Double) -> String { SketchFormat.number(v) }
        let fix = zoomable ? " — zoom out or move the view to see it." : " — you won't see it on this graph."
        switch k {
        case .vertical: return "Out of view: the box only shows x from \(n(view.xMin)) to \(n(view.xMax))" + fix
        case .horizontal: return "Out of view: the box only shows y from \(n(view.yMin)) to \(n(view.yMax))" + fix
        case .slanted: return "Out of view: this line passes \((m(k) * view.xMin + b(k)) > view.yMax ? "above" : "below") the whole box" + fix
        }
    }

    private func m(_ k: Guideline.Kind) -> Double { if case .slanted(let m, _) = k { return m }; return 0 }
    private func b(_ k: Guideline.Kind) -> Double { if case .slanted(_, let b) = k { return b }; return 0 }

    private func press(_ key: String) {
        var text = field == 0 ? first : second
        switch key {
        case "⌫":
            // ln( and √( go in one piece.
            if text.hasSuffix("ln(") { text.removeLast(3) } else if text.hasSuffix("√(") { text.removeLast(2) } else if !text.isEmpty { text.removeLast() }
        case "C": text = ""
        case "ln": text += "ln("
        case "√": text += "√("
        case "^": text += "^"
        default: text += key
        }
        if field == 0 { first = text } else { second = text }
    }

    private var parsed: Guideline.Kind? {
        switch kind {
        case 0: GuideNumber.parse(first).map { .vertical($0) }
        case 1: GuideNumber.parse(first).map { .horizontal($0) }
        default:
            if let m = GuideNumber.parse(first), let b = GuideNumber.parse(second.isEmpty ? "0" : second) { .slanted(m, b) } else { nil }
        }
    }

    private func add() {
        guard let k = parsed else { return }
        Haptics.tap()
        let clean = { (t: String) in t.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "-", with: "−") }
        let title: String
        switch k {
        case .vertical: title = "x = \(clean(first))"
        case .horizontal: title = "y = \(clean(first))"
        case .slanted:
            let b = clean(second)
            title = "y = \(clean(first) == "1" ? "" : clean(first))x" + (b.isEmpty || b == "0" ? "" : (b.hasPrefix("−") ? " − \(b.dropFirst())" : " + \(b)"))
        }
        lines.append(Guideline(kind: k, title: title))
        first = ""; second = ""; field = 0
    }
}
