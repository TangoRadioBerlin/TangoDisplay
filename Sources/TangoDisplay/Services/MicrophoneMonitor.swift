import Accelerate
import AVFoundation
import CoreAudio
import CoreMedia
import Foundation
import os
import TangoDisplayCore

/// Monitors the built-in microphone and publishes room level as an integer on 0–140.
///
/// Uses an `AVCaptureSession` (input-only) rather than `AVAudioEngine`: starting an
/// `AVAudioEngine` after touching its `inputNode` also activates an **output** node, which forces
/// a reconfiguration of the shared audio device and interrupts other apps' playback (and headphone
/// pre-listen). A capture session only opens the input device, so playback output is left alone.
///
/// Threading contract:
///   • captureOutput(_:didOutput:from:) fires on a private serial queue (the audio I/O thread).
///     It only writes to rawLock — never touches @Published properties.
///   • A 30 fps Timer on RunLoop.main reads the lock and updates @Published properties.
///   • start() / stop() must be called on the main thread.
final class MicrophoneMonitor: NSObject, ObservableObject {

    // MARK: - Published state (main-thread only)

    @Published private(set) var level: Int = 0
    @Published private(set) var permissionDenied: Bool = false

    // MARK: - Configuration

    /// User calibration in dB, added to the SPL-like mapping (see
    /// `splDecibels` in Core) so the built-in microphone can be matched to
    /// an external sound level meter. Main-thread only.
    private var calibrationOffsetDb: Double = 0

    /// Averaging window for the displayed level. Main-thread only (the
    /// averager is read/written from the display timer).
    private var averager = LevelAverager(windowSeconds: 2)

    // MARK: - Private types

    /// Energy accumulated by the capture callback since the display timer
    /// last drained it — every buffer counts, none is skipped.
    private struct RawEnergy {
        var sumSquares: Double = 0
        var sampleCount: Int = 0
    }

    // MARK: - Private state

    private let session = AVCaptureSession()
    private let output = AVCaptureAudioDataOutput()
    private let sampleQueue = DispatchQueue(label: "TangoDisplay.micMeter")
    private let rawLock = OSAllocatedUnfairLock(initialState: RawEnergy())
    private var displayTimer: Timer?
    private var runtimeErrorObserver: NSObjectProtocol?
    private var isRunning = false

    /// Unique ID of the input device to listen to. `nil` = built-in microphone.
    private var deviceUID: String?

    private let log = Logger(subsystem: "com.local.tangodisplay", category: "MicrophoneMonitor")

    /// Audio input device types we enumerate (built-in + external interfaces).
    private static var inputDeviceTypes: [AVCaptureDevice.DeviceType] {
        if #available(macOS 14.0, *) { return [.microphone, .external] }
        return [.builtInMicrophone]
    }

    /// Devices the user can pick from for the meter (uid + display name).
    static func availableInputDevices() -> [(uid: String, name: String)] {
        AVCaptureDevice.DiscoverySession(deviceTypes: inputDeviceTypes,
                                         mediaType: .audio, position: .unspecified)
            .devices.map { (uid: $0.uniqueID, name: $0.localizedName) }
    }

    // MARK: - Public API

    func start() {
        guard !isRunning else { return }
        permissionDenied = false
        requestPermissionAndStart()
    }

    func stop() {
        guard isRunning else { return }
        tearDown()
    }

    /// Calibration offset in dB (matches the meter to an external SPL meter). Takes effect
    /// on the next display update; no capture restart needed.
    func configure(calibrationOffsetDb: Int) {
        self.calibrationOffsetDb = Double(calibrationOffsetDb)
    }

    /// Averaging window in seconds; larger = calmer reading. Takes effect immediately.
    func configure(averagingSeconds: Double) {
        averager.windowSeconds = max(0.1, averagingSeconds)
    }

