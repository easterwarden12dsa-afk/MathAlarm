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
        }
    }
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

    public var signature: String {
        "quiz:\(kind.rawValue):\(prompt):\(formula?.description ?? formulaText ?? ""):\(graph?.function.description ?? "")"
    }
}

// MARK: - Checking typed answers

public enum QuizChecker {
    /// Typed answers: a number (no x) or a function of x.
    public static func check(_ typed: Expr, for q: QuizProblem) -> Bool {
        switch q.answer {
        case .number(let v):
            guard !typed.containsX else { return false }
            let t = typed.evaluate(at: 0)
            return t.isFinite && Swift.abs(t - v) <= 1e-6 * Swift.max(1, Swift.abs(v))
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
    public static func make(_ kind: QuizKind, level: Level, seed: UInt64, avoiding: Set<String> = []) -> QuizProblem {
        var s = seed
        var first: QuizProblem?
        for _ in 0..<60 {
            var r = SeededRandom(seed: s)
            if let q = candidate(kind, level: level, rng: &r, seed: s) {
                if !avoiding.contains(q.signature) { return q }
                if first == nil { first = q }
            }
            s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        }
        var fallback = SeededRandom(seed: seed)
        return first ?? candidate(.limit, level: .easy, rng: &fallback, seed: seed)!
    }

    static func candidate(_ kind: QuizKind, level: Level, rng r: inout SeededRandom, seed: UInt64) -> QuizProblem? {
        switch kind {
        case .chooseGraph: return chooseGraph(level, &r, seed)
        case .parameter: return parameter(level, &r, seed)
        case .area: return area(level, &r, seed)
        case .limit: return limit(level, &r, seed)
        case .tangent: return tangent(level, &r, seed)
        case .solutions: return solutions(level, &r, seed)
        case .signTable: return signTable(level, &r, seed)
        case .equation: return equation(level, &r, seed)
        }
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

    // MARK: Choose the graph

    static func chooseGraph(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        let baseLevel: Level = level == .bagrut ? .hard : level
        guard let f = SketchFactory.candidate(level: baseLevel, rng: &r, seed: seed), f.poles.isEmpty else { return nil }
        func fin(_ e: Expr) -> SketchProblem? {
            SketchFactory.finish(e, f.xMin, f.xMax, piBased: f.piBased, level: level, seed: seed)
        }
        let fx = f.function
        var q: QuizProblem
        var correct: SketchProblem
        var others: [SketchProblem?]
        switch r.int(0...3) {
        case 0:
            guard let d = fin(fx.derivative()) else { return nil }
            correct = d
            others = [fin(.neg(fx.derivative())), f, fin(fx.derivative().derivative())]
            q = blank(.chooseGraph, level, seed, "Here is the graph of f. Which graph is f′?", .number(0), topic: "choose:derivative")
            q.graph = f
            q.steps = [step("f′ is positive where f rises and negative where f falls."),
                       step("f′ = 0 exactly at f's peaks and dips."),
                       step("Where f is steepest (its inflection points) f′ has its own peaks and dips.")]
        case 1:
            correct = f
            others = [fin(.neg(fx)), fin(fx.derivative()), fin(fx.substitutingX(with: .neg(.x)))]
            q = blank(.chooseGraph, level, seed, "Which graph belongs to this function?", .number(0), topic: "choose:function")
            q.formulaLabel = "f(x) ="
            q.formula = fx
            q.steps = [step("Check a few easy values first, e.g. f(0) and the ends."),
                       step("Then the sign: where is f above or below the x-axis?"),
                       step("Then f′: where does it rise and fall?")]
        case 2:
            let negative = (0...60).contains { f.value(at: f.xMin + (f.xMax - f.xMin) * Double($0) / 60) < -0.05 * (f.yMax - f.yMin) }
            guard negative, let a = fin(.abs(fx)) else { return nil }
            correct = a
            others = [fin(.neg(.abs(fx))), f, fin(.p(fx, 2))]
            q = blank(.chooseGraph, level, seed, "Here is the graph of f. Which graph is |f(x)|?", .number(0), topic: "choose:absolute")
            q.graph = f
            q.steps = [step("|f| keeps the parts of f above the x-axis and flips the parts below it up."),
                       step("So |f| is never below the x-axis, and touches it where f crosses it.")]
        default:
            // f is shown; choose an antiderivative F (F′ = f).
            guard let fp = fin(fx.derivative()) else { return nil }
            correct = f
            others = [fin(.neg(fx)), fin(fx.derivative().derivative()), fin(.neg(fx.derivative()))]
            q = blank(.chooseGraph, level, seed, "Here is the graph of g. Which graph could be a function F with F′ = g?", .number(0), topic: "choose:antiderivative")
            q.graph = fp
            q.steps = [step("Where g > 0, F rises; where g < 0, F falls."),
                       step("Where g crosses the x-axis, F turns (peak or dip)."),
                       step("Where g has a peak or dip, F has an inflection point.")]
        }
        let distractors = others.compactMap { $0 }.filter { distinct($0, correct) }
        // The distractors must also differ from each other.
        var picked: [SketchProblem] = []
        for d in distractors where picked.allSatisfy({ distinct($0, d) }) { picked.append(d) }
        guard picked.count >= 3 else { return nil }
        q.answer = shuffled(QuizOption(graph: correct), picked.prefix(3).map { QuizOption(graph: $0) }, &r)
        return q
    }

    // MARK: Find the parameter

    static func parameter(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [2, 4, 8]
        case .medium: pool = [0, 6, 7, 3, 4]
        case .hard: pool = [1, 5, 9, 3, 7]
        case .bagrut: pool = [1, 5, 9, 7, 3]
        }
        func ask(_ text: String, _ cond: String, _ a: Double, _ steps: [String], _ topic: String) -> QuizProblem {
            var q = blank(.parameter, level, seed, "\(cond) Find a.", .number(a), topic: "parameter:\(topic)")
            q.formulaText = text
            q.steps = steps.map { step($0) } + [SolutionStep.result("a = \(num(a))")]
            return q
        }
        switch r.pick(pool) {
        case 0:
            let k = r.pick([1, 2, -1, 3, -2])
            let a = -1.5 * Double(k)
            return ask("f(x) = x³ + a·x²", "f has an extremum at x = \(k).", a,
                       ["f′(x) = 3x² + 2a·x", "At an extremum f′(\(k)) = 0:  3·\(k * k) + 2a·\(k) = 0", "a = −3·\(k)/2"], "cubic extremum")
        case 1:
            let p = r.pick([1, 2, -1]), k = r.pick([3, 4, -2, 5])
            guard k != p else { return nil }
            let a = Double(k * k - 2 * p * k)
            return ask("f(x) = (x² + a)/(x \(p > 0 ? "−" : "+") \(Swift.abs(p)))", "f has an extremum at x = \(k).", a,
                       ["Quotient rule: f′(x) = (x² − \(2 * p)x − a)/(x − \(p))²  (the numerator decides)",
                        "f′(\(k)) = 0:  \(k * k) − \(2 * p * k) − a = 0"], "rational extremum")
        case 2:
            let m = r.int(2...6), c = r.int(1...4), p = r.int(1...3)
            return ask("f(x) = (a·x + \(c))/(x − \(p))", "The graph of f has the horizontal asymptote y = \(m).", Double(m),
                       ["For x → ±∞ only the leading terms matter: f(x) → a·x/x = a", "So the asymptote is y = a."], "horizontal asymptote")
        case 3:
            let k = r.int(1...3)
            return ask("f(x) = x² + a·ln x", "f has an extremum at x = \(k).", Double(-2 * k * k),
                       ["f′(x) = 2x + a/x", "f′(\(k)) = 0:  \(2 * k) + a/\(k) = 0", "a = −\(2 * k * k)"], "ln extremum")
        case 4:
            let m = r.pick([2, 3, -1, -2, 4])
            return ask("f(x) = e^(a·x)", "The tangent to f at x = 0 has slope \(m).", Double(m),
                       ["f′(x) = a·e^(a·x), so f′(0) = a·e⁰ = a", "The slope at 0 is f′(0), so a = \(m)."], "tangent slope")
        case 5:
            let (label, value, exact): (String, Double, String) = r.pick([("π/6", 1 / 3.0.squareRoot(), "1/√3"), ("π/4", 1, "1"), ("π/3", 3.0.squareRoot(), "√3")])
            return ask("f(x) = a·sin x + cos x", "f has an extremum at x = \(label).", value,
                       ["f′(x) = a·cos x − sin x", "f′(\(label)) = 0:  a·cos(\(label)) = sin(\(label))", "a = tan(\(label)) = \(exact)"], "trig extremum")
        case 6:
            let k = r.int(1...4)
            return ask("f(x) = x/(x² + a)", "f has an extremum at x = \(k).", Double(k * k),
                       ["Quotient rule: f′(x) = (a − x²)/(x² + a)²", "f′(\(k)) = 0:  a − \(k * k) = 0"], "rational extremum")
        case 7:
            let k = r.int(-1...3)
            return ask("f(x) = (x − a)·eˣ", "f has a minimum at x = \(k).", Double(k + 1),
                       ["Product rule: f′(x) = eˣ + (x − a)eˣ = eˣ(x − a + 1)", "eˣ > 0, so f′(\(k)) = 0 means \(k) − a + 1 = 0"], "exp extremum")
        case 8:
            let x0 = r.pick([3, 4, 5]), y0 = r.int(3...6), k = r.int(1...2)
            let a = Double((y0 - k) * (x0 - 1))
            return ask("f(x) = a/(x − 1) + \(k)", "The graph of f passes through (\(x0), \(y0)).", a,
                       ["Substitute the point: \(y0) = a/(\(x0) − 1) + \(k)", "a/\(x0 - 1) = \(y0 - k)"], "point on graph")
        default:
            let k = r.pick([1, 2, -1, -2])
            return ask("f(x) = ln(x² + a·x + 5)", "f has an extremum at x = \(k).", Double(-2 * k),
                       ["Chain rule: f′(x) = (2x + a)/(x² + a·x + 5)", "f′(\(k)) = 0:  2·\(k) + a = 0"], "ln extremum")
        }
    }

    // MARK: Area

    static func area(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 2]
        case .medium: pool = [0, 1, 2, 3, 4]
        case .hard: pool = [3, 4, 5, 6, 8]
        case .bagrut: pool = [5, 6, 7, 8, 4]
        }
        let x = Expr.x
        var f: Expr, lo: Double, hi: Double, value: Double, steps: [String], g: Expr? = nil, piBased = false, topic: String
        var prompt: String
        switch r.pick(pool) {
        case 0:
            let c = r.pick([1, 4, 9]), rc = Int(Double(c).squareRoot())
            f = .sum([.n(c), .neg(.p(x, 2))]); lo = -Double(rc); hi = Double(rc)
            value = 4 * pow(Double(c), 1.5) / 3
            prompt = "Find the area between f and the x-axis."
            steps = ["f = 0 at x = ±\(rc), and f ≥ 0 between them.",
                     "Area = ∫ from −\(rc) to \(rc) of (\(c) − x²) dx = [\(c)x − x³/3] = \(num(value))"]
            topic = "area:parabola"
        case 1:
            let c = r.int(1...3), b = r.int(1...3)
            f = .sum([.p(x, 2), .n(c)]); lo = 0; hi = Double(b)
            value = pow(Double(b), 3) / 3 + Double(c * b)
            prompt = "Find the shaded area under f from x = 0 to x = \(b)."
            steps = ["Area = ∫ from 0 to \(b) of (x² + \(c)) dx = [x³/3 + \(c)x] from 0 to \(b) = \(num(value))"]
            topic = "area:polynomial"
        case 2:
            let m = r.int(1...3)
            f = .sin(.scaled(m, 1, x)); lo = 0; hi = Double.pi / Double(m); piBased = true
            value = 2 / Double(m)
            prompt = "Find the area between f and the x-axis on one arch."
            steps = ["The arch runs from 0 to π/\(m).", "Area = ∫ sin(\(m)x) dx = [−cos(\(m)x)/\(m)] = 2/\(m)"]
            topic = "area:trig"
        case 3:
            let k = r.int(1...2), n = r.int(2...4)
            f = .exp(.scaled(k, 1, x)); lo = 0; hi = log(Double(n)) / Double(k)
            value = Double(n - 1) / Double(k)
            prompt = "Find the shaded area under f from x = 0 to x = \(k == 1 ? "ln \(n)" : "(ln \(n))/\(k)")."
            steps = ["Area = [e^(\(k)x)/\(k)] = (e^(ln \(n)) − 1)/\(k) = (\(n) − 1)/\(k)"]
            topic = "area:exp"
        case 4:
            let p = r.int(1...2), q = r.int(1...3)
            f = .div(1, .sum([x, .n(p)])); lo = 0; hi = Double(q)
            value = log(Double(q + p) / Double(p))
            prompt = "Find the shaded area under f from x = 0 to x = \(q)."
            steps = ["∫ 1/(x + \(p)) dx = ln(x + \(p))", "Area = ln(\(q + p)) − ln(\(p)) = ln(\(frac(q + p, p)))"]
            topic = "area:ln"
        case 5:
            let c = r.int(1...3)
            f = .scaled(c, 1, x); g = .p(x, 2); lo = 0; hi = Double(c)
            value = pow(Double(c), 3) / 6
            prompt = "Find the area between y = \(c == 1 ? "" : "\(c)")x and y = x²."
            steps = ["They meet where x² = \(c)x: x = 0 and x = \(c).", "Area = ∫ from 0 to \(c) of (\(c)x − x²) dx = [\(c)x²/2 − x³/3] = \(num(value))"]
            topic = "area:between"
        case 6:
            let b = r.int(1...3)
            f = .div(.scaled(2, 1, x), .sum([.p(x, 2), 1])); lo = 0; hi = Double(b)
            value = log(Double(b * b + 1))
            prompt = "Find the shaded area under f from x = 0 to x = \(b)."
            steps = ["The top is the derivative of the bottom: ∫ 2x/(x² + 1) dx = ln(x² + 1)", "Area = ln(\(b * b + 1)) − ln 1 = ln \(b * b + 1)"]
            topic = "area:f′/f"
        case 7:
            f = .mul(x, .exp(.p(x, 2))); lo = 0; hi = 1
            value = (M_E - 1) / 2
            prompt = "Find the shaded area under f from x = 0 to x = 1."
            steps = ["Substitute u = x²: ∫ x·e^(x²) dx = e^(x²)/2", "Area = (e − 1)/2"]
            topic = "area:substitution"
        default:
            let c = r.int(1...2)
            f = .sub(.p(x, 3), .scaled(c * c, 1, x)); lo = -Double(c); hi = Double(c)
            value = pow(Double(c), 4) / 2
            prompt = "Find the total area between f and the x-axis from x = −\(c) to x = \(c)."
            steps = ["f = x(x − \(c))(x + \(c)) changes sign at 0, so split the integral.",
                     "f is odd: the two parts are equal. ∫ from −\(c) to 0 of (x³ − \(c * c)x) dx = \(num(value / 2))",
                     "Total area = 2·\(num(value / 2)) = \(num(value))"]
            topic = "area:sign change"
        }
        let w = hi - lo
        guard var graph = SketchFactory.finish(f, lo - 0.25 * w, hi + 0.25 * w, piBased: piBased, level: level, seed: seed) else { return nil }
        if let g {
            guard let gp = SketchFactory.finish(g, lo - 0.25 * w, hi + 0.25 * w, piBased: piBased, level: level, seed: seed) else { return nil }
            graph.yMin = Swift.min(graph.yMin, gp.yMin); graph.yMax = Swift.max(graph.yMax, gp.yMax)
            var q = blank(.area, level, seed, prompt, .number(value), topic: topic)
            q.graph = graph; q.lower = gp; q.shade = lo...hi
            q.formulaLabel = "f(x) ="; q.formula = f
            q.steps = steps.map { step($0) } + [.result("Area = \(num(value))")]
            return q
        }
        var q = blank(.area, level, seed, prompt, .number(value), topic: topic)
        q.graph = graph; q.shade = lo...hi
        q.formulaLabel = "f(x) ="; q.formula = f
        q.steps = steps.map { step($0) } + [.result("Area = \(num(value))")]
        return q
    }

