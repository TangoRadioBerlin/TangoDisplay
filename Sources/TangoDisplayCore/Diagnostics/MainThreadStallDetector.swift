// MainThreadStallDetector.swift
// Pure, AppKit-free logic that determines whether the main thread is stalled.
//
// Usage pattern (App layer):
//   - A background timer fires every `intervalSeconds`.
//   - On each fire, `beatsRequested` is incremented and a block is posted
//     to the main queue to increment `beatsServiced`.
//   - `check(beatsRequested:beatsServiced:)` is called on each timer fire;
//     if the gap exceeds `thresholdBeats`, the main thread is stalled.

import Foundation

// MARK: - MainThreadStallDetector

/// Determines whether a main-thread stall is occurring based on heartbeat counts.
///
/// The caller maintains two monotonically increasing counters:
///   - `beatsRequested`: incremented each timer tick (on background queue)
///   - `beatsServiced`:  incremented when main queue drains the heartbeat (on background queue, via double-hop)
///
/// A gap >= `thresholdBeats` between the two signals a stall.
public struct MainThreadStallDetector {

    // MARK: - Types

    public enum StallResult: Equatable {
        case ok
        case stalled(duration: TimeInterval)
    }

    // MARK: - Configuration

    /// Interval between heartbeat ticks (seconds).
    public let intervalSeconds: TimeInterval
    /// Minimum stall duration to report (seconds).
    public let thresholdSeconds: TimeInterval

    /// Number of missed beats that constitutes a stall.
    public var thresholdBeats: Int {
        max(1, Int((thresholdSeconds / intervalSeconds).rounded(.up)))
    }

    // MARK: - Init

    public init(intervalSeconds: TimeInterval = 0.2, thresholdSeconds: TimeInterval = 2.0) {
        self.intervalSeconds = intervalSeconds
        self.thresholdSeconds = thresholdSeconds
    }

    // MARK: - API

    /// Returns `.stalled(duration:)` when `beatsRequested - beatsServiced >= thresholdBeats`.
    public func check(beatsRequested: Int, beatsServiced: Int) -> StallResult {
        let missed = beatsRequested - beatsServiced
        guard missed >= thresholdBeats else { return .ok }
        return .stalled(duration: TimeInterval(missed) * intervalSeconds)
    }
}

// MARK: - BreadcrumbTrail

/// Holds a single "last seen" breadcrumb string used to identify where the
/// main thread was when a stall occurred.  Kept in Core so the detection
/// logic can be tested without AppKit/OSLog.
///
/// Thread-safety is the caller's responsibility (App layer uses a lock).
public struct BreadcrumbTrail {

    private var _last: String = ""

    public init() {}

    /// The most recently recorded breadcrumb, or `""` if none.
    public var last: String { _last }

    /// Record a new breadcrumb (replaces the previous one).
    public mutating func record(_ crumb: String) {
        _last = crumb
    }

    /// Clear the breadcrumb (e.g. after the risky section completes).
    public mutating func clear() {
        _last = ""
    }

    /// Human-readable description for log messages.
    public func formatted() -> String {
        _last.isEmpty ? "<none>" : _last
    }
}
