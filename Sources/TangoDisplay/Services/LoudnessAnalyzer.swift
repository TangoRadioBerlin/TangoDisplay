import AVFoundation
import Foundation
import OSLog
import TangoDisplayCore

// MARK: - Errors

enum LoudnessAnalysisError: Error {
    case cannotOpenFile
    case unsupportedFormat
    case insufficientData
}

// MARK: - Internal biquad types

private struct BiquadCoefs {
    let b0, b1, b2, a1, a2: Double
}

private struct BiquadState {
    var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    mutating func process(_ x0: Double, coefs: BiquadCoefs) -> Double {
        let y0 = coefs.b0 * x0 + coefs.b1 * x1 + coefs.b2 * x2
                 - coefs.a1 * y1 - coefs.a2 * y2
        x2 = x1; x1 = x0
        y2 = y1; y1 = y0
        return y0
    }
}

// MARK: - Analyzer actor

/// Performs EBU R128 / ITU-R BS.1770 integrated loudness analysis off the main thread.
/// Calls are serialised by the actor; use `Task.detached(priority: .background)` at call sites
/// to keep the work off the cooperative thread pool during playback.
actor LoudnessAnalyzer {
    static let shared = LoudnessAnalyzer()

    private nonisolated static let logger = Logger(subsystem: "TangoDisplay", category: "LoudnessAnalyzer")

    func analyse(url: URL, targetLoudnessLufs: Double) async throws -> LoudnessAnalysisResult {
        try Self.analyzeFile(url: url, targetLoudnessLufs: targetLoudnessLufs)
    }

    // MARK: - K-weighting filter design (ITU-R BS.1770 / libebur128)

    /// Stage 1: high-frequency pre-filter modelling head acoustic effect.
    /// Coefficients derived from analog prototype via bilinear transform (K method).
    nonisolated private static func preFilterCoefs(sampleRate: Double) -> BiquadCoefs {
        let f0 = 1500.0
        let Q  = 1.0 / sqrt(2.0)
        let G  = 3.999843853973347
        let Vh = pow(10.0, G / 20.0)
        let Vb = pow(Vh, 0.4142135623730951)   // pow(Vh, sqrt(2) - 1)
        let K  = tan(.pi * f0 / sampleRate)
        let a0 = 1.0 + K / Q + K * K
        return BiquadCoefs(
            b0: (Vh + Vb * K / Q + K * K) / a0,
            b1: 2.0  * (K * K - Vh) / a0,
            b2: (Vh - Vb * K / Q + K * K) / a0,
            a1: 2.0  * (K * K - 1.0) / a0,
            a2: (1.0 - K / Q + K * K) / a0
        )
    }

    /// Stage 2: 2nd-order Butterworth high-pass removing DC and very-low-frequency content.
    nonisolated private static func highPassCoefs(sampleRate: Double) -> BiquadCoefs {
        let f0 = 38.13547087602444
        let Q  = 0.5003270373238773
        let K  = tan(.pi * f0 / sampleRate)
        let a0 = 1.0 + K / Q + K * K
        return BiquadCoefs(
            b0:  1.0 / a0,
            b1: -2.0 / a0,
            b2:  1.0 / a0,
            a1:  2.0 * (K * K - 1.0) / a0,
            a2:  (1.0 - K / Q + K * K) / a0
        )
    }

    // MARK: - Core analysis (nonisolated — runs on calling task's thread)

    nonisolated private static func analyzeFile(
        url: URL,
        targetLoudnessLufs: Double
    ) throws -> LoudnessAnalysisResult {
        guard let file = try? AVAudioFile(forReading: url,
                                          commonFormat: .pcmFormatFloat32,
                                          interleaved: false)
        else { throw LoudnessAnalysisError.cannotOpenFile }

        let sampleRate   = file.processingFormat.sampleRate
        let channelCount = min(Int(file.processingFormat.channelCount), 2)
        let totalFrames  = Int(file.length)
        guard sampleRate > 0, totalFrames > 0, channelCount > 0
        else { throw LoudnessAnalysisError.unsupportedFormat }

        let audioDuration = Double(totalFrames) / sampleRate
        logger.info("LoudnessAnalyzer: start \(url.lastPathComponent) — \(String(format: "%.1f", audioDuration))s, \(Int(sampleRate)) Hz, \(channelCount)ch")
        let wallStart = Date()

        let stage1 = preFilterCoefs(sampleRate: sampleRate)
        let stage2 = highPassCoefs(sampleRate: sampleRate)
        // One filter state pair per channel (stage1 state, stage2 state)
        var filterStates = Array(repeating: (BiquadState(), BiquadState()), count: channelCount)

        let blockFrames = Int(0.4 * sampleRate)  // 400ms gate block
        let hopFrames   = Int(0.1 * sampleRate)  // 100ms hop → 75% overlap

        // Fixed-size circular buffer per channel (~280 KB at 44100 Hz stereo)
        var circBuf: [[Double]] = Array(repeating: Array(repeating: 0.0, count: blockFrames),
                                        count: channelCount)
        // Rolling sum-of-squares per channel — updated sample-by-sample, eliminating reduce() per hop
        var sumSquares = Array(repeating: 0.0, count: channelCount)
        var writePos  = 0   // next write position in the circular buffer
        var filled    = 0   // samples written so far (capped at blockFrames)
        var hopCount  = 0   // samples written since the last block emission
        var blockLoudnesses: [Double] = []
        var samplePeak: Double = 0

        let readCap = AVAudioFrameCount(hopFrames)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                             frameCapacity: readCap)
        else { throw LoudnessAnalysisError.unsupportedFormat }

        while file.framePosition < file.length {
            // Cooperative cancellation: stop the (CPU-heavy) scan promptly when the
            // requesting track is no longer current — e.g. the user skipped past it (F8).
            try Task.checkCancellation()
            buffer.frameLength = 0
            guard (try? file.read(into: buffer, frameCount: readCap)) != nil,
                  buffer.frameLength > 0 else { break }
            let n = Int(buffer.frameLength)
            guard let channelData = buffer.floatChannelData else { break }

            for i in 0..<n {
                for ch in 0..<channelCount {
                    let raw = Double(channelData[ch][i])
                    samplePeak = max(samplePeak, abs(raw))
                    // K-weighting: stage 1 then stage 2
                    let filtered = filterStates[ch].1.process(
                        filterStates[ch].0.process(raw, coefs: stage1),
                        coefs: stage2)
                    // Rolling sumSquares: subtract outgoing sample, write new, add new squared
                    let old = circBuf[ch][writePos]
                    sumSquares[ch] -= old * old
                    circBuf[ch][writePos] = filtered
                    sumSquares[ch] += filtered * filtered
                }
                writePos = (writePos + 1) % blockFrames
                if filled < blockFrames { filled += 1 }
                hopCount += 1

                // Emit a block loudness value once the buffer is full and a hop boundary is reached
                if filled == blockFrames, hopCount >= hopFrames {
                    hopCount = 0
                    // BS.1770 §2.1: sum channel mean powers (G_i = 1 for L/R), do not average
                    var ms = 0.0
                    for ch in 0..<channelCount {
                        ms += sumSquares[ch] / Double(blockFrames)
                    }
                    blockLoudnesses.append(-0.691 + 10.0 * log10(ms + 1e-10))
                }
            }
        }

        let wallTime = Date().timeIntervalSince(wallStart)
        let speedRatio = audioDuration / max(wallTime, 1e-9)
        let summary = "\(url.lastPathComponent) done in \(String(format: "%.2f", wallTime))s (\(String(format: "%.1f", speedRatio))x real-time)"
        if speedRatio < 1.0 {
            logger.warning("LoudnessAnalyzer: \(summary) — slower than real-time")
        } else {
            logger.info("LoudnessAnalyzer: \(summary)")
        }

        guard !blockLoudnesses.isEmpty else { throw LoudnessAnalysisError.insufficientData }

        // Absolute gate: discard blocks below −70 LUFS
        let absoluteGated = blockLoudnesses.filter { $0 >= -70.0 }
        guard !absoluteGated.isEmpty else { throw LoudnessAnalysisError.insufficientData }

        // Relative gate: discard blocks more than 10 LU below the preliminary loudness
        let prelim = gatedAverageLoudness(absoluteGated)
        let relativeGated = absoluteGated.filter { $0 >= prelim - 10.0 }
        guard !relativeGated.isEmpty else { throw LoudnessAnalysisError.insufficientData }

        let integratedLufs = gatedAverageLoudness(relativeGated)
        let gainDb = targetLoudnessLufs - integratedLufs

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return LoudnessAnalysisResult(
            filePath:               url.path,
            fileSize:               (attrs[.size] as? Int64) ?? 0,
            modifiedDate:           (attrs[.modificationDate] as? Date) ?? Date(),
            duration:               audioDuration,
            integratedLoudnessLufs: integratedLufs,
            calculatedReplayGainDb: gainDb,
            targetLoudnessLufs:     targetLoudnessLufs,
            samplePeak:             samplePeak > 0 ? samplePeak : nil,
            truePeak:               nil,    // true peak analysis deferred
            analysedAt:             Date()
        )
    }

    /// Average loudness from a list of block loudness values (in LUFS).
    /// Averages in the power domain, not the dB domain (per EBU R128 §3.2).
    nonisolated private static func gatedAverageLoudness(_ loudnesses: [Double]) -> Double {
        let meanPower = loudnesses
            .map { pow(10.0, ($0 + 0.691) / 10.0) }
            .reduce(0.0, +) / Double(loudnesses.count)
        return -0.691 + 10.0 * log10(meanPower)
    }
}
