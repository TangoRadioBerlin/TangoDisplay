import SwiftUI
import TangoDisplayCore

struct PerformanceView: View {
    let currentTrack: Track?
    let settings: AppSettings

    var body: some View {
        VStack(spacing: 24) {
            if settings.performanceTextLines.isEmpty {
                fallbackContent
            } else {
                ForEach(settings.performanceTextLines) { line in
                    Text(resolvePerformancePlaceholders(line.text, track: currentTrack))
                        .font(performanceFont(line))
                        .foregroundColor(Color(hex: line.colorHex))
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                }
            }
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Shown when the DJ marked a track as a performance but configured no text lines —
    /// without this the audience would see only the (possibly black) background (F3).
    @ViewBuilder
    private var fallbackContent: some View {
        if let track = currentTrack {
            Text(track.title)
                .font(.system(size: 72, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            if !track.artist.isEmpty {
                Text(track.artist)
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            }
        }
    }

    private func performanceFont(_ line: PerformanceTextLine) -> Font {
        if line.fontName == "System" || line.fontName.isEmpty {
            return .system(size: line.fontSize)
        }
        return .custom(line.fontName, size: line.fontSize)
    }
}
