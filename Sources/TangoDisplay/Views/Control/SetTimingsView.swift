import SwiftUI
import AppKit
import TangoDisplayCore

// MARK: - Layout enum

enum SetTimingsLayout: String, CaseIterable {
    case grid, horizontal, vertical
}

extension SetTimingsLayout {
    /// Minimum content size (padding-inclusive) for each layout mode.
    var minContentSize: CGSize {
        switch self {
        case .grid:       CGSize(width: 480, height: 440)
        case .horizontal: CGSize(width: 720, height: 200)
        case .vertical:   CGSize(width: 240, height: 560)
        }
    }
}

// MARK: - Main view

struct SetTimingsView: View {
    var layout: SetTimingsLayout
    @ObservedObject var player: LocalPlayerSource
    @ObservedObject var setlist: SetlistManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            switch layout {
            case .grid:       gridBody
            case .horizontal: horizontalBody
            case .vertical:   verticalBody
            }
        }
        .padding(16)
        .frame(minWidth: layout.minContentSize.width,
               minHeight: layout.minContentSize.height)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Layout bodies

    private var gridBody: some View {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                timingCard(icon: "clock", title: "Total Set Time",
                           value: formatDuration(setlist.totalPlaylistDuration))
                timingCard(icon: "list.bullet", title: "Tracks Remaining",
                           value: "\(unplayedCount)")
            }
            GridRow {
                timingCard(icon: "forward.end.fill", title: "Next Cortina",
                           value: formatDuration(timeUntilNextCortina))
                timingCard(icon: "flag.fill", title: "Ends At",
                           value: formattedEndTime)
            }
            GridRow {
                currentTrackCard(vertical: false)
                    .gridCellColumns(2)
            }
        }
    }

    private var horizontalBody: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                timingCard(icon: "clock", title: "Total Set Time",
                           value: formatDuration(setlist.totalPlaylistDuration))
                timingCard(icon: "list.bullet", title: "Tracks Remaining",
                           value: "\(unplayedCount)")
                timingCard(icon: "forward.end.fill", title: "Next Cortina",
                           value: formatDuration(timeUntilNextCortina))
                timingCard(icon: "flag.fill", title: "Ends At",
                           value: formattedEndTime)
            }
            currentTrackCard(vertical: false)
        }
    }

    private var verticalBody: some View {
        HStack(spacing: 8) {
            verticalProgressStrip
                .frame(width: 14)
                .frame(maxHeight: .infinity)
            VStack(spacing: 8) {
                timingCard(icon: "waveform", title: "Current Track",
                           value: currentTrackCountdown)
                timingCard(icon: "clock", title: "Total Set Time",
                           value: formatDuration(setlist.totalPlaylistDuration))
                timingCard(icon: "list.bullet", title: "Tracks Remaining",
                           value: "\(unplayedCount)")
                timingCard(icon: "forward.end.fill", title: "Next Cortina",
                           value: formatDuration(timeUntilNextCortina))
                timingCard(icon: "flag.fill", title: "Ends At",
                           value: formattedEndTime)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var verticalProgressStrip: some View {
        let isPlaying = appState.currentPlayerState == .playing
        let barColor: Color = isPlaying ? ControlTheme.accent : .orange
        let duration = player.duration
        let progress = duration > 0 ? player.elapsed / max(duration, 1) : 0.0
        return GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .separatorColor))
                RoundedRectangle(cornerRadius: 4)
                    .fill(barColor)
                    .frame(height: geo.size.height * progress)
            }
            .allowsHitTesting(false)
        }
    }

    private var currentTrackCountdown: String {
        guard player.currentEntryID != nil else { return "—" }
        let remaining = max(0, player.duration - player.elapsed)
        return "-\(formatTime(remaining))"
    }

    // MARK: - Card views

    private func timingCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
            }
            Text(value)
                .font(.system(size: 72, weight: .bold))
                .foregroundColor(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func currentTrackCard(vertical: Bool) -> some View {
        let isPlaying = appState.currentPlayerState == .playing
        let barColor: Color = isPlaying ? ControlTheme.accent : .orange
        let elapsed = player.elapsed
        let duration = player.duration
        let remaining = max(0, duration - elapsed)
        let progress = duration > 0 ? elapsed / max(duration, 1) : 0.0
        let trackTitle = setlist.entries.first { $0.id == player.currentEntryID }?.track.title
        let hasTrack = player.currentEntryID != nil

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
                Text("Current Track")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.primary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(hasTrack ? "-\(formatTime(remaining))" : "—")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)

                if let title = trackTitle, !vertical {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if vertical {
                verticalProgressBar(progress: progress, barColor: barColor,
                                    elapsed: elapsed, remaining: remaining)
            } else {
                horizontalProgressBar(progress: progress, barColor: barColor,
                                      elapsed: elapsed, remaining: remaining)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity,
               maxHeight: vertical ? .infinity : nil,
               alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private func horizontalProgressBar(progress: Double, barColor: Color,
                                        elapsed: Double, remaining: Double) -> some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(nsColor: .separatorColor))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geo.size.width * progress, height: 6)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 6)

            HStack {
                Text(formatTime(elapsed))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text("-\(formatTime(remaining))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func verticalProgressBar(progress: Double, barColor: Color,
                                      elapsed: Double, remaining: Double) -> some View {
        HStack(spacing: 6) {
            // Time labels: remaining at top, elapsed at bottom
            VStack {
                Text(formatTime(remaining))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Text(formatTime(elapsed))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Bar fills from bottom to top
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(height: geo.size.height * progress)
                }
                .allowsHitTesting(false)
            }
            .frame(width: 8)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Timing calculations (mirrored from StatusBarView)

    private var unplayedCount: Int {
        setlist.entries.filter { $0.state != .played }.count
    }

    private var timeUntilNextCortina: TimeInterval {
        let detector = settings.makeDetector()
        let entries = setlist.entries

        let startIdx: Int
        var remaining: TimeInterval

        if let id = player.currentEntryID,
           let idx = entries.firstIndex(where: { $0.id == id }) {
            let entry = entries[idx]
            if detector.isCortina(genre: entry.track.genre) { return 0 }
            startIdx = idx
            remaining = max(0, (entry.duration ?? 0) - player.elapsed)
        } else if let idx = entries.firstIndex(where: { $0.state != .played }) {
            let entry = entries[idx]
            if detector.isCortina(genre: entry.track.genre) { return 0 }
            startIdx = idx
            remaining = entry.duration ?? 0
        } else {
            return 0
        }

        for entry in entries[(startIdx + 1)...] {
            guard entry.state != .played else { continue }
            if detector.isCortina(genre: entry.track.genre) { return remaining }
            remaining += entry.duration ?? 0
        }
        return 0
    }

    private func effectiveDuration(for entry: SetlistEntry, detector: CortinaDetector) -> TimeInterval {
        let duration = entry.duration ?? 0
        guard settings.autoFadeCortinasEnabled,
              !entry.ignoresAutoFade,
              detector.isCortina(genre: entry.track.genre) else {
            return duration
        }
        let fade = settings.builtInFadeDuration
        let play = settings.cortinaPlayTime
        let delay: Double
        if duration > play + fade { delay = play }
        else if duration > fade   { delay = duration - fade }
        else                      { delay = 0 }
        return min(duration, delay + fade + 1.0)
    }

    private var setEndTime: Date? {
        guard appState.currentPlayerState != .stopped else { return nil }
        var remaining: TimeInterval = 0
        let stopAfterID = setlist.stopAfterEntryID
        let detector = settings.makeDetector()
        for entry in setlist.entries {
            switch entry.state {
            case .playing:
                remaining += max(0, effectiveDuration(for: entry, detector: detector) - player.elapsed)
            case .paused, .queued:
                remaining += effectiveDuration(for: entry, detector: detector)
            case .played:
                if entry.id == player.currentEntryID {
                    remaining += max(0, effectiveDuration(for: entry, detector: detector) - player.elapsed)
                }
            }
            if let stopID = stopAfterID, entry.id == stopID { break }
        }
        return Date().addingTimeInterval(remaining)
    }

    private var formattedEndTime: String {
        guard let end = setEndTime else { return "play to calc" }
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: end)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Window content wrapper

struct SetTimingsWindowContent: View {
    @AppStorage("SetTimings.layout") private var layout: SetTimingsLayout = .grid
    @State private var hostWindow: NSWindow?
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Group {
            if let player = appState.localPlayer {
                SetTimingsView(layout: layout, player: player, setlist: appState.setlist)
                    .environmentObject(appState)
                    .environmentObject(settings)
            } else {
                Text("Set timings are available with the built-in player.")
                    .foregroundColor(.secondary)
                    .frame(width: 480, height: 380)
            }
        }
        .background(WindowAccessor { window in
            if hostWindow == nil {
                hostWindow = window
                window.setContentSize(layout.minContentSize)
            }
            window.contentMinSize = layout.minContentSize
        })
        .onChange(of: layout) { newLayout in
            hostWindow?.setContentSize(newLayout.minContentSize)
            hostWindow?.contentMinSize = newLayout.minContentSize
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("Layout", selection: $layout) {
                        Text("Grid").tag(SetTimingsLayout.grid)
                        Text("Wide").tag(SetTimingsLayout.horizontal)
                        Text("Tall").tag(SetTimingsLayout.vertical)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Layout", systemImage: "square.grid.2x2")
                }
                .help("Window layout")
            }
        }
    }
}