    /// Selects the input device (`nil` = built-in microphone) and restarts capture if running.
    func configure(deviceUID: String?) {
        guard deviceUID != self.deviceUID else { return }
        self.deviceUID = deviceUID
        guard isRunning else { return }
        stop()
        start()
    }

    // MARK: - Permission + session lifecycle

    private func requestPermissionAndStart() {
        // Use the AVCaptureDevice authorization that actually gates AVCaptureSession audio input.
        // (AVAudioApplication.recordPermission is the AVAudioSession permission and does not
        // reliably reflect the capture-device TCC grant on macOS.)
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startSession()
        case .denied, .restricted:
            permissionDenied = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startSession() }
                    else       { self?.permissionDenied = true }
                }
            }
        @unknown default:
            startSession()
        }
    }

    /// Resolves the input device: an explicitly selected UID, else the built-in microphone
    /// (preferred over the system default, which may be a pro interface with no live signal),
    /// else the system default.
    private func resolveInputDevice() -> AVCaptureDevice? {
        if let uid = deviceUID, let d = AVCaptureDevice(uniqueID: uid) { return d }
        // Default = the real built-in microphone, found via CoreAudio's transport type. The
        // AVCaptureDevice `.builtInMicrophone`/`.microphone` discovery is unreliable here: the
        // legacy type returns nothing on recent macOS, and virtual/aggregate devices (MMAudio,
        // Teams, NoMachine, …) also advertise as `.microphone` with no room signal.
        if let uid = Self.builtInInputDeviceUID(), let d = AVCaptureDevice(uniqueID: uid) { return d }
        return AVCaptureDevice.default(for: .audio)
    }

    /// CoreAudio UID of the physical built-in input device (transport type "built-in" with input
    /// streams). AVCaptureDevice's `uniqueID` for audio equals this CoreAudio UID.
    private static func builtInInputDeviceUID() -> String? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &devicesAddr, 0, nil, &size) == noErr, size > 0 else { return nil }
        var deviceIDs = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &devicesAddr, 0, nil, &size, &deviceIDs) == noErr else { return nil }

        for id in deviceIDs {
            // Require at least one input stream.
            var streamsAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var streamsSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streamsAddr, 0, nil, &streamsSize) == noErr, streamsSize > 0 else { continue }

            // Transport type must be built-in.
            var transport: UInt32 = 0
            var transportSize = UInt32(MemoryLayout<UInt32>.size)
            var transportAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyTransportType,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(id, &transportAddr, 0, nil, &transportSize, &transport) == noErr,
                  transport == kAudioDeviceTransportTypeBuiltIn else { continue }

            // Read the device UID.
            var uid: CFString = "" as CFString
            var uidSize = UInt32(MemoryLayout<CFString>.size)
            var uidAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            guard AudioObjectGetPropertyData(id, &uidAddr, 0, nil, &uidSize, &uid) == noErr else { continue }
            return uid as String
        }
        return nil
    }

    private func startSession() {
        // B3: guard against a second call (e.g. TCC prompt race) leaking the previous timer
        // and notification observer — tear them down before recreating.
        displayTimer?.invalidate()
        displayTimer = nil
        if let obs = runtimeErrorObserver {
            NotificationCenter.default.removeObserver(obs)
            runtimeErrorObserver = nil
        }

        guard let device = resolveInputDevice(),
              let input = try? AVCaptureDeviceInput(device: device) else {
            log.error("Decibel meter: no usable audio input device (requested uid=\(self.deviceUID ?? "built-in", privacy: .public))")
            permissionDenied = true
            return
        }
        log.info("Decibel meter input: \(device.localizedName, privacy: .public) [\(device.uniqueID, privacy: .public)]")

        session.beginConfiguration()
        for existing in session.inputs { session.removeInput(existing) }
        for existing in session.outputs { session.removeOutput(existing) }
        if session.canAddInput(input) { session.addInput(input) }
        output.setSampleBufferDelegate(self, queue: sampleQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()

        runtimeErrorObserver = NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError, object: session, queue: .main
        ) { [weak self] _ in
            guard let self, self.isRunning else { return }
            self.sampleQueue.async { [weak self] in
                guard let self, self.isRunning, !self.session.isRunning else { return }
                self.session.startRunning()
            }
        }

        isRunning = true
        permissionDenied = false
        // startRunning blocks; keep it off the main thread.
        sampleQueue.async { [weak self] in
            guard let self else { return }
            self.session.startRunning()
            self.log.info("Decibel meter capture session running=\(self.session.isRunning, privacy: .public)")
        }

        // 10 Hz is plenty: the toolbar throttles to 250 ms anyway and the
        // averager, not the timer rate, defines the meter's response.
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateDisplay()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func tearDown() {
        isRunning = false
        displayTimer?.invalidate()
        displayTimer = nil
        if let obs = runtimeErrorObserver {
            NotificationCenter.default.removeObserver(obs)
            runtimeErrorObserver = nil
        }
        sampleQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
        rawLock.withLock { $0 = RawEnergy() }
        averager.reset()
        level = 0
    }

    // MARK: - Main-thread display update (10 Hz)

    private func updateDisplay() {
        // Drain everything captured since the last tick into the averager.
        let energy = rawLock.withLock { e -> RawEnergy in
            let snapshot = e
            e = RawEnergy()
            return snapshot
        }
        let now = CACurrentMediaTime()
        averager.add(sumSquares: energy.sumSquares, sampleCount: energy.sampleCount, at: now)
        let db = splDecibels(meanSquare: averager.meanSquare(at: now), calibrationOffset: calibrationOffsetDb)
        let newLevel = meterLevel(decibels: db)
        if newLevel != level { level = newLevel }
    }

    // MARK: - deinit

    deinit {
        displayTimer?.invalidate()
        if let obs = runtimeErrorObserver {
            NotificationCenter.default.removeObserver(obs)
        }
        if session.isRunning { session.stopRunning() }
    }
}

