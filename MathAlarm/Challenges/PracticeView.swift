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
    @State private var strokes: [SketchStroke] = []
    @State private var change: ChangeProblem?
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

                HStack {
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                    if kind.isDrawing {
                        Picker("Mode", selection: $mode) {
                            ForEach(SketchMode.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.menu)
                    }
                    Spacer()
                    if solvedCount > 0 {
                        Text("Solved: \(solvedCount)").font(.subheadline.bold()).foregroundStyle(.green)
                    }
                    Spacer()
                    Button {
                        Haptics.tap()
                        newProblem()
                    } label: {
                        Label("New", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    if !kind.isDrawing {
                        Button {
                            showSolution = true
                        } label: {
                            Label("Solution", systemImage: "list.number")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .font(.subheadline)

                if kind == .sketch, let sketch {
                    SketchChallengeView(problem: sketch, strokes: $strokes, mode: mode,
                                        allowReveal: true, onSolved: solved) {
                        SketchHeader(problem: sketch)
                    }
                    .id(sketch.signature + mode.rawValue)
                } else if kind == .change, let change {
                    let display = settings.changeDisplay
                    SketchChallengeView(problem: change.target, strokes: $strokes, mode: mode,
                                        reference: display.showsGraph ? change.base : nil,
                                        allowReveal: true, onSolved: solved) {
                        ChangeHeader(change: change, display: display)
                    }
                    .id(change.signature + mode.rawValue)
                } else {
                    ChallengeView(problem: problem, editor: $editor, onSolved: solved)
                        .id(problem.seed)
                }
            }
            .padding(.horizontal, 12)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toast($toast)
            .onChange(of: kind) { _, _ in newProblem() }
            .onChange(of: difficulty) { _, _ in newProblem() }
            .sheet(isPresented: $showSolution) {
                SolutionSheet(problem: problem)
            }
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
            sketch = ProblemHistory.shared.freshSketch(level: difficulty.level)
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
