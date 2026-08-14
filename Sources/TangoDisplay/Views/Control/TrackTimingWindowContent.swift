import AVFoundation
import SwiftUI

/// Editor to trim a setlist entry's playback to a [start, end] sub-range.
/// Operates on `appState.trimEditorEntryID` (the right-clicked entry, which may be idle),
/// not the currently playing track. Built-in player enforces the trim; see LocalPlayerSource.loadEntry.
struct TrackTimingWindowContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var entry: SetlistEntry? {
        guard let id = appState.trimEditorEntryID else { return nil }
        return appState.setlist.entries.first(where: { $0.id == id })
    }

    var body: some View {
        Group {
            if let entry {
                TrackTimingEditor(entry: entry) { dismiss() }
                    .id(entry.id)   // reset editor state when the target entry changes
            } else {
                Text("No track selected")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(16)
    }
}

// MARK: -

private struct TrackTimingEditor: View {
    let entry: SetlistEntry
    let onDone: () -> Void

    @EnvironmentObject var appState: AppState

    @State private var waveform: WaveformData? = nil
    @State private var isLoading = false
    @State private var fullDuration: Double = 0
    @State private var startSec: Double = 0
    @State private var endSec: Double = 0
    @State private var startText: String = ""
    @State private var endText: String = ""

    private let minGap: Double = 0.1   // smallest allowed [start, end] window

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(entry.track.title)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            ZStack {
                if isLoading {
                    ProgressView()
                } else if let waveform {
                    WaveformRangeView(
                        samples: waveform.peaks,
                        duration: fullDuration,
                        startSec: $startSec,
                        endSec: $endSec
                    )
                    .frame(height: 70)
                } else {
                    Text("Waveform unavailable")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                timeField("Start", text: $startText) { commitStart() }
                timeField("End", text: $endText) { commitEnd() }
                Spacer()
                Button("Cancel") { onDone() }
                    .keyboardShortcut(.cancelAction)
                Button("Apply") { apply() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(fullDuration <= 0)
            }
        }
        .onAppear(perform: initialise)
        .task {
            isLoading = true
            // Fork adaptation: WaveformOverview (peaks, no duration) instead of
            // upstream's WaveformLoader; the duration comes from the entry or the file.
            let data = await WaveformOverview.shared.overview(url: entry.fileURL)
            if !data.peaks.isEmpty {
                waveform = data
                if fullDuration <= 0 { fullDuration = Self.fileDuration(url: entry.fileURL) }
                // Clamp defaults to the loaded duration now it's known.
                if endSec <= 0 || endSec > fullDuration { endSec = fullDuration }
                startSec = min(startSec, max(0, endSec - minGap))
                syncTextFromState()
            }
            isLoading = false
        }
        .onChange(of: startSec) { _ in syncTextFromState() }
        .onChange(of: endSec) { _ in syncTextFromState() }
    }

    private func initialise() {
        fullDuration = entry.duration ?? 0
        startSec = entry.trimStartSeconds ?? 0
        endSec = entry.trimEndSeconds ?? (fullDuration > 0 ? fullDuration : 0)
        syncTextFromState()
    }

    private static func fileDuration(url: URL) -> Double {
        guard let f = try? AVAudioFile(forReading: url), f.fileFormat.sampleRate > 0 else { return 0 }
        return Double(f.length) / f.fileFormat.sampleRate
    }

    private func timeField(_ label: String, text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 12)).foregroundColor(.secondary)
            TextField("m:ss.d", text: text)
                .font(.system(size: 13).monospacedDigit())
                .frame(width: 72)
                .onSubmit(onCommit)
        }
    }

    private func commitStart() {
        guard let v = parseTime(startText) else { syncTextFromState(); return }
        startSec = max(0, min(v, max(0, endSec - minGap)))
        syncTextFromState()
    }

    private func commitEnd() {
        guard let v = parseTime(endText) else { syncTextFromState(); return }
        let cap = fullDuration > 0 ? fullDuration : v
        endSec = min(cap, max(v, startSec + minGap))
        syncTextFromState()
    }

    private func apply() {
        commitStart(); commitEnd()
        // Whole-range selection = no trim.
        let noTrim = startSec <= 0 && (fullDuration <= 0 || endSec >= fullDuration)
        appState.setlist.setTrim(
            start: noTrim ? nil : startSec,
            end: noTrim ? nil : endSec,
            for: entry.id
        )
        onDone()
    }

    private func syncTextFromState() {
        startText = formatTime(startSec)
        endText = formatTime(endSec)
    }
}

// MARK: - Helpers

private func formatTime(_ seconds: Double) -> String {
    let total = max(0, seconds)
    let m = Int(total) / 60
    let s = total - Double(m * 60)
    return String(format: "%d:%04.1f", m, s)   // 1:05.4
}

/// Parses "m:ss.d" or a bare seconds count (both allow tenths); nil if unparseable.
private func parseTime(_ text: String) -> Double? {
    let t = text.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return nil }
    let parts = t.split(separator: ":")
    if parts.count == 2, let m = Int(parts[0]), let s = Double(parts[1]) {
        return Double(m * 60) + s
    }
    return Double(t)
}

// MARK: - Waveform with range handles

private struct WaveformRangeView: View {
    let samples: [Float]
    let duration: Double
    @Binding var startSec: Double
    @Binding var endSec: Double

    @State private var dragStartAnchor: Double = 0
    @State private var dragEndAnchor: Double = 0
    @State private var draggingStart = false
    @State private var draggingEnd = false

    private let handleWidth: CGFloat = 8
    private let minGap: Double = 0.1   // smallest allowed [start, end] window

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let startFrac = duration > 0 ? startSec / duration : 0
            let endFrac = duration > 0 ? endSec / duration : 1

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    guard !samples.isEmpty else { return }
                    let barWidth = size.width / CGFloat(samples.count)
                    let startX = CGFloat(startFrac) * size.width
                    let endX = CGFloat(endFrac) * size.width
                    for (i, sample) in samples.enumerated() {
                        let x = CGFloat(i) * barWidth
                        let height = max(2, CGFloat(sample) * size.height * 0.9)
                        let rect = CGRect(x: x, y: (size.height - height) / 2,
                                          width: max(1, barWidth - 0.5), height: height)
                        let mid = x + barWidth * 0.5
                        let inRange = mid >= startX && mid <= endX
                        context.fill(Path(rect),
                                     with: .color(inRange ? Color.primary : Color.secondary.opacity(0.25)))
                    }
                }

                handle(color: .green)
                    .offset(x: CGFloat(startFrac) * w - handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !draggingStart { draggingStart = true; dragStartAnchor = startSec }
                                let delta = Double(drag.translation.width / w) * duration
                                startSec = max(0, min(endSec - minGap, dragStartAnchor + delta))
                            }
                            .onEnded { _ in draggingStart = false }
                    )

                handle(color: .red)
                    .offset(x: CGFloat(endFrac) * w - handleWidth / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                if !draggingEnd { draggingEnd = true; dragEndAnchor = endSec }
                                let delta = Double(drag.translation.width / w) * duration
                                endSec = min(duration, max(startSec + minGap, dragEndAnchor + delta))
                            }
                            .onEnded { _ in draggingEnd = false }
                    )
            }
        }
    }

    private func handle(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: handleWidth)
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}
