import Foundation

/// A geometry drawing: points, segments, circles, marked angles and curves,
/// optionally on axes (conics, the complex plane). Figures in space arrive
/// already projected to the page, with their x, y, z axes drawn as segments.
public struct GeoFigure: Codable, Hashable, Sendable {
    public enum Style: String, Codable, Sendable {
        case solid, dashed, arrow, highlight, faint
    }

    public struct Point: Codable, Hashable, Sendable {
        public var x: Double
        public var y: Double
        /// "" = no name.
        public var label: String
        public var dot: Bool = true
        /// The point the question is about (drawn in yellow).
        public var highlight: Bool = false
    }

    public struct Segment: Codable, Hashable, Sendable {
        public var a: Int
        public var b: Int
        public var label: String? = nil
        public var style: Style = .solid
    }

    public struct Circle: Codable, Hashable, Sendable {
        public var cx: Double
        public var cy: Double
        public var r: Double
        public var style: Style = .solid
    }

    /// An angle at `vertex` between the rays to `from` and `to` (point indices).
    public struct Angle: Codable, Hashable, Sendable {
        public var vertex: Int
        public var from: Int
        public var to: Int
        public var label: String
    }

    /// A polyline x0, y0, x1, y1, …; `fill` closes and fills it.
    public struct Curve: Codable, Hashable, Sendable {
        public var xy: [Double]
        public var style: Style = .solid
        public var fill: Bool = false
        public var label: String? = nil
    }

    public var points: [Point] = []
    public var segments: [Segment] = []
    public var circles: [Circle] = []
    public var angles: [Angle] = []
    public var curves: [Curve] = []
    /// Draw x and y axes through (0, 0) with these names, e.g. ["x", "y"] or ["Re", "Im"].
    public var axes: [String]? = nil
    /// x0, x1, y0, y1; nil = fit everything drawn.
    public var window: [Double]? = nil

    public init() {}

    // MARK: Building

    @discardableResult
    mutating func point(_ x: Double, _ y: Double, _ label: String = "", dot: Bool = true, highlight: Bool = false) -> Int {
        points.append(Point(x: x, y: y, label: label, dot: dot, highlight: highlight))
        return points.count - 1
    }

    mutating func segment(_ a: Int, _ b: Int, _ label: String? = nil, _ style: Style = .solid) {
        segments.append(Segment(a: a, b: b, label: label, style: style))
    }

    /// A closed polygon through the given points.
    mutating func polygon(_ ids: [Int], _ style: Style = .solid) {
        for (i, a) in ids.enumerated() { segment(a, ids[(i + 1) % ids.count], nil, style) }
    }

    mutating func circle(_ cx: Double, _ cy: Double, _ r: Double, _ style: Style = .solid) {
        circles.append(Circle(cx: cx, cy: cy, r: r, style: style))
    }

    mutating func angle(_ vertex: Int, _ from: Int, _ to: Int, _ label: String) {
        angles.append(Angle(vertex: vertex, from: from, to: to, label: label))
    }

    /// Samples a parametric curve.
    mutating func curve(_ t0: Double, _ t1: Double, steps: Int = 80, _ style: Style = .solid, fill: Bool = false, label: String? = nil,
                        _ f: (Double) -> (Double, Double)?) {
        var xy: [Double] = []
        for i in 0...steps {
            let t = t0 + (t1 - t0) * Double(i) / Double(steps)
            if let (x, y) = f(t), x.isFinite, y.isFinite {
                xy += [x, y]
            } else if xy.count >= 4 {
                curves.append(Curve(xy: xy, style: style, fill: false, label: label))
                xy = []
            } else {
                xy = []
            }
        }
        if xy.count >= 4 { curves.append(Curve(xy: xy, style: style, fill: fill, label: label)) }
    }

    /// A straight line through two points, as a curve (asymptotes, directrices).
    mutating func line(_ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double, _ style: Style = .dashed, label: String? = nil) {
        curves.append(Curve(xy: [x0, y0, x1, y1], style: style, label: label))
    }

    // MARK: Space

    /// Oblique projection: x comes towards the viewer (down-left), y goes right, z goes up.
    static func project(_ p: [Double]) -> (Double, Double) {
        let k = 0.5, a = Double.pi * 7 / 6
        return (p[1] + k * p[0] * cos(a), p[2] + k * p[0] * sin(a))
    }

    /// x, y and z axes from the origin, long enough to hold every given point.
    mutating func axes3D(holding pts: [[Double]]) {
        let o = point(0, 0, "O", dot: false)
        let names = ["x", "y", "z"]
        for i in 0..<3 {
            let reach = Swift.max(2, (pts.map { Swift.abs($0[i]) }.max() ?? 2) * 1.25)
            var e = [0.0, 0.0, 0.0]
            e[i] = reach
            let (x, y) = Self.project(e)
            let end = point(x, y, names[i], dot: false)
            segment(o, end, nil, .faint)
        }
    }

    @discardableResult
    mutating func point3D(_ p: [Double], _ label: String, highlight: Bool = false) -> Int {
        let (x, y) = Self.project(p)
        return point(x, y, label, highlight: highlight)
    }
}