// MARK: - Sample delegate (audio I/O thread — no main-thread work here)

extension MicrophoneMonitor: AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let fmt = CMSampleBufferGetFormatDescription(sampleBuffer),
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)?.pointee else { return }

        var blockBuffer: CMBlockBuffer?
        var abl = AudioBufferList()
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &abl,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer)
        guard status == noErr else { return }

        let isFloat = (asbd.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let bits = asbd.mBitsPerChannel
        var sumSquares: Double = 0
        var sampleCount = 0

        for buf in UnsafeMutableAudioBufferListPointer(&abl) {
            guard let data = buf.mData, buf.mDataByteSize > 0 else { continue }
            if isFloat && bits == 32 {
                let n = Int(buf.mDataByteSize) / MemoryLayout<Float>.size
                guard n > 0 else { continue }
                var rms: Float = 0
                vDSP_rmsqv(data.bindMemory(to: Float.self, capacity: n), 1, &rms, vDSP_Length(n))
                sumSquares += Double(rms) * Double(rms) * Double(n)
                sampleCount += n
            } else if !isFloat && bits == 16 {
                let n = Int(buf.mDataByteSize) / MemoryLayout<Int16>.size
                guard n > 0 else { continue }
                var floats = [Float](repeating: 0, count: n)
                vDSP_vflt16(data.bindMemory(to: Int16.self, capacity: n), 1, &floats, 1, vDSP_Length(n))
                var scale: Float = 1.0 / 32768.0
                vDSP_vsmul(floats, 1, &scale, &floats, 1, vDSP_Length(n))
                var rms: Float = 0
                vDSP_rmsqv(floats, 1, &rms, vDSP_Length(n))
                sumSquares += Double(rms) * Double(rms) * Double(n)
                sampleCount += n
            }
        }

        guard sampleCount > 0 else { return }
        let chunkSum = sumSquares, chunkCount = sampleCount
        rawLock.withLock {
            $0.sumSquares += chunkSum
            $0.sampleCount += chunkCount
        }
    }
}
