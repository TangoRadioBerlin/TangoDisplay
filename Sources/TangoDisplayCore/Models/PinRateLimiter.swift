import Foundation

/// Throttles PIN brute-force attempts against the Setlist Remote for ONE client
/// identity: after `maxAttempts` consecutive failures, authentication locks for
/// `baseLockout` seconds, and every further failure doubles the next lockout up
/// to `maxLockout`. A successful authentication resets everything.
///
/// Used through `PinRateLimiterRegistry` below, which keys one of these per
/// remote identity — a single shared instance would let any one identity's
/// failures lock out every other identity's (including the DJ's own) correct
/// PIN, since `isLocked` is checked before the PIN comparison.
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

/// One `PinRateLimiter` per client identity (the remote's IP address in practice),
/// so a brute-force attacker can only lock out their OWN identity instead of the
/// whole feature. A single global limiter — the original design, before the remote
/// transport exposed a per-connection host — meant anyone on the LAN could keep the
/// legitimate DJ permanently locked out too: `isLocked` is checked before the PIN
/// comparison, so even the correct PIN never gets a chance while a shared limiter
/// is locked.
///
/// Bounded at `maxBuckets`, evicting the least-recently-touched identity, so a flood
/// of spoofed/rotating identities can't grow this unboundedly. Evicting a locked
/// bucket does lift that identity's lockout — an accepted trade-off at any
/// `maxBuckets` large enough to cover a real event's device count (default 64).
public struct PinRateLimiterRegistry {
    /// Used when the transport cannot determine a remote host (should not normally
    /// happen) — falls back to the old global-limiter behavior rather than being
    /// left unprotected.
    public static let unknownHostKey = "unknown"

    private let maxAttempts: Int
    private let baseLockout: TimeInterval
    private let maxLockout: TimeInterval
    private let maxBuckets: Int

    private var buckets: [String: PinRateLimiter] = [:]
    private var order: [String] = []   // least-recently-touched first

    public init(maxAttempts: Int = 5, baseLockout: TimeInterval = 5,
                maxLockout: TimeInterval = 300, maxBuckets: Int = 64) {
        self.maxAttempts = maxAttempts
        self.baseLockout = baseLockout
        self.maxLockout = maxLockout
        self.maxBuckets = max(1, maxBuckets)
    }

    public var bucketCount: Int { buckets.count }

    public func isLocked(key: String, at now: TimeInterval) -> Bool {
        buckets[key]?.isLocked(at: now) ?? false
    }

    public mutating func registerFailure(key: String, at now: TimeInterval) {
        touch(key)
        var limiter = buckets[key] ?? PinRateLimiter(maxAttempts: maxAttempts,
                                                     baseLockout: baseLockout,
                                                     maxLockout: maxLockout)
        limiter.registerFailure(at: now)
        buckets[key] = limiter
    }

    public mutating func registerSuccess(key: String) {
        touch(key)
        buckets[key]?.registerSuccess()
    }

    /// Marks `key` as most-recently-touched; evicts the least-recently-touched
    /// OTHER key first if this touch would introduce a new bucket beyond `maxBuckets`.
    private mutating func touch(_ key: String) {
        if let idx = order.firstIndex(of: key) { order.remove(at: idx) }
        order.append(key)
        if buckets[key] == nil, buckets.count >= maxBuckets, let lru = order.first, lru != key {
            order.removeFirst()
            buckets.removeValue(forKey: lru)
        }
    }
}
