import Foundation

// Bagrut 571, chapter 3: plane geometry (angles in a circle, chords and
// tangents, similar triangles, bisectors) and trigonometric identities.
// Every question has a drawing built to scale where the numbers allow it.

extension QuizFactory {
    static func onCircle(_ deg: Double, r: Double = 1, cx: Double = 0, cy: Double = 0) -> (Double, Double) {
        (cx + r * cos(deg * .pi / 180), cy + r * sin(deg * .pi / 180))
    }

    // MARK: - Geometry

    static func geometry(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 5, 3]
        case .medium: pool = [0, 1, 2, 3, 5, 7]
        case .hard: pool = [2, 4, 6, 7, 8, 9]
        case .bagrut: pool = [4, 6, 8, 9, 2]
        }
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep], _ fig: GeoFigure) -> QuizProblem {
            var q = number(.geometry, level, seed, prompt, value, topic: "geometry:\(topic)", steps: steps)
            q.figure = fig
            return q
        }

        switch choose(pool, cases, &r) {
        case 0:
            // Inscribed and central angles on the same arc.
            let al = r.pick([25, 30, 35, 40, 42, 48, 50, 55, 62, 65, 70, 75])
            let what = r.int(0...2)
            var f = GeoFigure()
            f.circle(0, 0, 1)
            let o = f.point(0, 0, "O")
            let (ax, ay) = onCircle(-90 - Double(al)), (bx, by) = onCircle(-90 + Double(al)), (cx, cy) = onCircle(90 + Double(r.int(-30...30)))
            let A = f.point(ax, ay, "A"), B = f.point(bx, by, "B"), C = f.point(cx, cy, "C")
            f.segment(C, A); f.segment(C, B); f.segment(o, A, nil, .dashed); f.segment(o, B, nil, .dashed)
            let prompt: String, value: Int, steps: [SolutionStep]
            switch what {
            case 0:
                f.angle(C, A, B, "\(al)°"); f.angle(o, A, B, "?")
                prompt = "A, B and C are on a circle with centre O, and ∠ACB = \(al)°. Find the central angle ∠AOB."
                value = 2 * al
                steps = [H("Same arc AB"), S("∠ACB is an inscribed angle and ∠AOB is the central angle on the same arc AB."),
                         S("A central angle is twice the inscribed angle on the same arc."), R("∠AOB = 2·\(al)° = \(2 * al)°")]
            case 1:
                f.angle(o, A, B, "\(2 * al)°"); f.angle(C, A, B, "?")
                prompt = "A, B and C are on a circle with centre O, and the central angle ∠AOB = \(2 * al)°. Find ∠ACB."
                value = al
                steps = [H("Same arc AB"), S("∠ACB is inscribed on arc AB; ∠AOB is the central angle on it."),
                         S("Inscribed angle = half the central angle."), R("∠ACB = \(2 * al)°/2 = \(al)°")]
            default:
                f.segment(A, B)
                f.angle(C, A, B, "\(al)°"); f.angle(A, o, B, "?")
                prompt = "A, B and C are on a circle with centre O, and ∠ACB = \(al)°. Find ∠OAB."
                value = 90 - al
                steps = [H("The central angle"), S("∠AOB = 2·∠ACB = \(2 * al)° (central and inscribed on arc AB)"),
                         H("Triangle AOB is isosceles"), S("OA = OB (radii), so ∠OAB = ∠OBA."),
                         S("∠OAB = (180° − \(2 * al)°)/2"), R("∠OAB = \(90 - al)°")]
            }
            return ask(prompt, Double(value), "inscribed angle", steps, f)
        case 1:
            // Cyclic quadrilateral: arcs 2p, 2q, 2r, 2s.
            var arcs: [Int] = []
            for _ in 0..<40 {
                let p = r.int(5...12) * 5, q = r.int(5...12) * 5, t = r.int(5...12) * 5
                let s = 180 - p - q - t
                if s >= 25 && s <= 65 { arcs = [p, q, t, s]; break }
            }
            guard arcs.count == 4 else { return nil }
            let (p, q, t, s) = (arcs[0], arcs[1], arcs[2], arcs[3])
            let angA = q + t, angB = t + s, angC = s + p, angD = p + q
            var f = GeoFigure()
            f.circle(0, 0, 1)
            var at = 200.0
            var ids: [Int] = []
            for (name, arc) in zip(["A", "B", "C", "D"], [p, q, t, s]) {
                let (x, y) = onCircle(at)
                ids.append(f.point(x, y, name))
                at += 2 * Double(arc)
            }
            f.polygon(ids)
            let exterior = r.bool()
            f.angle(ids[0], ids[3], ids[1], "\(angA)°")
            f.angle(ids[1], ids[0], ids[2], "\(angB)°")
            if exterior {
                let b = f.points[ids[1]], c = f.points[ids[2]]
                let ext = f.point(c.x + (c.x - b.x) * 0.6, c.y + (c.y - b.y) * 0.6, "", dot: false)
                f.segment(ids[2], ext, nil, .dashed)
                f.angle(ids[2], ext, ids[3], "?")
                return ask("ABCD is inscribed in a circle, with ∠A = \(angA)° and ∠B = \(angB)°. Find the exterior angle at C (between BC extended past C and CD).",
                           Double(angA), "cyclic quadrilateral",
                           [H("Opposite angles"), S("In a cyclic quadrilateral opposite angles add up to 180°: ∠C = 180° − \(angA)° = \(angC)°"),
                            H("The exterior angle"), S("It sits next to ∠C on a straight line: 180° − \(angC)°"),
                            R("Exterior angle at C = \(angA)° (equal to the opposite inner angle ∠A)")], f)
            }
            let askC = r.bool()
            f.angle(ids[askC ? 2 : 3], ids[askC ? 1 : 2], ids[askC ? 3 : 0], "?")
            return ask("ABCD is inscribed in a circle, with ∠A = \(angA)° and ∠B = \(angB)°. Find ∠\(askC ? "C" : "D").", Double(askC ? angC : angD),
                       "cyclic quadrilateral",
                       [H("Opposite angles of a cyclic quadrilateral"), S("They add up to 180° (together they stand on the whole circle)."),
                        R(askC ? "∠C = 180° − \(angA)° = \(angC)°" : "∠D = 180° − \(angB)° = \(angD)°")], f)
        case 2:
            // Tangent–chord angle.
            let al = r.pick([30, 35, 40, 50, 55, 65, 70, 72])
            var f = GeoFigure()
            f.circle(0, 0, 1)
            let o = f.point(0, 0, "O", dot: true)
            let A = f.point(0, -1, "A")
            let t1 = f.point(-1.7, -1, "", dot: false), t2 = f.point(1.7, -1, "T", dot: false)
            f.segment(t1, t2, nil, .highlight)
            let (bx, by) = onCircle(-90 + 2 * Double(al))
            let B = f.point(bx, by, "B")
            let (cx, cy) = onCircle(140 + Double(r.int(0...30)))
            let C = f.point(cx, cy, "C")
            f.segment(A, B); f.segment(C, A); f.segment(C, B)
            f.angle(A, t2, B, "\(al)°")
            let central = r.bool() && level != .easy
            if central {
                f.segment(o, A, nil, .dashed); f.segment(o, B, nil, .dashed)
                f.angle(o, A, B, "?")
            } else {
                f.angle(C, A, B, "?")
            }
            return ask("AT is tangent to the circle at A, and ∠TAB = \(al)° where AB is a chord. Find \(central ? "the central angle ∠AOB" : "the inscribed angle ∠ACB").",
                       Double(central ? 2 * al : al), "tangent and chord",
                       [H("Tangent–chord angle"), S("The angle between a tangent and a chord equals the inscribed angle on the other side of the chord."),
                        S("∠ACB = ∠TAB = \(al)°")]
                       + (central ? [H("Central angle"), S("∠AOB = 2·∠ACB"), R("∠AOB = \(2 * al)°")] : [R("∠ACB = \(al)°")]), f)
        case 3:
            // Two chords crossing: AE·EB = CE·ED.
            let ae = r.int(2...9), eb = r.int(2...9), ce = r.int(2...9)
            guard ae * eb != ce * ce else { return nil }
            var f = GeoFigure()
            f.circle(0, 0, 1)
            let ex = 0.22, ey = -0.12
            func chord(_ deg: Double) -> ((Double, Double), (Double, Double)) {
                let dx = cos(deg * .pi / 180), dy = sin(deg * .pi / 180)
                let b = ex * dx + ey * dy, c = ex * ex + ey * ey - 1
                let t1 = -b + (b * b - c).squareRoot(), t2 = -b - (b * b - c).squareRoot()
                return ((ex + t2 * dx, ey + t2 * dy), (ex + t1 * dx, ey + t1 * dy))
            }
            let (a1, b1) = chord(15), (c1, d1) = chord(110)
            let A = f.point(a1.0, a1.1, "A"), B = f.point(b1.0, b1.1, "B"), C = f.point(c1.0, c1.1, "C"), D = f.point(d1.0, d1.1, "D")
            let E = f.point(ex, ey, "E")
            f.segment(A, E, "\(ae)"); f.segment(E, B, "\(eb)"); f.segment(C, E, "\(ce)"); f.segment(E, D, "?", .highlight)
            return ask("Chords AB and CD of a circle meet at E. AE = \(ae), EB = \(eb) and CE = \(ce). Find ED.", Double(ae * eb) / Double(ce), "chords",
                       [H("Intersecting chords"), S("The products of the pieces are equal: AE·EB = CE·ED (triangles AEC and DEB are similar)."),
                        S("\(ae)·\(eb) = \(ce)·ED"), R("ED = \(fr(ae * eb, ce))")], f)
        case 4:
            // Tangent and secant from P: PT² = PA·PB.
            let pa = r.int(2...8), ab = r.int(2...10)
            let fromTangent = r.bool()
            var f = GeoFigure()
            f.circle(0, 0, 1)
            let d = 2.4
            let P = f.point(d, 0, "P")
            let th = acos(1 / d) * 180 / .pi
            let (tx, ty) = onCircle(th)
            let T = f.point(tx, ty, "T")
            // The secant through P at a small angle below the axis.
            let ang = Double.pi + 0.22
            let dx = cos(ang), dy = sin(ang)
            let b = d * dx, c = d * d - 1
            let tNear = -b - (b * b - c).squareRoot(), tFar = -b + (b * b - c).squareRoot()
            let A = f.point(d + tNear * dx, tNear * dy, "A"), B = f.point(d + tFar * dx, tFar * dy, "B")
            if fromTangent {
                // PT given; PA·PB = PT², with PB = PT²/PA.
                let pt = r.int(3...9)
                guard pt * pt > pa * pa else { return nil }
                f.segment(P, T, "\(pt)"); f.segment(P, A, "\(pa)"); f.segment(A, B, "?", .highlight)
                return ask("From P outside a circle, PT is a tangent and a secant meets the circle at A and then B. PT = \(pt) and PA = \(pa). Find AB.",
                           Double(pt * pt) / Double(pa) - Double(pa), "tangent and secant",
                           [H("Tangent–secant theorem"), S("PT² = PA·PB"), S("\(pt * pt) = \(pa)·PB  ⇒  PB = \(fr(pt * pt, pa))"),
                            H("The chord"), R("AB = PB − PA = \(fr(pt * pt, pa)) − \(pa) = \(fr(pt * pt - pa * pa, pa))")], f)
            }
            f.segment(P, T, "?", .highlight); f.segment(P, A, "\(pa)"); f.segment(A, B, "\(ab)")
            let e = exact(1, rad: pa * (pa + ab), den: 1)
            return ask("From P outside a circle, PT is a tangent and a secant meets the circle at A and then B. PA = \(pa) and AB = \(ab). Find PT.", e.value,
                       "tangent and secant",
                       [H("Tangent–secant theorem"), S("PT² = PA·PB (triangles PTA and PBT are similar)."),
                        S("PB = PA + AB = \(pa + ab)"), S("PT² = \(pa)·\(pa + ab) = \(pa * (pa + ab))"), R("PT = \(e.text)")], f)
        case 5:
            // DE ∥ BC: similar triangles.
            let m = r.int(2...7), n = r.int(1...6), bc = r.int(4...15)
            var f = GeoFigure()
            let A = f.point(1.1, 2.6, "A"), B = f.point(0, 0, "B"), C = f.point(3.6, 0, "C")
            let k = Double(m) / Double(m + n)
            let D = f.point(1.1 - 1.1 * k, 2.6 - 2.6 * k, "D"), E = f.point(1.1 + 2.5 * k, 2.6 - 2.6 * k, "E")
            f.segment(A, D, "\(m)"); f.segment(D, B, "\(n)"); f.segment(B, C, "\(bc)"); f.segment(C, E); f.segment(E, A)
            f.segment(D, E, "?", .highlight)
            return ask("In triangle ABC, D is on AB and E is on AC with DE ∥ BC. AD = \(m), DB = \(n) and BC = \(bc). Find DE.",
                       Double(bc * m) / Double(m + n), "similar triangles",
                       [H("Similar triangles"), S("DE ∥ BC, so ∠ADE = ∠ABC and ∠AED = ∠ACB (corresponding angles): △ADE ∼ △ABC."),
                        H("Ratio of similarity"), S("AD/AB = DE/BC,  with AB = \(m) + \(n) = \(m + n)"),
                        S("DE = BC·AD/AB = \(bc)·\(m)/\(m + n)"), R("DE = \(fr(bc * m, m + n))")], f)
        case 6:
            // Area ratio = (ratio of similarity)².
            let m = r.int(1...4), n = r.int(1...4), area = r.int(2...12)
            var f = GeoFigure()
            let A = f.point(1.3, 2.8, "A"), B = f.point(0, 0, "B"), C = f.point(3.8, 0, "C")
            let k = Double(m) / Double(m + n)
            let D = f.point(1.3 - 1.3 * k, 2.8 - 2.8 * k, "D"), E = f.point(1.3 + 2.5 * k, 2.8 - 2.8 * k, "E")
            f.polygon([A, B, C]); f.segment(D, E)
            f.curves.append(.init(xy: [f.points[D].x, f.points[D].y, f.points[E].x, f.points[E].y, 3.8, 0, 0, 0], style: .highlight, fill: true))
            let total = area * (m + n) * (m + n)
            return ask("In triangle ABC, DE ∥ BC with D on AB and AD : DB = \(m) : \(n). The area of triangle ADE is \(area). Find the area of the trapezoid DBCE.",
                       Double(total - area * m * m) / Double(m * m), "area ratio",
                       [H("Similar triangles"), S("DE ∥ BC, so △ADE ∼ △ABC with ratio AD/AB = \(m)/\(m + n)."),
                        H("Areas go with the square of the ratio"), S("S(ADE)/S(ABC) = (\(m)/\(m + n))² = \(m * m)/\((m + n) * (m + n))"),
                        S("S(ABC) = \(area)·\((m + n) * (m + n))/\(m * m) = \(fr(total, m * m))"),
                        R("S(DBCE) = \(fr(total, m * m)) − \(area) = \(fr(total - area * m * m, m * m))")], f)
        case 7:
            // Angle bisector theorem.
            var sides: (Int, Int, Int) = (0, 0, 0)
            for _ in 0..<30 {
                let b = r.int(4...12), c = r.int(4...12), a = r.int(4...15)
                if a < b + c, b < a + c, c < a + b, b != c { sides = (a, b, c); break }
            }
            let (a, b, c) = sides
            guard a > 0 else { return nil }
            let x = (Double(a * a + c * c - b * b)) / Double(2 * a)
            let y = (Double(c * c) - x * x).squareRoot()
            var f = GeoFigure()
            let A = f.point(x, y, "A"), B = f.point(0, 0, "B"), C = f.point(Double(a), 0, "C")
            let bd = Double(a * c) / Double(b + c)
            let D = f.point(bd, 0, "D")
            f.segment(A, B, "\(c)"); f.segment(A, C, "\(b)"); f.segment(B, D, "?", .highlight); f.segment(D, C); f.segment(A, D, nil, .dashed)
            f.angle(A, B, D, "α"); f.angle(A, D, C, "α")
            return ask("In triangle ABC, AB = \(c), AC = \(b) and BC = \(a). AD bisects angle A (D on BC). Find BD.", bd, "angle bisector",
                       [H("Angle bisector theorem"), S("The bisector splits the opposite side in the ratio of the other two sides: BD/DC = AB/AC = \(c)/\(b)"),
                        H("Split BC = \(a) in the ratio \(c) : \(b)"), S("BD = \(a)·\(c)/(\(c) + \(b))"), R("BD = \(fr(a * c, b + c))")], f)
        case 8:
            if r.bool() {
                // Tangent lengths of the inscribed circle.
                var sides: (Int, Int, Int) = (0, 0, 0)
                for _ in 0..<30 {
                    let a = r.int(5...14), b = r.int(5...14), c = r.int(5...14)
                    if a < b + c, b < a + c, c < a + b { sides = (a, b, c); break }
                }
                let (a, b, c) = sides
                guard a > 0 else { return nil }
                let x = Double(a * a + c * c - b * b) / Double(2 * a), y = (Double(c * c) - x * x).squareRoot()
                var f = GeoFigure()
                let A = f.point(x, y, "A"), B = f.point(0, 0, "B"), C = f.point(Double(a), 0, "C")
                f.segment(A, B, "\(c)"); f.segment(B, C, "\(a)"); f.segment(C, A, "\(b)")
                let s = Double(a + b + c) / 2, area = (s * (s - Double(a)) * (s - Double(b)) * (s - Double(c))).squareRoot()
                let rr = area / s
                let ix = (Double(a) * x + Double(b) * 0 + Double(c) * Double(a)) / Double(a + b + c)
                let iy = (Double(a) * y) / Double(a + b + c)
                f.circle(ix, iy, rr)
                let ak = Double(b + c - a) / 2
                let K = f.point(x + (0 - x) * ak / Double(c), y - y * ak / Double(c), "K", highlight: true)
                f.segment(A, K, "?", .highlight)
                return ask("A circle is inscribed in triangle ABC with AB = \(c), BC = \(a), CA = \(b). It touches AB at K. Find AK.", ak, "tangent lengths",
                           [H("Equal tangents"), S("Two tangents from the same point to a circle are equal. Call them x (from A), y (from B), z (from C)."),
                            S("x + y = \(c),  y + z = \(a),  z + x = \(b)"),
                            H("Solve"), S("Add all three: 2(x + y + z) = \(a + b + c),  x + y + z = \(fr(a + b + c, 2))"),
                            S("x = (x + y + z) − (y + z) = \(fr(a + b + c, 2)) − \(a)"), R("AK = \(fr(b + c - a, 2))")], f)
            }
            // A quadrilateral around a circle: AB + CD = BC + DA.
            let ab = r.int(5...12), bc = r.int(5...12), cd = r.int(5...12)
            let da = ab + cd - bc
            guard da > 2 else { return nil }
            var f = GeoFigure()
            f.circle(0, 0, 1)
            var ids: [Int] = []
            let corners = [(-1.35, 1.0), (1.25, 1.0), (1.7, -1.0), (-1.55, -1.0)]
            for (i, (x, y)) in corners.enumerated() { ids.append(f.point(x, y, ["A", "B", "C", "D"][i])) }
            f.segment(ids[0], ids[1], "\(ab)"); f.segment(ids[1], ids[2], "\(bc)"); f.segment(ids[2], ids[3], "\(cd)"); f.segment(ids[3], ids[0], "?", .highlight)
            return ask("Quadrilateral ABCD is drawn around a circle (every side touches it). AB = \(ab), BC = \(bc), CD = \(cd). Find DA.", Double(da),
                       "tangential quadrilateral",
                       [H("Equal tangents"), S("From each corner the two tangents to the circle are equal; each side is made of two of them."),
                        S("So AB + CD and BC + DA use each tangent length once: AB + CD = BC + DA."),
                        S("\(ab) + \(cd) = \(bc) + DA"), R("DA = \(da)")], f)
        default:
            // Right triangle with the altitude to the hypotenuse.
            let p = r.int(1...9), q = r.int(1...9)
            var f = GeoFigure()
            let c = Double(p + q), h = Double(p * q).squareRoot()
            let A = f.point(0, 0, "A"), B = f.point(c, 0, "B"), C = f.point(Double(p), h, "C"), D = f.point(Double(p), 0, "D")
            f.segment(A, D, "\(p)"); f.segment(D, B, "\(q)"); f.segment(A, C); f.segment(C, B)
            let what = r.int(0...1)
            f.segment(C, D, what == 0 ? "?" : nil, what == 0 ? .highlight : .dashed)
            f.angle(C, A, B, "90°")
            if what == 0 {
                let e = exact(1, rad: p * q, den: 1)
                return ask("In right triangle ABC (∠C = 90°), CD is the height to the hypotenuse. AD = \(p) and DB = \(q). Find CD.", e.value, "right triangle height",
                           [H("Similar triangles"), S("The height splits ABC into two triangles similar to it: △ACD ∼ △CBD."),
                            S("AD/CD = CD/DB  ⇒  CD² = AD·DB"), S("CD² = \(p)·\(q) = \(p * q)"), R("CD = \(e.text)")], f)
            }
            f.points[C].highlight = true
            let e = exact(1, rad: p * (p + q), den: 1)
            return ask("In right triangle ABC (∠C = 90°), CD is the height to the hypotenuse. AD = \(p) and DB = \(q). Find AC.", e.value, "right triangle leg",
                       [H("Similar triangles"), S("△ACD ∼ △ABC (they share ∠A and both have a right angle)."),
                        S("AD/AC = AC/AB  ⇒  AC² = AD·AB"), S("AB = \(p) + \(q) = \(p + q),  AC² = \(p)·\(p + q) = \(p * (p + q))"), R("AC = \(e.text)")], f)
        }
    }

    // MARK: - Trigonometric identities

    static func trigIdentity(_ level: Level, _ r: inout SeededRandom, _ seed: UInt64, _ cases: [Int]? = nil) -> QuizProblem? {
        let pool: [Int]
        switch level {
        case .easy: pool = [0, 1, 4]
        case .medium: pool = [0, 1, 2, 4, 5]
        case .hard: pool = [1, 2, 3, 5, 4]
        case .bagrut: pool = [2, 3, 5, 1]
        }
        func ask(_ prompt: String, _ value: Double, _ topic: String, _ steps: [SolutionStep]) -> QuizProblem {
            number(.trigIdentity, level, seed, prompt, value, topic: "trig:\(topic)", steps: steps)
        }
        // Pythagorean triples for sin and cos.
        let triples = [(3, 4, 5), (5, 12, 13), (8, 15, 17), (7, 24, 25), (4, 3, 5), (12, 5, 13), (20, 21, 29)]

        switch choose(pool, cases, &r) {
        case 0:
            // Exact values from sum and difference formulas.
            let base: [Int: (s: String, c: String)] = [30: ("1/2", "√3/2"), 45: ("√2/2", "√2/2"), 60: ("√3/2", "1/2"), 120: ("√3/2", "−1/2"), 135: ("√2/2", "−√2/2")]
            let exactText: [String: String] = ["sin15": "(√6 − √2)/4", "cos15": "(√6 + √2)/4", "sin75": "(√6 + √2)/4", "cos75": "(√6 − √2)/4",
                                                "sin105": "(√6 + √2)/4", "cos105": "(√2 − √6)/4", "sin165": "(√6 − √2)/4", "cos165": "−(√6 + √2)/4"]
            let (t, a, b, plus) = r.pick([(15, 45, 30, false), (15, 60, 45, false), (75, 45, 30, true), (105, 60, 45, true), (165, 120, 45, true), (75, 120, 45, false)])
            let useSin = r.bool()
            let fa = base[a]!, fb = base[b]!
            let formula = useSin ? "sin(\(a)° \(plus ? "+" : "−") \(b)°) = sin \(a)°·cos \(b)° \(plus ? "+" : "−") cos \(a)°·sin \(b)°"
                                 : "cos(\(a)° \(plus ? "+" : "−") \(b)°) = cos \(a)°·cos \(b)° \(plus ? "−" : "+") sin \(a)°·sin \(b)°"
            let numbers = useSin ? "(\(fa.s))(\(fb.c)) \(plus ? "+" : "−") (\(fa.c))(\(fb.s))" : "(\(fa.c))(\(fb.c)) \(plus ? "−" : "+") (\(fa.s))(\(fb.s))"
            let name = (useSin ? "sin" : "cos") + "\(t)"
            let value = useSin ? sin(deg(Double(t))) : cos(deg(Double(t)))
            return ask("Find the exact value of \(useSin ? "sin" : "cos") \(t)° (e.g. (√6 + √2)/4).", value, "exact value",
                       [H("Write \(t)° with known angles"), S("\(t)° = \(a)° \(plus ? "+" : "−") \(b)°"),
                        H("Use the formula"), S(formula), S("= \(numbers)", 2), R("\(useSin ? "sin" : "cos") \(t)° = \(exactText[name]!)")])
        case 1:
            // Double angle from sin α in a given quadrant.
            let (p, q, h) = r.pick(triples)
            let second = r.bool()
            let cosSign = second ? -1 : 1
            let what = r.int(0...2)
            let sin2 = 2 * p * q * cosSign, cos2 = q * q - p * p
            let value: Double, result: String, work: [SolutionStep]
            switch what {
            case 0:
                value = Double(sin2) / Double(h * h); result = "sin 2α = \(fr(sin2, h * h))"
                work = [H("Double angle"), S("sin 2α = 2 sin α cos α = 2·(\(p)/\(h))·(\(fr(cosSign * q, h)))")]
            case 1:
                value = Double(cos2) / Double(h * h); result = "cos 2α = \(fr(cos2, h * h))"
                work = [H("Double angle"), S("cos 2α = cos²α − sin²α = \(q * q)/\(h * h) − \(p * p)/\(h * h)")]
            default:
                guard cos2 != 0 else { return nil }
                value = Double(sin2) / Double(cos2); result = "tan 2α = \(fr(sin2, cos2))"
                work = [H("Double angle"), S("sin 2α = \(fr(sin2, h * h)),  cos 2α = \(fr(cos2, h * h))"), S("tan 2α = sin 2α / cos 2α")]
            }
            return ask("sin α = \(p)/\(h) and α is \(second ? "between 90° and 180°" : "between 0° and 90°"). Find \(["sin 2α", "cos 2α", "tan 2α"][what]).", value,
                       "double angle",
                       [H("Find cos α"), S("cos²α = 1 − sin²α = 1 − \(p * p)/\(h * h) = \(q * q)/\(h * h)"),
                        S("cos α is \(second ? "negative in the second quadrant" : "positive in the first quadrant"): cos α = \(fr(cosSign * q, h))")]
                       + work + [R(result)])
        case 2:
            // sin(α ± β), cos(α ± β) from two triangles.
            let t1 = r.pick(triples), t2 = r.pick(triples)
            let (p1, q1, h1) = t1, (p2, q2, h2) = t2
            let op = r.int(0...3)
            let names = ["sin(α + β)", "sin(α − β)", "cos(α + β)", "cos(α − β)"]
            let nums = [p1 * q2 + q1 * p2, p1 * q2 - q1 * p2, q1 * q2 - p1 * p2, q1 * q2 + p1 * p2]
            let lines = ["sin α cos β + cos α sin β", "sin α cos β − cos α sin β", "cos α cos β − sin α sin β", "cos α cos β + sin α sin β"]
            let subs = ["(\(p1)/\(h1))(\(q2)/\(h2)) + (\(q1)/\(h1))(\(p2)/\(h2))", "(\(p1)/\(h1))(\(q2)/\(h2)) − (\(q1)/\(h1))(\(p2)/\(h2))",
                        "(\(q1)/\(h1))(\(q2)/\(h2)) − (\(p1)/\(h1))(\(p2)/\(h2))", "(\(q1)/\(h1))(\(q2)/\(h2)) + (\(p1)/\(h1))(\(p2)/\(h2))"]
            return ask("α and β are acute angles with sin α = \(p1)/\(h1) and cos β = \(q2)/\(h2). Find \(names[op]).", Double(nums[op]) / Double(h1 * h2), "sum formula",
                       [H("The missing values"), S("cos α = √(1 − \(p1 * p1)/\(h1 * h1)) = \(q1)/\(h1)"), S("sin β = √(1 − \(q2 * q2)/\(h2 * h2)) = \(p2)/\(h2)"),
                        S("Both positive: the angles are acute."),
                        H("The formula"), S("\(names[op]) = \(lines[op])"), S("= \(subs[op])", 2), R("\(names[op]) = \(fr(nums[op], h1 * h2))")])
        case 3:
            // tan(α + β): sometimes a famous angle comes out.
            if r.bool() {
                let (a, b, c, d, ans) = r.pick([(1, 2, 1, 3, 45), (1, 4, 3, 5, 45), (1, 5, 2, 3, 45), (1, 7, 3, 4, 45), (2, 1, 3, 1, 135), (1, 2, 1, 3, 45)])
                return ask("α and β are acute with tan α = \(fr(a, b)) and tan β = \(fr(c, d)). Find α + β in degrees.", Double(ans), "tan sum angle",
                           [H("tan of the sum"), S("tan(α + β) = (tan α + tan β)/(1 − tan α·tan β)"),
                            S("= (\(fr(a, b)) + \(fr(c, d)))/(1 − \(fr(a * c, b * d))) = \(fr(a * d + b * c, b * d))/\(fr(b * d - a * c, b * d)) = \(fr(a * d + b * c, b * d - a * c))", 2),
                            H("Which angle?"), S("0° < α + β < 180°, and tan(α + β) = \(ans == 45 ? "1" : "−1")"), R("α + β = \(ans)°")])
            }
            let a = r.nonZero(-3...4), b = r.int(1...5), c = r.nonZero(-3...4), d = r.int(1...5)
            let num = a * d + b * c, den = b * d - a * c
            guard den != 0, num != 0 else { return nil }
            return ask("tan α = \(fr(a, b)) and tan β = \(fr(c, d)). Find tan(α + β).", Double(num) / Double(den), "tan sum",
                       [H("tan of the sum"), S("tan(α + β) = (tan α + tan β)/(1 − tan α·tan β)"),
                        S("Numerator: \(fr(a, b)) + \(fr(c, d)) = \(fr(num, b * d))"), S("Denominator: 1 − \(fr(a * c, b * d)) = \(fr(den, b * d))"),
                        R("tan(α + β) = \(fr(num, den))")])
        case 4:
            // Simplify: pick the equal expression.
            let ids: [(String, String, [String], [String])] = [
                ("sin 2x / (1 + cos 2x)", "tan x", ["cot x", "sin x", "2 tan x"], ["sin 2x = 2 sin x cos x", "1 + cos 2x = 2cos²x", "So it is 2 sin x cos x / 2cos²x = sin x / cos x"]),
                ("(1 − cos 2x) / sin 2x", "tan x", ["cot x", "cos x", "2 sin x"], ["1 − cos 2x = 2sin²x", "sin 2x = 2 sin x cos x", "So it is 2sin²x / (2 sin x cos x) = sin x / cos x"]),
                ("cos⁴x − sin⁴x", "cos 2x", ["1", "sin 2x", "cos²x"], ["Difference of squares: (cos²x − sin²x)(cos²x + sin²x)", "cos²x + sin²x = 1, and cos²x − sin²x = cos 2x"]),
                ("(sin x + cos x)²", "1 + sin 2x", ["1", "1 + cos 2x", "2 sin 2x"], ["sin²x + 2 sin x cos x + cos²x", "= 1 + 2 sin x cos x = 1 + sin 2x"]),
                ("sin(x + y) + sin(x − y)", "2 sin x cos y", ["2 sin x", "2 cos x sin y", "sin 2x"], ["sin x cos y + cos x sin y + sin x cos y − cos x sin y", "= 2 sin x cos y"]),
                ("cos(x − y) − cos(x + y)", "2 sin x sin y", ["2 cos x cos y", "0", "−2 sin x sin y"], ["cos x cos y + sin x sin y − (cos x cos y − sin x sin y)", "= 2 sin x sin y"]),
                ("2cos²x − cos 2x", "1", ["cos²x", "sin²x", "2"], ["cos 2x = 2cos²x − 1", "So 2cos²x − (2cos²x − 1) = 1"]),
                ("sin 3x / sin x − cos 3x / cos x", "2", ["1", "sin 2x", "0"], ["Common denominator: (sin 3x cos x − cos 3x sin x)/(sin x cos x)", "= sin(3x − x)/(sin x cos x) = sin 2x/(½ sin 2x) = 2"]),
            ]
            let (e, correct, wrong, why) = r.pick(ids)
            var q = blank(.trigIdentity, level, seed, "Which expression is equal to  \(e)  (wherever it is defined)?", .number(0), topic: "trig:simplify")
            q.answer = shuffled(QuizOption(text: correct), wrong.map { QuizOption(text: $0) }, &r)
            q.steps = [H("Use identities")] + why.map { S($0) } + [R("\(e) = \(correct)")]
            return q
        default:
            // Equations solved with an identity: how many solutions in [0°, 360°)?
            let eqs: [(String, (Double) -> Double, [String])] = [
                ("sin 2x = sin x", { x in sin(2 * x) - sin(x) }, ["2 sin x cos x − sin x = 0  ⇒  sin x(2cos x − 1) = 0", "sin x = 0  or  cos x = ½"]),
                ("cos 2x = cos x", { x in cos(2 * x) - cos(x) }, ["2cos²x − 1 − cos x = 0  ⇒  (2cos x + 1)(cos x − 1) = 0", "cos x = 1  or  cos x = −½"]),
                ("sin 2x = cos x", { x in sin(2 * x) - cos(x) }, ["2 sin x cos x − cos x = 0  ⇒  cos x(2 sin x − 1) = 0", "cos x = 0  or  sin x = ½"]),
                ("cos 2x + sin x = 0", { x in cos(2 * x) + sin(x) }, ["1 − 2sin²x + sin x = 0  ⇒  2sin²x − sin x − 1 = 0", "(2 sin x + 1)(sin x − 1) = 0:  sin x = 1  or  sin x = −½"]),
                ("cos 2x = 3cos x − 2", { x in cos(2 * x) - 3 * cos(x) + 2 }, ["2cos²x − 1 − 3cos x + 2 = 0  ⇒  2cos²x − 3cos x + 1 = 0", "(2cos x − 1)(cos x − 1) = 0:  cos x = ½  or  cos x = 1"]),
                ("sin 2x = √3 sin x", { x in sin(2 * x) - 3.0.squareRoot() * sin(x) }, ["sin x(2cos x − √3) = 0", "sin x = 0  or  cos x = √3/2"]),
            ]
            let (text, f, algebra) = r.pick(eqs)
            let sols = (0..<360).filter { Swift.abs(f(deg(Double($0)))) < 1e-9 }
            guard !sols.isEmpty else { return nil }
            let largest = r.bool() && level != .easy
            return ask("Solve \(text) for 0° ≤ x < 360°. " + (largest ? "Type the largest solution (in degrees)." : "How many solutions are there?"),
                       Double(largest ? sols.max()! : sols.count), "identity equation",
                       [H("Use a double-angle identity")] + algebra.map { S($0) }
                       + [H("All solutions in [0°, 360°)"), S(sols.map { "\($0)°" }.joined(separator: ",  "))]
                       + [R(largest ? "x = \(sols.max()!)°" : "\(sols.count) solutions")])
        }
    }
}
