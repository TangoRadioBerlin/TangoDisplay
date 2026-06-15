import AppKit
import Foundation
import TangoDisplayCore

/// Polls Music.app every 2 seconds via AppleScriptBridge.
///
/// Uses a DispatchSourceTimer rescheduled after each poll (not a repeating timer)
/// so slow AppleScript calls never queue up.
///
/// Also subscribes to `com.apple.Music.playerInfo` via DistributedNotificationCenter
/// to trigger an immediate poll on track/state changes, mirroring EmbracMonitor's
/// push+poll strategy. The 2-second fallback polling and watchdog backoff are unchanged.
///
/// Watchdog: 3 consecutive failures → enter backoff mode (2→4→8…→30s).
/// Recovery: first success after watchdog → reset to 2s.
final class MusicPoller {

    private let bridge = AppleScriptBridge()
    private let timerQueue = DispatchQueue(label: "com.tangodisplay.pollertimer", qos: .utility)

    private static let updateNotification = "com.apple.Music.playerInfo"
    private var notificationObserver: AnyObject?

    private var timer: DispatchSourceTimer?
    private var pollCount = 0
    private var consecutiveFailures = 0
    private var currentInterval: TimeInterval = 2.0
    private let normalInterval: TimeInterval = 2.0
    private let maxInterval: TimeInterval = 30.0
    private let failuresBeforeWatchdog = 3
    private let playlistPollEvery = 10  // poll playlist every Nth track poll

    // MARK: - Callbacks (always delivered on main queue)

    var onTrackUpdate: ((Track?, PlayerState) -> Void)?
    var onPlaylistUpdate: ((tracks: [Track], currentIndex: Int)?) -> Void = { _ in }
    var onNextTrackUpdate: ((Track?) -> Void)? = nil
    var onWatchdogChanged: ((Bool) -> Void)?

    // MARK: - Lifecycle

    func start() {
        bridge.compile()

        let observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(Self.updateNotification),
            object: nil,
            queue: nil   // delivered on whatever thread DNC chooses; we dispatch to timerQueue
        ) { [weak self] _ in
            self?.notificationTriggeredPoll()
        }
        notificationObserver = observer

        schedulePoll(after: normalInterval)
    }

    func stop() {
        timer?.cancel()
        timer = nil
        if let observer = notificationObserver {
            DistributedNotificationCenter.default().removeObserver(observer)
            notificationObserver = nil
        }
    }

    /// Trigger an immediate poll (e.g. from ⌘⇧R hotkey).
    func pollNow() {
        timer?.cancel()
        timer = nil
        doPoll()
    }

    /// Immediately fetch playlist context outside the normal poll cycle.
    /// Used by AppState when transitioning tracks without usable playlist data.
    func triggerPlaylistFetch() {
        bridge.fetchPlaylistContext { [weak self] result in
            guard let self else { return }
            let context = try? result.get()
            DispatchQueue.main.async {
                self.onPlaylistUpdate(context)
            }
        }
    }

    // MARK: - Internal scheduling

    private func notificationTriggeredPoll() {
        timerQueue.async { [weak self] in
            guard let self else { return }
            self.timer?.cancel()
            self.timer = nil
            self.doPoll()
        }
    }

    private func schedulePoll(after interval: TimeInterval) {
        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + interval)
        t.setEventHandler { [weak self] in
            self?.doPoll()
        }
        t.resume()
        timer?.cancel()   // release any previous source before replacing it
        timer = t
    }

    private func doPoll() {
        pollCount += 1
        let shouldPollPlaylist = (pollCount % playlistPollEvery == 0)

        bridge.fetchCurrentTrack { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let (track, state)):
                self.handleSuccess()
                DispatchQueue.main.async {
                    self.onTrackUpdate?(track, state)
                }
                if shouldPollPlaylist {
                    self.bridge.fetchPlaylistContext { [weak self] playlistResult in
                        guard let self else { return }
                        let context = try? playlistResult.get()
                        DispatchQueue.main.async {
                            self.onPlaylistUpdate(context)
                        }
                        self.schedulePoll(after: self.currentInterval)
                    }
                } else {
                    self.schedulePoll(after: self.currentInterval)
                }

            case .failure(let error):
                NSLog("TangoDisplay: poll error: %@", error.localizedDescription)
                self.handleFailure()
                DispatchQueue.main.async {
                    self.onTrackUpdate?(nil, .stopped)
                }
                self.schedulePoll(after: self.currentInterval)
            }
        }
    }

    private func handleSuccess() {
        let wasWatchdog = consecutiveFailures >= failuresBeforeWatchdog
        consecutiveFailures = 0
        currentInterval = normalInterval
        if wasWatchdog {
            DispatchQueue.main.async { [weak self] in
                self?.onWatchdogChanged?(false)
            }
        }
    }

    private func handleFailure() {
        consecutiveFailures += 1
        if consecutiveFailures == failuresBeforeWatchdog {
            DispatchQueue.main.async { [weak self] in
                self?.onWatchdogChanged?(true)
            }
        }
        if consecutiveFailures >= failuresBeforeWatchdog {
            currentInterval = min(currentInterval * 2, maxInterval)
        }
    }
}

extension MusicPoller: MusicPlayerSource {
    func fetchArtwork(for track: Track) async -> NSImage? {
        await withCheckedContinuation { continuation in
            bridge.fetchCurrentArtwork { image in
                continuation.resume(returning: image)
            }
        }
    }
}
