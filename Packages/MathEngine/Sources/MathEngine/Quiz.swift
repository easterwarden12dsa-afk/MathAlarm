import Foundation

// MARK: - Model

/// One answer option of a multiple-choice question: text, a formula or a graph.
public struct QuizOption: Codable, Hashable, Sendable {
    public var text: String?
    public var math: Expr?
    public var graph: SketchProblem?

    public init(text: String? = nil, math: Expr? = nil, graph: SketchProblem? = nil) {
        self.text = text
        self.math = math
        self.graph = graph
    }
}

public enum QuizAnswer: Codable, Hashable, Sendable {
    /// Tap one option.
    case choice([QuizOption], correct: Int)
    /// Type a number (exact forms like ln 3, √3, 2π/3 are fine).
    case number(Double)
    /// Type a function of x (e.g. the right side of a tangent line).
    case function(Expr)
    /// Tap + or − for each interval.
    case signs(intervals: [String], positive: [Bool])
}

/// The quick question types (Bagrut sub-questions).
public enum QuizKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case chooseGraph, parameter, area, limit, tangent, solutions, signTable, equation
    // Added later: keep them last so share codes stay the same.
    case probability, triangle, optimization
    case sequence, induction, geometry, trigIdentity, vectors, conics, complex, growth, antiderivative

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chooseGraph: "Choose the graph"
        case .parameter: "Find the parameter"
        case .area: "Area"
        case .limit: "Limit"
        case .tangent: "Tangent line"
        case .solutions: "How many solutions"
        case .signTable: "Sign table"
        case .equation: "Equation"
        case .probability: "Probability"
        case .triangle: "Triangles"
        case .optimization: "Min & max"
        case .sequence: "Sequences"
        case .induction: "Induction"
        case .geometry: "Circles & similarity"
        case .trigIdentity: "Trig identities"
        case .vectors: "Vectors in space"
        case .conics: "Analytic geometry"
        case .complex: "Complex numbers"
        case .growth: "Growth & decay"
        case .antiderivative: "Find f from f′"
        }
    }

    public var symbol: String {
        switch self {
        case .chooseGraph: "square.grid.2x2"
        case .parameter: "a.circle"
        case .area: "square.bottomhalf.filled"
        case .limit: "arrow.right.to.line"
        case .tangent: "line.diagonal.arrow"
        case .solutions: "number"
        case .signTable: "plusminus"
        case .equation: "equal"
        case .probability: "dice"
        case .triangle: "triangle"
        case .optimization: "arrow.up.and.down"
        case .sequence: "list.number"
        case .induction: "arrow.down.forward.and.arrow.up.backward"
        case .geometry: "circle.dashed"
        case .trigIdentity: "waveform"
        case .vectors: "cube"
        case .conics: "oval"
        case .complex: "i.circle"
        case .growth: "chart.line.uptrend.xyaxis"
        case .antiderivative: "arrow.uturn.backward"
        }
    }

    /// The sub-types of this kind of question (empty: only one type).
    public var variants: [QuizVariant] {
        func v(_ id: String, _ title: String, _ symbol: String, _ cases: [Int]) -> QuizVariant {
            QuizVariant(id: id, title: title, symbol: symbol, cases: cases)
        }
        switch self {
        case .chooseGraph:
            return [v("derivative", "f → f′", "chart.line.downtrend.xyaxis", [0]), v("formula", "Formula → graph", "function", [1]),
                    v("absolute", "|f|", "chart.line.flattrend.xyaxis", [2]), v("antiderivative", "f → F", "chart.line.uptrend.xyaxis", [3])]
        case .parameter:
            return [v("extremum", "Extreme points", "arrow.up.and.down", [0, 1, 3, 5, 6, 7, 9, 10, 12]),
                    v("tangents", "Tangents & slopes", "line.diagonal", [4, 14, 15]),
                    v("other", "Asymptotes, points, areas", "point.topleft.down.to.point.bottomright.curvepath", [2, 8, 11, 13])]
        case .area:
            return [v("under", "Under a curve", "square.bottomhalf.filled", [1, 3, 4, 6, 7, 10, 11, 12]),
                    v("between", "Between two curves", "square.split.1x2", [5, 9]),
                    v("sign", "Arches & sign changes", "waveform", [0, 2, 8]),
                    v("volume", "Volume of revolution", "rotate.3d", [13])]
        case .limit:
            return [v("factor", "0/0 by factoring", "divide", [0]), v("infinity", "x → ±∞", "infinity", [1, 9]),
                    v("roots", "Square roots (conjugate)", "x.squareroot", [2, 3]), v("onesided", "At an asymptote (±∞)", "arrow.right.to.line", [4]),
                    v("special", "Special limits (sin, e, ln, 1^∞)", "sparkles", [5, 6, 7]), v("lhopital", "L'Hôpital", "function", [8])]
        case .equation:
            return [v("exp", "Exponential", "x.squareroot", [0, 4, 8]), v("log", "Logarithms", "l.circle", [2, 3, 6]),
                    v("trig", "Trigonometric", "waveform.path", [1, 7]), v("root", "Square roots", "checkmark.shield", [5]),
                    v("base", "Logs in any base", "textformat.subscript", [9, 10]), v("powers", "Rational powers", "textformat.superscript", [11, 12])]
        case .probability:
            return [v("independent", "Independent events", "circle.grid.2x1", [0]), v("draws", "Without replacement", "bag", [1]),
                    v("table", "Two-way tables", "tablecells", [2]), v("binomial", "Binomial", "chart.bar", [3, 5]),
                    v("tree", "Trees & Bayes", "arrow.triangle.branch", [4, 8]), v("tries", "Repeated tries", "repeat", [6, 7]),
                    v("conditional", "Conditional binomial", "line.3.horizontal.decrease.circle", [9]),
                    v("counting", "Counting", "number.square", [10, 11])]
        case .triangle:
            return [v("cosines", "Law of cosines", "triangle", [0, 5]), v("sines", "Law of sines", "triangle.lefthalf.filled", [2]),
                    v("area", "Area", "triangle.fill", [1]), v("angle", "Find an angle", "angle", [3, 6]),
                    v("radius", "Circle radius", "circle.circle", [4, 9]), v("median", "Medians & heights", "line.diagonal", [7, 8])]
        case .optimization:
            return [v("numbers", "Numbers", "number", [0, 3]), v("fence", "Fences & boxes", "shippingbox", [1, 2]),
                    v("rectangles", "Rectangles in graphs", "rectangle.dashed", [4, 6, 7]), v("distance", "Shortest distance", "ruler", [5]),
                    v("classics", "Bagrut classics", "graduationcap", [8, 9, 10])]
        case .tangent:
            return [v("point", "Tangent at a point", "line.diagonal", [0]), v("normal", "Normal line", "arrow.up.right.and.arrow.down.left", [1]),
                    v("slope", "Tangent with a given slope", "angle", [2])]
        case .sequence:
            return [v("arithmetic", "Arithmetic", "plus.forwardslash.minus", [0, 1, 10]), v("geometric", "Geometric", "multiply", [2, 3]),
                    v("infinite", "Infinite series", "infinity", [4, 5]), v("recursive", "Recursive", "arrow.clockwise", [6, 7]),
                    v("words", "Word problems", "text.bubble", [8, 9])]
        case .induction:
            return [v("equality", "Sum formulas", "equal.square", [0, 1, 2]), v("divisibility", "Divisibility", "divide.square", [3]),
                    v("inequality", "Inequalities", "lessthan.square", [4])]
        case .geometry:
            return [v("angles", "Angles in a circle", "circle.dashed", [0, 1, 2]), v("chords", "Chords, tangents, secants", "circle.and.line.horizontal", [3, 4]),
                    v("similar", "Similar triangles", "triangle", [5, 6, 9]), v("bisector", "Bisectors & tangent lengths", "angle", [7, 8])]
        case .trigIdentity:
            return [v("exact", "Exact values", "number", [0]), v("double", "Double angle", "2.circle", [1]),
                    v("sum", "sin/cos/tan(α ± β)", "plus.forwardslash.minus", [2, 3]), v("simplify", "Simplify", "wand.and.stars", [4]),
                    v("equations", "Equations with identities", "equal", [5])]
        case .vectors:
            return [v("dot", "Length, dot product, angle", "arrow.up.right", [0, 1, 2]), v("lines", "Lines in space", "line.diagonal", [3, 4]),
                    v("planes", "Planes", "square.on.square.dashed", [5, 6]), v("angles", "Angles", "angle", [7, 8]),
                    v("distance", "Distances", "ruler", [9, 10])]
        case .conics:
            return [v("circle", "Circles", "circle", [0, 1, 2]), v("parabola", "Parabola", "point.topleft.down.to.point.bottomright.curvepath", [3]),
                    v("ellipse", "Ellipse", "oval", [4]), v("hyperbola", "Hyperbola", "arrow.left.and.right", [5]),
                    v("loci", "Loci", "location", [6, 7])]
        case .complex:
            return [v("algebraic", "Algebraic form", "i.circle", [0, 1, 2]), v("polar", "Polar form, De Moivre", "circle.and.line.horizontal", [3, 4]),
                    v("roots", "Roots & polygons", "hexagon", [5, 6]), v("loci", "Loci", "location.circle", [7])]
        case .growth:
            return [v("growth", "Growth", "chart.line.uptrend.xyaxis", [0, 1]), v("decay", "Decay & half-life", "chart.line.downtrend.xyaxis", [2]),
                    v("time", "How long?", "clock", [3, 4]), v("model", "Find the model", "function", [5])]
        case .antiderivative:
            return [v("polynomial", "Polynomials", "x.squareroot", [0, 3]), v("exp", "eˣ and 1/x", "e.circle", [1]),
                    v("trig", "Trigonometric", "waveform", [2])]
        case .solutions, .signTable:
            return []
        }
    }

    /// Sub-types used only by the full exams (not shown in Practice).
    var examVariants: [QuizVariant] {
        switch self {
        case .area: [QuizVariant(id: "explog", title: "eˣ and ln", symbol: "e.circle", cases: [3, 11, 12])]
        case .parameter: [QuizVariant(id: "explog", title: "eˣ and ln", symbol: "e.circle", cases: [3, 7, 9, 10])]
        default: []
        }
    }

    /// The short calculus questions (the "Questions" mix).
    public static let quickCalculus: [QuizKind] = [.chooseGraph, .parameter, .area, .limit, .tangent, .solutions, .signTable, .equation]

    /// Calculus questions about a function, as opposed to the other Bagrut topics.
    public var isCalculus: Bool {
        switch self {
        case .chooseGraph, .parameter, .area, .limit, .tangent, .solutions, .signTable, .equation, .optimization, .antiderivative, .growth: true
        default: false
        }
    }
}

/// A sub-type of a question kind (e.g. "Binomial" in Probability).
public struct QuizVariant: Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbol: String
    /// Which generator cases make it.
    let cases: [Int]
}

/// A short question about a function, answered by tapping or typing.
public struct QuizProblem: Codable, Hashable, Sendable {
    public var kind: QuizKind
    public var level: Level
    public var seed: UInt64
    /// What to do, in words.
    public var prompt: String
    /// The function, typeset ("f(x) =" + formula) …
    public var formulaLabel: String?
    public var formula: Expr?
    /// … or as plain text when it contains a parameter a.
    public var formulaText: String?
    /// A graph to look at.
    public var graph: SketchProblem?
    /// Shaded area under the graph (to the x-axis, or to `lower`).
    public var shade: ClosedRange<Double>?
    public var lower: SketchProblem?
    /// A horizontal line y = k drawn on the graph.
    public var level_k: Double?
    public var answer: QuizAnswer
    public var steps: [SolutionStep]
    /// For weak-spot statistics, e.g. "limit:removable".
    public var topic: String
    /// A triangle to look at (trigonometry in the plane).
    public var triangle: TriangleFigure? = nil
    /// A two-way table of counts (probability).
    public var table: QuizTable? = nil
    /// Typed numbers within this distance are right (answers "to 2 decimal places").
    public var tolerance: Double? = nil
    /// The sub-type it was asked for (nil = any), so share codes rebuild it exactly.
    public var variant: String? = nil
    /// A picture of the situation (fence, box, tree diagram…).
    public var diagram: QuizDiagram? = nil
    /// A geometry drawing: circles, solids in space, conics, the complex plane.
    public var figure: GeoFigure? = nil

