import Foundation

// Bagrut 572, chapter 1: vectors in space — lengths, the dot product and
// angles, lines (meeting, parallel, skew), planes, angles and distances.

extension QuizFactory {
    typealias V3 = [Int]

    static func dot(_ u: V3, _ v: V3) -> Int { u[0] * v[0] + u[1] * v[1] + u[2] * v[2] }
    static func cross(_ u: V3, _ v: V3) -> V3 { [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]] }
    static func minus(_ u: V3, _ v: V3) -> V3 { [u[0] - v[0], u[1] - v[1], u[2] - v[2]] }
    static func plus(_ u: V3, _ v: V3, _ k: Int = 1) -> V3 { [u[0] + k * v[0], u[1] + k * v[1], u[2] + k * v[2]] }
    static func norm2(_ u: V3) -> Int { dot(u, u) }
    static func vt(_ u: V3) -> String { "(\(u.map(iv).joined(separator: ", ")))" }
    static func d3(_ u: V3) -> [Double] { u.map(Double.init) }

    /// Divided by the gcd of its entries, first non-zero entry positive.
    static func reduced(_ u: V3) -> V3 {
        let g = u.reduce(0) { gcd($0, Swift.abs($1)) }
        guard g > 0 else { return u }
        var v = u.map { $0 / g }
        if let first = v.first(where: { $0 != 0 }), first < 0 { v = v.map { -$0 } }
        return v
    }

    /// "2x − y + 3z = 5".
    static func planeText(_ n: V3, _ d: Int) -> String {
        var out = ""
        for (c, name) in zip(n, ["x", "y", "z"]) where c != 0 {
            let body = (Swift.abs(c) == 1 ? "" : "\(Swift.abs(c))") + name
            out += out.isEmpty ? (c < 0 ? "−" : "") + body : (c < 0 ? " − " : " + ") + body
        }
        return out + " = \(iv(d))"
    }

    static func lineText(_ p: V3, _ u: V3, _ t: String = "t") -> String { "\(vt(p)) + \(t)\(vt(u))" }

    static func randomVector(_ r: inout SeededRandom, _ range: ClosedRange<Int> = -4...4) -> V3 {
        var v: V3 = [0, 0, 0]
        while v == [0, 0, 0] { v = [r.int(range), r.int(range), r.int(range)] }
        return v
    }

    /// A drawing in space: axes, named points, segments between them.
    static func spaceFigure(_ pts: [(V3, String)], segments: [(Int, Int, String?, GeoFigure.Style)] = [], highlight: Set<Int> = []) -> GeoFigure {
        var f = GeoFigure()
        f.axes3D(holding: pts.map { d3($0.0) })
        let ids = pts.enumerated().map { i, p in f.point3D(d3(p.0), p.1, highlight: highlight.contains(i)) }
        for (a, b, label, style) in segments { f.segment(ids[a], ids[b], label, style) }
        return f
    }

    static func vectors(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 2, 9]
        case .medium: pool = [1, 2, 3, 5, 9]
        case .hard: pool = [3, 4, 5, 6, 7, 8, 10]
        case .bagrut: pool = [4, 6, 7, 8, 10, 3]
        }
        let twoDP = "Give the answer in degrees to 2 decimal places."
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], _ fig: GeoFigure, tol: Double? = nil) -> QuizProblem {
            var q = number(.vectors, level, seed, prompt, value, topic: "vectors:\(topic)", steps: steps, tolerance: tol)
            q.figure = fig
            return q
        }

        let which = choose(pool, cases, &r)
        switch which {
        case 0:
            // The length of AB.
            let A = randomVector(&r, -3...5), B = randomVector(&r, -3...5)
            guard A != B else { return nil }
            let ab = minus(B, A)
            let e = exact(1, rad: norm2(ab), den: 1)
            return ask("A = \(vt(A)) and B = \(vt(B)). Find the length of AB.", e.value, "length",
                       [H("The vector AB"), S("AB = B − A = \(vt(ab))"),
                        H("Its length"), S("|AB| = √(\(ab.map { "(\(iv($0)))²" }.joined(separator: " + "))) = √\(norm2(ab))"), R("|AB| = \(e.text)")],
                       spaceFigure([(A, "A"), (B, "B")], segments: [(0, 1, "?", .highlight)]))
        case 1:
            // The angle between two vectors.
            let u = randomVector(&r, -3...3), v = randomVector(&r, -3...3)
            let uv = dot(u, v), nu = norm2(u), nv = norm2(v)
            let c = Double(uv) / (Double(nu) * Double(nv)).squareRoot()
            guard Swift.abs(c) < 0.999 else { return nil }
            let angle = acos(c) * 180 / .pi
            return ask("u = \(vt(u)) and v = \(vt(v)). Find the angle between u and v. \(twoDP)", angle, "angle between vectors",
                       [H("Dot product"), S("u·v = \(zip(u, v).map { "\(pv($0.0))·\(pv($0.1))" }.joined(separator: " + ")) = \(iv(uv))"),
                        H("Lengths"), S("|u| = √\(nu),  |v| = √\(nv)"),
                        H("The angle"), S("cos θ = u·v / (|u||v|) = \(iv(uv))/√\(nu * nv) ≈ \(dp(c, 4))"),
                        S(uv < 0 ? "cos θ < 0, so the angle is obtuse." : "cos θ > 0, so the angle is acute."), R("θ ≈ \(dp(angle))°")],
                       spaceFigure([([0, 0, 0], ""), (u, "u"), (v, "v")], segments: [(0, 1, nil, .arrow), (0, 2, nil, .arrow)]), tol: 0.006)
        case 2:
            // Perpendicular: find t.
            let u = randomVector(&r, -4...4), v = randomVector(&r, -4...4)
            let tPos = r.int(0...2)
            // Put the unknown t in place tPos of u.
            var shown = u.map(iv)
            shown[tPos] = "t"
            var known = u
            known[tPos] = 0
            let partial = dot(known, v)
            guard v[tPos] != 0 else { return nil }
            return ask("u = (\(shown.joined(separator: ", "))) and v = \(vt(v)) are perpendicular. Find t.", -Double(partial) / Double(v[tPos]), "perpendicular",
                       [H("Perpendicular means u·v = 0"),
                        S("u·v = \(shown.enumerated().map { i, s in "\(s.hasPrefix("−") ? "(\(s))" : s)·\(pv(v[i]))" }.joined(separator: " + "))"),
                        S("= \(iv(partial))\(signedTerm(v[tPos], "t")) = 0", 2), R("t = \(fr(-partial, v[tPos]))")],
                       spaceFigure([([0, 0, 0], ""), (u, "u"), (v, "v")], segments: [(0, 1, nil, .arrow), (0, 2, nil, .arrow)]))
        case 3, 4:
            // Two lines: meet, parallel, skew or the same.
            let u = randomVector(&r, -3...3)
            let kind = which == 4 ? 0 : r.int(0...3)
            let P = randomVector(&r, -4...4)
            var v = randomVector(&r, -3...3)
            var A = P, B = P
            switch kind {
            case 0:
                guard cross(u, v) != [0, 0, 0] else { return nil }
                A = minus(P, u.map { $0 * r.nonZero(-2...2) })
                B = minus(P, v.map { $0 * r.nonZero(-2...2) })
            case 1:
                v = u.map { $0 * r.pick([2, -1, -2, 3]) }
                A = P
                B = plus(P, randomVector(&r, -3...3))
                guard cross(minus(B, A), u) != [0, 0, 0] else { return nil }
            case 2:
                guard cross(u, v) != [0, 0, 0] else { return nil }
                A = P
                B = plus(P, randomVector(&r, -3...3))
                // Skew when AB, u and v are not in one plane.
                guard dot(minus(B, A), cross(u, v)) != 0 else { return nil }
            default:
                v = u.map { $0 * r.pick([2, -1, -2, 3]) }
                A = P
                B = plus(P, u, r.nonZero(-2...2))
            }
            let l1 = lineText(A, u, "t"), l2 = lineText(B, v, "s")
            let parallel = cross(u, v) == [0, 0, 0]
            var steps = [H("Are the directions parallel?"),
                         S(parallel ? "\(vt(v)) = \(fr(v.first { $0 != 0 }!, u[v.firstIndex { $0 != 0 }!]))·\(vt(u)): the directions are parallel."
                                    : "\(vt(u)) and \(vt(v)) are not multiples of each other: the directions are not parallel.")]
            var meet: V3? = nil
            if parallel {
                steps += [H("Is B on the first line?"), S("B − A = \(vt(minus(B, A)))"),
                          S(kind == 3 ? "It is a multiple of \(vt(u)), so B is on the first line." : "It is not a multiple of \(vt(u)), so B is not on the first line.")]
            } else {
                // Solve t·u − s·v = B − A on two coordinates.
                let w = minus(B, A)
                var solved = false
                for (i, j) in [(0, 1), (0, 2), (1, 2)] {
                    let det = u[i] * (-v[j]) - (-v[i]) * u[j]
                    guard det != 0 else { continue }
                    let tn = w[i] * (-v[j]) - (-v[i]) * w[j], sn = u[i] * w[j] - u[j] * w[i]
                    let k = 3 - i - j
                    let lhs = Double(tn) / Double(det) * Double(u[k]) - Double(sn) / Double(det) * Double(v[k])
                    let names = ["x", "y", "z"]
                    steps += [H("Equate the points"), S("\(vt(A)) + t\(vt(u)) = \(vt(B)) + s\(vt(v))"),
                              S("\(names[i]):  \(iv(A[i]))\(signedTerm(u[i], "t")) = \(iv(B[i]))\(signedTerm(v[i], "s"))", 2),
                              S("\(names[j]):  \(iv(A[j]))\(signedTerm(u[j], "t")) = \(iv(B[j]))\(signedTerm(v[j], "s"))", 2),
                              S("Solving: t = \(fr(tn, det)),  s = \(fr(sn, det))"),
                              H("Check the \(names[k]) equation")]
                    let ok = Swift.abs(lhs - Double(w[k])) < 1e-9
                    steps.append(S(ok ? "\(names[k]) agrees, so the lines meet." : "\(names[k]) gives \(dec(Double(A[k]) + Double(tn) / Double(det) * Double(u[k]))) on the first line but \(dec(Double(B[k]) + Double(sn) / Double(det) * Double(v[k]))) on the second: they don't meet."))
                    if ok, tn % det == 0 { meet = plus(A, u, tn / det) }
                    solved = true
                    break
                }
                guard solved else { return nil }
            }
            let fig = spaceFigure([(A, "A"), (plus(A, u), ""), (B, "B"), (plus(B, v), "")], segments: [(0, 1, nil, .arrow), (2, 3, nil, .arrow)])
            if which == 4 || kind == 0 && r.bool() && level != .easy {
                guard let m = meet else { return nil }
                let c = r.int(0...2)
                return ask("The lines  \(l1)  and  \(l2)  meet at a point. Find its \(["x", "y", "z"][c])-coordinate.", Double(m[c]), "lines meet",
                           steps + [H("The meeting point"), S("Put t into the first line: \(vt(m))"), R("\(["x", "y", "z"][c]) = \(iv(m[c]))")], fig)
            }
            let answers = ["They meet at one point", "They are parallel", "They are skew", "They are the same line"]
            var q = blank(.vectors, level, seed, "How are the lines  \(l1)  and  \(l2)  placed?", .number(0), topic: "vectors:two lines")
            q.answer = .choice(answers.map { QuizOption(text: $0) }, correct: kind)
            q.steps = steps + [R(answers[kind])]
            q.figure = fig
            return q
        case 5:
            // A point on the plane through A, B, C.
            let A = randomVector(&r, -3...3), B = randomVector(&r, -3...3), C = randomVector(&r, -3...3)
            let n = reduced(cross(minus(B, A), minus(C, A)))
            guard n != [0, 0, 0], n[2] != 0 else { return nil }
            let d = dot(n, A)
            let x = r.int(-3...3), y = r.int(-3...3)
            let rest = n[0] * x + n[1] * y
            return ask("Find k so that D(\(iv(x)), \(iv(y)), k) is on the plane through A\(vt(A)), B\(vt(B)) and C\(vt(C)).", Double(d - rest) / Double(n[2]), "plane",
                       [H("Two vectors in the plane"), S("AB = \(vt(minus(B, A))),  AC = \(vt(minus(C, A)))"),
                        H("A normal"), S("n = AB × AC = \(vt(cross(minus(B, A), minus(C, A))))\(n == cross(minus(B, A), minus(C, A)) ? "" : ",  or simply \(vt(n))")"),
                        H("The plane's equation"), S("n·(X − A) = 0:  \(planeText(n, d))"),
                        H("Put D in"), S("\(iv(rest))\(signedTerm(n[2], "k")) = \(iv(d))"), R("k = \(fr(d - rest, n[2]))")],
                       spaceFigure([(A, "A"), (B, "B"), (C, "C")], segments: [(0, 1, nil, .solid), (1, 2, nil, .solid), (2, 0, nil, .solid)]))
        case 6:
            // A line meets a plane.
            let n = randomVector(&r, -3...3), u = randomVector(&r, -3...3)
            guard dot(n, u) != 0 else { return nil }
            let A = randomVector(&r, -3...3), t0 = r.nonZero(-3...3)
            let P = plus(A, u, t0)
            let d = dot(n, P)
            let c = r.int(0...2)
            return ask("The line  \(lineText(A, u))  meets the plane  \(planeText(n, d)). Find the \(["x", "y", "z"][c])-coordinate of the meeting point.",
                       Double(P[c]), "line meets plane",
                       [H("A general point of the line"), S("(\(iv(A[0]))\(signedTerm(u[0], "t")),  \(iv(A[1]))\(signedTerm(u[1], "t")),  \(iv(A[2]))\(signedTerm(u[2], "t")))"),
                        H("Put it into the plane"), S("\(iv(dot(n, A)))\(signedTerm(dot(n, u), "t")) = \(iv(d))  ⇒  t = \(iv(t0))"),
                        H("The point"), S("\(vt(P))"), R("\(["x", "y", "z"][c]) = \(iv(P[c]))")],
                       spaceFigure([(A, "A"), (P, "P")], segments: [(0, 1, nil, .arrow)], highlight: [1]))
        case 7:
            // The angle between a line and a plane.
            let n = randomVector(&r, -3...3), u = randomVector(&r, -3...3)
            let s = Double(Swift.abs(dot(n, u))) / (Double(norm2(n)) * Double(norm2(u))).squareRoot()
            guard s > 0.02, s < 0.999 else { return nil }
            let angle = asin(s) * 180 / .pi
            let d = r.int(-6...6)
            return ask("Find the angle between the line  \(lineText([r.int(-3...3), r.int(-3...3), r.int(-3...3)], u))  and the plane  \(planeText(n, d)). \(twoDP)",
                       angle, "line and plane",
                       [H("Direction and normal"), S("Line direction u = \(vt(u)), plane normal n = \(vt(n))"),
                        H("The line makes 90° − (angle with the normal)"), S("sin θ = |u·n| / (|u||n|) = |\(iv(dot(n, u)))|/√\(norm2(n) * norm2(u)) ≈ \(dp(s, 4))"),
                        R("θ ≈ \(dp(angle))°")],
                       spaceFigure([([0, 0, 0], ""), (u, "u"), (n, "n")], segments: [(0, 1, nil, .arrow), (0, 2, nil, .dashed)]), tol: 0.006)
        case 8:
            // The angle between two planes.
            let n1 = randomVector(&r, -3...3), n2 = randomVector(&r, -3...3)
            let c = Double(Swift.abs(dot(n1, n2))) / (Double(norm2(n1)) * Double(norm2(n2))).squareRoot()
            guard c > 0.02, c < 0.999 else { return nil }
            let angle = acos(c) * 180 / .pi
            return ask("Find the (acute) angle between the planes  \(planeText(n1, r.int(-5...5)))  and  \(planeText(n2, r.int(-5...5))). \(twoDP)", angle, "two planes",
                       [H("The normals"), S("n₁ = \(vt(n1)),  n₂ = \(vt(n2))"),
                        H("Angle between the normals"), S("cos θ = |n₁·n₂| / (|n₁||n₂|) = |\(iv(dot(n1, n2)))|/√\(norm2(n1) * norm2(n2)) ≈ \(dp(c, 4))"),
                        R("θ ≈ \(dp(angle))°")],
                       spaceFigure([([0, 0, 0], ""), (n1, "n₁"), (n2, "n₂")], segments: [(0, 1, nil, .arrow), (0, 2, nil, .arrow)]), tol: 0.006)
        case 9:
            // Distance from a point to a plane.
            let n = randomVector(&r, -3...3), P = randomVector(&r, -4...4), d = r.int(-8...8)
            let top = Swift.abs(dot(n, P) - d)
            guard top != 0 else { return nil }
            let e = exact(top, rad: norm2(n), den: norm2(n))
            return ask("Find the distance from P\(vt(P)) to the plane  \(planeText(n, d)).", e.value, "point to plane",
                       [H("Distance formula"), S("dist = |ax₀ + by₀ + cz₀ − d| / √(a² + b² + c²)"),
                        S("= |\(iv(dot(n, P))) − \(pv(d))| / √\(norm2(n)) = \(top)/√\(norm2(n))"), R("dist = \(e.text)")],
                       spaceFigure([(P, "P")], highlight: [0]))
        default:
            // Distance between parallel planes.
            let n = reduced(randomVector(&r, -3...3)), d1 = r.int(-8...8), e2 = r.int(-8...8), k = r.pick([2, 3, -1, -2])
            guard d1 != e2 else { return nil }
            let e = exact(Swift.abs(d1 - e2), rad: norm2(n), den: norm2(n))
            return ask("Find the distance between the parallel planes  \(planeText(n, d1))  and  \(planeText(n.map { $0 * k }, e2 * k)).", e.value, "parallel planes",
                       [H("Same normal"), S("Divide the second equation by \(iv(k)): \(planeText(n, e2))"),
                        H("Distance formula"), S("dist = |d₁ − d₂| / |n| = |\(iv(d1)) − \(pv(e2))| / √\(norm2(n))"), R("dist = \(e.text)")],
                       spaceFigure([([0, 0, 0], ""), (n, "n")], segments: [(0, 1, nil, .arrow)]))
        }
    }
}
