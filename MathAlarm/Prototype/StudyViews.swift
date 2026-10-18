import SwiftUI
import MathEngine

// MARK: - Speed round

/// Ten easy derivatives against the clock.
struct SpeedRoundView: View {
    static let count = 10

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LearningStore.shared
    @State private var problems: [CalculusProblem] = []
    @State private var index = 0
    @State private var editor = MathEditor()
    @State private var start: Date?
    @State private var finishedAfter: Double?
    @State private var previousBest: Double?
    @State private var wrongs = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if let finishedAfter {
                    results(finishedAfter)
                } else if start == nil {
                    intro
                } else if index < problems.count {
                    TimelineView(.periodic(from: .now, by: 0.1)) { t in
                        HStack {
                            Text("\(index + 1) / \(Self.count)")
                                .font(.headline.monospacedDigit())
                            ProgressView(value: Double(index), total: Double(Self.count))
                                .tint(.orange)
                            Text(clock(t.date.timeIntervalSince(start ?? t.date)))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(.orange)
                        }
                    }
                    ChallengeView(problem: problems[index], editor: $editor, onWrong: { wrongs += 1 }) {
                        next()
                    }
                    .id(index)
                }
            }
            .padding(.horizontal, 12)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Speed round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private var intro: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "stopwatch.fill").font(.system(size: 64)).foregroundStyle(.orange)
            Text("\(Self.count) quick derivatives").font(.title.bold())
            Text("The clock runs until the last one is right.")
                .foregroundStyle(.secondary)
            if let best = store.data.bestSpeedRound {
                Label("Best: \(clock(best))", systemImage: "trophy.fill").foregroundStyle(.yellow)
            }
            Spacer()
            Button {
                Haptics.press()
                problems = (0..<Self.count).map { _ in ProblemHistory.shared.fresh(.derivative, level: .easy) }
                index = 0
                editor = MathEditor()
                previousBest = store.data.bestSpeedRound
                start = Date()
            } label: {
                Text("Start").font(.title2.bold()).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.bottom)
    }

    private func results(_ t: Double) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: (previousBest ?? .infinity) > t ? "trophy.fill" : "flag.checkered")
                .font(.system(size: 64)).foregroundStyle(.yellow)
            Text(clock(t)).font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
            if (previousBest ?? .infinity) > t { Text("New best time!").font(.title3.bold()).foregroundStyle(.green) }
            else if let b = previousBest { Text("Best: \(clock(b))").foregroundStyle(.secondary) }
            Text("\(wrongs) wrong answer\(wrongs == 1 ? "" : "s")").foregroundStyle(.secondary)
            Spacer()
            Button {
                finishedAfter = nil
                start = nil
                wrongs = 0
            } label: {
                Text("Again").font(.title2.bold()).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.bottom)
    }

    private func next() {
        store.record(.calculus(problems[index]), correct: true)
        if index + 1 >= problems.count {
            let t = Date().timeIntervalSince(start ?? Date())
            store.recordSpeedRound(seconds: t)
            AppSettings.shared.recordSolved()
            finishedAfter = t
        } else {
            index += 1
            editor = MathEditor()
        }
    }

    private func clock(_ t: Double) -> String {
        let s = max(0, t)
        return String(format: "%d:%04.1f", Int(s) / 60, s.truncatingRemainder(dividingBy: 60))
    }
}

// MARK: - Mini exam

/// One function, three Bagrut-style parts: sign of f′, an extreme point, the sketch.
struct MiniExamView: View {
    let difficulty: Difficulty
    @Environment(\.dismiss) private var dismiss
    @State private var exam: MiniExam?
    @State private var part = 0
    @State private var editor = MathEditor()
    @State private var strokes: [SketchStroke] = []
    @State private var mistakes = 0