    public var signature: String {
        "quiz:\(kind.rawValue):\(prompt):\(formula?.description ?? formulaText ?? ""):\(graph?.function.description ?? "")"
    }
}

/// A triangle drawn with its labels. Vertices are in any units (the app scales them).
public struct TriangleFigure: Codable, Hashable, Sendable {
    /// x0, y0, x1, y1, x2, y2.
    public var points: [Double]
    public var vertexLabels: [String]
    /// Side i joins vertex i and vertex i+1 (AB, BC, CA); nil = no label.
    public var sideLabels: [String?]
    /// At vertex i; nil = no label.
    public var angleLabels: [String?]
    /// An extra segment (median, height): x1, y1, x2, y2, with its label and the new point's name.
    public var extra: [Double]? = nil
    public var extraLabel: String? = nil
    public var extraPoint: String? = nil
}

/// A sketch of a word problem. `numbers` and `labels` depend on the kind.
public struct QuizDiagram: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// A rectangle against a wall: labels = [side, other side].
        case fence
        /// A square sheet with squares cut from the corners: labels = [side, cut].
        case box
        /// A trapezoid with three equal sides: labels = [side, angle].
        case trapezoid
        /// A cone's cross-section: labels = [slant, height, radius].
        case cone
        /// A two-level tree: numbers = [P(A), P(event|A), P(event|B)], labels = [A, B, event, not event].
        case tree
        /// A bag of balls: numbers = [red, blue].
        case bag
        /// On the graph: a rectangle from x = numbers[0] to numbers[1] up to f(numbers[2]).
        case rectangleUnder
        /// On the graph: the tangent at x = numbers[0] and the triangle it makes with the axes.
        case tangentTriangle
    }
    public var kind: Kind
    public var numbers: [Double] = []
    public var labels: [String] = []

    public init(_ kind: Kind, numbers: [Double] = [], labels: [String] = []) {
        self.kind = kind
        self.numbers = numbers
        self.labels = labels
    }
}

/// Counts in a two-way table; the first entry of each row is its name.
public struct QuizTable: Codable, Hashable, Sendable {
    public var columns: [String]
    public var rows: [[String]]
}

// MARK: - Checking typed answers

public enum QuizChecker {
    /// Typed answers: a number (no x) or a function of x.
    public static func check(_ typed: Expr, for q: QuizProblem) -> Bool {
        switch q.answer {
        case .number(let v):
            guard !typed.containsX else { return false }
            let t = typed.evaluate(at: 0)
            return t.isFinite && Swift.abs(t - v) <= (q.tolerance ?? 1e-6 * Swift.max(1, Swift.abs(v)))
        case .function(let f):
            let xs: [Double] = [-2.3, -1.1, -0.4, 0.3, 0.9, 1.7, 2.6, 3.4]
            var compared = 0
            for x in xs {
                let a = typed.evaluate(at: x), b = f.evaluate(at: x)
                guard b.isFinite else { continue }
                guard a.isFinite, Swift.abs(a - b) <= 1e-6 * Swift.max(1, Swift.abs(b)) else { return false }
                compared += 1
            }
            return compared >= 4
        case .choice, .signs:
            return false
        }
    }
}

// MARK: - Generators

