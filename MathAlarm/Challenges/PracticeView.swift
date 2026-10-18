import SwiftUI
import UIKit
import MathEngine

/// Try every challenge without an alarm ringing, plus the study modes:
/// quick questions, speed round, mini exam, review, weak spots, history.
struct PracticeView: View {
    enum Mode: Hashable, Identifiable {
        case integral, derivative, sketch, change
        /// One quick-question type, or nil for a mix of all of them.
        case quiz(QuizKind?)

        var id: String { title }

        static var all: [Mode] { [.integral, .derivative, .sketch, .change, .quiz(nil)] + QuizKind.allCases.map { .quiz($0) } }

        var title: String {
            switch self {
            case .integral: "Integral"
            case .derivative: "Derivative"
            case .sketch: "Sketch"
            case .change: "Change"
            case .quiz(nil): "Quiz mix"
            case .quiz(let k?): k.title
            }
        }

        var symbol: String {
            switch self {
            case .integral: "sum"
            case .derivative: "function"
            case .sketch: "scribble.variable"
            case .change: "arrow.triangle.swap"
            case .quiz(nil): "questionmark.bubble"
            case .quiz(let k?): k.symbol
            }
        }

        var isDrawing: Bool { self == .sketch || self == .change }
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
        case speed, exam, review, weak, history
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                modeBar
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
            .sheet(item: $sheet) { which in
                switch which {
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

    private var modeBar: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Mode.all) { m in
                        Button {
                            Haptics.tap()
                            select(m)
                        } label: {
                            Label(m.title, systemImage: m.symbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(m == mode ? .black : .white)
                                .padding(.horizontal, 12)
                                .frame(minHeight: 34)
                                .background(m == mode ? Color.orange : Color.white.opacity(0.12), in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(PressableStyle())
                        .id(m.id)
                    }
                }
                .padding(.vertical, 2)
            }
            .onChange(of: mode) { _, m in withAnimation { proxy.scrollTo(m.id, anchor: .center) } }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                Button { sheet = .speed } label: { Label("Speed round", systemImage: "stopwatch") }
                Button { sheet = .exam } label: { Label("Mini exam", systemImage: "doc.text") }
                Button { sheet = .review } label: {
                    Label(store.dueReview.isEmpty ? "Review" : "Review (\(store.dueReview.count) due)", systemImage: "arrow.counterclockwise")
                }
                Button { sheet = .weak } label: { Label("Weak spots", systemImage: "scope") }
                Button { sheet = .history } label: { Label("History & favourites", systemImage: "clock") }
                Divider()
                Button { showCodeEntry = true } label: { Label("Enter a share code", systemImage: "keyboard") }
            } label: {
                Image(systemName: store.dueReview.isEmpty ? "square.grid.2x2" : "square.grid.2x2.fill")
            }
            .accessibilityLabel("More practice modes")
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
            mode = .quiz(q.kind)
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
        case .quiz(let k):
            quiz = ProblemHistory.shared.freshQuiz(level: difficulty.level, kind: k)
            editor = MathEditor()
        case .integral, .derivative:
            problem = ProblemHistory.shared.fresh(mode == .integral ? .integral : .derivative, level: difficulty.level)
            editor = MathEditor()
        }
    }
}
