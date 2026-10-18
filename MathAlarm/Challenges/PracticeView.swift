import SwiftUI
import UIKit
import MathEngine

/// Try every challenge without an alarm ringing, plus the study modes:
/// quick questions, speed round, mini exam, review, weak spots, history.
struct PracticeView: View {
    enum Mode: Hashable, Identifiable {
        case integral, derivative, sketch, change
        /// A question type (nil = a mix of the function questions), optionally one of its sub-types.
        case quiz(QuizKind?, String?)

        var id: String {
            switch self {
            case .quiz(let k, let v): "quiz:\(k?.rawValue ?? "mix"):\(v ?? "all")"
            default: title
            }
        }

        /// Whole subjects whose sub-types get their own row (Probability → Binomial…).
        static let topicKinds: [QuizKind] = [.probability, .triangle, .optimization]
        /// The "Functions" mix.
        static let functionKinds: [QuizKind] = [.parameter, .limit, .tangent, .area, .equation]

        var title: String {
            switch self {
            case .integral: "Integral"
            case .derivative: "Derivative"
            case .sketch: "Sketch"
            case .change: "Change"
            case .quiz(nil, _): "Mix"
            case .quiz(let k?, let v):
                if let v, let variant = k.variants.first(where: { $0.id == v }) { variant.title }
                else if Self.topicKinds.contains(k) { "Mix" }
                else { k.title }
            }
        }

        var symbol: String {
            switch self {
            case .integral: "sum"
            case .derivative: "function"
            case .sketch: "scribble.variable"
            case .change: "arrow.triangle.swap"
            case .quiz(nil, _): "shuffle"
            case .quiz(let k?, let v):
                if let v, let variant = k.variants.first(where: { $0.id == v }) { variant.symbol }
                else if Self.topicKinds.contains(k) { "shuffle" }
                else { k.symbol }
            }
        }

        var isDrawing: Bool { self == .sketch || self == .change }

        var kind: QuizKind? { if case .quiz(let k, _) = self { k } else { nil } }

        var category: Category {
            switch self {
            case .integral, .derivative: return .calculus
            case .sketch, .change: return .graphs
            case .quiz(nil, _): return .functions
            case .quiz(let k?, _):
                switch k {
                case .chooseGraph, .signTable, .solutions: return .graphs
                case .probability: return .probability
                case .triangle: return .triangles
                case .optimization: return .minmax
                default: return .functions
                }
            }
        }

        /// The mode that shows a given question (sub-types of the function questions go in the Type menu).
        static func of(_ q: QuizProblem) -> Mode { topicKinds.contains(q.kind) ? .quiz(q.kind, q.variant) : .quiz(q.kind, nil) }
    }

    /// The big modes. Each has its own modes in the second row.
    enum Category: String, CaseIterable, Identifiable {
        case calculus, graphs, functions, probability, triangles, minmax

        var id: String { rawValue }

        var title: String {
            switch self {
            case .calculus: "Calculus"
            case .graphs: "Graphs"
            case .functions: "Functions"
            case .probability: "Probability"
            case .triangles: "Triangles"
            case .minmax: "Min & max"
            }
        }

        var symbol: String {
            switch self {
            case .calculus: "function"
            case .graphs: "scribble.variable"
            case .functions: "x.squareroot"
            case .probability: "dice"
            case .triangles: "triangle"
            case .minmax: "arrow.up.and.down"
            }
        }

        /// One line about what is inside, shown under the rows.
        var blurb: String {
            switch self {
            case .calculus: "Integrals and derivatives, typed as formulas"
            case .graphs: "Draw graphs, or read them: f′, sign tables, solutions"
            case .functions: "Parameters, limits, tangents, areas and equations"
            case .probability: "Independent events, tables, binomial, trees and Bayes"
            case .triangles: "Trigonometry in the plane: sines, cosines, areas"
            case .minmax: "Word problems: set up a function, then f′ = 0"
            }
        }