public enum QuizFactory {
    /// `avoidTopics`: sub-types shown recently ("limit:factor"); a different one is preferred.
    public static func make(_ kind: QuizKind, level: Level, seed: UInt64, avoiding: Set<String> = [], variant: String? = nil,
                            avoidTopics: Set<String> = []) -> QuizProblem {
        let cases = (kind.variants + kind.examVariants).first { $0.id == variant }?.cases
        var s = seed
        var first: QuizProblem?, fresh: QuizProblem?
        for i in 0..<80 {
            var r = SeededRandom(seed: s)
            if var q = candidate(kind, level: level, rng: &r, seed: s, cases: cases) {
                if cases != nil { q.variant = variant }
                q.steps = numbered(q.steps)
                if !avoiding.contains(q.signature) {
                    if !avoidTopics.contains(q.topic) || i >= 40 { return q }
                    if fresh == nil { fresh = q }
                }
                if first == nil { first = q }
            }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        if let q = fresh ?? first { return q }
        // Never fails: keep trying seeds, then any easy limit.
        for k in UInt64(1)...2_000 {
            var r = SeededRandom(seed: seed &+ k)
            if var q = candidate(kind, level: level, rng: &r, seed: seed &+ k, cases: nil) ?? candidate(.limit, level: .easy, rng: &r, seed: seed &+ k, cases: nil) {
                q.steps = numbered(q.steps)
                return q
            }
        }
        fatalError("no quiz question could be made")
    }

    static func candidate(_ kind: QuizKind, level: Level, rng r: inout SeededRandom, seed: UInt64, cases: [Int]?) -> QuizProblem? {
        switch kind {
        case .chooseGraph: return chooseGraph(level, &r, seed, cases)
        case .parameter: return parameter(level, &r, seed, cases)
        case .area: return area(level, &r, seed, cases)
        case .limit: return limit(level, &r, seed, cases)
        case .tangent: return tangent(level, &r, seed, cases)
        case .solutions: return solutions(level, &r, seed)
        case .signTable: return signTable(level, &r, seed)
        case .equation: return equation(level, &r, seed, cases)
        case .probability: return probability(level, &r, seed, cases)
        case .triangle: return triangle(level, &r, seed, cases)
        case .optimization: return optimization(level, &r, seed, cases)
        case .sequence: return sequence(level, &r, seed, cases)
        case .induction: return induction(level, &r, seed, cases)
        case .geometry: return geometry(level, &r, seed, cases)
        case .trigIdentity: return trigIdentity(level, &r, seed, cases)
        case .vectors: return vectors(level, &r, seed, cases)
        case .conics: return conics(level, &r, seed, cases)
        case .complex: return complex(level, &r, seed, cases)
        case .growth: return growth(level, &r, seed, cases)
        case .antiderivative: return antiderivative(level, &r, seed, cases)
        }
    }

    /// Numbers the sections ("Step 2 · …"), gives the max/min check its own
    /// section and puts the final result under "Answer".
    static func numbered(_ steps: [SolutionStep]) -> [SolutionStep] {
        var out: [SolutionStep] = []
        var n = 0
        for (i, step) in steps.enumerated() {
            var step = step
            if step.style == .result, i == steps.count - 1, out.last(where: { $0.style == .heading })?.text != "Answer" {
                out.append(.heading("Answer"))
            }
            if step.style == nil, step.text.contains("changes from"), step.text.contains("so it is a") {
                n += 1
                out.append(.heading("Step \(n) · Maximum or minimum?"))
            }
            if step.style == .heading {
                if step.text.hasPrefix("Step ") {
                    n += 1
                } else if step.text != "Answer" && step.text != "Check" {
                    n += 1
                    step.text = "Step \(n) · \(step.text)"
                }
            }
            out.append(step)
        }
        return out
    }

    /// One generator case: from the level's pool, narrowed to the asked sub-type.
    static func choose(_ pool: [Int], _ cases: [Int]?, _ r: inout SeededRandom) -> Int {
        guard let cases else { return r.pick(pool) }
        let both = pool.filter(cases.contains)
        return r.pick(both.isEmpty ? cases : both)
    }

    // MARK: Helpers

    static func blank(_ kind: QuizKind, _ level: Level, _ seed: UInt64, _ prompt: String, _ answer: QuizAnswer, topic: String) -> QuizProblem {
        QuizProblem(kind: kind, level: level, seed: seed, prompt: prompt, formulaLabel: nil, formula: nil, formulaText: nil,
                    graph: nil, shade: nil, lower: nil, level_k: nil, answer: answer, steps: [], topic: topic)
    }

    /// Puts the correct option among the others in a random place.
    static func shuffled(_ correct: QuizOption, _ others: [QuizOption], _ r: inout SeededRandom) -> QuizAnswer {
        var all = others
        let at = r.int(0...others.count)
        all.insert(correct, at: at)
        return .choice(all, correct: at)
    }

    static func step(_ t: String, depth: Int = 0) -> SolutionStep { SolutionStep(t, depth: depth) }
    static func num(_ v: Double) -> String { GraphSteps.num(v) }
    static func frac(_ p: Int, _ q: Int) -> String { Solver.frac(p, q) }

    /// Two graphs look different (no flipping allowed: −f is a different answer).
    static func distinct(_ a: SketchProblem, _ b: SketchProblem) -> Bool {
        let ka = ShapeKey.of(a), kb = ShapeKey.of(b)
        let d = zip(ka, kb).reduce(0) { $0 + Swift.abs($1.0 - $1.1) } / Double(ka.count)
        // Same shape on a different scale counts as different only if the axis sits elsewhere.
        return d > 0.08 || Swift.abs(a.yMin - b.yMin) + Swift.abs(a.yMax - b.yMax) > 0.3 * (a.yMax - a.yMin)
    }

    // MARK: Worked-solution helpers

    static func iv(_ n: Int) -> String { "\(n)".replacingOccurrences(of: "-", with: "−") }
    /// " + 3", " − 3" or "" — for appending a term.
    static func sg(_ n: Int) -> String { n == 0 ? "" : (n < 0 ? " − \(-n)" : " + \(n)") }
    /// "x − 2", "x + 1", "x".
    static func xm(_ p: Int) -> String { "x" + sg(-p) }
    static func S(_ t: String, _ depth: Int = 1) -> SolutionStep { SolutionStep(t, depth: depth) }
    static func H(_ t: String) -> SolutionStep { .heading(t) }
    static func R(_ t: String) -> SolutionStep { .result(t) }

    /// Exact x labels where the algebra knows them, else π-multiples or decimals.
    static func labeler(_ f: SketchProblem) -> (Double) -> String {
        let inv = GraphAlgebra.investigate(f)
        let exact = (inv?.d1?.solve.roots ?? []) + (inv?.zeros?.roots ?? [])
        let solver = Solver(a: f.xMin, b: f.xMax, piBased: f.piBased)
        return { v in
            if Swift.abs(v - f.xMin) < 1e-9 { return f.xLabel(f.xMin) }
            if Swift.abs(v - f.xMax) < 1e-9 { return f.xLabel(f.xMax) }
            if let e = exact.first(where: { Swift.abs($0.x - v) < 1e-6 }) { return GraphSteps.bare(e.label) }
            if let i = f.poles.firstIndex(where: { Swift.abs($0 - v) < 1e-9 }), let l = f.asymptoteLabels?[safe: i] { return l }
            return GraphSteps.bare(solver.xLabel(v, exact: true))
        }
    }

    struct SignPiece {
        var lo: Double
        var hi: Double
        var positive: Bool
        var text: String
    }

    /// Where g is positive or negative on f's interval, e.g. "−2 < x < 1".
    static func signPieces(of g: Expr, on f: SketchProblem, label: (Double) -> String) -> [SignPiece] {
        let a = f.xMin, b = f.xMax
        let cuts = (GraphSteps.roots(of: g, in: a...b) + f.poles.filter { $0 > a && $0 < b }).sorted()
        let pts = [a] + cuts + [b]
        var out: [SignPiece] = []
        for (l, h) in zip(pts, pts.dropFirst()) where h - l > 1e-9 {
            let v = g.evaluate(at: (l + h) / 2)
            guard v.isFinite, Swift.abs(v) > 1e-12 else { continue }
            let pole = f.poles.contains { Swift.abs($0 - l) < 1e-9 }
            if var last = out.last, last.positive == (v > 0), Swift.abs(last.hi - l) < 1e-9, !pole {
                last.hi = h
                out[out.count - 1] = last
            } else {
                out.append(SignPiece(lo: l, hi: h, positive: v > 0, text: ""))
            }
        }
        return out.map { var p = $0; p.text = "\(label(p.lo)) < x < \(label(p.hi))"; return p }
    }

    /// A simple point inside (lo, hi) to test a sign with.
    static func testPoint(_ lo: Double, _ hi: Double) -> Double {
        let mid = (lo + hi) / 2
        for c in [mid.rounded(), (mid * 2).rounded() / 2, (mid * 10).rounded() / 10] where c > lo + 1e-6 && c < hi - 1e-6 { return c }
        return mid
    }

    /// " + 3x", " − x²/2" or "" for a coefficient and a term.
    static func signedTerm(_ c: Int, _ body: String) -> String {
        c == 0 ? "" : (c < 0 ? " − " : " + ") + (Swift.abs(c) == 1 ? "" : "\(Swift.abs(c))") + body
    }

    static func list(_ items: [String]) -> String { items.isEmpty ? "nowhere" : items.joined(separator: ",  ") }

    // MARK: Choose the graph

    static func chooseGraph(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let baseLevel: Level = level == .bagrut ? .hard : level
        guard let f = SketchFactory.candidate(level: baseLevel, rng: &r, seed: seed), f.poles.isEmpty else { return nil }
        func fin(_ e: Expr) -> SketchProblem? {
            SketchFactory.finish(e, f.xMin, f.xMax, piBased: f.piBased, level: level, seed: seed)
        }
        let fx = f.function
        let L = labeler(f)
        var q: QuizProblem
        var correct: SketchProblem
        var others: [SketchProblem?]
        var steps: [SolutionStep]
        var match: String
        switch choose([0, 1, 2, 3], cases, &r) {
        case 0:
            guard let d = fin(fx.derivative()) else { return nil }
            correct = d
            others = [fin(.neg(fx.derivative())), f, fin(fx.derivative().derivative())]
            q = blank(.chooseGraph, level, seed, "Here is the graph of f. Which graph is f′?", .number(0), topic: "choose:derivative")
            q.graph = f
            let pieces = signPieces(of: fx.derivative(), on: f, label: L)
            let turns = GraphSteps.roots(of: fx.derivative(), in: f.xMin...f.xMax)
            steps = [H("Step 1 · Where f rises and falls")]
                + pieces.map { S("f \($0.positive ? "rises ↗" : "falls ↘") on \($0.text)  ⇒  f′ \($0.positive ? "> 0" : "< 0") there") }
                + [H("Step 2 · Where f′ = 0")]
                + (turns.isEmpty ? [S("f never turns, so f′ never crosses the x-axis.")]
                                 : turns.map { S("f turns at x = \(L($0))  ⇒  f′(\(L($0))) = 0: f′ crosses the x-axis there") })
            match = "above the x-axis on \(list(pieces.filter(\.positive).map(\.text))), below it on \(list(pieces.filter { !$0.positive }.map(\.text)))"
        case 1:
            correct = f
            others = [fin(.neg(fx)), fin(fx.derivative()), fin(fx.substitutingX(with: .neg(.x)))]
            q = blank(.chooseGraph, level, seed, "Which graph belongs to this function?", .number(0), topic: "choose:function")
            q.formulaLabel = "f(x) ="
            q.formula = fx
            let zeros = GraphSteps.roots(of: fx, in: f.xMin...f.xMax)
            let pieces = signPieces(of: fx.derivative(), on: f, label: L)
            var easy: [SolutionStep] = []
            if f.xMin < 0, f.xMax > 0, fx.evaluate(at: 0).isFinite { easy.append(S("f(0) = \(num(fx.evaluate(at: 0)))")) }
            easy.append(S("At the ends: f(\(f.xLabel(f.xMin))) ≈ \(num(fx.evaluate(at: f.xMin))),  f(\(f.xLabel(f.xMax))) ≈ \(num(fx.evaluate(at: f.xMax)))"))
            steps = [H("Step 1 · Easy values")] + easy
                + [H("Step 2 · Zeros"), S(zeros.isEmpty ? "f is never 0 here." : "f = 0 at x = \(zeros.map(L).joined(separator: ", "))")]
                + [H("Step 3 · Rises and falls (sign of f′)")]
                + pieces.map { S("f′ \($0.positive ? "> 0: f rises" : "< 0: f falls") on \($0.text)") }
            match = "through these values, crossing zero at \(zeros.isEmpty ? "no point" : zeros.map(L).joined(separator: ", "))"
        case 2:
            let negative = (0...60).contains { f.value(at: f.xMin + (f.xMax - f.xMin) * Double($0) / 60) < -0.05 * (f.yMax - f.yMin) }
            guard negative, let a = fin(.abs(fx)) else { return nil }
            correct = a
            others = [fin(.neg(.abs(fx))), f, fin(.p(fx, 2))]
            q = blank(.chooseGraph, level, seed, "Here is the graph of f. Which graph is |f(x)|?", .number(0), topic: "choose:absolute")
            q.graph = f
            let pieces = signPieces(of: fx, on: f, label: L)
            let zeros = GraphSteps.roots(of: fx, in: f.xMin...f.xMax)
            steps = [H("Step 1 · Where f is above and below the x-axis")]
                + pieces.map { S("\($0.text): f \($0.positive ? "> 0, so |f| = f (unchanged)" : "< 0, so |f| = −f (flipped up)")") }
                + [H("Step 2 · Where |f| touches the axis"),
                   S(zeros.isEmpty ? "f is never 0, so |f| never touches the x-axis." : "|f| = 0 exactly where f = 0: x = \(zeros.map(L).joined(separator: ", "))"),
                   S("|f| is never below the x-axis.")]
            match = "never below the axis, equal to f on \(list(pieces.filter(\.positive).map(\.text))) and the mirror image of f on \(list(pieces.filter { !$0.positive }.map(\.text)))"
        default:
            guard let fp = fin(fx.derivative()) else { return nil }
            correct = f
            others = [fin(.neg(fx)), fin(fx.derivative().derivative()), fin(.neg(fx.derivative()))]
            q = blank(.chooseGraph, level, seed, "Here is the graph of g. Which graph could be a function F with F′ = g?", .number(0), topic: "choose:antiderivative")
            q.graph = fp
            let pieces = signPieces(of: fx.derivative(), on: f, label: L)
            var turns: [SolutionStep] = []
            for p1 in pieces.dropLast() {
                turns.append(S("At x = \(L(p1.hi)) g goes from \(p1.positive ? "+ to −" : "− to +")  ⇒  F has a \(p1.positive ? "peak" : "dip") there"))
            }
            steps = [H("Step 1 · The sign of g = F′")]
                + pieces.map { S("g \($0.positive ? "> 0: F rises" : "< 0: F falls") on \($0.text)") }
                + [H("Step 2 · Where g crosses zero")] + (turns.isEmpty ? [S("g keeps one sign, so F has no peaks or dips.")] : turns)
                + [H("Step 3 · Where g peaks or dips"), S("There F is steepest: these are F's inflection points.")]
            match = "rising on \(list(pieces.filter(\.positive).map(\.text))) and falling on \(list(pieces.filter { !$0.positive }.map(\.text)))"
        }
        let distractors = others.compactMap { $0 }.filter { distinct($0, correct) }
        // The distractors must also differ from each other.
        var picked: [SketchProblem] = []
        for d in distractors where picked.allSatisfy({ distinct($0, d) }) { picked.append(d) }
        guard picked.count >= 3 else { return nil }
        let answer = shuffled(QuizOption(graph: correct), picked.prefix(3).map { QuizOption(graph: $0) }, &r)
        q.answer = answer
        if case .choice(_, let at) = answer {
            let letter = ["A", "B", "C", "D"][at]
            q.steps = steps + [H("Step \(steps.filter { $0.style == .heading }.count + 1) · Match the graph"),
                               S("We need a graph \(match)."), R("Graph \(letter)")]
        }
        return q
    }

    // MARK: Find the parameter

    static func parameter(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [2, 4, 8, 11, 13]
        case .medium: pool = [0, 6, 7, 3, 4, 10, 12, 14]
        case .hard: pool = [1, 5, 9, 3, 7, 10, 13, 14]
        case .bagrut: pool = [1, 5, 9, 7, 3, 11, 12, 15]
        }
        func ask(_ text: String, _ cond: String, _ a: Double, _ aText: String, _ steps: [SolutionStep], _ topic: String) -> QuizProblem {
            var q = blank(.parameter, level, seed, "\(cond) Find a.", .number(a), topic: "parameter:\(topic)")
            q.formulaText = text
            q.steps = steps + [R("a = \(aText)")]
            return q
        }
        switch choose(pool, cases, &r) {
        case 0:
            let k = r.pick([1, 2, -1, 3, -2])
            return ask("f(x) = x³ + a·x²", "f has an extremum at x = \(k).", -1.5 * Double(k), frac(-3 * k, 2),
                       [H("Step 1 · Differentiate"), S("f′(x) = 3x² + 2a·x"),
                        H("Step 2 · Use the condition"), S("An extremum at x = \(iv(k)) means f′(\(iv(k))) = 0:"),
                        S("3·(\(iv(k)))² + 2a·(\(iv(k))) = 0   ⇒   \(3 * k * k)\(sg(2 * k))a = 0", 2),
                        H("Step 3 · Solve for a"), S("\(iv(2 * k))a = \(iv(-3 * k * k))   ⇒   a = \(frac(-3 * k * k, 2 * k))"),
                        H("Step 4 · Check it is really an extremum"),
                        S("f′(x) = x(3x + 2a) = 3x(x\(sg(-k)))"), S("f′ has two different roots (0 and \(iv(k))), so it changes sign at x = \(iv(k)) ✓")],
                       "cubic extremum")
        case 1:
            let p = r.pick([1, 2, -1]), k = r.pick([3, 4, -2, 5])
            guard k != p, 2 * p - k != k else { return nil }
            let a = k * k - 2 * p * k
            return ask("f(x) = (x² + a)/(\(xm(p)))", "f has an extremum at x = \(k).", Double(a), iv(a),
                       [H("Step 1 · Differentiate (quotient rule)"),
                        S("f′(x) = [2x·(\(xm(p))) − (x² + a)·1] / (\(xm(p)))²"),
                        S("= (x²\(sg(-2 * p))x − a) / (\(xm(p)))²", 2),
                        H("Step 2 · Use the condition"),
                        S("f′(\(iv(k))) = 0. The denominator (\(iv(k))\(sg(-p)))² = \((k - p) * (k - p)) ≠ 0, so the numerator is 0:"),
                        S("\(k < 0 ? "(\(iv(k)))" : iv(k))²\(sg(-2 * p))·\(k < 0 ? "(\(iv(k)))" : iv(k)) − a = 0   ⇒   \(k * k)\(sg(-2 * p * k)) − a = 0", 2),
                        H("Step 3 · Solve for a"), S("a = \(iv(a))"),
                        H("Step 4 · Check"),
                        S("The numerator x²\(sg(-2 * p))x\(sg(-a)) has roots \(iv(k)) and \(iv(2 * p - k)) (they add up to \(iv(2 * p))): different, so f′ changes sign ✓")],
                       "rational extremum")
        case 2:
            let m = r.int(2...6), c = r.int(1...4), p = r.int(1...3)
            return ask("f(x) = (a·x + \(c))/(x − \(p))", "The graph of f has the horizontal asymptote y = \(m).", Double(m), "\(m)",
                       [H("Step 1 · What happens as x → ±∞"), S("Divide top and bottom by x:  f(x) = (a + \(c)/x) / (1 − \(p)/x)"),
                        S("\(c)/x → 0 and \(p)/x → 0, so f(x) → a/1 = a"),
                        H("Step 2 · Match the asymptote"), S("The asymptote is y = a, so a = \(m)."),
                        H("Step 3 · Check"), S("With a = \(m): \(m)·\(p) + \(c) = \(m * p + c) ≠ 0, so f is not constant and y = \(m) really is an asymptote ✓")],
                       "horizontal asymptote")
        case 3:
            let k = r.int(1...3)
            return ask("f(x) = x² + a·ln x", "f has an extremum at x = \(k).", Double(-2 * k * k), iv(-2 * k * k),
                       [H("Step 1 · Domain and derivative"), S("ln x needs x > 0."), S("f′(x) = 2x + a/x"),
                        H("Step 2 · Use the condition"), S("f′(\(k)) = 0:   \(2 * k) + a/\(k) = 0"),
                        H("Step 3 · Solve for a"), S("a/\(k) = −\(2 * k)   ⇒   a = −\(2 * k * k)"),
                        H("Step 4 · Check"), S("f′(x) = (2x² − \(2 * k * k))/x = 2(x − \(k))(x + \(k))/x"),
                        S("For x > 0 only x = \(k) is a root, and f′ goes from − to +: a minimum ✓")],
                       "ln extremum")
        case 4:
            let m = r.pick([2, 3, -1, -2, 4])
            return ask("f(x) = e^(a·x)", "The tangent to f at x = 0 has slope \(iv(m)).", Double(m), iv(m),
                       [H("Step 1 · Differentiate (chain rule)"), S("f′(x) = a·e^(a·x)"),
                        H("Step 2 · The slope at x = 0"), S("f′(0) = a·e⁰ = a·1 = a"),
                        H("Step 3 · Solve"), S("The tangent's slope is f′(0), so a = \(iv(m)).")],
                       "tangent slope")
        case 5:
            let (label, value, sinT, cosT, exact): (String, Double, String, String, String) =
                r.pick([("π/6", 1 / 3.0.squareRoot(), "1/2", "√3/2", "1/√3 = √3/3"), ("π/4", 1, "√2/2", "√2/2", "1"), ("π/3", 3.0.squareRoot(), "√3/2", "1/2", "√3")])
            return ask("f(x) = a·sin x + cos x", "f has an extremum at x = \(label).", value, exact,
                       [H("Step 1 · Differentiate"), S("f′(x) = a·cos x − sin x"),
                        H("Step 2 · Use the condition"), S("f′(\(label)) = 0:   a·cos(\(label)) = sin(\(label))"),
                        S("a·\(cosT) = \(sinT)", 2),
                        H("Step 3 · Solve for a"), S("a = (\(sinT)) / (\(cosT)) = tan(\(label)) = \(exact)"),
                        H("Step 4 · Check"), S("f″(x) = −a·sin x − cos x, and f″(\(label)) = −1/cos(\(label)) ≠ 0, so it is an extremum ✓")],
                       "trig extremum")
        case 6:
            let k = r.int(1...4)
            return ask("f(x) = x/(x² + a)", "f has an extremum at x = \(k).", Double(k * k), "\(k * k)",
                       [H("Step 1 · Differentiate (quotient rule)"), S("f′(x) = [1·(x² + a) − x·2x] / (x² + a)² = (a − x²)/(x² + a)²"),
                        H("Step 2 · Use the condition"), S("f′(\(k)) = 0  ⇒  the numerator is 0:   a − \(k * k) = 0"),
                        H("Step 3 · Solve for a"), S("a = \(k * k)"),
                        H("Step 4 · Check"), S("a − x² = (\(k) − x)(\(k) + x) changes sign at x = \(k), and x² + \(k * k) > 0 always ✓")],
                       "rational extremum")
        case 7:
            let k = r.int(-1...3)
            return ask("f(x) = (x − a)·eˣ", "f has a minimum at x = \(iv(k)).", Double(k + 1), iv(k + 1),
                       [H("Step 1 · Differentiate (product rule)"), S("f′(x) = 1·eˣ + (x − a)·eˣ = eˣ(x − a + 1)"),
                        H("Step 2 · Use the condition"), S("eˣ > 0 always, so f′(\(iv(k))) = 0 means  \(iv(k)) − a + 1 = 0"),
                        H("Step 3 · Solve for a"), S("a = \(iv(k)) + 1 = \(iv(k + 1))"),
                        H("Step 4 · Check it is a minimum"), S("f′(x) = eˣ(\(xm(k))): negative before x = \(iv(k)), positive after ⇒ minimum ✓")],
                       "exp extremum")
        case 8:
            let x0 = r.pick([3, 4, 5]), y0 = r.int(3...6), k = r.int(1...2)
            let a = (y0 - k) * (x0 - 1)
            return ask("f(x) = a/(x − 1) + \(k)", "The graph of f passes through (\(x0), \(y0)).", Double(a), iv(a),
                       [H("Step 1 · Substitute the point"), S("f(\(x0)) = \(y0):   a/(\(x0) − 1) + \(k) = \(y0)"),
                        H("Step 2 · Solve for a"), S("a/\(x0 - 1) = \(y0) − \(k) = \(y0 - k)"), S("a = \(y0 - k)·\(x0 - 1) = \(a)"),
                        H("Step 3 · Check"), S("\(a)/\(x0 - 1) + \(k) = \(a / (x0 - 1)) + \(k) = \(y0) ✓")],
                       "point on graph")
        case 10:
            let k = r.int(2...6)
            return ask("f(x) = a·eˣ + x", "f has an extremum at x = ln \(k).", -1 / Double(k), "−1/\(k)",
                       [H("Differentiate"), S("f′(x) = a·eˣ + 1"),
                        H("Use the condition"), S("f′(ln \(k)) = 0:   a·e^(ln \(k)) + 1 = 0   ⇒   \(k)a + 1 = 0"),
                        H("Solve for a"), S("a = −1/\(k)"),
                        H("Check"), S("f′(x) = 1 − eˣ/\(k) changes from + to − at x = ln \(k): a maximum ✓")], "exp extremum")
        case 11:
            let c = r.int(2...7)
            return ask("f(x) = x² − a·x + \(c * c),  a > 0", "The graph of f touches the x-axis at exactly one point.", Double(2 * c), "\(2 * c)",
                       [H("One point on the axis"), S("f(x) = 0 has exactly one solution ⇔ the discriminant is 0."),
                        H("The discriminant"), S("Δ = a² − 4·1·\(c * c) = a² − \(4 * c * c)"),
                        H("Solve"), S("a² = \(4 * c * c)  ⇒  a = ±\(2 * c)"), S("a > 0, so a = \(2 * c); a = −\(2 * c) is rejected ✗"),
                        H("Check"), S("x² − \(2 * c)x + \(c * c) = (x − \(c))² touches the axis at x = \(c) ✓")], "discriminant")
        case 12:
            let k = r.int(1...5)
            return ask("f(x) = x + a/x", "f has an extremum at x = \(k).", Double(k * k), "\(k * k)",
                       [H("Differentiate"), S("f′(x) = 1 − a/x²"),
                        H("Use the condition"), S("f′(\(k)) = 0:   1 − a/\(k * k) = 0"),
                        H("Solve for a"), S("a = \(k * k)"),
                        H("Check"), S("f′(x) = (x² − \(k * k))/x² changes from − to + at x = \(k): a minimum ✓")], "rational extremum")
        case 13:
            let h = r.int(1...3), a = r.int(1...4)
            let area = a * h * h * h
            return ask("f(x) = a·x²,  a > 0", "The area under f from x = 0 to x = \(h) is \(frac(area, 3)).", Double(a), "\(a)",
                       [H("Write the area as an integral"), S("∫₀^\(h) a·x² dx = a·[x³/3]₀^\(h) = a·\(frac(h * h * h, 3))"),
                        H("Use the condition"), S("a·\(frac(h * h * h, 3)) = \(frac(area, 3))"),
                        H("Solve for a"), S("a = \(frac(area, 3)) ÷ \(frac(h * h * h, 3)) = \(a)")], "area condition")
        case 14:
            let k = r.pick([1, 2, -1, 3]), m = r.int(-3...5)
            // f(x) = x³ + a x has slope m at x = k: 3k² + a = m.
            let a = m - 3 * k * k
            return ask("f(x) = x³ + a·x", "The tangent to f at x = \(iv(k)) has slope \(iv(m)).", Double(a), iv(a),
                       [H("Differentiate"), S("f′(x) = 3x² + a"),
                        H("The slope at x = \(iv(k))"), S("f′(\(iv(k))) = 3·\(k * k) + a = \(3 * k * k) + a"),
                        H("Solve for a"), S("\(3 * k * k) + a = \(iv(m))  ⇒  a = \(iv(a))")], "tangent slope")
        case 15:
            let p = r.int(1...3)
            // f′(x) = a/x + x = 0 at x = p  ⇒  a = −p².
            return ask("f(x) = a·ln x + x²/2", "The tangent to f at x = \(p) is horizontal.", Double(-p * p), iv(-p * p),
                       [H("Domain"), S("ln x needs x > 0."),
                        H("Differentiate"), S("f′(x) = a/x + x"),
                        H("Horizontal tangent ⇔ slope 0"), S("f′(\(p)) = 0:   a/\(p) + \(p) = 0"),
                        H("Solve for a"), S("a = −\(p * p)")], "horizontal tangent")
        default:
            let k = r.pick([1, 2, -1, -2])
            return ask("f(x) = ln(x² + a·x + 5)", "f has an extremum at x = \(iv(k)).", Double(-2 * k), iv(-2 * k),
                       [H("Step 1 · Differentiate (chain rule)"), S("f′(x) = (2x + a)/(x² + a·x + 5)"),
                        H("Step 2 · Use the condition"), S("f′(\(iv(k))) = 0  ⇒  the numerator is 0:   2·(\(iv(k))) + a = 0"),
                        H("Step 3 · Solve for a"), S("a = \(iv(-2 * k))"),
                        H("Step 4 · Check"), S("At x = \(iv(k)): x² + a·x + 5 = \(k * k)\(sg(-2 * k * k)) + 5 = \(5 - k * k) > 0, so f is defined there ✓"),
                        S("The numerator 2x\(sg(-2 * k)) changes sign at x = \(iv(k)) ✓")],
                       "ln extremum")
        }
    }

