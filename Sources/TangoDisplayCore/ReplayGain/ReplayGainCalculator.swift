import Foundation

public enum ReplayGainMode: String, CaseIterable, Identifiable, Codable {
    case off
    case track
    case album
    case auto

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .off:   return "Off"
        case .track: return "Track Gain"
        case .album: return "Album Gain"
        case .auto:  return "Auto"
        }
    }
}

public struct ReplayGainSettings {
    public var mode: ReplayGainMode
    public var preampDb: Double
    public var preventClipping: Bool
    public var targetLoudnessLufs: Double
    /// In `.auto`: when true, ignore file ReplayGain tags and use our own loudness analysis instead
    /// (analysis is preferred; while it is still pending no gain is applied). When false, trust the
    /// tag gain if present and only analyse when it is missing.
    public var alwaysAnalyze: Bool

    public init(mode: ReplayGainMode = .off, preampDb: Double = 0,
                preventClipping: Bool = true, targetLoudnessLufs: Double = -18.0,
                alwaysAnalyze: Bool = false) {
        self.mode = mode
        self.preampDb = preampDb
        self.preventClipping = preventClipping
        self.targetLoudnessLufs = targetLoudnessLufs
        self.alwaysAnalyze = alwaysAnalyze
    }
}

public enum ReplayGainSource: Equatable {
    case none
    case metadataTrack
    case metadataAlbum
    case analysed
}

public struct ReplayGainCalculationResult: Equatable {
    public let linearGain: Float
    public let gainDb: Double?
    public let source: ReplayGainSource
    public let clippingProtectionApplied: Bool
    public let integratedLoudnessLufs: Double?

    public init(linearGain: Float, gainDb: Double?, source: ReplayGainSource,
                clippingProtectionApplied: Bool, integratedLoudnessLufs: Double?) {
        self.linearGain = linearGain
        self.gainDb = gainDb
        self.source = source
        self.clippingProtectionApplied = clippingProtectionApplied
        self.integratedLoudnessLufs = integratedLoudnessLufs
    }
}

/// Source-aware ReplayGain calculation supporting metadata (track/album) and analysed loudness.
/// Returns linearGain = 1.0 when mode is off, metadata is absent, or required gain is missing.
public func calculateReplayGain(
    info: ReplayGainInfo?,
    analysis: LoudnessAnalysisResult?,
    settings: ReplayGainSettings
) -> ReplayGainCalculationResult {
    let noChange = ReplayGainCalculationResult(
        linearGain: 1.0, gainDb: nil, source: .none,
        clippingProtectionApplied: false, integratedLoudnessLufs: nil)

    guard settings.mode != .off else { return noChange }

    let gainDb: Double?
    let peak: Double?
    let source: ReplayGainSource
    let integratedLufs: Double?

    switch settings.mode {
    case .off:
        return noChange
    case .track:
        gainDb = info?.trackGainDb
        peak = info?.trackPeak
        source = (gainDb != nil) ? .metadataTrack : .none
        integratedLufs = nil
    case .album:
        gainDb = info?.albumGainDb
        peak = info?.albumPeak
        source = (gainDb != nil) ? .metadataAlbum : .none
        integratedLufs = nil
    case .auto:
        if settings.alwaysAnalyze {
            // Trust our analysis over the file tags; if it hasn't finished yet, apply no gain.
            if let a = analysis {
                gainDb = a.calculatedReplayGainDb
                peak = a.truePeak ?? a.samplePeak
                source = .analysed
                integratedLufs = a.integratedLoudnessLufs
            } else {
                return noChange
            }
        } else if let trackGain = info?.trackGainDb {
            gainDb = trackGain
            peak = info?.trackPeak
            source = .metadataTrack
            integratedLufs = nil
        } else if let a = analysis {
            gainDb = a.calculatedReplayGainDb
            peak = a.truePeak ?? a.samplePeak
            source = .analysed
            integratedLufs = a.integratedLoudnessLufs
        } else {
            return noChange
        }
    }

    guard let gainDb else {
        return ReplayGainCalculationResult(
            linearGain: 1.0, gainDb: nil, source: .none,
            clippingProtectionApplied: false, integratedLoudnessLufs: integratedLufs)
    }

    let total = gainDb + settings.preampDb
    var linear = pow(10.0, total / 20.0)
    var clipped = false
    if settings.preventClipping, let peak, peak > 0, linear * peak > 1.0 {
        linear = 1.0 / peak
        clipped = true
    }
    return ReplayGainCalculationResult(
        linearGain: Float(max(0, linear)), gainDb: gainDb, source: source,
        clippingProtectionApplied: clipped, integratedLoudnessLufs: integratedLufs)
}

/// Legacy scalar API — returns the linear gain multiplier without source metadata.
/// Retained for any call sites that don't need the richer result type.
public func calculateReplayGainLinear(info: ReplayGainInfo?, settings: ReplayGainSettings) -> Float {
    calculateReplayGain(info: info, analysis: nil, settings: settings).linearGain
}

/// Parses a ReplayGain dB string such as "-7.23 dB", "+3.00 dB", or "-5.4".
/// Returns nil for empty, nil, or non-numeric input.
public func parseReplayGainDb(_ value: String?) -> Double? {
    guard let value, !value.isEmpty else { return nil }
    let cleaned = value
        .replacingOccurrences(of: "db", with: "", options: .caseInsensitive)
        .trimmingCharacters(in: .whitespaces)
    return Double(cleaned)
}
