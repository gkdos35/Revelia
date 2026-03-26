// Signalfield/Engine/SplitMix64.swift

import Foundation

/// SplitMix64 — a fast, deterministic pseudo-random number generator.
/// Same seed always produces the same sequence. Used for ALL game randomness.
///
/// Reference: https://prng.di.unimi.it/splitmix64.c
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    /// Create a new generator with the given seed.
    init(seed: UInt64) {
        self.state = seed
    }

    /// Generate the next random UInt64.
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Generate a random Int in the given range (inclusive).
    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % span)
    }

    /// Generate a random Double in [0, 1).
    mutating func nextDouble() -> Double {
        Double(next() >> 11) * 0x1.0p-53  // Standard conversion
    }

    /// Shuffle an array in-place using Fisher-Yates.
    mutating func shuffle<T>(_ array: inout [T]) {
        for i in stride(from: array.count - 1, through: 1, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            array.swapAt(i, j)
        }
    }
}
