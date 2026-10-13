import Foundation
import TangoDisplayCore

func runEngineRecoveryTests() {
    suite("hogClaim — never re-set hog mode on a device we already own") {
        test("hog mode off: nothing to claim") {
            try expectEqual(hogClaim(hogEnabled: false, hasDevice: true, owner: -1, ownPID: 42), .notWanted)
        }
        test("System Default (no pinned device) is never hogged") {
            try expectEqual(hogClaim(hogEnabled: true, hasDevice: false, owner: -1, ownPID: 42), .notWanted)
        }
        test("a free device is acquired") {
            try expectEqual(hogClaim(hogEnabled: true, hasDevice: true, owner: -1, ownPID: 42), .acquire)
        }
        test("a device we still own is kept — setting the property again would RELEASE it") {
            try expectEqual(hogClaim(hogEnabled: true, hasDevice: true, owner: 42, ownPID: 42), .alreadyOurs)
        }
        test("a device another process owns is a conflict") {
            try expectEqual(hogClaim(hogEnabled: true, hasDevice: true, owner: 7, ownPID: 42), .heldByOther)
        }
    }

    suite("deviceHeldByOther — hog theft detection") {
        test("free device") { try expect(!deviceHeldByOther(hasDevice: true, owner: -1, ownPID: 42)) }
        test("our own claim is not theft") { try expect(!deviceHeldByOther(hasDevice: true, owner: 42, ownPID: 42)) }
        test("another pid is theft") { try expect(deviceHeldByOther(hasDevice: true, owner: 7, ownPID: 42)) }
        test("System Default cannot be stolen") { try expect(!deviceHeldByOther(hasDevice: false, owner: 7, ownPID: 42)) }
    }

    suite("engineRecoveryOutcome — what the UI does after a restart attempt") {
        test("a stolen device wins over everything else") {
            try expectEqual(engineRecoveryOutcome(deviceHeldByOther: true, engineStarted: true), .deviceStolen)
            try expectEqual(engineRecoveryOutcome(deviceHeldByOther: true, engineStarted: false), .deviceStolen)
        }
        test("an engine that never came back is a stall, not a resume") {
            try expectEqual(engineRecoveryOutcome(deviceHeldByOther: false, engineStarted: false), .stalled)
        }
        test("a restarted engine resumes") {
            try expectEqual(engineRecoveryOutcome(deviceHeldByOther: false, engineStarted: true), .resumed)
        }
    }

    suite("engineNeedsRecovery — leave a healthy engine alone") {
        test("a stopped engine always needs recovery") {
            try expect(engineNeedsRecovery(isRunning: false, currentDevice: 5, wantedDevice: 5))
        }
        test("running on the wanted device: nothing to do, no audible gap") {
            try expect(!engineNeedsRecovery(isRunning: true, currentDevice: 5, wantedDevice: 5))
        }
        test("running on another device (the engine fell back to the default) needs recovery") {
            try expect(engineNeedsRecovery(isRunning: true, currentDevice: 9, wantedDevice: 5))
        }
        test("an unknown device on either side is never assumed healthy") {
            try expect(engineNeedsRecovery(isRunning: true, currentDevice: nil, wantedDevice: 5))
            try expect(engineNeedsRecovery(isRunning: true, currentDevice: 5, wantedDevice: nil))
            try expect(engineNeedsRecovery(isRunning: true, currentDevice: nil, wantedDevice: nil))
        }
    }

    suite("EngineRestartPolicy") {
        test("retries cover a device that takes seconds to return after wake") {
            try expect(Double(EngineRestartPolicy.attempts - 1) * EngineRestartPolicy.retryInterval >= 4)
        }
    }
}
