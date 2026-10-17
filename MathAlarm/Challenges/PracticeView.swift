import SwiftUI
import MathEngine

/// Try the challenges without an alarm ringing.
struct PracticeView: View {
    @State private var kind: ProblemKind = .integral
    @State private var difficulty: Difficulty = .medium
    @State private var problem = ProblemHistory.shared.fresh(.integral, level: .medium)
    @State private var editor = MathEditor()
    @State private var showAnswer = false
    @State private var solvedCount = 0
    @State private var toast: Toast?

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Challenge", selection: $kind) {
                    Text("Integral").tag(ProblemKind.integral)
                    Text("Derivative").tag(ProblemKind.derivative)
                }
                .pickerStyle(.segmented)
                Picker("Difficulty", selection: $difficulty) {
                    ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button {
                    newProblem()
                } label: {
                    Label("New problem", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                Spacer()
                if solvedCount > 0 {
                    Text("Solved: \(solvedCount)").font(.subheadline.bold()).foregroundStyle(.green)
                }
                Spacer()
                Button {
                    showAnswer = true
                } label: {
                    Label("Full solution", systemImage: "list.number")
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)

            ChallengeView(problem: problem, editor: $editor, onSolved: {
                solvedCount += 1
                toast = Toast(message: "Correct! Next problem…", symbol: "checkmark.circle.fill", style: .success)
                newProblem()
            })
            .id(problem.seed)
        }
        .padding(.horizontal, 12)
        .background(Color.black.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toast($toast)
        .onChange(of: kind) { _, _ in newProblem() }
        .onChange(of: difficulty) { _, _ in newProblem() }
        .sheet(isPresented: $showAnswer) {
            SolutionSheet(problem: problem)
        }
    }

    private func newProblem() {
        problem = ProblemHistory.shared.fresh(kind, level: difficulty.level)
        editor = MathEditor()
    }
}
