import SwiftUI
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Darwin
import SystemConfiguration

/// The "Setlist Remote" section of the Player settings tab. Toggles the embedded
/// HTTP/WebSocket server, displays the URL, PIN and QR code for the phone to scan,
/// and shows how many clients are currently connected.
struct SetlistRemoteSettingsSection: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject var bridge: RemoteControlBridge

    @State private var localHostname: String = ""
    @State private var localIP: String = ""

    private let port: Int = 4747

    var body: some View {
        Section {
            Toggle("Enable Setlist Remote", isOn: $settings.remoteControlEnabled)

            Text("Lets an iPhone or other device on the same Wi-Fi adjust volume, cortina volume, and replay gain through a small built-in web page.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if settings.remoteControlEnabled {
                if let error = bridge.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    enabledContent
                }
            }
        } header: {
            Text("Setlist Remote")
                .font(.title3.bold())
                .foregroundColor(.white)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private var enabledContent: some View {
        let primaryURL = primaryURLString
        let hostnameURL = hostnameURLString

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Allow remote setlist control", isOn: $settings.remoteControlAllowSetlistControl)
                Text("Lets a connected controller (e.g. a planning app) drive transport — play/pause, next/previous, fade — and broadcasts the full setlist. Leave off for the read-only phone remote.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if primaryURL.isEmpty {
                Label("No network address available — connect to Wi-Fi and reopen this tab.",
                      systemImage: "wifi.exclamationmark")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        urlRow(label: "URL", value: primaryURL)
                        if !hostnameURL.isEmpty && hostnameURL != primaryURL {
                            urlRow(label: "Or", value: hostnameURL)
                        }
                        pinRow
                        connectedRow
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let qr = qrImage(for: primaryURL) {
                        Image(nsImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 120, height: 120)
                            .background(Color.white)
                            .cornerRadius(6)
                    }
                }
            }

            HStack(spacing: 8) {
                Button("Regenerate PIN") {
                    settings.regenerateRemoteControlPin()
                }
                Button("Refresh URL") {
                    refreshNetworkInfo()
                }
                Button("Open in Browser") {
                    if let url = URL(string: primaryURL) {
                        NSWorkspace.shared.open(url)
                    }
                }
                .disabled(primaryURL.isEmpty)
            }
            .font(.caption)

            Text("Scan the QR code from your iPhone. Anyone on this Wi-Fi who knows the PIN can connect, so the PIN regenerates each time TangoDisplay launches.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .onChange(of: settings.remoteControlEnabled) { _ in refreshNetworkInfo() }
        .onAppear(perform: refreshNetworkInfo)
    }

    private func urlRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)
        }
    }

    private var pinRow: some View {
        HStack(spacing: 8) {
            Text("PIN")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            Text(settings.remoteControlPin)
                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                .tracking(4)
                .foregroundColor(ControlTheme.accent)
                .textSelection(.enabled)
        }
    }

    private var connectedRow: some View {
        HStack(spacing: 8) {
            Text("Connected")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            let count = bridge.connectionCount
            Text(count == 1 ? "1 device" : "\(count) devices")
                .font(.system(size: 12))
                .foregroundColor(count > 0 ? ControlTheme.accent : .secondary)
        }
    }

    // MARK: - URL helpers

    /// The URL we surface as the primary one (encoded into the QR). We prefer the IP
    /// because it always resolves on the same subnet, whereas `.local` depends on the
    /// phone successfully resolving Bonjour and can fail silently.
    private var primaryURLString: String {
        if !localIP.isEmpty { return "http://\(localIP):\(port)" }
        if !localHostname.isEmpty { return "http://\(localHostname):\(port)" }
        return ""
    }

    private var ipURLString: String {
        guard !localIP.isEmpty else { return "" }
        return "http://\(localIP):\(port)"
    }

    private var hostnameURLString: String {
        guard !localHostname.isEmpty else { return "" }
        return "http://\(localHostname):\(port)"
    }

    private func refreshNetworkInfo() {
        localHostname = Self.bestLocalHostname()
        localIP = Self.firstLocalIPv4() ?? ""
    }

    /// Returns the `.local` hostname (Bonjour) when available, sourced in priority
    /// order: SystemConfiguration's authoritative Bonjour name, then the BSD hostname.
    /// Filters known-bad placeholders (`unknown`, `localhost`) so the UI never shows
    /// an unresolvable URL like `unknown.local`.
    private static func bestLocalHostname() -> String {
        let bad: Set<String> = ["unknown", "localhost", "unknown.local", "localhost.local", ""]

        if let cf = SCDynamicStoreCopyLocalHostName(nil) as String? {
            let name = cf.trimmingCharacters(in: .whitespaces)
            if !bad.contains(name.lowercased()) {
                return name + ".local"
            }
        }

        let raw = ProcessInfo.processInfo.hostName.trimmingCharacters(in: .whitespaces)
        let lower = raw.lowercased()
        if raw.hasSuffix(".local") && !bad.contains(lower) {
            return raw
        }
        if !bad.contains(lower) {
            return raw + ".local"
        }
        return ""
    }

    /// Walks the interface list and returns the first non-loopback IPv4 address.
    private static func firstLocalIPv4() -> String? {
        var address: String?
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let addr = cur.pointee.ifa_addr
            if (flags & IFF_UP) == IFF_UP,
               (flags & IFF_LOOPBACK) == 0,
               let addr,
               addr.pointee.sa_family == sa_family_t(AF_INET) {
                let name = String(cString: cur.pointee.ifa_name)
                if name.hasPrefix("en") || name.hasPrefix("eth") || name.hasPrefix("bridge") {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                   &host, socklen_t(host.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        address = String(cString: host)
                        break
                    }
                }
            }
            ptr = cur.pointee.ifa_next
        }
        return address
    }

    // MARK: - QR

    private func qrImage(for text: String) -> NSImage? {
        guard !text.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let rep = NSCIImageRep(ciImage: scaled)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
