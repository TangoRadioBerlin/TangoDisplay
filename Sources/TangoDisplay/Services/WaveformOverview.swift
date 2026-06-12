import AVFoundation
import Foundation

/// Coarse peak overview + detected leading/trailing silence for an audio file.
struct WaveformData {
    let peaks: [Float]                  // one value per bucket (0…1, peak amplitude)
    let leadingSilenceFraction: Double  // 0…1 of total length that is silent at the start
    let trailingSilenceFraction: Double // 0…1 of total length that is silent at the end
}

/// Generates and caches a coarse peak overview of an audio file for waveform display.
/// Cached per URL so each track is read once.
actor WaveformOverview {
    static let shared = WaveformOverview()

    private var cache: [URL: WaveformData] = [:]
    private let bucketCount = 3000
    private let silenceThreshold: Float = 0.02 // ≈ -34 dBFS

    func overview(url: URL) async -> WaveformData {
        if let cached = cache[url] { return cached }
        let peaks = Self.generate(url: url, buckets: bucketCount)
        let result = Self.withSilence(peaks: peaks, threshold: silenceThreshold)
        cache[url] = result
        return result
    }

    private static func withSilence(peaks: [Float], threshold: Float) -> WaveformData {
        let n = peaks.count
        guard n > 0 else { return WaveformData(peaks: peaks, leadingSilenceFraction: 0, trailingSilenceFraction: 0) }
        var first = 0
        while first < n && peaks[first] <= threshold { first += 1 }
        if first == n { // entirely silent — mark nothing to avoid a fully red panel
            return WaveformData(peaks: peaks, leadingSilenceFraction: 0, trailingSilenceFraction: 0)
        }
        var last = n - 1
        while last > first && peaks[last] <= threshold { last -= 1 }
        let leading = Double(first) / Double(n)
        let trailing = Double(n - 1 - last) / Double(n)
        return WaveformData(peaks: peaks, leadingSilenceFraction: leading, trailingSilenceFraction: trailing)
    }

    private static func generate(url: URL, buckets: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url,
                                          commonFormat: .pcmFormatFloat32,
                                          interleaved: false) else { return [] }
        let total = file.length
        guard total > 0 else { return [] }
        let framesPerBucket = max(1, Int(total) / buckets)
        let format = file.processingFormat
        var peaks: [Float] = []
        peaks.reserveCapacity(buckets)

        while file.framePosition < total {
            let remaining = Int(total - file.framePosition)
            let toRead = AVAudioFrameCount(min(framesPerBucket, remaining))
            guard toRead > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: toRead),
                  (try? file.read(into: buffer, frameCount: toRead)) != nil else { break }
            let n = Int(buffer.frameLength)
            if n == 0 { break }
            var peak: Float = 0
            if let channels = buffer.floatChannelData {
                for c in 0..<Int(buffer.format.channelCount) {
                    let p = channels[c]
                    for i in 0..<n { peak = max(peak, abs(p[i])) }
                }
            }
            peaks.append(min(1, peak))
        }
        return peaks
    }
}
