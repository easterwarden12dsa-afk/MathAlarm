import SwiftUI
import MathEngine

/// Renders a list of worked-solution steps with indentation for sub-steps.
struct StepsList: View {
    let steps: [SolutionStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                StepRow(step: step)
            }
        }
    }
}

private struct StepRow: View {
    let step: SolutionStep

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if step.depth > 0 {
                Rectangle()
                    .fill(Color.orange.opacity(0.5))
                    .frame(width: 2)
                    .padding(.leading, CGFloat(step.depth - 1) * 14)
            }
            VStack(alignment: .leading, spacing: 4) {
                if !step.text.isEmpty {
                    Text(step.text)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if step.math != nil || step.prime != nil {
                    FittedMath(sizes: [22, 19, 16, 14, 12, 11]) { size in
                        formula(size: size)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func formula(size: CGFloat) -> some View {
        HStack(alignment: .mathAxis, spacing: size * 0.25) {
            if let label = step.label {
                Text(label).font(MathFont.italic(size))
            }
            if let prime = step.prime {
                HStack(alignment: .mathAxis, spacing: 0) {
                    MathRowView(row: Row([.paren(ExprDisplay.row(prime))]), size: size, mergeFunctionPowers: true)
                    Text("′").font(MathFont.upright(size))
                }
                Text("=").font(MathFont.upright(size))
            }
            if let math = step.math {
                MathRowView(row: ExprDisplay.row(math), size: size, mergeFunctionPowers: true)
            }
        }
        .foregroundStyle(.white)
    }
}

/// Full worked solution for a problem.
struct SolutionSheet: View {
    let problem: CalculusProblem
    /// Shown at the top in ring mode, where viewing the solution swaps the problem.
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
                    FittedMath { size in ProblemFormula(problem: problem, size: size) }
                        .frame(maxWidth: .infinity)
                    Text("Technique: \(problem.technique)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    StepsList(steps: problem.solutionSteps)
                    Text("Any equivalent form of the answer is accepted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Step-by-step solution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// Explains why the last answer was wrong, without giving the answer away
/// (for integrals it differentiates *your* answer step by step).
struct WhyWrongSheet: View {
    let problem: CalculusProblem
    let answer: Expr
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let d = Checker.diagnose(answer, for: problem) {
                        content(d)
                    } else {
                        Text("This answer is actually correct now — tap Check answer.")
                            .foregroundStyle(.green)
                    }
                }
                .padding()
            }
            .background(Color.black)
            .navigationTitle("Why it's not right")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Back to it") { dismiss() } }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ d: Diagnosis) -> some View {
        switch problem.kind {
        case .integral:
            Text("An antiderivative is right when its derivative equals the integrand. Here's your answer differentiated:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            StepsList(steps: d.steps)
            Divider().background(Color.white.opacity(0.3))
            Text("That should equal the integrand:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            FittedMath(sizes: [24, 20, 17, 14, 12, 11]) { size in
                MathRowView(row: ExprDisplay.row(problem.display), size: size, mergeFunctionPowers: true)
                    .foregroundStyle(.white)
            }
            comparison(d, yoursLabel: "your answer′", expectedLabel: "integrand")
        case .derivative:
            Text("Your answer and the true derivative give different values:")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            comparison(d, yoursLabel: "your answer", expectedLabel: "f′")
            Text("Common slips: a missing inner derivative (chain rule), a sign in the quotient rule (u′v − uv′), or a power off by one.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func comparison(_ d: Diagnosis, yoursLabel: String, expectedLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("At x = \(fmt(d.x)):").font(.headline)
            HStack {
                Text("\(yoursLabel) =").foregroundStyle(.red)
                Text(d.yours.isFinite ? fmt(d.yours) : "undefined").bold().foregroundStyle(.red)
            }
            HStack {
                Text("\(expectedLabel) =").foregroundStyle(.green)
                Text(fmt(d.expected)).bold().foregroundStyle(.green)
            }
        }
        .font(.body.monospacedDigit())
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func fmt(_ v: Double) -> String {
        if v == v.rounded(), Swift.abs(v) < 1e6 { return String(Int(v)) }
        return String(format: "%.4g", v)
    }
}
