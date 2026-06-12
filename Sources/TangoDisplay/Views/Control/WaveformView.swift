import SwiftUI
import TangoDisplayCore

/// Waveform of the currently playing built-in-player track with a running playhead,
/// timeline, total/remaining time, and detected leading/trailing silence markers. Display only.
struct WaveformView: View {
    @EnvironmentObject var appState: AppState

    @State private var samples: [Float] = []
    @State private var leadingSilence: Double = 0
    @State private var trailingSilence: Double = 0
    @State private var loadedURL: URL?
    @State private var loading = false
    @State private var progress: Double = 0
    @State private var elapsed: Double = 0
    @State private var duration: Double = 0

    private let tick = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    private var player: LocalPlayerSource? { appState.localPlayer }
    private var currentURL: URL? {
        guard let id = player?.currentEntryID else { return nil }
        return appState.setlist.entries.first { $0.id == id }?.fileURL
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .onAppear { reload(); refreshTimes() }
        .onReceive(tick) { _ in
            if let url = currentURL, url != loadedURL { reload() }
            else if currentURL == nil && loadedURL != nil { resetTrack() }
            refreshTimes()
        }
    }

    @ViewBuilder
    private var content: some View {
        if player == nil {
            placeholder("Waveform shows the built-in player only")
        } else if samples.isEmpty {
            placeholder(loading ? "Analysing…" : "No track playing")
        } else {
            VStack(spacing: 2) {
                Canvas { ctx, size in drawWaveform(ctx, size) }
                    .frame(maxHeight: .infinity)
                Canvas { ctx, size in drawTimeline(ctx, size) }
                    .frame(height: 16)
                timeLabels
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    private var timeLabels: some View {
        HStack {
            Text(fmt(elapsed))
                .foregroundColor(.cyan.opacity(0.9))
            Spacer()
            Text(fmt(duration))
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text("-" + fmt(max(0, duration - elapsed)))
                .foregroundColor(.white.opacity(0.7))
        }
        .font(.system(size: 11, weight: .medium).monospacedDigit())
        .frame(height: 14)
    }

    // MARK: - Drawing

    private func drawWaveform(_ ctx: GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height, mid = h / 2
        let n = samples.count
        guard n > 0, w > 0 else { return }

        // Detected silence regions (behind the bars).
        if leadingSilence > 0 {
            let lx = w * CGFloat(leadingSilence)
            ctx.fill(Path(CGRect(x: 0, y: 0, width: lx, height: h)), with: .color(.orange.opacity(0.10)))
        }
        if trailingSilence > 0 {
            let tx = w * CGFloat(trailingSilence)
            ctx.fill(Path(CGRect(x: w - tx, y: 0, width: tx, height: h)), with: .color(.orange.opacity(0.10)))
        }

        let playedX = w * CGFloat(progress)
        let columns = max(1, Int(w))
        for x in 0..<columns {
            let lo = Int(Double(x) / Double(columns) * Double(n))
            let hi = max(lo + 1, Int(Double(x + 1) / Double(columns) * Double(n)))
            var amp: Float = 0
            var i = lo
            while i < min(hi, n) { amp = max(amp, samples[i]); i += 1 }
            let barH = max(1, CGFloat(amp) * (h * 0.92))
            let color: Color = CGFloat(x) <= playedX ? .cyan : .white.opacity(0.32)
            ctx.fill(Path(CGRect(x: CGFloat(x), y: mid - barH / 2, width: 1, height: barH)),
                     with: .color(color))
        }

        // Silence boundary lines.
        if leadingSilence > 0 { strokeV(ctx, x: w * CGFloat(leadingSilence), h: h, color: .orange.opacity(0.55)) }
        if trailingSilence > 0 { strokeV(ctx, x: w * CGFloat(1 - trailingSilence), h: h, color: .orange.opacity(0.55)) }

        // Playhead.
        strokeV(ctx, x: playedX, h: h, color: .white, lineWidth: 1.5)
    }

    private func drawTimeline(_ ctx: GraphicsContext, _ size: CGSize) {
        let w = size.width, h = size.height
        guard duration > 0, w > 0 else { return }

        // Baseline.
        var base = Path()
        base.move(to: CGPoint(x: 0, y: 1))
        base.addLine(to: CGPoint(x: w, y: 1))
        ctx.stroke(base, with: .color(.white.opacity(0.25)), lineWidth: 1)

        let interval = tickInterval(duration: duration, width: w)
        guard interval > 0 else { return }
        var t = 0.0
        while t <= duration + 0.001 {
            let x = w * CGFloat(t / duration)
            var p = Path()
            p.move(to: CGPoint(x: x, y: 0))
            p.addLine(to: CGPoint(x: x, y: 4))
            ctx.stroke(p, with: .color(.white.opacity(0.4)), lineWidth: 1)

            let label = fmt(t)
            let resolved = ctx.resolve(Text(label)
                .font(.system(size: 9).monospacedDigit())
                .foregroundColor(.white.opacity(0.55)))
            let lsize = resolved.measure(in: size)
            let lx = min(max(x, lsize.width / 2 + 1), w - lsize.width / 2 - 1)
            ctx.draw(resolved, at: CGPoint(x: lx, y: h - lsize.height / 2 - 1))
            t += interval
        }

        // Playhead marker on the timeline.
        strokeV(ctx, x: w * CGFloat(progress), h: 5, color: .white.opacity(0.9), lineWidth: 1.5)
    }

    private func strokeV(_ ctx: GraphicsContext, x: CGFloat, h: CGFloat, color: Color, lineWidth: CGFloat = 1) {
        var p = Path()
        p.move(to: CGPoint(x: x, y: 0))
        p.addLine(to: CGPoint(x: x, y: h))
        ctx.stroke(p, with: .color(color), lineWidth: lineWidth)
    }

    /// Choose a "nice" tick spacing so labels don't crowd (~70 px per label).
    private func tickInterval(duration: Double, width: CGFloat) -> Double {
        guard duration > 0 else { return 0 }
        let maxLabels = max(2, Int(width / 70))
        let candidates: [Double] = [5, 10, 15, 30, 60, 120, 180, 300, 600, 900]
        for c in candidates where duration / c <= Double(maxLabels) { return c }
        return duration / Double(maxLabels)
    }

    private func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let total = Int(s.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func placeholder(_ text: String) -> some View {
        Text(text).foregroundColor(.white.opacity(0.6)).font(.system(size: 13))
    }

    // MARK: - Data

    private func refreshTimes() {
        guard let p = player else { elapsed = 0; duration = 0; progress = 0; return }
        elapsed = p.elapsed
        duration = p.duration
        progress = duration > 0 ? min(1, max(0, elapsed / duration)) : 0
    }

    private func resetTrack() {
        samples = []
        loadedURL = nil
        leadingSilence = 0
        trailingSilence = 0
    }

    private func reload() {
        guard let url = currentURL else { resetTrack(); return }
        loadedURL = url
        loading = true
        Task {
            let data = await WaveformOverview.shared.overview(url: url)
            await MainActor.run {
                guard url == currentURL else { return }
                samples = data.peaks
                leadingSilence = data.leadingSilenceFraction
                trailingSilence = data.trailingSilenceFraction
                loading = false
            }
        }
    }
}