    private let parts = ["Sign of f′", "Extreme point", "Sketch"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(parts.indices, id: \.self) { i in
                        Text("\(i + 1). \(parts[i])")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(i == part ? .black : (i < part ? .green : .white.opacity(0.6)))
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .frame(maxWidth: .infinity)
                            .background(i == part ? Color.orange : Color.white.opacity(0.1), in: Capsule())
                    }
                }
                if let exam {
                    switch part {
                    case 0:
                        QuizView(quiz: exam.signs, editor: $editor, onWrong: { mistakes += 1 }) { advance() }
                            .id("signs")
                    case 1:
                        QuizView(quiz: exam.extreme, editor: $editor, onWrong: { mistakes += 1 }) { advance() }
                            .id("extreme")
                    case 2:
                        SketchChallengeView(problem: exam.sketch, strokes: $strokes, mode: AppSettings.shared.sketchMode,
                                            allowReveal: true, steps: { GraphSteps.steps(for: exam.sketch) },
                                            onWrong: { mistakes += 1 }, onSolved: advance) {
                            SketchHeader(problem: exam.sketch)
                        }
                        .id("sketch")
                    default:
                        done
                    }
                } else {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Mini exam · \(difficulty.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .task {
                if exam == nil {
                    let level = difficulty.level
                    exam = await Task.detached { MiniExam.make(level: level, seed: ProblemFactory.randomSeed()) }.value
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var done: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill").font(.system(size: 70)).foregroundStyle(.green)
            Text("Exam complete").font(.title.bold())
            Text(mistakes == 0 ? "No mistakes — Bagrut ready." : "\(mistakes) mistake\(mistakes == 1 ? "" : "s") along the way.")
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                part = 0; mistakes = 0; strokes = []; editor = MathEditor(); exam = nil
                let level = difficulty.level
                Task { exam = await Task.detached { MiniExam.make(level: level, seed: ProblemFactory.randomSeed()) }.value }
            } label: {
                Text("Another exam").font(.title2.bold()).foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 60)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(.bottom)
    }

    private func advance() {
        editor = MathEditor()
        withAnimation { part += 1 }
        if part == 3 {
            LearningStore.shared.recordExam()
            if let exam { LearningStore.shared.record(.sketch(exam.sketch), correct: mistakes == 0) }
        }
    }
}

// MARK: - Lists

/// One problem in a list: what kind, and its formula.
struct PracticeItemRow: View {
    let item: PracticeItem
    var date: Date? = nil
    var solved: Bool? = nil

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                    Text(item.level == .bagrut ? "Bagrut 5U" : item.level.rawValue.capitalized)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                if let f = item.formula {
                    MathRowView(row: ExprDisplay.row(f), size: 17, mergeFunctionPowers: true)
                        .foregroundStyle(.white)
                        .fixedSize()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()
                } else if let t = item.subtitle {
                    Text(t).font(.footnote).foregroundStyle(.white.opacity(0.8)).lineLimit(2)
                }
                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if let solved {
                Image(systemName: solved ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(solved ? .green : .red)
            }
        }
        .contentShape(Rectangle())
    }
}

struct ReviewListView: View {
    var open: (PracticeItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LearningStore.shared

    var body: some View {
        NavigationStack {
            List {
                let due = store.dueReview
                if due.isEmpty {
                    ContentUnavailableView("Nothing to review", systemImage: "checkmark.seal",
                                           description: Text("Problems you get wrong come back after 1, 3 and 7 days."))
                } else {
                    Section("Due now") {
                        ForEach(due) { r in
                            Button { open(r.item) } label: { PracticeItemRow(item: r.item) }
                        }
                    }
                }
                let later = store.data.review.filter { $0.due > Date() }.sorted { $0.due < $1.due }
                if !later.isEmpty {
                    Section("Coming back later") {
                        ForEach(later) { r in
                            VStack(alignment: .leading) {
                                PracticeItemRow(item: r.item)
                                Text("Due \(r.due.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.cyan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Review")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
}

struct WeakSpotsView: View {
    var practise: (PracticeView.Mode) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LearningStore.shared

    var body: some View {
        NavigationStack {
            List {
                let weak = store.weakTopics
                if weak.isEmpty {
                    ContentUnavailableView("Not enough data yet", systemImage: "scope",
                                           description: Text("After a few problems of each type, the ones you miss most show up here."))
                } else {
                    Section {
                        ForEach(Array(weak.enumerated()), id: \.offset) { _, w in
                            Button {
                                if let m = Self.mode(for: w.topic) { practise(m) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(w.topic).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                                        ProgressView(value: w.stat.rate)
                                            .tint(w.stat.rate < 0.5 ? .red : (w.stat.rate < 0.8 ? .yellow : .green))
                                    }
                                    Text("\(Int((w.stat.rate * 100).rounded()))%")
                                        .font(.headline.monospacedDigit())
                                        .frame(width: 52, alignment: .trailing)
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Worst first · tap to practise that type")
                    }
                }
            }
            .navigationTitle("Weak spots")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    static func mode(for topic: String) -> PracticeView.Mode? {
        let head = topic.components(separatedBy: " · ").first ?? topic
        switch head {
        case "Integral": return .integral
        case "Derivative": return .derivative
        case "Sketch": return .sketch
        case "Change": return .change
        default: return QuizKind.allCases.first { $0.title == head }.map { .quiz($0, nil) }
        }
    }
}

struct HistoryView: View {
    var open: (PracticeItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LearningStore.shared
    @State private var tab = 0
    @State private var pdf: URL?

    var body: some View {
        NavigationStack {
            List {
                Picker("Show", selection: $tab) {
                    Text("History").tag(0)
                    Text("Favourites").tag(1)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                let entries = tab == 0 ? store.data.history : store.data.favourites
                if entries.isEmpty {
                    ContentUnavailableView(tab == 0 ? "No problems yet" : "No favourites yet",
                                           systemImage: tab == 0 ? "clock" : "star",
                                           description: Text(tab == 0 ? "Problems you try in Practice appear here." : "Tap the star on a problem to keep it."))
                }
                ForEach(entries) { e in
                    Button { open(e.item) } label: {
                        PracticeItemRow(item: e.item, date: e.date, solved: tab == 0 ? e.solved : nil)
                    }
                    .swipeActions {
                        if tab == 1 {
                            Button(role: .destructive) { store.removeFavourite(e) } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
            }
            .navigationTitle(tab == 0 ? "History" : "Favourites")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                if tab == 1, !store.data.favourites.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        if let pdf {
                            ShareLink(item: pdf) { Label("Share PDF", systemImage: "square.and.arrow.up") }
                        } else {
                            Button { pdf = FavouritesPDF.make(store.data.favourites) } label: { Label("Make PDF", systemImage: "doc.richtext") }
                        }
                    }
                }
            }
            .onChange(of: store.data.favourites) { _, _ in pdf = nil }
        }
        .preferredColorScheme(.dark)
    }
}

/// A printable worksheet of your favourite problems (answers on the last page).
enum FavouritesPDF {
    @MainActor
    static func make(_ entries: [LearningStore.Entry]) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Math Alarm worksheet.pdf")
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let ctx = CGContext(url as CFURL, mediaBox: &box, nil) else { return nil }
        let perPage = 7
        let pages = stride(from: 0, to: entries.count, by: perPage).map { Array(entries[$0..<min($0 + perPage, entries.count)]) }
        for (n, page) in pages.enumerated() {
            render(Page(entries: page, first: n * perPage, answers: false), in: ctx)
        }
        let answers = entries.filter { if case .calculus = $0.item { return true } else { return false } }
        if !answers.isEmpty { render(Page(entries: Array(answers.prefix(14)), first: 0, answers: true), in: ctx) }
        ctx.closePDF()
        return url
    }

    @MainActor
    private static func render(_ page: Page, in ctx: CGContext) {
        let renderer = ImageRenderer(content: page.frame(width: 595, height: 842).colorInvert())
        ctx.beginPDFPage(nil)
        renderer.render { _, draw in draw(ctx) }
        ctx.endPDFPage()
    }

    private struct Page: View {
        let entries: [LearningStore.Entry]
        let first: Int
        let answers: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 18) {
                Text(answers ? "Answers" : "Math Alarm · practice sheet")
                    .font(.system(size: 22, weight: .bold))
                ForEach(Array(entries.enumerated()), id: \.offset) { i, e in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(first + i + 1). \(instruction(e.item))  ·  \(ShareCode.code(for: e.item))")
                            .font(.system(size: 12, weight: .semibold))
                        if answers, case .calculus(let p) = e.item {
                            MathRowView(row: ExprDisplay.row(p.reference), size: 18, mergeFunctionPowers: true).fixedSize()
                        } else if let f = e.item.formula {
                            MathRowView(row: ExprDisplay.row(f), size: 20, mergeFunctionPowers: true).fixedSize()
                        } else if let t = e.item.subtitle {
                            Text(t).font(.system(size: 14))
                        }
                    }
                }
                Spacer()
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(.white)
            .background(Color.black)
        }

        private func instruction(_ item: PracticeItem) -> String {
            switch item {
            case .calculus(let p): p.kind == .integral ? "Find the integral of" : "Differentiate"
            case .sketch: "Sketch the graph of"
            case .change(let c): "Given f, sketch \(c.transform.formula), where f(x) ="
            case .quiz(let q): q.prompt
            }
        }
    }
}

// MARK: - Study hub

/// Every study mode as a card, with a hint of where you stand.
struct StudyHubView: View {
    enum Choice {
        case sheet(PracticeView.Sheet)
        case code
        case daily(PracticeItem)
    }

    var choose: (Choice) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = LearningStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    dailyCard
                    HStack(spacing: 12) {
                        tile("Bagrut map", "map.fill", .mint, "All \(BagrutMap.topics.count) question types of the 5-unit Bagrut") { choose(.sheet(.map)) }
                        tile("Bagrut exam", "graduationcap.fill", .pink, "A full 571 or 572 paper, timed and scored") { choose(.sheet(.bagrut)) }
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        tile("Speed round", "stopwatch.fill", .orange,
                             store.data.bestSpeedRound.map { String(format: "Best %.0f s", $0) } ?? "10 derivatives, against the clock") { choose(.sheet(.speed)) }
                        tile("Mini exam", "doc.text.fill", .purple,
                             store.data.examsDone > 0 ? "\(store.data.examsDone) done" : "Sign table → extreme → sketch") { choose(.sheet(.exam)) }
                        tile("Review", "arrow.counterclockwise.circle.fill", .red,
                             store.dueReview.isEmpty ? "Nothing due" : "\(store.dueReview.count) due now",
                             badge: store.dueReview.count) { choose(.sheet(.review)) }
                        tile("Weak spots", "scope", .yellow,
                             store.weakTopics.first.map { "Weakest: \($0.topic)" } ?? "Needs a few attempts first") { choose(.sheet(.weak)) }
                        tile("History", "clock.fill", .cyan,
                             "\(store.data.history.count) problems · \(store.data.favourites.count) ★") { choose(.sheet(.history)) }
                        tile("Share code", "keyboard", .green, "Open a friend's problem") { choose(.code) }
                    }
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }

    private var dailyCard: some View {
        let item = DailyProblem.today()
        let done = store.data.history.contains { $0.item.signature == item.signature && $0.solved }
        return Button {
            Haptics.tap()
            choose(.daily(item))
        } label: {
            HStack(spacing: 14) {
                Image(systemName: done ? "checkmark.seal.fill" : "sun.max.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(done ? .green : .yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily problem").font(.headline).foregroundStyle(.white)
                    Text("\(item.title) · the same for everyone today").font(.footnote).foregroundStyle(.white.opacity(0.7))
                    if done { Text("Solved today").font(.caption.weight(.bold)).foregroundStyle(.green) }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.5))
            }
            .padding(16)
            .background(LinearGradient(colors: [Color.orange.opacity(0.35), Color.purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle(scale: 0.97))
    }

    private func tile(_ title: String, _ symbol: String, _ color: Color, _ detail: String, badge: Int = 0,
                      action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol).font(.title2).foregroundStyle(color)
                    Spacer()
                    if badge > 0 {
                        Text("\(badge)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 2).background(Color.red, in: Capsule())
                    }
                }
                Text(title).font(.headline).foregroundStyle(.white)
                Text(detail).font(.caption).foregroundStyle(.white.opacity(0.65)).lineLimit(2).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle(scale: 0.96))
    }
}
