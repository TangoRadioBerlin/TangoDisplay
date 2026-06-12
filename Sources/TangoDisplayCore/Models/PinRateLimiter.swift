import Foundation

/// Throttles PIN brute-force attempts against the Setlist Remote.
///
/// Remote clients have no stable identity (each connection gets a fresh UUID,
/// no source IP is exposed), so the limiter is global: after `maxAttempts`
/// consecutive failures, authentication locks for `baseLockout` seconds, and
/// every further failure doubles the next lockout up to `maxLockout`. A
/// successful authentication resets everything.
///
/// Time is injected (seconds on any monotonic clock) so the logic is testable.
public struct PinRateLimiter {
    private let maxAttempts: Int
    private let baseLockout: TimeInterval
    private let maxLockout: TimeInterval

    private var failureCount = 0
    private var lockoutsServed = 0
    private var lockedUntil: TimeInterval?

    public init(maxAttempts: Int = 5,
                baseLockout: TimeInterval = 5,
                maxLockout: TimeInterval = 300) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseLockout = baseLockout
        self.maxLockout = maxLockout
    }

    public func isLocked(at now: TimeInterval) -> Bool {
        guard let lockedUntil else { return false }
        return now < lockedUntil
    }

    public mutating func registerFailure(at now: TimeInterval) {
        failureCount += 1
        // Once a lockout has been served, every further failure re-locks
        // immediately (with doubled duration) — no fresh grace window.
        guard lockoutsServed > 0 || failureCount >= maxAttempts else { return }
        let duration = min(maxLockout, baseLockout * pow(2.0, Double(lockoutsServed)))
        lockedUntil = now + duration
        lockoutsServed += 1
        failureCount = 0
    }

    public mutating func registerSuccess() {
        failureCount = 0
        lockoutsServed = 0
        lockedUntil = nil
    }
}
