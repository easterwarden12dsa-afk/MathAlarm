import SwiftUI
import MathEngine

/// Try every challenge without an alarm ringing.
struct PracticeView: View {
    enum Kind: String, CaseIterable, Identifiable {
        case integral, derivative, sketch, change
        var id: String { rawValue }
        var title: String {
            switch self {
            case .integral: "Integral"
            case .derivative: "Deriv."
            case .sketch: "Sketch"
            case .change: "Change"
            }
        }
        var isDrawing: Bool { self == .sketch || self == .change }
    }

    @ObservedObject private var settings = AppSettings.shared
    @State private var kind: Kind = .integral
    @State private var difficulty: Difficulty = .medium
    @State private var problem = ProblemHistory.shared.fresh(.integral, level: .medium)
    @State private var editor = MathEditor()
    @State private var sketch: SketchProblem?
    /// The interval version of the current sketch, so "Whole graph" can be switched without a new problem.
    @State private var plainSketch: SketchProblem?
    @State private var change: ChangeProblem?
    @State private var strokes: [SketchStroke] = []
    @State private var mode: SketchMode = AppSettings.shared.sketchMode
    @State private var showSolution = false
    @State private var solvedCount = 0
    @State private var toast: Toast?

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Picker("Challenge", selection: $kind) {
                    ForEach(Kind.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                controls

                content
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(solvedCount > 0 ? "Practice · \(solvedCount) solved" : "Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toast($toast)
            .onChange(of: kind) { _, _ in newProblem() }
            .onChange(of: difficulty) { _, _ in newProblem() }
            .onChange(of: settings.wholeGraph) { _, whole in
                // Same problem, same drawing — only the view changes.
                if kind == .sketch, let plain = plainSketch { sketch = whole ? SketchFactory.whole(plain) : plain }
            }
            .sheet(isPresented: $showSolution) {
                SolutionSheet(problem: problem)
            }
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
            if kind.isDrawing {
                Menu {
                    Picker("Drawing mode", selection: $mode) {
                        ForEach(SketchMode.allCases) { Text($0.title).tag($0) }
                    }
                    if kind == .sketch {
                        Toggle("Whole graph (zoom)", isOn: $settings.wholeGraph)
                    }
                } label: {
                    chip(mode.title, "pencil.and.ruler")
                }
            } else {
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
                chip("New", "arrow.clockwise")
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

    @ViewBuilder
    private var content: some View {
        if kind == .sketch, let sketch {
            SketchChallengeView(problem: sketch, strokes: $strokes, mode: mode,
                                allowReveal: true, steps: { GraphSteps.steps(for: sketch) }, onSolved: solved) {
                SketchHeader(problem: sketch)
            }
            .id(sketch.function.description + mode.rawValue)
        } else if kind == .change, let change {
            let display = settings.changeDisplay
            SketchChallengeView(problem: change.target, strokes: $strokes, mode: mode,
                                reference: display.showsGraph ? change.base : nil,
                                allowReveal: true, steps: { GraphSteps.steps(for: change, formulaVisible: display.showsFormula) },
                                change: change, onSolved: solved) {
                ChangeHeader(change: change, display: display)
            }
            .id(change.signature + mode.rawValue)
        } else {
            ChallengeView(problem: problem, editor: $editor, onSolved: solved)
                .id(problem.seed)
        }
    }

    private func solved() {
        solvedCount += 1
        toast = Toast(message: "Correct! Next one…", symbol: "checkmark.circle.fill", style: .success)
        newProblem()
    }

    private func newProblem() {
        switch kind {
        case .sketch:
            let plain = ProblemHistory.shared.freshSketch(level: difficulty.level, whole: false)
            plainSketch = plain
            sketch = settings.wholeGraph ? SketchFactory.whole(plain) : plain
            strokes = []
        case .change:
            change = ProblemHistory.shared.freshChange(level: difficulty.level)
            strokes = []
        case .integral, .derivative:
            problem = ProblemHistory.shared.fresh(kind == .integral ? .integral : .derivative, level: difficulty.level)
            editor = MathEditor()
        }
    }
}