        var modes: [Mode] {
            switch self {
            case .calculus: [.integral, .derivative]
            case .graphs: [.sketch, .change, .quiz(.chooseGraph, nil), .quiz(.signTable, nil), .quiz(.solutions, nil)]
            case .functions: [Mode.quiz(nil, nil)] + Mode.functionKinds.map { Mode.quiz($0, nil) }
            case .probability: Self.topic(.probability)
            case .triangles: Self.topic(.triangle)
            case .minmax: Self.topic(.optimization)
            }
        }

        private static func topic(_ k: QuizKind) -> [Mode] { [Mode.quiz(k, nil)] + k.variants.map { Mode.quiz(k, $0.id) } }
    }

    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = LearningStore.shared
    @State private var mode: Mode = .integral
    @State private var difficulty: Difficulty = .medium
    @State private var problem = ProblemHistory.shared.fresh(.integral, level: .medium)
    @State private var editor = MathEditor()
    @State private var sketch: SketchProblem?
    /// The interval version of the current sketch, so "Whole graph" can be switched without a new problem.
    @State private var plainSketch: SketchProblem?
    @State private var change: ChangeProblem?
    @State private var quiz: QuizProblem?
    @State private var strokes: [SketchStroke] = []
    @State private var drawMode: SketchMode = AppSettings.shared.sketchMode
    @State private var showSolution = false
    @State private var solvedCount = 0
    @State private var toast: Toast?
    /// One statistic per problem: the first wrong answer, or a clean solve.
    @State private var attemptRecorded = false
    /// The current problem came from the review list.
    @State private var reviewing = false
    @State private var sheet: Sheet?
    @State private var showCodeEntry = false
    @State private var codeText = ""
    /// Bumped to rebuild the challenge view when a problem is loaded.
    @State private var generation = 0

