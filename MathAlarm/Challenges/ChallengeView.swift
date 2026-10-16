import SwiftUI
import MathEngine

/// Shows a calculus problem, the typeset answer being typed, the keypad and
/// a big Check button. Used by the ringing screen and Practice mode.
struct ChallengeView: View {
    let problem: CalculusProblem
    @Binding var editor: MathEditor
    /// A note shown above the problem (e.g. "Graph Sketch arrives in M3").
    var note: String? = nil
    var onSolved: () -> Void

    @State private var feedback: Feedback?
    @State private var wrongAttempts = 0
    @State private var shakes: CGFloat = 0
    @State private var solved = false

    enum Feedback: Equatable {
        case wrong
        case undefined
        case incomplete(String)
        case correct

        var text: String {
            switch self {
            case .wrong: "Not quite — keep editing and try again."
            case .undefined: "Your answer isn't defined on this interval."
            case .incomplete(let why): "Not finished yet: \(why)"
            case .correct: "Correct!"
            }
        }

        var color: Color {
            switch self {
            case .wrong, .undefined: .red
            case .incomplete: .yellow
            case .correct: .green
            }
        }

        var symbol: String {
            switch self {
            case .wrong, .undefined: "xmark.circle.fill"
            case .incomplete: "exclamationmark.circle.fill"
            case .correct: "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if let note {
                Text(note)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
            }

            problemCard

            answerCard
                .modifier(Shake(animatableData: shakes))

            feedbackLine

            MathKeypad(editor: $editor, allowConstantC: problem.kind == .integral)

            Button(action: check) {
                Label(solved ? "Correct!" : "Check answer", systemImage: solved ? "checkmark" : "checkmark.circle")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .background(solved ? Color.green : Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
            .disabled(solved)
        }
        .onChange(of: editor) { _, _ in
            if feedback != .correct { feedback = nil }
        }
    }

    // MARK: Pieces

    private var problemCard: some View {
        VStack(spacing: 6) {
            Text(problem.kind == .integral ? "Integrate" : "Differentiate")
                .font(.headline)
                .foregroundStyle(.orange)
            FittedMath { size in
                ProblemFormula(problem: problem, size: size)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 70)
            if problem.hasRestrictedDomain {
                Text("for \(format(problem.domainLow)) ≤ x ≤ \(format(problem.domainHigh))")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }
            if wrongAttempts >= 2 {
                Text("Hint: \(problem.technique)")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.cyan)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(problem.kind == .integral ? "Your antiderivative" : "Your derivative")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                if problem.kind == .integral {
                    Text("+ C optional")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            FittedMath(sizes: [30, 26, 22, 19, 16, 13]) { size in
                MathRowView(row: editor.root, cursor: editor.cursor, size: size)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }
        .padding(12)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 2))
    }

    private var borderColor: Color {
        switch feedback {
        case .some(let f): f.color
        case .none: Color.orange.opacity(0.6)
        }
    }

    @ViewBuilder
    private var feedbackLine: some View {
        if let feedback {
            Label(feedback.text, systemImage: feedback.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(feedback.color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }

    // MARK: Checking

    private func check() {
        guard !solved else { return }
        do {
            let answer = try RowParser.parse(editor)
            switch Checker.check(answer, for: problem) {
            case .correct:
                solved = true
                withAnimation { feedback = .correct }
                Haptics.success()
                Task {
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    onSolved()
                }
            case .incorrect:
                wrong(.wrong)
            case .undefined:
                wrong(.undefined)
            }
        } catch let error as EntryError {
            withAnimation { feedback = .incomplete(error.message) }
            Haptics.warning()
        } catch {
            withAnimation { feedback = .incomplete("Check your entry.") }
            Haptics.warning()
        }
    }

    private func wrong(_ f: Feedback) {
        wrongAttempts += 1
        withAnimation { feedback = f }
        withAnimation(.linear(duration: 0.4)) { shakes += 1 }
        Haptics.error()
    }

    private func format(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
    }
}

/// ∫ f(x) dx  or  d/dx [ f(x) ], typeset.
struct ProblemFormula: View {
    let problem: CalculusProblem
    var size: CGFloat = 28

    var body: some View {
        let formula = ExprDisplay.row(problem.display)
        HStack(alignment: .mathAxis, spacing: size * 0.12) {
            switch problem.kind {
            case .integral:
                Text("∫")
                    .font(.system(size: size * 1.9, weight: .light, design: .serif))
                    .alignmentGuide(.mathAxis) { d in d[VerticalAlignment.center] }
                MathRowView(row: formula, size: size, mergeFunctionPowers: true)
                Text("dx").font(MathFont.italic(size))
            case .derivative:
                VStack(spacing: size * 0.08) {
                    Text("d").font(MathFont.italic(size * 0.86))
                    Rectangle().fill(Color.white).frame(height: Swift.max(1.5, size * 0.06)).frame(maxWidth: .infinity)
                        .alignmentGuide(.mathAxis) { d in d[VerticalAlignment.center] }
                    Text("dx").font(MathFont.italic(size * 0.86))
                }
                .fixedSize()
                MathRowView(row: Row([.paren(formula)]), size: size, mergeFunctionPowers: true)
            }
        }
        .foregroundStyle(.white)
    }
}
