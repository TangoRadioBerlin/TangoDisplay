import Foundation

/// What to do about CoreAudio hog mode (exclusive access) on the output device.
public enum HogClaim: Equatable {
    case notWanted     // hog mode off, or no pinned device
    case alreadyOurs   // we still own it — leave it alone
    case acquire       // free — take it
    case heldByOther   // another process owns it
}

/// `kAudioDevicePropertyHogMode` is a toggle, not a setter: writing it while this
/// process already owns the device *releases* it. So a claim is only ever made on
/// a free device. `owner` is the owning pid, -1 when the device is free.
public func hogClaim(hogEnabled: Bool, hasDevice: Bool, owner: Int32, ownPID: Int32) -> HogClaim {
    guard hogEnabled, hasDevice else { return .notWanted }
    if owner == -1 { return .acquire }
    return owner == ownPID ? .alreadyOurs : .heldByOther
}

/// Another process has taken exclusive access of the pinned output device.
public func deviceHeldByOther(hasDevice: Bool, owner: Int32, ownPID: Int32) -> Bool {
    hasDevice && owner != -1 && owner != ownPID
}

public enum EngineRecoveryOutcome: Equatable {
    case deviceStolen  // pause and tell the user who has the device
    case stalled       // engine would not restart — stop, offer Retry
    case resumed       // back up: re-seek and continue
}

public func engineRecoveryOutcome(deviceHeldByOther: Bool, engineStarted: Bool) -> EngineRecoveryOutcome {
    if deviceHeldByOther { return .deviceStolen }
    return engineStarted ? .resumed : .stalled
}

/// Whether a configuration-change or wake notification needs the stop → re-pin →
/// restart → re-seek sequence at all. That sequence is audible, so an engine that
/// is still running on the device the user chose is left untouched. Device IDs
/// are CoreAudio `AudioDeviceID`s; nil = could not be determined.
public func engineNeedsRecovery(isRunning: Bool, currentDevice: UInt32?, wantedDevice: UInt32?) -> Bool {
    guard isRunning, let currentDevice, let wantedDevice else { return true }
    return currentDevice != wantedDevice
}

/// After wake the output device can take seconds to reappear, so one restart
/// attempt is not enough.
public enum EngineRestartPolicy {
    public static let attempts = 10
    public static let retryInterval: TimeInterval = 0.5
}