    // MARK: Area

    static func area(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 2, 10, 10]
        case .medium: pool = [0, 1, 2, 3, 4, 9, 10, 11]
        case .hard: pool = [3, 4, 5, 6, 8, 9, 11, 12, 13]
        case .bagrut: pool = [5, 6, 7, 8, 4, 9, 12, 13]
        }
        let x = Expr.x
        var f: Expr, lo: Double, hi: Double, value: Double, steps: [SolutionStep], g: Expr? = nil, piBased = false, topic: String
        var prompt: String, answer: String
        var resultName = "Area"
        switch choose(pool, cases, &r) {
        case 0:
            let c = r.pick([1, 4, 9]), rc = Int(Double(c).squareRoot())
            f = .sum([.n(c), .neg(.p(x, 2))]); lo = -Double(rc); hi = Double(rc)
            value = 4 * pow(Double(c), 1.5) / 3
            prompt = "Find the area between f and the x-axis."
            answer = frac(4 * rc * rc * rc, 3)
            steps = [H("Step 1 · Where the area starts and ends"), S("f(x) = 0:  \(c) − x² = 0  ⇒  x = ±\(rc)"),
                     S("Between them f ≥ 0 (e.g. f(0) = \(c) > 0), so no part is below the axis."),
                     H("Step 2 · An antiderivative"), S("F(x) = \(c)x − x³/3"),
                     H("Step 3 · F(\(rc)) − F(−\(rc))"), S("F(\(rc)) = \(c * rc) − \(frac(rc * rc * rc, 3)) = \(frac(2 * rc * rc * rc, 3))"),
                     S("F(−\(rc)) = −\(c * rc) + \(frac(rc * rc * rc, 3)) = −\(frac(2 * rc * rc * rc, 3))"),
                     S("Area = \(frac(2 * rc * rc * rc, 3)) − (−\(frac(2 * rc * rc * rc, 3)))")]
            topic = "area:parabola"
        case 1:
            let c = r.int(1...3), b = r.int(1...3)
            f = .sum([.p(x, 2), .n(c)]); lo = 0; hi = Double(b)
            value = pow(Double(b), 3) / 3 + Double(c * b)
            prompt = "Find the shaded area under f from x = 0 to x = \(b)."
            answer = frac(b * b * b + 3 * c * b, 3)
            steps = [H("Step 1 · Check the sign"), S("x² + \(c) > 0 for every x, so the area is just the integral."),
                     H("Step 2 · An antiderivative"), S("F(x) = x³/3 + \(c)x"),
                     H("Step 3 · F(\(b)) − F(0)"), S("F(\(b)) = \(frac(b * b * b, 3)) + \(c * b) = \(answer),   F(0) = 0")]
            topic = "area:polynomial"
        case 2:
            let m = r.int(1...3)
            f = .sin(.scaled(m, 1, x)); lo = 0; hi = Double.pi / Double(m); piBased = true
            value = 2 / Double(m)
            let end = m == 1 ? "π" : "π/\(m)"
            prompt = "Find the area between f and the x-axis on one arch."
            answer = frac(2, m)
            steps = [H("Step 1 · Where the arch is"), S("sin(\(m == 1 ? "" : "\(m)")x) = 0 at x = 0 and x = \(end); in between it is positive."),
                     H("Step 2 · An antiderivative"), S("F(x) = −cos(\(m == 1 ? "" : "\(m)")x)\(m == 1 ? "" : "/\(m)")"),
                     H("Step 3 · F(\(end)) − F(0)"), S("F(\(end)) = −cos π\(m == 1 ? "" : "/\(m)") = \(frac(1, m)),   F(0) = −cos 0\(m == 1 ? "" : "/\(m)") = −\(frac(1, m))"),
                     S("Area = \(frac(1, m)) − (−\(frac(1, m)))")]
            topic = "area:trig"
        case 3:
            let k = r.int(1...2), n = r.int(2...4)
            f = .exp(.scaled(k, 1, x)); lo = 0; hi = log(Double(n)) / Double(k)
            value = Double(n - 1) / Double(k)
            let end = k == 1 ? "ln \(n)" : "(ln \(n))/\(k)"
            prompt = "Find the shaded area under f from x = 0 to x = \(end)."
            answer = frac(n - 1, k)
            steps = [H("Step 1 · Check the sign"), S("eˣ-type functions are always positive."),
                     H("Step 2 · An antiderivative"), S("F(x) = e^(\(k == 1 ? "" : "\(k)")x)\(k == 1 ? "" : "/\(k)")"),
                     H("Step 3 · F(\(end)) − F(0)"), S("At x = \(end): \(k)x = ln \(n), so e^(\(k == 1 ? "" : "\(k)")x) = e^(ln \(n)) = \(n)"),
                     S("F(\(end)) = \(frac(n, k)),   F(0) = \(frac(1, k))"), S("Area = \(frac(n, k)) − \(frac(1, k))")]
            topic = "area:exp"
        case 4:
            let p = r.int(1...2), q = r.int(1...3)
            f = .div(1, .sum([x, .n(p)])); lo = 0; hi = Double(q)
            value = log(Double(q + p) / Double(p))
            prompt = "Find the shaded area under f from x = 0 to x = \(q)."
            answer = "ln(\(frac(q + p, p)))"
            steps = [H("Step 1 · Check the sign"), S("For x ≥ 0, x + \(p) > 0, so f > 0."),
                     H("Step 2 · An antiderivative"), S("F(x) = ln(x + \(p))  (the top is the derivative of the bottom)"),
                     H("Step 3 · F(\(q)) − F(0)"), S("ln(\(q + p)) − ln(\(p)) = ln(\(q + p)/\(p))")]
            topic = "area:ln"
        case 5:
            let c = r.int(1...3)
            f = .scaled(c, 1, x); g = .p(x, 2); lo = 0; hi = Double(c)
            value = pow(Double(c), 3) / 6
            let cx = c == 1 ? "x" : "\(c)x"
            prompt = "Find the area between y = \(cx) and y = x²."
            answer = frac(c * c * c, 6)
            steps = [H("Step 1 · Where they meet"), S("x² = \(cx)  ⇒  x(x − \(c)) = 0  ⇒  x = 0 or x = \(c)"),
                     H("Step 2 · Which one is on top"), S("At x = \(frac(c, 2)): \(cx) = \(frac(c * c, 2)) and x² = \(frac(c * c, 4)), so y = \(cx) is on top."),
                     H("Step 3 · Integrate top − bottom"), S("∫₀^\(c) (\(cx) − x²) dx = [\(c == 1 ? "" : "\(c)")x²/2 − x³/3]₀^\(c)"),
                     S("= \(frac(c * c * c, 2)) − \(frac(c * c * c, 3))")]
            topic = "area:between"
        case 6:
            let b = r.int(1...3)
            f = .div(.scaled(2, 1, x), .sum([.p(x, 2), 1])); lo = 0; hi = Double(b)
            value = log(Double(b * b + 1))
            prompt = "Find the shaded area under f from x = 0 to x = \(b)."
            answer = "ln \(b * b + 1)"
            steps = [H("Step 1 · Check the sign"), S("For x ≥ 0, 2x ≥ 0 and x² + 1 > 0, so f ≥ 0."),
                     H("Step 2 · An antiderivative"), S("The top is the derivative of the bottom: (x² + 1)′ = 2x"), S("F(x) = ln(x² + 1)"),
                     H("Step 3 · F(\(b)) − F(0)"), S("ln(\(b * b + 1)) − ln 1 = ln \(b * b + 1) − 0")]
            topic = "area:f′/f"
        case 7:
            f = .mul(x, .exp(.p(x, 2))); lo = 0; hi = 1
            value = (M_E - 1) / 2
            prompt = "Find the shaded area under f from x = 0 to x = 1."
            answer = "(e − 1)/2"
            steps = [H("Step 1 · Check the sign"), S("For x ≥ 0, x·e^(x²) ≥ 0."),
                     H("Step 2 · An antiderivative"), S("(e^(x²))′ = 2x·e^(x²), so F(x) = ½e^(x²)"),
                     H("Step 3 · F(1) − F(0)"), S("½e¹ − ½e⁰ = e/2 − 1/2")]
            topic = "area:substitution"
        case 9:
            // A line above a parabola: top − bottom = k(x − r1)(r2 − x).
            let r1 = r.int(-3...1), r2 = r1 + r.int(1...4), k = r.int(1...2)
            let m = r.int(-3...3), c = r.int(-2...4)
            let line = [m, c]
            let gap = polyMul([k], polyMul([1, -r1], [1, -r2]))          // k(x − r1)(x − r2) ≥ 0 outside
            let para = [gap[0], gap[1] + m, gap[2] + c]                   // the parabola = line + k(x − r1)(x − r2)
            f = Solver.polyExpr(line); g = Solver.polyExpr(para); lo = Double(r1); hi = Double(r2)
            let w = r2 - r1
            value = Double(k * w * w * w) / 6
            prompt = "Find the area between the line y = \(Solver.polyText(line)) and the parabola y = \(Solver.polyText(para))."
            answer = frac(k * w * w * w, 6)
            let F = { (t: Int) -> String in frac(-2 * k * t * t * t + 3 * k * (r1 + r2) * t * t - 6 * k * r1 * r2 * t, 6) }
            steps = [H("Where they meet"), S("\(Solver.polyText(para)) = \(Solver.polyText(line))  ⇒  \(Solver.polyText(gap)) = 0"),
                     S("\(k == 1 ? "" : "\(k)")(\(xm(r1)))(\(xm(r2))) = 0  ⇒  x = \(iv(r1)) or x = \(iv(r2))", 2),
                     H("Which one is on top"), S("Between \(iv(r1)) and \(iv(r2)) the factor (\(xm(r1)))(\(xm(r2))) is negative, so the parabola is below the line."),
                     H("Integrate top − bottom"), S("line − parabola = \(Solver.polyText(gap.map { -$0 }))"),
                     S("F(x) = −\(k == 1 ? "" : "\(k)")x³/3\(signedTerm(k * (r1 + r2), "x²/2"))\(signedTerm(-k * r1 * r2, "x"))"),
                     H("F(\(iv(r2))) − F(\(iv(r1)))"), S("F(\(iv(r2))) = \(F(r2)),   F(\(iv(r1))) = \(F(r1))"), S("\(F(r2)) − (\(F(r1)))")]
            topic = "area:line and parabola"
        case 10:
            // Under a quadratic that stays positive on [lo, hi].
            let a = r.int(1...3), b = r.int(-4...4), c = r.int(1...8)
            let l = r.int(-2...1), h = l + r.int(1...3)
            let P = [a, b, c]
            func positive(_ i: Int) -> Bool {
                let x: Double = Double(l) + Double(h - l) * Double(i) / 20
                let y: Double = Double(a) * x * x + Double(b) * x + Double(c)
                return y > 0
            }
            guard (0...20).allSatisfy(positive) else { return nil }
            func F6(_ t: Int) -> Int { 2 * a * t * t * t + 3 * b * t * t + 6 * c * t }      // 6·F(t)
            f = Solver.polyExpr(P); lo = Double(l); hi = Double(h)
            value = Double(F6(h) - F6(l)) / 6
            prompt = "Find the shaded area under f from x = \(iv(l)) to x = \(iv(h))."
            answer = frac(F6(h) - F6(l), 6)
            steps = [H("Check the sign"), S("f stays above the x-axis between \(iv(l)) and \(iv(h)) (e.g. f(\(iv(l))) = \(polyEval(P, l)), f(\(iv(h))) = \(polyEval(P, h))), so the area is the integral."),
                     H("An antiderivative"), S("F(x) = \(a == 1 ? "" : "\(a)")x³/3\(b == 0 ? "" : (b < 0 ? " − " : " + ") + "\(Swift.abs(b))x²/2")\(sg(c))x"),
                     H("F(\(iv(h))) − F(\(iv(l)))"), S("F(\(iv(h))) = \(frac(F6(h), 6)),   F(\(iv(l))) = \(frac(F6(l), 6))"),
                     S("\(frac(F6(h), 6)) − (\(frac(F6(l), 6)))")]
            topic = "area:quadratic"
        case 11:
            // Under 1/(ax + b): a logarithm.
            let a = r.int(1...3), b = r.int(1...4), l = 0, h = r.int(1...4)
            f = .div(1, .sum([.scaled(a, 1, x), .n(b)])); lo = Double(l); hi = Double(h)
            value = log(Double(a * h + b) / Double(b)) / Double(a)
            let ratio = frac(a * h + b, b)
            prompt = "Find the shaded area under f from x = 0 to x = \(h)."
            answer = a == 1 ? "ln(\(ratio))" : "(1/\(a))·ln(\(ratio))"
            steps = [H("Check the sign"), S("For x ≥ 0, \(a == 1 ? "" : "\(a)")x + \(b) > 0, so f > 0."),
                     H("An antiderivative"), S("Inner function \(a == 1 ? "" : "\(a)")x + \(b) with derivative \(a):  F(x) = \(a == 1 ? "" : "(1/\(a))·")ln(\(a == 1 ? "" : "\(a)")x + \(b))"),
                     H("F(\(h)) − F(0)"), S("\(a == 1 ? "" : "(1/\(a))·")[ln \(a * h + b) − ln \(b)] = \(a == 1 ? "" : "(1/\(a))·")ln(\(a * h + b)/\(b))")]
            topic = "area:linear ln"
        case 12:
            // e^(kx) from 0 to n: (e^(kn) − 1)/k.
            let k = r.pick([1, 2, -1]), n = r.int(1...2)
            f = .exp(.scaled(k, 1, x)); lo = 0; hi = Double(n)
            value = (exp(Double(k * n)) - 1) / Double(k)
            let ek = k * n == 1 ? "e" : "e^(\(iv(k * n)))"
            prompt = "Find the shaded area under f from x = 0 to x = \(n). (Type it exactly, with e.)"
            answer = k == 1 ? "\(ek) − 1" : (k < 0 ? "1 − \(ek)" : "(\(ek) − 1)/\(k)")
            steps = [H("Check the sign"), S("e to any power is positive."),
                     H("An antiderivative"), S("F(x) = e^(\(iv(k))x)\(k == 1 ? "" : "/\(iv(k))")"),
                     H("F(\(n)) − F(0)"), S("(\(ek) − e⁰)\(k == 1 ? "" : "/\(iv(k))")")]
            topic = "area:exp exact"
        case 13:
            // Volume of revolution: V = π∫f²dx.
            resultName = "Volume"
            let pi = "π"
            switch r.int(0...4) {
            case 0:
                let b = r.int(1...4)
                f = .sqrt(x); lo = 0; hi = Double(b)
                value = .pi * Double(b * b) / 2
                answer = "\(frac(b * b, 2))\(pi)"
                steps = [H("The volume formula"), S("V = π∫ f(x)² dx  from \(0) to \(b)"), S("f(x)² = (√x)² = x"),
                         H("Integrate"), S("π∫ x dx = π·[x²/2]  from 0 to \(b) = π·\(frac(b * b, 2))")]
                topic = "volume:root"
            case 1:
                let b = r.int(1...2)
                f = .p(x, 2); lo = 0; hi = Double(b)
                value = .pi * pow(Double(b), 5) / 5
                answer = "\(frac(b * b * b * b * b, 5))\(pi)"
                steps = [H("The volume formula"), S("V = π∫ f(x)² dx  from 0 to \(b)"), S("f(x)² = x⁴"),
                         H("Integrate"), S("π·[x⁵/5]  from 0 to \(b) = π·\(frac(b * b * b * b * b, 5))")]
                topic = "volume:polynomial"
            case 2:
                let b = r.int(2...5)
                f = .div(1, x); lo = 1; hi = Double(b)
                value = .pi * Double(b - 1) / Double(b)
                answer = "\(frac(b - 1, b))\(pi)"
                steps = [H("The volume formula"), S("V = π∫ f(x)² dx  from 1 to \(b)"), S("f(x)² = 1/x²"),
                         H("Integrate"), S("π·[−1/x]  from 1 to \(b) = π·(−1/\(b) + 1)")]
                topic = "volume:hyperbola"
            case 3:
                let k = r.int(1...3)
                f = .sqrt(.sub(.n(k * k), .p(x, 2))); lo = -Double(k); hi = Double(k)
                value = 4 * .pi * pow(Double(k), 3) / 3
                answer = "\(frac(4 * k * k * k, 3))\(pi)"
                steps = [H("A half-circle turns into a ball"), S("y = √(\(k * k) − x²) is the upper half of a circle of radius \(k)."),
                         H("The volume formula"), S("V = π∫ (\(k * k) − x²) dx  from −\(k) to \(k)"),
                         H("Integrate"), S("π·[\(k * k)x − x³/3]  from −\(k) to \(k) = π·(\(frac(2 * k * k * k, 3)) + \(frac(2 * k * k * k, 3)))")]
                topic = "volume:sphere"
            default:
                f = .exp(x); lo = 0; hi = 1
                value = .pi * (exp(2) - 1) / 2
                answer = "π(e² − 1)/2"
                steps = [H("The volume formula"), S("V = π∫ (eˣ)² dx = π∫ e^(2x) dx  from 0 to 1"),
                         H("Integrate"), S("π·[e^(2x)/2]  from 0 to 1 = π·(e² − 1)/2")]
                topic = "volume:exp"
            }
            prompt = "The shaded region is turned around the x-axis. Find the volume of the solid (exactly, with π)."
        default:
            let c = r.int(1...2)
            f = .sub(.p(x, 3), .scaled(c * c, 1, x)); lo = -Double(c); hi = Double(c)
            value = pow(Double(c), 4) / 2
            let c4 = c * c * c * c
            prompt = "Find the total area between f and the x-axis from x = −\(c) to x = \(c)."
            answer = frac(c4, 2)
            steps = [H("Step 1 · Where f changes sign"), S("f(x) = x(x − \(c))(x + \(c)) = 0 at x = −\(c), 0, \(c)"),
                     S("−\(c) < x < 0: f > 0 (e.g. f(−\(frac(c, 2))) = \(frac(3 * c * c * c, 8)));   0 < x < \(c): f < 0"),
                     H("Step 2 · An antiderivative"), S("F(x) = x⁴/4 − \(c * c == 1 ? "" : "\(c * c)")x²/2"),
                     H("Step 3 · Each part separately"), S("Left part: F(0) − F(−\(c)) = 0 − (\(frac(c4, 4)) − \(frac(c4, 2))) = \(frac(c4, 4))"),
                     S("Right part is below the axis: −(F(\(c)) − F(0)) = −(−\(frac(c4, 4))) = \(frac(c4, 4))"),
                     S("Total = \(frac(c4, 4)) + \(frac(c4, 4))")]
            topic = "area:sign change"
        }
        let w = hi - lo
        guard var graph = SketchFactory.finish(f, lo - 0.25 * w, hi + 0.25 * w, piBased: piBased, level: level, seed: seed) else { return nil }
        var q = blank(.area, level, seed, prompt, .number(value), topic: topic)
        if let g {
            guard let gp = SketchFactory.finish(g, lo - 0.25 * w, hi + 0.25 * w, piBased: piBased, level: level, seed: seed) else { return nil }
            graph.yMin = Swift.min(graph.yMin, gp.yMin); graph.yMax = Swift.max(graph.yMax, gp.yMax)
            q.lower = gp
        }
        q.graph = graph; q.shade = lo...hi
        q.formulaLabel = "f(x) ="; q.formula = f
        q.steps = steps + [R("\(resultName) = \(answer)")]
        return q
    }

    // MARK: How many solutions

    static func solutions(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        guard let f = SketchFactory.candidate(level: level == .bagrut ? .hard : level, rng: &r, seed: seed), f.poles.isEmpty else { return nil }
        let d = f.function.derivative()
        let turns = GraphSteps.roots(of: d, in: f.xMin...f.xMax)
        guard !turns.isEmpty else { return nil }
        let span = f.yMax - f.yMin
        // A level k that isn't (almost) at a peak or dip.
        var k = f.yMin + span * r.double(0.2...0.8)
        k = (k * 4).rounded() / 4
        guard turns.allSatisfy({ Swift.abs(f.value(at: $0) - k) > 0.06 * span }),
              Swift.abs(f.value(at: f.xMin) - k) > 0.04 * span, Swift.abs(f.value(at: f.xMax) - k) > 0.04 * span else { return nil }
        let count = GraphSteps.roots(of: .sub(f.function, .num(k)), in: f.xMin...f.xMax).count
        guard count <= 4 else { return nil }
        let L = labeler(f)
        // Count stretch by stretch: f is monotonic between turning points.
        let pts = [f.xMin] + turns + [f.xMax]
        var stretchLines: [SolutionStep] = []
        var total = 0
        for (l, h) in zip(pts, pts.dropFirst()) {
            let v1 = f.value(at: l), v2 = f.value(at: h)
            let hit = (v1 - k) * (v2 - k) < 0
            if hit { total += 1 }
            stretchLines.append(S("\(L(l)) → \(L(h)): f \(v2 > v1 ? "rises" : "falls") from \(num(v1)) to \(num(v2))  ⇒  \(hit ? "passes \(num(k)) once" : "never reaches \(num(k))")"))
        }
        guard total == count else { return nil }
        let showGraph = level == .easy || level == .medium
        let options = (0...4).map { QuizOption(text: "\($0)") }
        var q = blank(.solutions, level, seed,
                      "How many solutions does f(x) = \(num(k)) have for \(f.xLabel(f.xMin)) ≤ x ≤ \(f.xLabel(f.xMax))?",
                      .choice(options, correct: count), topic: "solutions")
        q.formulaLabel = "f(x) ="
        q.formula = f.function
        if showGraph { q.graph = f; q.level_k = k }
        q.steps = [H("Step 1 · Turning points (f′ = 0)")]
            + turns.map { t -> SolutionStep in
                let before = d.evaluate(at: t - 1e-4), after = d.evaluate(at: t + 1e-4)
                let kind = before > 0 && after < 0 ? "maximum" : (before < 0 && after > 0 ? "minimum" : "turning point")
                return S("x = \(L(t)): f = \(num(f.value(at: t))) (\(kind))")
            }
            + [H("Step 2 · The ends"), S("f(\(f.xLabel(f.xMin))) = \(num(f.value(at: f.xMin))),   f(\(f.xLabel(f.xMax))) = \(num(f.value(at: f.xMax)))"),
               H("Step 3 · Count crossings of y = \(num(k)) on each stretch"), S("Between turning points f only rises or only falls, so it can pass \(num(k)) at most once.")]
            + stretchLines
            + [R("\(count) solution\(count == 1 ? "" : "s")")]
        return q
    }

    // MARK: Sign table

    static func signTable(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        guard let f = SketchFactory.candidate(level: level, rng: &r, seed: seed) else { return nil }
        return signQuiz(for: f, level: level, seed: seed)
    }

    /// The sign-of-f′ question for a given graph (also the first part of a mini exam).
    public static func signQuiz(for f: SketchProblem, level: Level, seed: UInt64) -> QuizProblem? {
        let a = f.xMin, b = f.xMax
        let d1 = f.function.derivative()
        let crit = GraphSteps.roots(of: d1, in: a...b)
        let cuts = (crit + f.poles.filter { $0 > a && $0 < b }).sorted()
        guard !crit.isEmpty, cuts.count <= 4 else { return nil }
        let label = labeler(f)
        let pts = [a] + cuts + [b]
        var intervals: [String] = [], signs: [Bool] = [], tests: [SolutionStep] = []
        for (l, rr) in zip(pts, pts.dropFirst()) {
            let t = testPoint(l, rr)
            let v = d1.evaluate(at: t)
            guard v.isFinite else { continue }
            let text = "\(label(l)) < x < \(label(rr))"
            intervals.append(text)
            signs.append(v > 0)
            tests.append(S("\(text):  f′(\(num(t))) = \(num(v)) \(v > 0 ? "> 0  ⇒  +" : "< 0  ⇒  −")"))
        }
        guard intervals.count >= 2 else { return nil }
        var q = blank(.signTable, level, seed, "Tap + or − for the sign of f′(x) in each interval.",
                      .signs(intervals: intervals, positive: signs), topic: "signs")
        q.formulaLabel = "f(x) ="
        q.formula = f.function
        let inv = GraphAlgebra.investigate(f)
        var steps: [SolutionStep] = [H("Step 1 · Differentiate"),
                                     SolutionStep("", label: "f′(x) =", math: inv?.d1?.display ?? d1.simplified(), depth: 1),
                                     H("Step 2 · Solve f′(x) = 0")]
        if let lines = inv?.d1?.solve.lines, !lines.isEmpty {
            steps += lines
        } else {
            steps.append(S("f′(x) = 0 at x = \(crit.map(label).joined(separator: ", "))"))
        }
        let poles = f.poles.filter { $0 > a && $0 < b }
        if !poles.isEmpty { steps.append(S("f′ is undefined at x = \(poles.map(label).joined(separator: ", ")) (an asymptote), so that splits the intervals too.")) }
        steps.append(H("Step 3 · Test one point in each interval"))
        steps += tests
        steps.append(H("Answer"))
        steps.append(R("f′:  " + signs.map { $0 ? "+" : "−" }.joined(separator: "  |  ")))
        q.steps = steps
        return q
    }

    // MARK: Equations

    static func equation(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        func ask(_ eq: String, _ correct: String, _ wrong: [String], _ steps: [SolutionStep], _ topic: String) -> QuizProblem? {
            guard Set(wrong + [correct]).count == wrong.count + 1 else { return nil }
            var q = blank(.equation, level, seed, "Solve: \(eq)", .number(0), topic: "equation:\(topic)")
            q.answer = shuffled(QuizOption(text: correct), wrong.map { QuizOption(text: $0) }, &r)
            q.steps = steps + [R(correct)]
            return q
        }
        let pool: [Int]
        switch level {
        case .easy: pool = [1, 4, 2, 4, 8]
        case .medium: pool = [0, 1, 2, 4, 6, 8]
        case .hard: pool = [0, 3, 5, 6, 7, 8, 9, 11]
        case .bagrut: pool = [0, 3, 5, 6, 7, 2, 8, 10, 12]
        }
        let range = "   for 0 ≤ x ≤ 2π"
        switch choose(pool, cases, &r) {
        case 0:
            // e^(2x) + B eˣ + C = 0 with t = eˣ; sometimes one root is negative and must be rejected.
            let p = r.int(1...3), q0 = p + r.int(1...3)
            let lp = p == 1 ? "0" : "ln \(p)"
            if r.bool() {
                return ask("e^(2x) − \(p + q0)eˣ + \(p * q0) = 0", "x = \(lp),  x = ln \(q0)",
                           ["x = \(p),  x = \(q0)", "x = ln \(q0) only", "x = ln \(p + q0)"],
                           [H("Step 1 · Substitute t = eˣ"), S("e^(2x) = (eˣ)² = t², and t > 0 because eˣ is always positive."),
                            S("t² − \(p + q0)t + \(p * q0) = 0", 2),
                            H("Step 2 · Solve the quadratic"), S("(t − \(p))(t − \(q0)) = 0   ⇒   t = \(p) or t = \(q0)"),
                            H("Step 3 · Check t > 0"), S("Both are positive, so both are allowed ✓"),
                            H("Step 4 · Back to x"), S("eˣ = \(p)  ⇒  x = \(lp)"), S("eˣ = \(q0)  ⇒  x = ln \(q0)")], "e quadratic")
            }
            let diff = q0 - p
            let coef = diff == 1 ? "" : "\(diff)"
            return ask("e^(2x) − \(coef)eˣ − \(p * q0) = 0", "x = ln \(q0)",
                       ["x = ln \(q0),  x = ln(−\(p))", "x = ln \(q0),  x = −ln \(p)", "No solution"],
                       [H("Step 1 · Substitute t = eˣ"), S("t² − \(coef)t − \(p * q0) = 0, where t = eˣ > 0"),
                        H("Step 2 · Solve the quadratic"), S("(t − \(q0))(t + \(p)) = 0   ⇒   t = \(q0) or t = −\(p)"),
                        H("Step 3 · Check t > 0"), S("eˣ = −\(p) is impossible: eˣ is always positive. Rejected ✗"),
                        S("eˣ = \(q0) is fine ✓"),
                        H("Step 4 · Back to x"), S("eˣ = \(q0)  ⇒  x = ln \(q0)")], "e quadratic")
        case 1:
            let options: [(String, String, [String], [SolutionStep])] = [
                ("2 sin x = 1", "x = π/6,  x = 5π/6", ["x = π/6 only", "x = π/3,  x = 2π/3", "x = π/6,  x = 7π/6"],
                 [H("Step 1 · Isolate"), S("sin x = 1/2"),
                  H("Step 2 · The basic angle"), S("sin(π/6) = 1/2, so the basic angle is π/6."),
                  H("Step 3 · Every angle in [0, 2π]"), S("Sine is positive in the 1st and 2nd quadrants:"),
                  S("x = π/6   and   x = π − π/6 = 5π/6", 2), S("Adding 2π would leave the interval.")]),
                ("2 cos x = 1", "x = π/3,  x = 5π/3", ["x = π/3 only", "x = π/6,  x = 11π/6", "x = π/3,  x = 2π/3"],
                 [H("Step 1 · Isolate"), S("cos x = 1/2"),
                  H("Step 2 · The basic angle"), S("cos(π/3) = 1/2, so the basic angle is π/3."),
                  H("Step 3 · Every angle in [0, 2π]"), S("Cosine is positive in the 1st and 4th quadrants:"),
                  S("x = π/3   and   x = 2π − π/3 = 5π/3", 2)]),
                ("2 sin x = −1", "x = 7π/6,  x = 11π/6", ["x = −π/6", "x = 5π/6,  x = 7π/6", "x = 4π/3,  x = 5π/3"],
                 [H("Step 1 · Isolate"), S("sin x = −1/2"),
                  H("Step 2 · The basic angle"), S("sin(π/6) = 1/2, so the basic angle is π/6 (the sign tells the quadrant)."),
                  H("Step 3 · Every angle in [0, 2π]"), S("Sine is negative in the 3rd and 4th quadrants:"),
                  S("x = π + π/6 = 7π/6   and   x = 2π − π/6 = 11π/6", 2),
                  S("x = −π/6 also works, but it is outside [0, 2π] ✗")]),
                ("tan x = 1", "x = π/4,  x = 5π/4", ["x = π/4 only", "x = π/4,  x = 3π/4", "x = π/4,  x = 7π/4"],
                 [H("Step 1 · The basic angle"), S("tan(π/4) = 1."),
                  H("Step 2 · Every angle in [0, 2π]"), S("tan repeats every π: x = π/4 + kπ"),
                  S("k = 0: π/4,   k = 1: 5π/4,   k = 2: 9π/4 > 2π ✗", 2)]),
                ("2 cos x = −√3", "x = 5π/6,  x = 7π/6", ["x = π/6,  x = 11π/6", "x = 5π/6 only", "x = 2π/3,  x = 4π/3"],
                 [H("Step 1 · Isolate"), S("cos x = −√3/2"),
                  H("Step 2 · The basic angle"), S("cos(π/6) = √3/2, so the basic angle is π/6."),
                  H("Step 3 · Every angle in [0, 2π]"), S("Cosine is negative in the 2nd and 3rd quadrants:"),
                  S("x = π − π/6 = 5π/6   and   x = π + π/6 = 7π/6", 2)]),
            ]
            let (eq, right, wrong, steps) = r.pick(options)
            return ask(eq + range, right, wrong, steps, "trig")
        case 2:
            let k = r.int(1...3), root = k + r.int(1...3)
            let m = root * (root - k), other = k - root
            return ask("ln x + ln(x − \(k)) = ln \(m)", "x = \(root)",
                       ["x = \(root),  x = \(iv(other))", "x = \(m)", "x = \(root + k)"],
                       [H("Step 1 · Domain"), S("ln x needs x > 0 and ln(x − \(k)) needs x > \(k). Together: x > \(k)."),
                        H("Step 2 · Combine the logs"), S("ln a + ln b = ln(ab):   ln(x(x − \(k))) = ln \(m)"),
                        S("ln is one-to-one, so x(x − \(k)) = \(m)   ⇒   x² − \(k)x − \(m) = 0", 2),
                        H("Step 3 · Solve"), S("(x − \(root))(x\(sg(-other))) = 0   ⇒   x = \(root) or x = \(iv(other))"),
                        H("Step 4 · Check the domain"), S("x = \(root) > \(k) ✓"),
                        S("x = \(iv(other)) is not > \(k): ln of a negative number (or 0) is undefined. Rejected ✗")], "ln")
        case 3:
            let p = r.int(1...2), q0 = p + r.int(1...2)
            return ask("(ln x)² − \(p + q0)·ln x + \(p * q0) = 0", "x = e\(Solver.sup(p)),  x = e\(Solver.sup(q0))",
                       ["x = \(p),  x = \(q0)", "x = ln \(p),  x = ln \(q0)", "x = e\(Solver.sup(p + q0))"],
                       [H("Step 1 · Domain"), S("ln x needs x > 0."),
                        H("Step 2 · Substitute u = ln x"), S("u² − \(p + q0)u + \(p * q0) = 0"),
                        H("Step 3 · Solve the quadratic"), S("(u − \(p))(u − \(q0)) = 0   ⇒   u = \(p) or u = \(q0)"),
                        H("Step 4 · Back to x"), S("ln x = \(p)  ⇒  x = e\(Solver.sup(p))"), S("ln x = \(q0)  ⇒  x = e\(Solver.sup(q0))"),
                        H("Step 5 · Check the domain"), S("Both are positive ✓")], "ln quadratic")
        case 4:
            let b = r.pick([2, 3, 5]), m = r.int(1...3), s = r.int(-3...3)
            let n = b == 2 ? r.int(2...5) : (b == 3 ? r.int(2...4) : r.int(2...3))
            let N = Int(pow(Double(b), Double(n)))
            let exponent = "\(m == 1 ? "" : "\(m)")x\(sg(s))"
            func x(_ top: Int) -> String { "x = \(frac(top, m))" }
            return ask("\(b)^(\(exponent)) = \(N)", x(n - s), [x(n + s), x(N - s), "x = \(frac(n, m))"],
                       [H("Step 1 · Write both sides with the same base"), S("\(N) = \(b)\(Solver.sup(n))"),
                        S("\(b)^(\(exponent)) = \(b)\(Solver.sup(n))", 2),
                        H("Step 2 · Equal bases ⇒ equal exponents"), S("\(exponent) = \(n)"),
                        H("Step 3 · Solve"), S("\(m == 1 ? "" : "\(m)")x = \(n)\(sg(-s)) = \(iv(n - s))"),
                        H("Check"), S("Exponential equations like this have exactly one solution; nothing to reject.")], "same base")
        case 8:
            // 4ˣ − (2^p + 2^q)·2ˣ + 2^(p+q) = 0 with t = 2ˣ.
            let p = r.int(0...2), qq = p + r.int(1...2)
            let P = 1 << p, Q = 1 << qq
            return ask("4ˣ − \(P + Q)·2ˣ + \(P * Q) = 0", "x = \(p),  x = \(qq)", ["x = \(P),  x = \(Q)", "x = \(qq) only", "x = \(p + qq)"],
                       [H("Write 4ˣ with base 2"), S("4ˣ = (2²)ˣ = (2ˣ)²"),
                        H("Substitute t = 2ˣ (t > 0)"), S("t² − \(P + Q)t + \(P * Q) = 0"),
                        H("Solve the quadratic"), S("(t − \(P))(t − \(Q)) = 0   ⇒   t = \(P) or t = \(Q)"),
                        H("Check t > 0"), S("Both are positive ✓"),
                        H("Back to x"), S("2ˣ = \(P) = 2\(Solver.sup(p))  ⇒  x = \(p)"), S("2ˣ = \(Q) = 2\(Solver.sup(qq))  ⇒  x = \(qq)")], "base 2")
        case 5:
            // √(x + a) = x − c: squaring adds a false root, which the check removes.
            let c = r.int(1...3), r1 = c + r.int(2...4)
            let r2 = 2 * c + 1 - r1
            let a = c * c - r1 * r2
            guard r2 + a >= 0, a != 0 else { return nil }
            return ask("√(x\(sg(a))) = x − \(c)", "x = \(r1)", ["x = \(r1),  x = \(iv(r2))", "x = \(iv(r2))", "No solution"],
                       [H("Step 1 · Conditions"), S("Under the root: x\(sg(a)) ≥ 0."),
                        S("A square root is never negative, so the right side must be ≥ 0 too: x ≥ \(c)."),
                        H("Step 2 · Square both sides"), S("x\(sg(a)) = (x − \(c))² = x² − \(2 * c)x + \(c * c)"),
                        S("x² − \(2 * c + 1)x\(sg(c * c - a)) = 0", 2),
                        H("Step 3 · Solve"), S("(x − \(r1))(x\(sg(-r2))) = 0   ⇒   x = \(r1) or x = \(iv(r2))"),
                        H("Step 4 · Check in the original equation"),
                        S("x = \(r1):  √\(r1 + a) = \(Int(Double(r1 + a).squareRoot()))  and  \(r1) − \(c) = \(r1 - c) ✓"),
                        S("x = \(iv(r2)):  √\(r2 + a) = \(Int(Double(r2 + a).squareRoot())), but \(iv(r2)) − \(c) = \(iv(r2 - c)) is negative. Rejected ✗"),
                        S("(Squaring made −\(c - r2) and \(c - r2) look the same — that's where the false root came from.)")], "square root")
        case 6:
            // ln(x² − k) = ln(x + m): roots t and 1 − t; 1 − t breaks the domain.
            let t = r.int(3...5), m = r.int(1...(t - 1))
            let k = t * (t - 1) - m
            let bad = 1 - t
            return ask("ln(x² − \(k)) = ln(x + \(m))", "x = \(t)", ["x = \(t),  x = \(iv(bad))", "x = \(iv(bad))", "No solution"],
                       [H("Step 1 · Domain"), S("x² − \(k) > 0  and  x + \(m) > 0"),
                        H("Step 2 · ln is one-to-one"), S("x² − \(k) = x + \(m)   ⇒   x² − x − \(k + m) = 0"),
                        H("Step 3 · Solve"), S("(x − \(t))(x + \(t - 1)) = 0   ⇒   x = \(t) or x = \(iv(bad))"),
                        H("Step 4 · Check the domain"),
                        S("x = \(t):  \(t * t) − \(k) = \(t * t - k) > 0 and \(t) + \(m) = \(t + m) > 0 ✓"),
                        S("x = \(iv(bad)):  x + \(m) = \(iv(bad + m)) ≤ 0, so ln(x + \(m)) is undefined. Rejected ✗")], "ln domain")
        case 9:
            // log_a x + log_a(x − k) = n: one root breaks the domain.
            let (a, n, p, q) = r.pick([(2, 3, 8, 1), (2, 3, 4, 2), (2, 4, 8, 2), (2, 4, 16, 1), (3, 2, 9, 1), (2, 5, 8, 4), (5, 2, 25, 1), (2, 2, 4, 1), (3, 3, 9, 3), (2, 5, 16, 2)])
            let k = p - q
            let la = "log\(sub(a))"
            return ask("\(la) x + \(la)(x − \(k)) = \(n)", "x = \(p)", ["x = \(p),  x = \(iv(-q))", "x = \(q)", "No solution"],
                       [H("Domain"), S("x > 0 and x − \(k) > 0, so x > \(k)."),
                        H("Combine the logs"), S("\(la) x + \(la)(x − \(k)) = \(la)(x(x − \(k)))"),
                        S("\(la)(x² − \(k)x) = \(n)   ⇒   x² − \(k)x = \(a)^\(n) = \(p * q)"),
                        H("Solve"), S("x² − \(k)x − \(p * q) = 0   ⇒   (x − \(p))(x + \(q)) = 0"),
                        H("Check the domain"), S("x = \(p) > \(k) ✓"), S("x = \(iv(-q)) is not > \(k). Rejected ✗")], "log any base")
        case 10:
            let a = r.pick([2, 3])
            if r.bool() {
                // log_a x + log_(a²) x = 3L/2.
                let L = r.int(1...4)
                let x = Int(pow(Double(a), Double(L)))
                return ask("log\(sub(a)) x + log\(sub(a * a)) x = \(fr(3 * L, 2))", "x = \(x)", ["x = \(a * L)", "x = \(Int(pow(Double(a), Double(3 * L))))", "x = \(Int(pow(Double(a * a), Double(L))))"],
                           [H("Change the base"), S("log\(sub(a * a)) x = log\(sub(a)) x / log\(sub(a)) \(a * a) = ½·log\(sub(a)) x"),
                            H("Solve for t = log\(sub(a)) x"), S("t + ½t = \(fr(3 * L, 2))   ⇒   (3/2)t = \(fr(3 * L, 2))   ⇒   t = \(L)"),
                            H("Back to x"), S("log\(sub(a)) x = \(L)   ⇒   x = \(a)^\(L)")], "change of base")
            }
            // log_a x − 2·log_x a = 1: t − 2/t = 1.
            let x1 = a * a
            return ask("log\(sub(a)) x − 2·logₓ \(a) = 1", "x = \(x1),  x = 1/\(a)", ["x = \(x1) only", "x = \(x1),  x = \(iv(-a))", "x = 1/\(a) only"],
                       [H("Domain"), S("x > 0 and x ≠ 1 (x is a base)."),
                        H("Change the base"), S("logₓ \(a) = 1 / log\(sub(a)) x.  Let t = log\(sub(a)) x:  t − 2/t = 1"),
                        H("Solve"), S("t² − t − 2 = 0   ⇒   (t − 2)(t + 1) = 0   ⇒   t = 2 or t = −1"),
                        H("Back to x"), S("t = 2:  x = \(a)² = \(x1) ✓"), S("t = −1:  x = \(a)⁻¹ = 1/\(a) ✓ (positive, not 1)")], "log of a base")
        case 11:
            // x^(p/q) = b^p  ⇒  x = b^q.
            let (pp, qq) = r.pick([(3, 2), (2, 3), (3, 4), (4, 3), (5, 2), (2, 5)])
            let b = r.pick([2, 3, 2])
            let rhs = Int(pow(Double(b), Double(pp))), x = Int(pow(Double(b), Double(qq)))
            return ask("x^(\(pp)/\(qq)) = \(rhs)", "x = \(x)", ["x = \(Int(pow(Double(rhs), Double(pp) / Double(qq)).rounded()))", "x = ±\(x)", "x = \(b)"],
                       [H("Domain"), S("A rational power x^(\(pp)/\(qq)) is defined for x ≥ 0."),
                        H("Raise both sides to the power \(qq)/\(pp)"), S("(x^(\(pp)/\(qq)))^(\(qq)/\(pp)) = x"),
                        S("\(rhs) = \(b)^\(pp),  so  \(rhs)^(\(qq)/\(pp)) = \(b)^\(qq) = \(x)"),
                        H("Check"), S("x = \(x) ≥ 0 ✓")], "rational power")
        case 12:
            // x^(2/k) − (m + n)x^(1/k) + mn = 0 with t = x^(1/k) ≥ 0.
            let k = r.pick([2, 3])
            let m = r.int(1...4), n = r.pick([r.int(m + 1...6), -r.int(1...4)])
            let root = k == 2 ? "√x" : "x^(1/3)"
            let sq = k == 2 ? "x" : "x^(2/3)"
            func power(_ t: Int) -> Int { Int(pow(Double(t), Double(k))) }
            let eq = "\(sq)\(signedTerm(-(m + n), root))\(sg(m * n)) = 0"
            if n < 0 {
                return ask(eq, "x = \(power(m))", ["x = \(power(m)),  x = \(power(-n))", "x = \(m)", "No solution"],
                           [H("Substitute t = \(root)"), S("t ≥ 0, and \(sq) = t²:  t²\(signedTerm(-(m + n), "t"))\(sg(m * n)) = 0"),
                            H("Solve"), S("(t − \(m))(t + \(-n)) = 0   ⇒   t = \(m) or t = \(iv(n))"),
                            H("Check t ≥ 0"), S("t = \(iv(n)) < 0 is impossible. Rejected ✗"),
                            H("Back to x"), S("\(root) = \(m)   ⇒   x = \(m)^\(k) = \(power(m))")], "power substitution")
            }
            return ask(eq, "x = \(power(m)),  x = \(power(n))", ["x = \(m),  x = \(n)", "x = \(power(n)) only", "x = \(power(m)),  x = \(power(m + n))"],
                       [H("Substitute t = \(root)"), S("t ≥ 0, and \(sq) = t²:  t²\(signedTerm(-(m + n), "t")) + \(m * n) = 0"),
                        H("Solve"), S("(t − \(m))(t − \(n)) = 0   ⇒   t = \(m) or t = \(n), both ≥ 0 ✓"),
                        H("Back to x"), S("x = t^\(k):  x = \(power(m)) or x = \(power(n))")], "power substitution")
        default:
            let options: [(String, String, [String], [SolutionStep])] = [
                ("sin²x + sin x − 2 = 0", "x = π/2", ["x = π/2,  x = 3π/2", "No solution", "x = π/2,  x = π/6"],
                 [H("Step 1 · Substitute t = sin x"), S("t² + t − 2 = 0"),
                  H("Step 2 · Solve the quadratic"), S("(t − 1)(t + 2) = 0   ⇒   t = 1 or t = −2"),
                  H("Step 3 · Check −1 ≤ sin x ≤ 1"), S("sin x = −2 is impossible. Rejected ✗"), S("sin x = 1 ✓"),
                  H("Step 4 · The angles"), S("sin x = 1 only at x = π/2 in [0, 2π]")]),
                ("2sin²x − sin x − 1 = 0", "x = π/2,  7π/6,  11π/6", ["x = π/2 only", "x = π/2,  π/6,  5π/6", "x = 7π/6,  11π/6"],
                 [H("Step 1 · Substitute t = sin x"), S("2t² − t − 1 = 0"),
                  H("Step 2 · Solve the quadratic"), S("(2t + 1)(t − 1) = 0   ⇒   t = 1 or t = −1/2"),
                  H("Step 3 · Check −1 ≤ sin x ≤ 1"), S("Both values are allowed ✓"),
                  H("Step 4 · The angles"), S("sin x = 1:  x = π/2"),
                  S("sin x = −1/2: basic angle π/6, 3rd and 4th quadrants:  x = 7π/6, 11π/6")]),
                ("2cos²x + cos x − 1 = 0", "x = π/3,  π,  5π/3", ["x = π/3,  5π/3", "x = 2π/3,  π,  4π/3", "x = π/3,  2π/3"],
                 [H("Step 1 · Substitute t = cos x"), S("2t² + t − 1 = 0"),
                  H("Step 2 · Solve the quadratic"), S("(2t − 1)(t + 1) = 0   ⇒   t = 1/2 or t = −1"),
                  H("Step 3 · Check −1 ≤ cos x ≤ 1"), S("Both values are allowed ✓"),
                  H("Step 4 · The angles"), S("cos x = 1/2: 1st and 4th quadrants:  x = π/3, 5π/3"), S("cos x = −1:  x = π")]),
                ("cos²x − 3cos x + 2 = 0", "x = 0,  2π", ["x = 0 only", "x = 0,  π", "No solution"],
                 [H("Step 1 · Substitute t = cos x"), S("t² − 3t + 2 = 0"),
                  H("Step 2 · Solve the quadratic"), S("(t − 1)(t − 2) = 0   ⇒   t = 1 or t = 2"),
                  H("Step 3 · Check −1 ≤ cos x ≤ 1"), S("cos x = 2 is impossible. Rejected ✗"), S("cos x = 1 ✓"),
                  H("Step 4 · The angles"), S("cos x = 1 at x = 0 and x = 2π (both ends of the interval count)")]),
                ("2cos²x − 3cos x − 2 = 0", "x = 2π/3,  4π/3", ["x = π/3,  5π/3", "x = 2π/3 only", "No solution"],
                 [H("Step 1 · Substitute t = cos x"), S("2t² − 3t − 2 = 0"),
                  H("Step 2 · Solve the quadratic"), S("(2t + 1)(t − 2) = 0   ⇒   t = −1/2 or t = 2"),
                  H("Step 3 · Check −1 ≤ cos x ≤ 1"), S("cos x = 2 is impossible. Rejected ✗"), S("cos x = −1/2 ✓"),
                  H("Step 4 · The angles"), S("Basic angle π/3; cosine is negative in the 2nd and 3rd quadrants:"),
                  S("x = π − π/3 = 2π/3   and   x = π + π/3 = 4π/3", 2)]),
            ]
            let (eq, right, wrong, steps) = r.pick(options)
            return ask(eq + range, right, wrong, steps, "trig quadratic")
        }
    }
}

