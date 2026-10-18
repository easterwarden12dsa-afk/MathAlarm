import SwiftUI
import MathEngine

/// Shows a calculus problem, the typeset answer being typed, the keypad and
/// a big Check button. Used by the ringing screen and Practice mode.
struct ChallengeView: View {
    let problem: CalculusProblem
    @Binding var editor: MathEditor
    /// A note shown above the problem (e.g. "Graph Sketch arrives later").
    var note: String? = nil
    /// When set (ringing screen), opening the full solution replaces the
    /// problem with a new one; the closure does the replacing.
    var onSolutionViewed: (() -> Void)? = nil
    /// A wrong answer (alarms: escalation; practice: statistics).
    var onWrong: () -> Void = {}
    var onSolved: () -> Void

    @State private var feedback: Feedback?
    @State private var wrongAttempts = 0
    @State private var shakes: CGFloat = 0
    @State private var solved = false
    @State private var lastWrongAnswer: Expr?
    @State private var showWhy = false
    @State private var showSolution = false
    @State private var confirmSolution = false
    /// Hint ladder: 0 none, 1 technique, 2 first step, 3 more steps.
    @State private var hintLevel = 0
    @State private var mistake: MistakeFinder.Mistake?

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

    /// Pieces of the problem to paste into the answer (chain rule: the inner
    /// function again and again).
    private var copyStrip: some View {
        let pieces = ExprPieces.pieces(of: problem.display)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                    Button {
                        Haptics.tap()
                        editor.paste(ExprDisplay.row(piece))
                    } label: {
                        MathRowView(row: ExprDisplay.row(piece), size: 15, mergeFunctionPowers: true)
                            .foregroundStyle(.white)
                            .fixedSize()
                            .padding(.horizontal, 4)
                            .frame(minHeight: 26)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Paste \(piece.description)")
                }
            }
            .padding(.horizontal, 2)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 70)
    }

    var body: some View {
        // Shrink the keypad (not the problem) until everything fits, so the
        // screen never spills over the controls above it.
        ViewThatFits(in: .vertical) {
            layout(keyHeight: 44, spacing: 8)
            layout(keyHeight: 38, spacing: 6)
            layout(keyHeight: 33, spacing: 5)
            layout(keyHeight: 29, spacing: 4)
        }
        .onChange(of: editor) { _, _ in
            if feedback != .correct && feedback != .wrong && feedback != .undefined { feedback = nil }
        }
        .sheet(isPresented: $showWhy) {
            if let lastWrongAnswer {
                WhyWrongSheet(problem: problem, answer: lastWrongAnswer)
            }
        }
        .sheet(isPresented: $showSolution, onDismiss: {
            onSolutionViewed?()
        }) {
            SolutionSheet(problem: problem,
                          warning: onSolutionViewed == nil ? nil : "After you close this, you'll get a new problem of the same kind to solve.")
        }
        .confirmationDialog("Show the full solution?", isPresented: $confirmSolution, titleVisibility: .visible) {
            Button("Show solution (new problem after)") { showSolution = true }
            Button("Keep trying", role: .cancel) {}
        } message: {
            Text("The alarm still needs a solved problem, so you'll get a fresh one afterwards.")
        }
    }

    private func layout(keyHeight: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
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

            copyStrip

            MathKeypad(editor: $editor, allowConstantC: problem.kind == .integral, keyHeight: keyHeight)

            Button(action: check) {
                Label(solved ? "Correct!" : "Check answer", systemImage: solved ? "checkmark" : "checkmark.circle")
                    .font(.title3.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: keyHeight + 6)
                    .background(solved ? Color.green : Color.white, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(PressableStyle())
            .disabled(solved)
        }
    }

    // MARK: Pieces

    private var problemCard: some View {
        VStack(spacing: 4) {
            HStack {
                Text(problem.kind == .integral ? "Integrate" : "Differentiate")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                Button {
                    Haptics.tap()
                    if onSolutionViewed == nil { showSolution = true } else { confirmSolution = true }
                } label: {
                    Label("Steps", systemImage: "list.number")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(PressableStyle())
                .tint(.cyan)
            }
            FittedMath { size in
                ProblemFormula(problem: problem, size: size)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            if problem.hasRestrictedDomain {
                Text("for \(format(problem.domainLow)) ≤ x ≤ \(format(problem.domainHigh))")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.65))
            }
            hints
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    /// Hints get stronger one tap at a time: the technique, the first step, then more.
    @ViewBuilder
    private var hints: some View {
        if hintLevel >= 1 {
            Text("Hint: \(problem.technique)")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.cyan)
        }
        if hintLevel >= 2 {
            let steps = problem.solutionSteps.filter { $0.style == nil }
            ScrollView {
                StepsList(steps: Array(steps.prefix(hintLevel == 2 ? 1 : 3)))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: hintLevel == 2 ? 60 : 120)
        }
        if wrongAttempts >= 1, hintLevel < 3 {
            Button {
                Haptics.tap()
                withAnimation { hintLevel += 1 }
            } label: {
                Label(["Hint: which technique?", "Hint: first step", "Hint: more steps"][hintLevel], systemImage: "lightbulb.fill")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(PressableStyle())
            .tint(.cyan)
        }
    }

    private var answerCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(problem.kind == .integral ? "Your antiderivative" : "Your derivative")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(problem.kind == .integral ? "+ C optional · tap to move cursor" : "tap to move cursor")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            AnswerField(editor: $editor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 2))
    }

    private var borderColor: Color {
        switch feedback {
        case .some(let f): f.color
        case .none: Color.white.opacity(0.12)
        }
    }

    @ViewBuilder
    private var feedbackLine: some View {
        if let feedback {
            HStack(spacing: 8) {
                Label(feedback.text, systemImage: feedback.symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(feedback.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if (feedback == .wrong || feedback == .undefined), lastWrongAnswer != nil {
                    Button {
                        Haptics.tap()
                        showWhy = true
                    } label: {
                        Label("Why?", systemImage: "questionmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .transition(.opacity)
            if let mistake, feedback == .wrong {
                Label(mistake.explanation, systemImage: "lightbulb.max.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.yellow)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
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
                wrong(.wrong, answer)
            case .undefined:
                wrong(.undefined, answer)
            }
        } catch let error as EntryError {
            withAnimation { feedback = .incomplete(error.message) }
            Haptics.warning()
        } catch {
            withAnimation { feedback = .incomplete("Check your entry.") }
            Haptics.warning()
        }
    }

    private func wrong(_ f: Feedback, _ answer: Expr) {
        wrongAttempts += 1
        lastWrongAnswer = answer
        mistake = problem.kind == .derivative
            ? MistakeFinder.diagnose(answer, derivativeOf: problem.display, in: problem.domainLow...problem.domainHigh)
            : nil
        onWrong()
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((problem.kind == .integral ? "Integrate " : "Differentiate ") + problem.display.description)
    }
}
