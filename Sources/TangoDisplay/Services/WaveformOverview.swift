import AVFoundation
import Foundation
import OSLog
import TangoDisplayCore

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

    private static let log = Logger(subsystem: "TangoDisplay", category: "waveform")

    private var cache: [URL: WaveformData] = [:]
    private let bucketCount = 3000
    private let silenceThreshold: Float = 0.02 // ≈ -34 dBFS

    func overview(url: URL) async -> WaveformData {
        if let cached = cache[url] { return cached }
        let peaks = Self.generate(url: url, buckets: bucketCount)
        let fractions = waveformSilenceFractions(peaks: peaks, threshold: silenceThreshold)
        let result = WaveformData(peaks: peaks,
                                  leadingSilenceFraction: fractions.leading,
                                  trailingSilenceFraction: fractions.trailing)
        // Don't cache failures: a transient read error (file briefly locked/unavailable)
        // would otherwise pin an empty waveform for the rest of the session.
        if peaks.isEmpty {
            Self.log.error("Waveform read produced no data for \(url.lastPathComponent, privacy: .public)")
        } else {
            cache[url] = result
        }
        return result
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
