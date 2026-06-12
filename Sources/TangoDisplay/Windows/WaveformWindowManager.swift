import AppKit
import SwiftUI

/// Manages a single floating, freely positionable/resizable waveform panel. Frame persisted to UserDefaults.
@MainActor
enum WaveformWindowManager {
    private static var panel: NSPanel?
    private static var delegate: WaveformPanelDelegate?

    private static let kX = "TangoDisplay.waveformX"
    private static let kY = "TangoDisplay.waveformY"
    private static let kW = "TangoDisplay.waveformW"
    private static let kH = "TangoDisplay.waveformH"

    static func show(appState: AppState) {
        if let existing = panel {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }
        let d = UserDefaults.standard
        let width = (d.object(forKey: kW) as? Double) ?? 700
        let height = (d.object(forKey: kH) as? Double) ?? 200
        let originX = (d.object(forKey: kX) as? Double) ?? 200
        let originY = (d.object(forKey: kY) as? Double) ?? 200

        let p = NSPanel(
            contentRect: NSRect(x: originX, y: originY, width: width, height: height),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        p.title = "Waveform"
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.tabbingMode = .disallowed
        p.contentMinSize = NSSize(width: 320, height: 110)

        let root = WaveformView()
            .environmentObject(appState)
            .environmentObject(appState.settings)
        p.contentViewController = NSHostingController(rootView: root)

        let del = WaveformPanelDelegate()
        p.delegate = del
        delegate = del
        panel = p
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        p.orderFrontRegardless()
    }

    static func persist(_ window: NSWindow) {
        let f = window.frame
        let d = UserDefaults.standard
        d.set(Double(f.origin.x), forKey: kX)
        d.set(Double(f.origin.y), forKey: kY)
        d.set(Double(f.width), forKey: kW)
        d.set(Double(f.height), forKey: kH)
    }

    static func clear() {
        panel = nil
        delegate = nil
    }
}

final class WaveformPanelDelegate: NSObject, NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let w = notification.object as? NSWindow { WaveformWindowManager.persist(w) }
        WaveformWindowManager.clear()
    }
    func windowDidMove(_ notification: Notification) {
        if let w = notification.object as? NSWindow { WaveformWindowManager.persist(w) }
    }
    func windowDidResize(_ notification: Notification) {
        if let w = notification.object as? NSWindow { WaveformWindowManager.persist(w) }
    }
}
