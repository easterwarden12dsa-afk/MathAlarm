import Foundation

/// Small seeded generator so the same seed always rebuilds the same problem
/// (needed to restore a challenge after the app is relaunched).
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Random integer in `range`.
    public mutating func int(_ range: ClosedRange<Int>) -> Int {
        Int.random(in: range, using: &self)
    }

    /// Random non-zero integer in `range`.
    public mutating func nonZero(_ range: ClosedRange<Int>) -> Int {
        var v = 0
        while v == 0 { v = int(range) }
        return v
    }

    public mutating func double(_ range: ClosedRange<Double>) -> Double {
        Double.random(in: range, using: &self)
    }

    public mutating func bool() -> Bool { Bool.random(using: &self) }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[int(0...(items.count - 1))]
    }
}
