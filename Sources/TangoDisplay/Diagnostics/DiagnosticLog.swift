// DiagnosticLog.swift
// App-layer diagnostics facade: breadcrumb recording, OSLog subsystem,
// and signpost helpers for the drop path.
//
// All `record`/`clear` calls are expected from the main thread.
// `lastBreadcrumb` is read from the FreezeWatchdog background queue
// → protected by an NSLock.
//
// Gated by AppSettings.diagnosticLoggingEnabled: when disabled, record()
// is a no-op and no OSLog activity is generated.

import Foundation
import TangoDisplayCore
import os.log
import os.signpost

// MARK: - DiagnosticLog

final class DiagnosticLog {

    static let shared = DiagnosticLog()

    // OSLog subsystem shared across all diagnostic categories.
    static let subsystem = "com.tangodisplay"

    // Dedicated category so diagnostic noise is filterable:
    //   log show --predicate 'subsystem == "com.tangodisplay" AND category == "diagnostics"'
    let log = OSLog(subsystem: subsystem, category: "diagnostics")
    let dropLog = OSLog(subsystem: subsystem, category: "musicdrop.timing")

    // Signpost log for Instruments / Console timing spans.
    let signpostLog = OSLog(subsystem: subsystem, category: OSLog.Category.pointsOfInterest)

    // MARK: - Breadcrumb

    private var _trail = BreadcrumbTrail()
    private let lock = NSLock()

    /// Most recently recorded breadcrumb — safe to read from any queue.
    var lastBreadcrumb: String {
        lock.lock(); defer { lock.unlock() }
        return _trail.last
    }

    /// Record a breadcrumb identifying the current high-risk section.
    /// Call on main thread before entering a section that may block.
    /// Call `clearBreadcrumb()` when the section exits normally.
    func record(_ crumb: String) {
        lock.lock()
        _trail.record(crumb)
        lock.unlock()
    }

    /// Clear the breadcrumb after the risky section completes without stall.
    func clearBreadcrumb() {
        lock.lock()
        _trail.clear()
        lock.unlock()
    }

    // MARK: - Drop-path timing helpers

    /// Start a signpost interval (gated by `enabled`).
    func beginInterval(_ name: StaticString, enabled: Bool) -> OSSignpostID {
        guard enabled else { return OSSignpostID.exclusive }
        let id = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: name, signpostID: id)
        return id
    }

    /// End a signpost interval previously started with `beginInterval`.
    func endInterval(_ name: StaticString, id: OSSignpostID, enabled: Bool) {
        guard enabled, id != OSSignpostID.exclusive else { return }
        os_signpost(.end, log: signpostLog, name: name, signpostID: id)
    }

    /// Log a timing measurement on the drop path.
    func logTiming(_ message: String, elapsed: TimeInterval, enabled: Bool) {
        guard enabled else { return }
        os_log("⏱ %{public}@ (%.0f ms)", log: dropLog, type: .info, message, elapsed * 1000)
    }

    private init() {}
}
