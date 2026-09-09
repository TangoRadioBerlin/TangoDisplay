import Foundation
import Combine

/// Transport-agnostic surface used by `RemoteControlBridge`.
/// v1 ships only `HTTPServerTransport`; a future BLE transport could conform without
/// touching the bridge.
protocol RemoteTransport: AnyObject {
    var delegate: RemoteTransportDelegate? { get set }
    var connectionCount: Int { get }
    var connectionCountPublisher: AnyPublisher<Int, Never> { get }

    func start() throws

    /// Tear down the listener and all client connections. The completion fires once the
    /// underlying socket is fully cancelled and the port is released — important when
    /// the caller is about to start a new listener on the same port.
    func stop(completion: @escaping @Sendable () -> Void)

    /// Send a UTF-8 text frame to every connected client.
    func broadcast(_ text: String)

    /// Send a UTF-8 text frame to a specific client.
    func send(_ text: String, to clientID: UUID)

    /// Forcibly drop a client (used after auth failure).
    func disconnect(_ clientID: UUID)

    /// The remote host (IP address) of a connected client, or nil if unknown/already
    /// disconnected. Used to key PIN rate-limiting per identity rather than globally.
    func remoteHost(for clientID: UUID) -> String?
}

protocol RemoteTransportDelegate: AnyObject {
    func transport(_ transport: RemoteTransport, didConnect clientID: UUID)
    func transport(_ transport: RemoteTransport, didDisconnect clientID: UUID)
    func transport(_ transport: RemoteTransport, didReceiveText text: String, from clientID: UUID)
}
