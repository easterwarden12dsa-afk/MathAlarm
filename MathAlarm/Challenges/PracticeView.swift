import SwiftUI
import MathEngine

/// Try the challenges without an alarm ringing.
struct PracticeView: View {
    @State private var kind: ProblemKind = .integral
    @State private var difficulty: Difficulty = .medium
    @State private var problem = ProblemFactory.make(.integral, level: .medium, seed: ProblemFactory.randomSeed())
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
                    Label("Show answer", systemImage: "eye")
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)

            ChallengeView(problem: problem, editor: $editor) {
                solvedCount += 1
                toast = Toast(message: "Correct! Next problem…", symbol: "checkmark.circle.fill", style: .success)
                newProblem()
            }
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
            AnswerSheet(problem: problem)
                .presentationDetents([.medium])
        }
    }

    private func newProblem() {
        problem = ProblemFactory.make(kind, level: difficulty.level, seed: ProblemFactory.randomSeed())
        editor = MathEditor()
    }
}

private struct AnswerSheet: View {
    let problem: CalculusProblem

    var body: some View {
        VStack(spacing: 18) {
            Text("One correct answer").font(.headline).foregroundStyle(.orange)
            FittedMath { size in
                ProblemFormula(problem: problem, size: size)
            }
            Text("=").font(.title)
            FittedMath { size in
                HStack(alignment: .mathAxis, spacing: 6) {
                    MathRowView(row: ExprDisplay.row(problem.reference), size: size, mergeFunctionPowers: true)
                    if problem.kind == .integral {
                        Text("+ C").font(MathFont.italic(size))
                    }
                }
                .foregroundStyle(.white)
            }
            Text("Technique: \(problem.technique)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Any equivalent form is accepted.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}