    // MARK: Limits

    static func limit(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        let x = Expr.x
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 2, 4]
        case .medium: pool = [0, 1, 2, 3, 4]
        case .hard: pool = [1, 3, 4, 5, 6, 8]
        case .bagrut: pool = [1, 4, 5, 6, 7, 8]
        }
        func q(_ label: String, _ e: Expr, _ answer: QuizAnswer, _ steps: [String], _ topic: String) -> QuizProblem {
            var p = blank(.limit, level, seed, "Find the limit.", answer, topic: "limit:\(topic)")
            p.formulaLabel = label
            p.formula = e
            p.steps = steps.map { step($0) }
            return p
        }
        switch r.pick(pool) {
        case 0:
            let p = r.pick([1, 2, 3, -2])
            return q("lim x→\(p)", .div(.sum([.p(x, 2), .n(-p * p)]), .sum([x, .n(-p)])), .number(Double(2 * p)),
                     ["Substituting gives 0/0, so factor: x² − \(p * p) = (x − \(p))(x + \(p)).", "Cancel (x − \(p)): the limit is \(p) + \(p) = \(2 * p)."], "removable")
        case 1:
            let rr = r.pick([1, 2, -1, 3]), b = r.int(-3...3)
            let c = -rr * rr - b * rr
            return q("lim x→\(rr)", .div(Solver.polyExpr([1, b, c]), .sum([x, .n(-rr)])), .number(Double(2 * rr + b)),
                     ["x = \(rr) makes the top 0 too, so (x − \(rr)) is a factor of the top.", "Divide: (\(Solver.polyText([1, b, c])))/(x − \(rr)) = x + \(rr + b)", "Limit = \(2 * rr + b)"], "factor")
        case 2:
            let a = r.int(1...5), b = r.int(1...3)
            return q("lim x→∞", .div(.sum([.scaled(a, 1, .p(x, 2)), 1]), .sum([.scaled(b, 1, .p(x, 2)), .neg(x)])), .number(Double(a) / Double(b)),
                     ["Divide top and bottom by x²: (\(a) + 1/x²)/(\(b) − 1/x)", "As x → ∞ the small terms vanish: \(frac(a, b))"], "infinity")
        case 3:
            let k = r.int(2...5)
            return q("lim x→0", .div(.sin(.scaled(k, 1, x)), x), .number(Double(k)),
                     ["Use lim sin(u)/u = 1 with u = \(k)x:", "sin(\(k)x)/x = \(k)·sin(\(k)x)/(\(k)x) → \(k)"], "trig")
        case 4:
            let p = r.int(-2...3), c = r.pick([1, 2, -1, -3])
            let right = r.bool()
            let up = (c > 0) == right
            let options = ["+∞", "−∞", "0", "doesn't exist"].map { QuizOption(text: $0) }
            let correct = up ? 0 : 1
            return q("lim x→\(p)\(right ? "⁺" : "⁻")", .div(.n(c), .sum([x, .n(-p)])), .choice(options, correct: correct),
                     ["The bottom → 0 and the top → \(c): the fraction grows without bound.",
                      "x → \(p)\(right ? "⁺" : "⁻") means x − \(p) is a tiny \(right ? "positive" : "negative") number, and \(c) is \(c > 0 ? "positive" : "negative").",
                      "So the sign is \(up ? "+" : "−"): the limit is \(up ? "+∞" : "−∞")."], "one-sided")
        case 5:
            let k = r.int(1...3)
            return q("lim x→∞", .pow(.sum([1, .div(.n(k), x)]), x), .number(exp(Double(k))),
                     ["This is the special limit (1 + k/x)ˣ → eᵏ.", "With k = \(k): e\(Solver.sup(k))"], "e")
        case 6:
            let k = r.int(1...4)
            return q("lim x→0", .div(.sum([.exp(.scaled(k, 1, x)), .n(-1)]), x), .number(Double(k)),
                     ["0/0: this is the derivative of e^(\(k)x) at 0 (or L'Hôpital).", "(e^(\(k)x))′ = \(k)e^(\(k)x) → \(k)"], "exp")
        case 7:
            return q("lim x→0⁺", .mul(x, .ln(x)), .number(0),
                     ["x → 0 beats ln x → −∞ (write it as ln x/(1/x) and use L'Hôpital).", "The limit is 0."], "x ln x")
        default:
            let k = r.pick([2, 4, 6])
            return q("lim x→∞", .sub(.sqrt(.sum([.p(x, 2), .scaled(k, 1, x)])), x), .number(Double(k) / 2),
                     ["Multiply by the conjugate: (x² + \(k)x − x²)/(√(x² + \(k)x) + x) = \(k)x/(√(x² + \(k)x) + x)", "Divide by x: \(k)/(√(1 + \(k)/x) + 1) → \(k)/2"], "conjugate")
        }
    }

    // MARK: Tangent

    static func tangent(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        let x = Expr.x
        let pick: (Expr, Double, String)
        switch level {
        case .easy:
            let b = r.int(-3...3), c = r.int(-2...4), p = r.int(-1...2)
            pick = (Solver.polyExpr([1, b, c]), Double(p), "\(p)")
        case .medium:
            switch r.int(0...2) {
            case 0:
                let k = r.int(1...4), p = r.int(1...2)
                pick = (.sub(.p(x, 3), .scaled(k, 1, x)), Double(p), "\(p)")
            case 1: pick = (.exp(x), 0, "0")
            default: pick = (.ln(x), 1, "1")
            }
        default:
            switch r.int(0...3) {
            case 0: pick = (.mul(x, .exp(x)), 0, "0")
            case 1: pick = (.ln(.sum([.p(x, 2), 1])), 1, "1")
            case 2: pick = (.div(1, x), 2, "2")
            default: pick = (.sin(x), 0, "0")
            }
        }
        let (f, x0, label) = pick
        let m = f.derivative().evaluate(at: x0), y0 = f.evaluate(at: x0)
        let b = y0 - m * x0
        guard m.isFinite, b.isFinite else { return nil }
        let line = Expr.sum([.mul(.num(m), x), .num(b)]).simplified()
        var q = blank(.tangent, level, seed, "Find the tangent line to f at x = \(label). Type the right side of y = …", .function(line), topic: "tangent")
        q.formulaLabel = "f(x) ="
        q.formula = f
        q.steps = [step("Point: f(\(label)) = \(num(y0))"),
                   step("Slope: f′(x) is the derivative, f′(\(label)) = \(num(m))"),
                   step("y − \(num(y0)) = \(num(m))(x − \(label))"),
                   .result("y = \(num(m))x \(b < 0 ? "−" : "+") \(num(Swift.abs(b)))")]
        return q
    }

    // MARK: How many solutions

    static func solutions(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        guard let f = SketchFactory.candidate(level: level == .bagrut ? .hard : level, rng: &r, seed: seed), f.poles.isEmpty else { return nil }
        let turns = GraphSteps.keyPoints(f, inflections: false).filter { $0.kinds.contains(.peak) || $0.kinds.contains(.dip) }
        guard turns.count >= 1 else { return nil }
        let span = f.yMax - f.yMin
        // A level k that isn't (almost) at a peak or dip.
        var k = f.yMin + span * r.double(0.2...0.8)
        k = (k * 4).rounded() / 4
        guard turns.allSatisfy({ Swift.abs(f.value(at: $0.x) - k) > 0.06 * span }),
              Swift.abs(f.value(at: f.xMin) - k) > 0.04 * span, Swift.abs(f.value(at: f.xMax) - k) > 0.04 * span else { return nil }
        let count = GraphSteps.roots(of: .sub(f.function, .num(k)), in: f.xMin...f.xMax).count
        guard count <= 4 else { return nil }
        let showGraph = level == .easy || level == .medium
        let options = (0...4).map { QuizOption(text: "\($0)") }
        var q = blank(.solutions, level, seed,
                      "How many solutions does f(x) = \(num(k)) have for \(f.xLabel(f.xMin)) ≤ x ≤ \(f.xLabel(f.xMax))?",
                      .choice(options, correct: count), topic: "solutions")
        q.formulaLabel = "f(x) ="
        q.formula = f.function
        if showGraph { q.graph = f; q.level_k = k }
        q.steps = [step("Sketch f (peaks, dips, ends) and draw the line y = \(num(k))."),
                   step("Each crossing is one solution.")]
            + turns.map { step("\($0.kinds.contains(.peak) ? "Peak" : "Dip") at x ≈ \(num($0.x)): f ≈ \(num(f.value(at: $0.x)))", depth: 1) }
            + [.result("\(count) solution\(count == 1 ? "" : "s")")]
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
        // Exact labels from the algebra where available.
        let exact = GraphAlgebra.investigate(f)?.d1?.solve.roots ?? []
        func label(_ v: Double) -> String {
            if let e = exact.first(where: { Swift.abs($0.x - v) < 1e-6 }) { return GraphSteps.bare(e.label) }
            if let i = f.poles.firstIndex(where: { Swift.abs($0 - v) < 1e-9 }), let l = f.asymptoteLabels?[safe: i] { return l }
            return GraphSteps.bare(Solver(a: a, b: b, piBased: f.piBased).xLabel(v, exact: true))
        }
        let pts = [a] + cuts + [b]
        var intervals: [String] = [], signs: [Bool] = []
        for (l, rr) in zip(pts, pts.dropFirst()) {
            let v = d1.evaluate(at: (l + rr) / 2)
            guard v.isFinite else { continue }
            intervals.append("\(l == a ? f.xLabel(a) : label(l)) < x < \(rr == b ? f.xLabel(b) : label(rr))")
            signs.append(v > 0)
        }
        guard intervals.count >= 2 else { return nil }
        var q = blank(.signTable, level, seed, "Tap + or − for the sign of f′(x) in each interval.",
                      .signs(intervals: intervals, positive: signs), topic: "signs")
        q.formulaLabel = "f(x) ="
        q.formula = f.function
        q.steps = GraphSteps.steps(for: f).filter { $0.text.contains("f′(") && $0.text.contains("<") }
        if q.steps.isEmpty { q.steps = [step("Differentiate, find where f′ = 0, and test one point in each interval.")] }
        return q
    }

    // MARK: Equations

    static func equation(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64) -> QuizProblem? {
        func ask(_ eq: String, _ correct: String, _ wrong: [String], _ steps: [String], _ topic: String) -> QuizProblem {
            var q = blank(.equation, level, seed, "Solve: \(eq)", .number(0), topic: "equation:\(topic)")
            q.answer = shuffled(QuizOption(text: correct), wrong.map { QuizOption(text: $0) }, &r)
            q.steps = steps.map { step($0) }
            return q
        }
        let pool: [Int] = level == .easy ? [1, 1, 2] : (level == .medium ? [0, 1, 2] : [0, 2, 3, 1])
        switch r.pick(pool) {
        case 0:
            let p = r.int(1...3), q0 = p + r.int(1...3)
            let lp = p == 1 ? "0" : "ln \(p)"
            return ask("e^(2x) − \(p + q0)eˣ + \(p * q0) = 0", "x = \(lp),  x = ln \(q0)",
                       ["x = \(p),  x = \(q0)", "x = ln \(q0) only", "x = ln \(p + q0)"],
                       ["Substitute t = eˣ: t² − \(p + q0)t + \(p * q0) = 0 = (t − \(p))(t − \(q0))", "eˣ = \(p) or eˣ = \(q0)", "x = \(lp) or x = ln \(q0)"], "e quadratic")
        case 1:
            let options: [(String, String, [String], String)] = [
                ("2 sin x = 1", "x = π/6,  x = 5π/6", ["x = π/6 only", "x = π/3,  x = 2π/3", "x = π/6,  x = 7π/6"], "sin x = 1/2"),
                ("2 cos x = 1", "x = π/3,  x = 5π/3", ["x = π/3 only", "x = π/6,  x = 11π/6", "x = π/3,  x = 2π/3"], "cos x = 1/2"),
                ("2 sin x = −1", "x = 7π/6,  x = 11π/6", ["x = −π/6", "x = 5π/6,  x = 7π/6", "x = 4π/3,  x = 5π/3"], "sin x = −1/2"),
                ("tan x = 1", "x = π/4,  x = 5π/4", ["x = π/4 only", "x = π/4,  x = 3π/4", "x = π/4,  x = 7π/4"], "tan x = 1")]
            let (eq, right, wrong, key) = r.pick(options)
            return ask("\(eq)   for 0 ≤ x ≤ 2π", right, wrong,
                       ["\(key)", "Find the basic angle, then every angle in [0, 2π] with the same value (use the unit circle)."], "trig")
        case 2:
            let k = r.int(1...3), root = k + r.int(1...3)
            let m = root * (root - k)
            return ask("ln x + ln(x − \(k)) = ln \(m)", "x = \(root)",
                       ["x = \(root),  x = \(k - root)", "x = \(m)", "x = \(root + k)"],
                       ["Domain: x > \(k).", "ln(x(x − \(k))) = ln \(m)  ⇒  x² − \(k)x − \(m) = 0  ⇒  x = \(root) or x = \(k - root)",
                        "x = \(k - root) is outside the domain, so only x = \(root)."], "ln")
        default:
            let p = r.int(1...2), q0 = p + r.int(1...2)
            return ask("(ln x)² − \(p + q0)·ln x + \(p * q0) = 0", "x = e\(Solver.sup(p)),  x = e\(Solver.sup(q0))",
                       ["x = \(p),  x = \(q0)", "x = ln \(p),  x = ln \(q0)", "x = e\(Solver.sup(p + q0))"],
                       ["Substitute u = ln x: u² − \(p + q0)u + \(p * q0) = 0  ⇒  u = \(p) or u = \(q0)", "ln x = \(p) or ln x = \(q0)  ⇒  x = e\(Solver.sup(p)) or x = e\(Solver.sup(q0))"], "ln quadratic")
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
