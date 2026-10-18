import SwiftUI
import MathEngine

// MARK: - Bagrut map

/// One question type of the Bagrut, 5 units, with the practice that trains it.
struct BagrutTopic: Identifiable {
    enum Target {
        /// A practice mode, and a sub-type for its Type menu.
        case mode(PracticeView.Mode, String?)
        case exam
    }

    let id: Int
    let paper: String
    let chapter: String
    let title: String
    let target: Target
}

/// Every question type on papers 571 and 572, numbered as in the list.
enum BagrutMap {
    private static func q(_ k: QuizKind, _ v: String? = nil) -> BagrutTopic.Target {
        PracticeView.Mode.topicKinds.contains(k) ? .mode(.quiz(k, v), nil) : .mode(.quiz(k, nil), v)
    }

    static let topics: [BagrutTopic] = {
        let c571 = ["Chapter 1 · Short questions", "Chapter 2 · Sequences, induction, probability",
                    "Chapter 3 · Geometry and trigonometry in the plane", "Chapter 4 · Calculus"]
        let c572 = ["Chapter 1 · Vectors, analytic geometry, complex numbers", "Chapter 2 · Growth and decay, exponential and log functions"]
        let rows: [(String, String, String, BagrutTopic.Target)] = [
            ("571", c571[0], "Short mixed questions", .mode(.quiz(nil, nil), nil)),
            ("571", c571[1], "Arithmetic sequence: a term, a₁ or d, sums", q(.sequence, "arithmetic")),
            ("571", c571[1], "Geometric sequence: a term, the ratio, sums", q(.sequence, "geometric")),
            ("571", c571[1], "Infinite geometric series: sum, convergence, finding q", q(.sequence, "infinite")),
            ("571", c571[1], "Recursive sequences: aₙ₊₁ = f(aₙ)", q(.sequence, "recursive")),
            ("571", c571[1], "Sequence word problems: savings, a bouncing ball", q(.sequence, "words")),
            ("571", c571[1], "Induction: equalities (sum formulas)", q(.induction, "equality")),
            ("571", c571[1], "Induction: divisibility", q(.induction, "divisibility")),
            ("571", c571[1], "Induction: inequalities", q(.induction, "inequality")),
            ("571", c571[1], "Probability: counting (groups, arrangements)", q(.probability, "counting")),
            ("571", c571[1], "Probability: independent events, complement", q(.probability, "independent")),
            ("571", c571[1], "Probability: without replacement", q(.probability, "draws")),
            ("571", c571[1], "Probability: two-way tables, conditional", q(.probability, "table")),
            ("571", c571[1], "Probability: tree diagrams, Bayes", q(.probability, "tree")),
            ("571", c571[1], "Probability: binomial, at least / exactly", q(.probability, "binomial")),
            ("571", c571[1], "Probability: repeated tries, first success, how many tries", q(.probability, "tries")),
            ("571", c571[1], "Probability: conditional binomial", q(.probability, "conditional")),
            ("571", c571[2], "Circle angles: inscribed, central, cyclic quadrilateral", q(.geometry, "angles")),
            ("571", c571[2], "Chords, tangents, secants", q(.geometry, "chords")),
            ("571", c571[2], "Similar triangles, area ratios", q(.geometry, "similar")),
            ("571", c571[2], "Angle bisector theorem, tangent lengths", q(.geometry, "bisector")),
            ("571", c571[2], "Law of cosines", q(.triangle, "cosines")),
            ("571", c571[2], "Law of sines and the circumradius", q(.triangle, "sines")),
            ("571", c571[2], "Triangle area ½ab·sin C", q(.triangle, "area")),
            ("571", c571[2], "An angle from three sides", q(.triangle, "angle")),
            ("571", c571[2], "Medians, heights, multi-step triangles", q(.triangle, "median")),
            ("571", c571[2], "Trig identities: sin/cos(α ± β), double angle, exact values", q(.trigIdentity)),
            ("571", c571[3], "Derivatives", .mode(.derivative, nil)),
            ("571", c571[3], "Integrals", .mode(.integral, nil)),
            ("571", c571[3], "Full investigation and sketch", .mode(.sketch, nil)),
            ("571", c571[3], "Reading graphs of f, f′ and F", q(.chooseGraph)),
            ("571", c571[3], "Transformations (|f|, 1/f, f², √f…)", .mode(.change, nil)),
            ("571", c571[3], "Sign tables", q(.signTable)),
            ("571", c571[3], "Number of solutions", q(.solutions)),
            ("571", c571[3], "Parameters", q(.parameter)),
            ("571", c571[3], "Limits and asymptotes", q(.limit)),
            ("571", c571[3], "Tangent and normal", q(.tangent)),
            ("571", c571[3], "Areas", q(.area)),
            ("571", c571[3], "Volume of revolution", q(.area, "volume")),
            ("571", c571[3], "Antiderivative through a point", q(.antiderivative)),
            ("571", c571[3], "Min and max problems", q(.optimization)),
            ("572", c572[0], "Vectors: length, dot product, angle, perpendicular", q(.vectors, "dot")),
            ("572", c572[0], "Lines in space: meeting, parallel or skew", q(.vectors, "lines")),
            ("572", c572[0], "Planes: a point on a plane, a line meets a plane", q(.vectors, "planes")),
            ("572", c572[0], "Angles: line and plane, two planes", q(.vectors, "angles")),
            ("572", c572[0], "Distances: point to plane, parallel planes", q(.vectors, "distance")),
            ("572", c572[0], "Circles: centre and radius, tangent, line and circle", q(.conics, "circle")),
            ("572", c572[0], "Parabola: focus, directrix", q(.conics, "parabola")),
            ("572", c572[0], "Ellipse: axes, foci", q(.conics, "ellipse")),
            ("572", c572[0], "Hyperbola: foci, asymptotes", q(.conics, "hyperbola")),
            ("572", c572[0], "Loci", q(.conics, "loci")),
            ("572", c572[0], "Complex numbers: algebraic form, equations", q(.complex, "algebraic")),
            ("572", c572[0], "Polar form, De Moivre", q(.complex, "polar")),
            ("572", c572[0], "Roots of complex numbers and their polygon", q(.complex, "roots")),
            ("572", c572[0], "Loci in the complex plane", q(.complex, "loci")),
            ("572", c572[1], "Growth and decay word problems", q(.growth)),
            ("572", c572[1], "Exponential and log equations (base e)", q(.equation, "exp")),
            ("572", c572[1], "Logs in any base", q(.equation, "base")),
            ("572", c572[1], "Rational powers", q(.equation, "powers")),
            ("572", c572[1], "Exponential and log investigation and sketch", .mode(.sketch, nil)),
            ("572", c572[1], "Exponential and log derivatives and integrals", .mode(.derivative, nil)),
            ("572", c572[1], "Graphs of ln f, e^f and 1/f", .mode(.change, nil)),
            ("571 + 572", "Full exams", "Full Bagrut exams (571 / 572 style), timed and scored", .exam),
        ]
        return rows.enumerated().map { i, r in BagrutTopic(id: i + 1, paper: r.0, chapter: r.1, title: r.2, target: r.3) }
    }()
}