// MARK: - Mini exam

/// A short Bagrut-style question chain about one function: the sign of f′,
/// the x of an extreme point (exact), then a sketch of f.
public struct MiniExam: Sendable {
    public var sketch: SketchProblem
    public var signs: QuizProblem
    public var extreme: QuizProblem

    public static func make(level: Level, seed: UInt64) -> MiniExam {
        var s = seed
        for _ in 0..<80 {
            var r = SeededRandom(seed: s)
            if let f = SketchFactory.candidate(level: level, rng: &r, seed: s), let e = make(f, level: level, seed: s) { return e }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        // Always works: a cubic with exact turning points.
        let f = SketchFactory.make(level: .easy, seed: seed)
        return make(f, level: .easy, seed: seed) ?? MiniExam(sketch: f, signs: QuizFactory.make(.signTable, level: .easy, seed: seed),
                                                            extreme: QuizFactory.make(.limit, level: .easy, seed: seed))
    }

    static func make(_ f: SketchProblem, level: Level, seed: UInt64) -> MiniExam? {
        guard !f.isWhole, let signs = QuizFactory.signQuiz(for: f, level: level, seed: seed),
              let inv = GraphAlgebra.investigate(f), let d1 = inv.d1, d1.solve.exact else { return nil }
        let d = f.function.derivative()
        // The first extreme point with an exact x.
        for root in d1.solve.roots.sorted(by: { $0.x < $1.x }) where root.x > f.xMin && root.x < f.xMax {
            let l = d.evaluate(at: root.x - 1e-4), r = d.evaluate(at: root.x + 1e-4)
            guard l.isFinite, r.isFinite, (l > 0) != (r > 0) else { continue }
            let isMax = l > 0
            var q = QuizFactory.blank(.signTable, level, seed,
                                      "Using the sign table, type the x of the \(isMax ? "maximum" : "minimum") point\(d1.solve.roots.count > 1 ? " (the leftmost one)" : "").",
                                      .number(root.x), topic: "extreme")
            q.formulaLabel = "f(x) ="
            q.formula = f.function
            q.steps = [SolutionStep("f′(x) = 0 at x = \(GraphSteps.bare(root.label))."),
                       SolutionStep("f′ changes from \(isMax ? "+ to −" : "− to +") there, so it is a \(isMax ? "maximum" : "minimum").", depth: 1)]
            return MiniExam(sketch: f, signs: signs, extreme: q)
        }
        return nil
    }
}
