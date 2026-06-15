import Foundation

/// Resource bounds for the Setlist Remote HTTP/WebSocket server. Centralised and
/// unit-tested so the transport can't accumulate unbounded state from a client
/// that never completes its request (slowloris) or from a connection flood.
public enum RemoteServerLimits {
    /// Max bytes buffered while waiting for the end of the HTTP request headers
    /// (`\r\n\r\n`). A legitimate request is well under this; exceeding it means
    /// the client is stalling or hostile → respond 400 and close. (The 1 MiB
    /// WebSocket frame cap covers the post-handshake phase separately.)
    public static let maxHeaderBytes = 16 * 1024

    /// Max simultaneously accepted client connections; further ones are dropped.
    public static let maxConcurrentClients = 16

    public static func isHeaderOversized(bufferBytes: Int) -> Bool {
        bufferBytes > maxHeaderBytes
    }
}
