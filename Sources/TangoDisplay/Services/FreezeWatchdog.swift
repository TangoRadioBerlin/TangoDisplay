// FreezeWatchdog.swift
// Detects main-thread stalls via a background heartbeat timer.
//
// Mechanism:
//   1. A DispatchSourceTimer fires every `intervalSeconds` on `timerQueue`.
//   2. Each tick increments `beatsRequested` and posts a main-async block
//      whose only job is to double-hop back to `timerQueue` and increment
//      `beatsServiced`. Both counters are accessed exclusively on `timerQueue`.
//   3. `MainThreadStallDetector` checks the gap; a gap >= `thresholdBeats`
//      means the main thread cannot drain its queue → stall detected.
//   4. A `.fault`-level log fires ONCE per stall episode (not every tick),
//      and a `.info`-level recovery log fires when the gap clears.
//
// Usage: owned by AppState; started/stopped when AppSettings.diagnosticLoggingEnabled changes.

import Foundation
import TangoDisplayCore
import os.log

final class FreezeWatchdog {

    // MARK: - Configuration

    private static let intervalSeconds: TimeInterval = 0.2
    private static let thresholdSeconds: TimeInterval = 2.0

    // MARK: - State (all accessed on timerQueue)

    private let timerQueue = DispatchQueue(label: "com.tangodisplay.freeze-watchdog", qos: .background)
    private var timer: DispatchSourceTimer?
    private var beatsRequested = 0
    private var beatsServiced  = 0
    private var isCurrentlyStalled = false

    private let detector = MainThreadStallDetector(
        intervalSeconds: intervalSeconds,
        thresholdSeconds: thresholdSeconds
    )
    private let log: OSLog

    // MARK: - Init

    init() {
        self.log = DiagnosticLog.shared.log
    }

    // MARK: - Lifecycle

    /// Start the watchdog. Idempotent if already running.
    func start() {
        timerQueue.async { [weak self] in
            guard let self, self.timer == nil else { return }

            // Reset counters: an in-flight heartbeat can land after stop()'s reset
            // (its double-hop block runs regardless), leaving a permanent skew for
            // the next session if start() trusted the old values.
            self.beatsRequested = 0
            self.beatsServiced  = 0
            self.isCurrentlyStalled = false

            let t = DispatchSource.makeTimerSource(queue: self.timerQueue)
            t.schedule(
                deadline: .now() + Self.intervalSeconds,
                repeating: Self.intervalSeconds,
                leeway: .milliseconds(50)
            )
            t.setEventHandler { [weak self] in self?.tick() }
            t.resume()
            self.timer = t

            os_log("FreezeWatchdog started (interval=%.0fms threshold=%.0fs)",
                   log: self.log, type: .info,
                   Self.intervalSeconds * 1000, Self.thresholdSeconds)
        }
    }

    /// Stop the watchdog and reset counters.
    func stop() {
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.beatsRequested = 0
            self.beatsServiced  = 0
            self.isCurrentlyStalled = false
            os_log("FreezeWatchdog stopped", log: self.log, type: .info)
        }
    }

    // MARK: - Internal

    /// Called on `timerQueue` every `intervalSeconds`.
    private func tick() {
        beatsRequested += 1

        // Post a lightweight heartbeat to main. The block double-hops back
        // to timerQueue to keep counter mutations on a single queue.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timerQueue.async { self.beatsServiced += 1 }
        }

        // Check stall state.
        let result = detector.check(beatsRequested: beatsRequested, beatsServiced: beatsServiced)
        switch result {
        case .ok:
            if isCurrentlyStalled {
                isCurrentlyStalled = false
                os_log("🟢 MAIN THREAD RECOVERED; serviced=%d requested=%d",
                       log: log, type: .info, beatsServiced, beatsRequested)
            }
        case .stalled(let duration):
            if !isCurrentlyStalled {
                isCurrentlyStalled = true
                let crumb = DiagnosticLog.shared.lastBreadcrumb
                // .fault persists in the Unified Log and survives app force-quit.
                os_log("🔴 MAIN THREAD STALLED ≥%.0fs; last breadcrumb: %{public}@",
                       log: log, type: .fault, duration, crumb)
            }
        }
    }
}