    enum Sheet: String, Identifiable {
        case hub, speed, exam, review, weak, history
        var id: String { rawValue }
    }
    /// Opened after the Study hub closes (one sheet at a time).
    @State private var pendingSheet: Sheet?
    @State private var pendingCode = false
    /// For question types whose sub-types are in the Type menu (nil = all).
    @State private var subVariant: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                VStack(spacing: 6) {
                    categoryBar
                    if mode.category.modes.count > 1 { modeBar }
                    Text(mode.category.blurb)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .zIndex(2)   // always on top: nothing below can steal its taps
                controls
                    .zIndex(2)
                content
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
                    .zIndex(0)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(solvedCount > 0 ? "Practice · \(solvedCount) solved" : "Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .toast($toast)
            .onChange(of: difficulty) { _, _ in newProblem() }
            .onChange(of: settings.wholeGraph) { _, whole in
                // Same problem, same drawing — only the view changes.
                if mode == .sketch, let plain = plainSketch { sketch = whole ? SketchFactory.whole(plain) : plain }
            }
            .sheet(isPresented: $showSolution) { SolutionSheet(problem: problem) }
            .sheet(item: $sheet, onDismiss: {
                if let next = pendingSheet {
                    pendingSheet = nil
                    sheet = next
                } else if pendingCode {
                    pendingCode = false
                    showCodeEntry = true
                }
            }) { which in
                switch which {
                case .hub:
                    StudyHubView { choice in
                        switch choice {
                        case .sheet(let s): pendingSheet = s
                        case .code: pendingCode = true
                        case .daily(let item): load(item, fromReview: false)
                        }
                        sheet = nil
                    }
                case .speed: SpeedRoundView()
                case .exam: MiniExamView(difficulty: difficulty)
                case .review: ReviewListView { item in load(item, fromReview: true) }
                case .weak: WeakSpotsView { m in sheet = nil; select(m) }
                case .history: HistoryView { item in load(item, fromReview: false) }
                }
            }
            .alert("Enter a share code", isPresented: $showCodeEntry) {
                TextField("MA-d-2-123456", text: $codeText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                Button("Open") {
                    if let item = ShareCode.item(from: codeText) {
                        load(item, fromReview: false)
                    } else {
                        toast = Toast(message: "That code doesn't look right", symbol: "exclamationmark.triangle.fill", style: .warning)
                    }
                    codeText = ""
                }
                Button("Cancel", role: .cancel) { codeText = "" }
            } message: {
                Text("A friend's code opens exactly the same problem.")
            }
        }
    }

    // MARK: Top

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Category.allCases) { c in
                    let on = c == mode.category
                    Button {
                        Haptics.tap()
                        if !on { select(c.modes[0]) }
                    } label: {
                        Label(c.title, systemImage: c.symbol)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(on ? .black : .white)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(on ? Color.orange : Color.white.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }

    /// The modes of the chosen subject, smaller and underlined.
    private var modeBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(mode.category.modes) { m in
                        let on = m == mode
                        Button {
                            Haptics.tap()
                            select(m)
                        } label: {
                            VStack(spacing: 3) {
                                Label(m.title, systemImage: m.symbol)
                                    .font(.footnote.weight(on ? .bold : .semibold))
                                    .foregroundStyle(on ? .orange : .white.opacity(0.75))
                                Capsule().fill(on ? Color.orange : .clear).frame(height: 2.5)
                            }
                            .padding(.horizontal, 8)
                            .frame(minHeight: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableStyle())
                        .id(m.id)
                    }
                }
            }
            .onChange(of: mode) { _, m in withAnimation { proxy.scrollTo(m.id, anchor: .center) } }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                Haptics.tap()
                sheet = .hub
            } label: {
                Image(systemName: "rectangle.grid.2x2")
                    .overlay(alignment: .topTrailing) {
                        if !store.dueReview.isEmpty {
                            Circle().fill(Color.red).frame(width: 9, height: 9).offset(x: 4, y: -3)
                        }
                    }
            }
            .accessibilityLabel(store.dueReview.isEmpty ? "Study modes" : "Study modes, \(store.dueReview.count) to review")
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                Haptics.tap()
                store.toggleFavourite(currentItem)
            } label: {
                Image(systemName: store.isFavourite(currentItem) ? "star.fill" : "star")
                    .foregroundStyle(.yellow)
            }
            .accessibilityLabel(store.isFavourite(currentItem) ? "Remove from favourites" : "Add to favourites")
            Menu {
                let code = ShareCode.code(for: currentItem)
                Button {
                    UIPasteboard.general.string = code
                    toast = Toast(message: "Copied \(code)", symbol: "doc.on.doc.fill", style: .success)
                } label: { Label("Copy code \(code)", systemImage: "doc.on.doc") }
                ShareLink(item: "Try this Math Alarm problem: \(code)") { Label("Share…", systemImage: "square.and.arrow.up") }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("Share this problem")
        }
    }

    /// Difficulty, drawing mode and New — big, separate buttons so taps always land.
    private var controls: some View {
        GlassEffectContainer(spacing: 8) {
        HStack(spacing: 8) {
            Menu {
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                }
            } label: {
                chip(difficulty.title, "dial.medium")
            }
            if mode.isDrawing {
                Menu {
                    Picker("Drawing mode", selection: $drawMode) {
                        ForEach(SketchMode.allCases) { Text($0.title).tag($0) }
                    }
                    if mode == .sketch {
                        Toggle("Whole graph (zoom)", isOn: $settings.wholeGraph)
                    }
                } label: {
                    chip(drawMode.title, "pencil.and.ruler")
                }
            } else if let k = mode.kind, !Mode.topicKinds.contains(k), !k.variants.isEmpty {
                Menu {
                    Picker("Type", selection: Binding(get: { subVariant }, set: { subVariant = $0; newProblem() })) {
                        Text("All types").tag(String?.none)
                        ForEach(k.variants) { v in Label(v.title, systemImage: v.symbol).tag(String?.some(v.id)) }
                    }
                } label: {
                    chip(k.variants.first { $0.id == subVariant }?.title ?? "All types", "line.3.horizontal.decrease.circle")
                }
            } else if mode == .integral || mode == .derivative {
                Button {
                    Haptics.tap()
                    showSolution = true
                } label: {
                    chip("Solution", "list.number")
                }
            }
            Button {
                Haptics.tap()
                newProblem()
            } label: {
                chip(reviewing ? "Done reviewing" : "New", "arrow.clockwise")
            }
        }
        .menuStyle(.button)
        .buttonStyle(.glass)
        }
    }

    private func chip(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, minHeight: 28)
            .contentShape(Rectangle())
    }

    // MARK: Content

    private var content: some View {
        VStack(spacing: 6) {
            challenge
        }
    }

    @ViewBuilder
    private var challenge: some View {
        if reviewing {
            Label("Review: a problem you missed earlier", systemImage: "arrow.counterclockwise")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.cyan)
        }
        switch mode {
        case .sketch:
            if let sketch {
                SketchChallengeView(problem: sketch, strokes: $strokes, mode: drawMode,
                                    allowReveal: true, steps: { GraphSteps.steps(for: sketch) },
                                    onWrong: wrong, onSolved: solved) {
                    SketchHeader(problem: sketch)
                }
                .id(sketch.function.description + drawMode.rawValue + "\(generation)")
            }
        case .change:
            if let change {
                let display = settings.changeDisplay
                SketchChallengeView(problem: change.target, strokes: $strokes, mode: drawMode,
                                    reference: display.showsGraph ? change.base : nil,
                                    allowReveal: true, steps: { GraphSteps.steps(for: change, formulaVisible: display.showsFormula) },
                                    change: change, onWrong: wrong, onSolved: solved) {
                    ChangeHeader(change: change, display: display)
                }
                .id(change.signature + drawMode.rawValue + "\(generation)")
            }
        case .quiz:
            if let quiz {
                QuizView(quiz: quiz, editor: $editor, onWrong: wrong, onSolved: solved)
                    .id(quiz.signature + "\(generation)")
            }
        case .integral, .derivative:
            ChallengeView(problem: problem, editor: $editor, onWrong: wrong, onSolved: solved)
                .id("\(problem.seed)-\(generation)")
        }
    }

    private var currentItem: PracticeItem {
        switch mode {
        case .sketch:
            if let s = plainSketch ?? sketch { return .sketch(s) }
        case .change:
            if let change { return .change(change) }
        case .quiz:
            if let quiz { return .quiz(quiz) }
        case .integral, .derivative:
            break
        }
        return .calculus(problem)
    }

    // MARK: Actions

    private func select(_ m: Mode) {
        guard m != mode || reviewing else { return }
        mode = m
        subVariant = nil
        newProblem()
    }

    private func wrong() {
        guard !attemptRecorded else { return }
        attemptRecorded = true
        store.record(currentItem, correct: false, fromReview: reviewing)
    }

    private func solved() {
        if !attemptRecorded { store.record(currentItem, correct: true, fromReview: reviewing) }
        solvedCount += 1
        toast = Toast(message: reviewing ? "Reviewed — see it again in a few days" : "Correct! Next one…",
                      symbol: "checkmark.circle.fill", style: .success)
        newProblem()
    }

    /// Opens a saved, shared or review problem.
    private func load(_ item: PracticeItem, fromReview: Bool) {
        sheet = nil
        reviewing = fromReview
        attemptRecorded = false
        strokes = []
        editor = MathEditor()
        switch item {
        case .calculus(let p):
            mode = p.kind == .integral ? .integral : .derivative
            problem = p
        case .sketch(let p):
            mode = .sketch
            plainSketch = p
            sketch = settings.wholeGraph ? SketchFactory.whole(p) : p
        case .change(let c):
            mode = .change
            change = c
        case .quiz(let q):
            mode = Mode.of(q)
            subVariant = Mode.topicKinds.contains(q.kind) ? nil : q.variant
            quiz = q
        }
        generation += 1
    }

    private func newProblem() {
        reviewing = false
        attemptRecorded = false
        generation += 1
        switch mode {
        case .sketch:
            let plain = ProblemHistory.shared.freshSketch(level: difficulty.level, whole: false)
            plainSketch = plain
            sketch = settings.wholeGraph ? SketchFactory.whole(plain) : plain
            strokes = []
        case .change:
            change = ProblemHistory.shared.freshChange(level: difficulty.level)
            strokes = []
        case .quiz(let k, let v):
            let kind = k ?? Mode.functionKinds.randomElement()!
            quiz = ProblemHistory.shared.freshQuiz(level: difficulty.level, kind: kind, variant: v ?? (k == nil ? nil : subVariant))
            editor = MathEditor()
        case .integral, .derivative:
            problem = ProblemHistory.shared.fresh(mode == .integral ? .integral : .derivative, level: difficulty.level)
            editor = MathEditor()
        }
    }
}