struct BagrutMapView: View {
    var open: (BagrutTopic.Target) -> Void
    @Environment(\.dismiss) private var dismiss

    private struct ChapterGroup: Identifiable {
        let id: String
        var topics: [BagrutTopic]
    }

    private var chapters: [ChapterGroup] {
        var out: [ChapterGroup] = []
        for t in BagrutMap.topics {
            let key = "\(t.paper) · \(t.chapter)"
            if out.last?.id == key { out[out.count - 1].topics.append(t) } else { out.append(ChapterGroup(id: key, topics: [t])) }
        }
        return out
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Every question type of the 5-unit Bagrut (papers 571 and 572). Tap one to practise it.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(chapters) { chapter in
                    Section(chapter.id) {
                        ForEach(chapter.topics) { t in
                            Button {
                                Haptics.tap()
                                open(t.target)
                            } label: {
                                HStack(spacing: 10) {
                                    Text("\(t.id)")
                                        .font(.subheadline.monospacedDigit().weight(.bold))
                                        .foregroundStyle(.orange)
                                        .frame(minWidth: 28, alignment: .trailing)
                                    Text(t.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 4)
                                    Image(systemName: icon(t.target))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Bagrut map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func icon(_ t: BagrutTopic.Target) -> String {
        switch t {
        case .exam: "doc.text.fill"
        case .mode(let m, _): m.symbol
        }
    }
}

// MARK: - Full exam

/// A timed mock paper: the questions of 571 or 572, answered in any order, then scored like the Bagrut.
struct BagrutExamView: View {
    struct PartRef: Identifiable, Hashable {
        let question: Int
        let part: Int
        var id: String { "\(question)-\(part)" }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var paper: BagrutExam.Paper = .p571
    @State private var difficulty: Difficulty = .hard
    @State private var exam: BagrutExam?
    @State private var loading = false
    @State private var started = Date()
    @State private var finishedAt: Date?
    /// Credit per part: 1 = right first time, 0.5 = right after mistakes, 0 = wrong so far.
    @State private var credit: [String: Double] = [:]
    @State private var openPart: PartRef?
    @State private var reviewPart: PartRef?
    @State private var confirmFinish = false

    var body: some View {
        NavigationStack {
            Group {
                if let exam, let finishedAt {
                    results(exam, finishedAt)
                } else if let exam {
                    paperView(exam)
                } else {
                    intro
                }
            }
            .padding(.horizontal, 12)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(exam.map { "Bagrut \($0.paper.rawValue)" } ?? "Bagrut exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if exam != nil && finishedAt == nil {
                    ToolbarItem(placement: .confirmationAction) { Button("Finish") { confirmFinish = true } }
                }
            }
            .confirmationDialog("Finish the exam and see your score?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish") { finish() }
                Button("Keep going", role: .cancel) {}
            }
            .sheet(item: $openPart) { ref in
                if let exam, let q = part(exam, ref) {
                    ExamPartView(quiz: q, title: label(exam, ref)) { solvedFirstTime in
                        credit[ref.id] = max(credit[ref.id] ?? 0, solvedFirstTime ? 1 : 0.5)
                    } onWrong: {
                        if credit[ref.id] == nil { credit[ref.id] = 0 }
                    }
                }
            }
            .sheet(item: $reviewPart) { ref in
                if let exam, let q = part(exam, ref) { QuizStepsSheet(quiz: q) }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Before

    private var intro: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Paper", selection: $paper) {
                    ForEach(BagrutExam.Paper.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                VStack(alignment: .leading, spacing: 8) {
                    Text(paper.title).font(.title2.bold())
                    Text(paper.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.7))
                    Label("\(paper.minutes / 60) h \(paper.minutes % 60 == 0 ? "" : "\(paper.minutes % 60) min")", systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(paper.rules).font(.subheadline)
                    Text("Scoring: right the first time = full marks for that part; right after a mistake = half. Only your best \(paper.answerCount) questions count.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Summer 2026: the Ministry lifted the chapter limits and published a focus list for this session only — check the official notice with your teacher.")
                        .font(.footnote)
                        .foregroundStyle(.yellow.opacity(0.85))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
                HStack {
                    Text("Difficulty").font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                Button {
                    Haptics.press()
                    start()
                } label: {
                    Group {
                        if loading { ProgressView().tint(.black) } else { Text("Start the exam").font(.title2.bold()) }
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(PressableStyle())
                .disabled(loading)
            }
            .padding(.vertical)
        }
    }

    private func start() {
        loading = true
        let p = paper, level = difficulty.level, seed = ProblemFactory.randomSeed()
        Task {
            let made = await Task.detached { BagrutExam.make(p, level: level, seed: seed) }.value
            credit = [:]
            finishedAt = nil
            started = Date()
            exam = made
            loading = false
        }
    }

    // MARK: During

    private func paperView(_ exam: BagrutExam) -> some View {
        VStack(spacing: 8) {
            TimelineView(.periodic(from: .now, by: 1)) { t in
                let left = Double(exam.paper.minutes * 60) - t.date.timeIntervalSince(started)
                HStack {
                    Label(clock(max(0, left)), systemImage: left > 0 ? "timer" : "exclamationmark.triangle.fill")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(left > 600 ? .orange : .red)
                    Spacer()
                    Text("\(credit.filter { $0.value > 0 }.count) parts solved")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(exam.paper.rules)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ForEach(exam.questions) { question in
                        if question.number == exam.questions.first(where: { $0.chapter == question.chapter })?.number {
                            Text(question.chapterTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.orange)
                                .padding(.top, 6)
                        }
                        questionCard(question)
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func questionCard(_ question: BagrutExam.Question) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(question.number) · \(question.title)")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(Array(question.parts.enumerated()), id: \.offset) { i, part in
                let ref = PartRef(question: question.number, part: i)
                Button {
                    Haptics.tap()
                    openPart = ref
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(letter(i))
                            .font(.subheadline.bold())
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.kind.title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
                            Text(part.prompt)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 4)
                        statusIcon(credit[ref.id])
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(PressableStyle(scale: 0.98))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func statusIcon(_ c: Double?) -> some View {
        switch c {
        case nil: Image(systemName: "circle").foregroundStyle(.white.opacity(0.35))
        case 1?: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case 0.5?: Image(systemName: "checkmark.circle").foregroundStyle(.yellow)
        default: Image(systemName: "xmark.circle").foregroundStyle(.red)
        }
    }

    private func finish() {
        guard let exam else { return }
        for question in exam.questions {
            for (i, q) in question.parts.enumerated() {
                if let c = credit[PartRef(question: question.number, part: i).id] {
                    LearningStore.shared.record(.quiz(q), correct: c == 1)
                }
            }
        }
        LearningStore.shared.recordExam()
        withAnimation { finishedAt = Date() }
    }

    // MARK: After

    private func results(_ exam: BagrutExam, _ end: Date) -> some View {
        let get = { (q: Int, p: Int) -> Double in credit[PartRef(question: q, part: p).id] ?? 0 }
        let total = exam.score(credit: get)
        let per = exam.questionScores(credit: get)
        let counted = Set(per.enumerated().sorted { $0.element > $1.element }.prefix(exam.paper.answerCount).map(\.offset))
        return ScrollView {
            VStack(spacing: 14) {
                Text("\(Int(total.rounded()))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(total >= 85 ? .green : (total >= 55 ? .orange : .red))
                Text("out of 100 · \(clock(end.timeIntervalSince(started))) used")
                    .foregroundStyle(.secondary)
                Text("Your best \(exam.paper.answerCount) questions count. Tap a part to see its full solution.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ForEach(Array(exam.questions.enumerated()), id: \.offset) { i, question in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Question \(question.number) · \(question.title)").font(.subheadline.bold())
                            Spacer()
                            Text(String(format: "%.1f", per[i]))
                                .font(.subheadline.monospacedDigit().bold())
                                .foregroundStyle(counted.contains(i) ? .orange : .white.opacity(0.4))
                        }
                        HStack(spacing: 8) {
                            ForEach(question.parts.indices, id: \.self) { p in
                                Button {
                                    reviewPart = PartRef(question: question.number, part: p)
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(letter(p)).font(.caption.bold())
                                        statusIcon(credit[PartRef(question: question.number, part: p).id])
                                    }
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                }
                Button {
                    reset()
                } label: {
                    Text("Another exam").font(.title2.bold()).foregroundStyle(.black)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(PressableStyle())
            }
            .padding(.vertical)
        }
    }

    private func reset() {
        exam = nil
        finishedAt = nil
        credit = [:]
    }

    // MARK: Helpers

    private func part(_ exam: BagrutExam, _ ref: PartRef) -> QuizProblem? {
        exam.questions.first { $0.number == ref.question }?.parts[safe: ref.part]
    }

    private func label(_ exam: BagrutExam, _ ref: PartRef) -> String { "Question \(ref.question) · \(letter(ref.part))" }

    private func letter(_ i: Int) -> String { ["a", "b", "c", "d", "e", "f"][safe: i] ?? "\(i + 1)" }

    private func clock(_ t: Double) -> String {
        let s = Int(t)
        return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}

/// One sub-question of the exam, answered like any quick question.
struct ExamPartView: View {
    let quiz: QuizProblem
    let title: String
    var onSolved: (_ firstTime: Bool) -> Void
    var onWrong: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var editor = MathEditor()
    @State private var mistakes = 0

    var body: some View {
        NavigationStack {
            QuizView(quiz: quiz, editor: $editor, onWrong: {
                mistakes += 1
                onWrong()
            }) {
                onSolved(mistakes == 0)
                Haptics.press()
                dismiss()
            }
            .padding(.horizontal, 12)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Back to the paper") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}
