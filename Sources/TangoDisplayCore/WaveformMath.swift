import CoreGraphics
import Foundation

/// Fractions of a peak-bucket overview that are silent at each end.
/// A fully silent input reports 0/0 so the waveform panel doesn't render as one
/// solid "silence" region.
public func waveformSilenceFractions(peaks: [Float],
                                     threshold: Float) -> (leading: Double, trailing: Double) {
    let n = peaks.count
    guard n > 0 else { return (0, 0) }
    var first = 0
    while first < n && peaks[first] <= threshold { first += 1 }
    if first == n { return (0, 0) }
    var last = n - 1
    while last > first && peaks[last] <= threshold { last -= 1 }
    return (Double(first) / Double(n), Double(n - 1 - last) / Double(n))
}

/// Scales a single peak by a linear gain and clamps to the 0…1 display range.
/// Used to show the waveform "after ReplayGain": a gain < 1 shrinks the peak, a
/// gain > 1 raises it until it clips flat at 1.0 (mirroring real playback).
public func normalizedPeak(_ peak: Float, gain: Float) -> Float {
    min(1, max(0, peak) * max(0, gain))
}

/// Applies `normalizedPeak` across a whole overview.
public func normalizedWaveformPeaks(_ peaks: [Float], gain: Float) -> [Float] {
    peaks.map { normalizedPeak($0, gain: gain) }
}

/// Validates a window frame restored from persistence against the current screens,
/// so a frame saved on a since-disconnected monitor can't come back invisible.
public enum WindowFramePlacement {
    /// - Grows the frame to `minSize` if it shrank below it.
    /// - Leaves partially visible frames alone (deliberate user placement).
    /// - Centres a frame that intersects no screen on the first screen.
    /// - With no screen information, returns the frame unchanged.
    public static func sanitized(frame: CGRect,
                                 visibleScreens: [CGRect],
                                 minSize: CGSize) -> CGRect {
        var f = frame
        if f.width < minSize.width { f.size.width = minSize.width }
        if f.height < minSize.height { f.size.height = minSize.height }
        guard !visibleScreens.isEmpty else { return f }
        if visibleScreens.contains(where: { $0.intersects(f) }) { return f }

        let screen = visibleScreens[0]
        return CGRect(x: screen.midX - f.width / 2,
                      y: screen.midY - f.height / 2,
                      width: f.width, height: f.height)
    }
}
