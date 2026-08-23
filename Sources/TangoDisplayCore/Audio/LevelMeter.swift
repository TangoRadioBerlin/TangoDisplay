// LevelMeter.swift
// Pure math behind the room-level (decibel) meter: a time-windowed energy
// average for a steady reading, and the dBFS → SPL-like mapping with a
// user calibration offset. AppKit/AVFoundation-free so it is unit-testable.

import Foundation

/// Sliding-window average of signal power (mean square), weighted by sample
/// count. Entries older than `windowSeconds` relative to the read time are
/// dropped, so the reading reflects the last N seconds rather than the last
/// capture buffer — a larger window means a calmer display.
public struct LevelAverager {
    public var windowSeconds: Double

    private struct Chunk { let time: Double; let sumSquares: Double; let count: Int }
    private var chunks: [Chunk] = []

    public init(windowSeconds: Double) {
        self.windowSeconds = max(0.01, windowSeconds)
    }

    /// Add one captured chunk: the sum of squared samples and how many samples
    /// it spans, stamped with a monotonic time in seconds.
    public mutating func add(sumSquares: Double, sampleCount: Int, at time: Double) {
        guard sampleCount > 0 else { return }
        chunks.append(Chunk(time: time, sumSquares: sumSquares, count: sampleCount))
    }

    /// Mean square over the chunks inside the window ending at `time`.
    /// 0 when nothing is in the window.
    public mutating func meanSquare(at time: Double) -> Double {
        let cutoff = time - max(0.01, windowSeconds)
        chunks.removeAll { $0.time < cutoff }
        var sum = 0.0
        var n = 0
        for c in chunks { sum += c.sumSquares; n += c.count }
        return n > 0 ? sum / Double(n) : 0
    }

    public mutating func reset() { chunks.removeAll() }
}

/// Map signal power (mean square, full scale = 1.0) to an approximate SPL-like
/// decibel value. `baseOffset` places typical quiet-room background
/// (≈ −30 dBFS) near 60 dB; `calibrationOffset` is the user's correction to
/// match an external sound level meter. Silence is floored at −180 dBFS.
public func splDecibels(meanSquare: Double, baseOffset: Double = 90, calibrationOffset: Double) -> Double {
    let power = max(meanSquare, 1e-18)
    return 10 * log10(power) + baseOffset + calibrationOffset
}

/// Integer meter reading: rounded and clamped to the 0…140 dB display range.
public func meterLevel(decibels: Double) -> Int {
    guard decibels.isFinite else { return 0 }
    return max(0, min(140, Int(decibels.rounded())))
}
