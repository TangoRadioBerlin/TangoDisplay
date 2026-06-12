import AVFoundation
import Foundation

actor AudioSilenceAnalyzer {

    struct Result {
        let silenceAtStart: Double  // seconds
        let silenceAtEnd: Double    // seconds
    }

    static let shared = AudioSilenceAnalyzer()

    private var cache: [URL: Result] = [:]

    func analyze(url: URL) async -> Result {
        if let cached = cache[url] { return cached }
        let result = Self.analyzeFile(url: url)
        cache[url] = result
        return result
    }

    func invalidate(url: URL) {
        cache.removeValue(forKey: url)
    }

    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Private

    private static let overviewRate: Double = 100.0   // samples per second
    private static let silenceThreshold: UInt8 = 2    // on 0–255 scale ≈ −42 dBFS peak
                                                      // (was 4 ≈ −36 dB, Embrace-compatible, but
                                                      // that classified quiet fade-outs as silence)
    private static let scanWindow: Double = 10.0       // seconds to scan at each end

    private static func analyzeFile(url: URL) -> Result {
        guard let file = try? AVAudioFile(forReading: url) else {
            return Result(silenceAtStart: 0, silenceAtEnd: 0)
        }

        let nativeSampleRate = file.fileFormat.sampleRate
        let totalFrames = file.length
        guard nativeSampleRate > 0, totalFrames > 0 else {
            return Result(silenceAtStart: 0, silenceAtEnd: 0)
        }

        // Use mono float32 client format — AVAudioFile handles any channel/format conversion.
        guard let monoFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: nativeSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            return Result(silenceAtStart: 0, silenceAtEnd: 0)
        }

        guard let monoFile = try? AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32,
                                              interleaved: false) else {
            return Result(silenceAtStart: 0, silenceAtEnd: 0)
        }
        _ = monoFormat  // used implicitly via forReading with commonFormat

        // Frames per overview sample (e.g. 441 frames at 44100 Hz → 100 samples/sec)
        let framesPerSample = AVAudioFrameCount(max(1, nativeSampleRate / overviewRate))
        let scanFrames = AVAudioFramePosition(scanWindow * nativeSampleRate)
        let startScanEnd = min(scanFrames, totalFrames)
        let endScanStart = max(0, totalFrames - scanFrames)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: monoFile.processingFormat,
                                            frameCapacity: framesPerSample) else {
            return Result(silenceAtStart: 0, silenceAtEnd: 0)
        }

        // --- Scan start ---
        monoFile.framePosition = 0
        var startOverview: [UInt8] = []
        var framesLeft = startScanEnd
        while framesLeft > 0 {
            let toRead = AVAudioFrameCount(min(Int64(framesPerSample), framesLeft))
            buffer.frameLength = 0
            guard (try? monoFile.read(into: buffer, frameCount: toRead)) != nil,
                  buffer.frameLength > 0 else { break }
            startOverview.append(rmsToUInt8(buffer: buffer))
            framesLeft -= Int64(buffer.frameLength)
        }

        // --- Scan end (seek to last scanWindow seconds) ---
        monoFile.framePosition = endScanStart
        var endOverview: [UInt8] = []
        while monoFile.framePosition < totalFrames {
            buffer.frameLength = 0
            guard (try? monoFile.read(into: buffer, frameCount: framesPerSample)) != nil,
                  buffer.frameLength > 0 else { break }
            endOverview.append(rmsToUInt8(buffer: buffer))
        }

        let chunkDuration = Double(framesPerSample) / nativeSampleRate

        // Count consecutive silent samples from the very start
        var silenceAtStart: Double = 0
        for sample in startOverview {
            if sample <= silenceThreshold { silenceAtStart += chunkDuration }
            else { break }
        }

        // Count consecutive silent samples from the very end
        var silenceAtEnd: Double = 0
        for sample in endOverview.reversed() {
            if sample <= silenceThreshold { silenceAtEnd += chunkDuration }
            else { break }
        }

        return Result(silenceAtStart: silenceAtStart, silenceAtEnd: silenceAtEnd)
    }

    // Compute peak absolute amplitude across all frames, scale to 0–255.
    private static func rmsToUInt8(buffer: AVAudioPCMBuffer) -> UInt8 {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return 0 }

        var peak: Float = 0
        let channelCount = Int(buffer.format.channelCount)
        for ch in 0..<channelCount {
            let ptr = channelData[ch]
            for i in 0..<frameCount {
                let abs = Swift.abs(ptr[i])
                if abs > peak { peak = abs }
            }
        }
        // Clamp to 0–255; peak of 1.0 → 255. Round to nearest — truncating would
        // push borderline-quiet chunks below the silence threshold.
        return UInt8(min(255, Int((peak * 255).rounded())))
    }
}
