import Foundation
import Network
import Combine
import CryptoKit
import TangoDisplayCore

/// Minimal HTTP/1.1 + WebSocket server built on `NWListener`.
///
/// Serves a single static page (the bundled `index.html`) on `GET /`, and accepts
/// WebSocket upgrade requests on the same port. WebSocket framing is handled inline —
/// only single-frame text messages are supported (sufficient for the JSON control
/// protocol). Bonjour advertising is registered automatically via `NWListener.service`.
final class HTTPServerTransport: RemoteTransport {

    private let port: UInt16
    private let bonjourName: String
    private let htmlProvider: () -> Data
    private let queue = DispatchQueue(label: "com.tangodisplay.remote.transport")

    private var listener: NWListener?
    private var clients: [UUID: ClientConnection] = [:]

    private let connectionCountSubject = CurrentValueSubject<Int, Never>(0)

    weak var delegate: RemoteTransportDelegate?

    var connectionCount: Int { connectionCountSubject.value }
    var connectionCountPublisher: AnyPublisher<Int, Never> {
        connectionCountSubject.eraseToAnyPublisher()
    }

    /// Closure invoked when the listener fails (e.g. port already in use). Set by the bridge.
    var onListenerFailure: ((String) -> Void)?

    init(port: UInt16 = 4747, bonjourName: String = "TangoDisplay Remote", htmlProvider: @escaping () -> Data) {
        self.port = port
        self.bonjourName = bonjourName
        self.htmlProvider = htmlProvider
    }

    // MARK: - Lifecycle

    func start() throws {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        listener.service = NWListener.Service(name: bonjourName, type: "_http._tcp")

        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection: connection)
        }
        listener.stateUpdateHandler = { [weak self] state in
            if case .failed(let error) = state {
                NSLog("[TangoDisplay] HTTPServerTransport listener failed: \(error)")
                self?.onListenerFailure?("Could not start server: \(error.localizedDescription)")
            }
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop(completion: @escaping @Sendable () -> Void) {
        queue.async { [weak self] in
            guard let self else { completion(); return }
            let listener = self.listener
            self.listener = nil
            for client in self.clients.values { client.connection.cancel() }
            self.clients.removeAll()
            self.connectionCountSubject.send(0)
            self.onListenerFailure = nil

            guard let listener else { completion(); return }
            // Drop any prior failure handler; wait for the .cancelled transition before
            // signalling completion so the caller can safely bind the port again.
            listener.stateUpdateHandler = { state in
                if case .cancelled = state {
                    completion()
                }
            }
            listener.cancel()
        }
    }

    // MARK: - Sending

    func broadcast(_ text: String) {
        queue.async { [weak self] in
            guard let self else { return }
            let frame = Self.encodeTextFrame(text)
            for client in self.clients.values where client.state == .websocket {
                client.connection.send(content: frame, completion: .contentProcessed { _ in })
            }
        }
    }

    func send(_ text: String, to clientID: UUID) {
        queue.async { [weak self] in
            guard let self, let client = self.clients[clientID], client.state == .websocket else { return }
            let frame = Self.encodeTextFrame(text)
            client.connection.send(content: frame, completion: .contentProcessed { _ in })
        }
    }

    func disconnect(_ clientID: UUID) {
        queue.async { [weak self] in
            guard let self, let client = self.clients[clientID] else { return }
            // Send a zero-byte frame with isComplete=true so any previously queued
            // text frame (e.g. an auth NACK) gets flushed before the socket closes —
            // without this, the cancel() can preempt pending sends and the client
            // never sees the rejection message.
            client.connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .contentProcessed { [weak self] _ in
                self?.queue.async {
                    client.connection.cancel()
                    self?.removeClient(clientID)
                }
            })
        }
    }

    // MARK: - Per-connection handling

    private func accept(connection: NWConnection) {
        // Cap simultaneous connections so a flood can't exhaust resources (F1).
        guard clients.count < RemoteServerLimits.maxConcurrentClients else {
            connection.cancel()
            return
        }
        let client = ClientConnection(connection: connection)
        clients[client.id] = client
        connectionCountSubject.send(clients.count)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: break
            case .failed, .cancelled:
                self?.queue.async { self?.removeClient(client.id) }
            default: break
            }
        }
        connection.start(queue: queue)
        receive(on: client)
    }

    private func removeClient(_ id: UUID) {
        guard let client = clients.removeValue(forKey: id) else { return }
        let wasAuthed = client.state == .websocket
        connectionCountSubject.send(clients.count)
        if wasAuthed {
            delegate?.transport(self, didDisconnect: id)
        }
    }

    private func receive(on client: ClientConnection) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                client.buffer.append(data)
                self.processBuffer(for: client)
            }
            if isComplete || error != nil {
                client.connection.cancel()
                self.queue.async { self.removeClient(client.id) }
                return
            }
            self.receive(on: client)
        }
    }

    private func processBuffer(for client: ClientConnection) {
        switch client.state {
        case .awaitingHTTPRequest:
            processHTTPRequest(for: client)
        case .websocket:
            processWebSocketFrames(for: client)
        }
    }

    // MARK: - HTTP request handling

    private func processHTTPRequest(for client: ClientConnection) {
        // Wait for full headers (terminator: \r\n\r\n). Bound the wait: a client that
        // keeps sending without ever terminating the headers (slowloris) must not grow
        // the buffer without limit (F1).
        guard let terminatorRange = client.buffer.range(of: Data("\r\n\r\n".utf8)) else {
            if RemoteServerLimits.isHeaderOversized(bufferBytes: client.buffer.count) {
                sendHTTPResponse(client: client, status: "400 Bad Request", body: nil, closeAfter: true)
            }
            return
        }
        let headerData = client.buffer.subdata(in: 0..<terminatorRange.lowerBound)
        client.buffer.removeSubrange(0..<terminatorRange.upperBound)

        guard let headerString = String(data: headerData, encoding: .utf8) else {
            sendHTTPResponse(client: client, status: "400 Bad Request", body: nil, closeAfter: true)
            return
        }

        let lines = headerString.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let requestLine = lines.first else {
            sendHTTPResponse(client: client, status: "400 Bad Request", body: nil, closeAfter: true)
            return
        }
        let parts = requestLine.split(separator: " ").map(String.init)
        guard parts.count >= 2 else {
            sendHTTPResponse(client: client, status: "400 Bad Request", body: nil, closeAfter: true)
            return
        }
        let method = parts[0]
        let path = parts[1]

        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            let value = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let isWebSocketUpgrade = (headers["upgrade"]?.lowercased() == "websocket") &&
                                 (headers["connection"]?.lowercased().contains("upgrade") ?? false)

        if isWebSocketUpgrade, let key = headers["sec-websocket-key"] {
            performWebSocketHandshake(client: client, secKey: key)
            return
        }

        guard method == "GET" else {
            sendHTTPResponse(client: client, status: "405 Method Not Allowed", body: nil, closeAfter: true)
            return
        }

        switch path {
        case "/", "/index.html":
            let body = htmlProvider()
            sendHTTPResponse(client: client, status: "200 OK", contentType: "text/html; charset=utf-8", body: body, closeAfter: true)
        default:
            sendHTTPResponse(client: client, status: "404 Not Found", body: nil, closeAfter: true)
        }
    }

    private func sendHTTPResponse(client: ClientConnection, status: String, contentType: String = "text/plain; charset=utf-8", body: Data?, closeAfter: Bool) {
        var response = "HTTP/1.1 \(status)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(body?.count ?? 0)\r\n"
        response += "Cache-Control: no-store\r\n"
        if closeAfter { response += "Connection: close\r\n" }
        response += "\r\n"
        var data = Data(response.utf8)
        if let body { data.append(body) }
        client.connection.send(content: data, completion: .contentProcessed { [weak self] _ in
            if closeAfter {
                client.connection.cancel()
                self?.queue.async { self?.removeClient(client.id) }
            }
        })
    }

    private func performWebSocketHandshake(client: ClientConnection, secKey: String) {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = secKey + magic
        let hash = Insecure.SHA1.hash(data: Data(combined.utf8))
        let accept = Data(hash).base64EncodedString()

        var response = "HTTP/1.1 101 Switching Protocols\r\n"
        response += "Upgrade: websocket\r\n"
        response += "Connection: Upgrade\r\n"
        response += "Sec-WebSocket-Accept: \(accept)\r\n"
        response += "\r\n"

        client.state = .websocket
        client.connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, let self else { return }
            self.delegate?.transport(self, didConnect: client.id)
        })
    }

    // MARK: - WebSocket framing

    private func processWebSocketFrames(for client: ClientConnection) {
        while let frame = Self.decodeFrame(from: &client.buffer) {
            switch frame.opcode {
            case 0x1: // text
                if let text = String(data: frame.payload, encoding: .utf8) {
                    delegate?.transport(self, didReceiveText: text, from: client.id)
                }
            case 0x8: // close
                let closeFrame = Self.encodeCloseFrame()
                client.connection.send(content: closeFrame, completion: .contentProcessed { _ in
                    client.connection.cancel()
                })
                queue.async { [weak self] in self?.removeClient(client.id) }
                return
            case 0x9: // ping
                let pong = Self.encodeFrame(opcode: 0xA, payload: frame.payload)
                client.connection.send(content: pong, completion: .contentProcessed { _ in })
            default:
                break // ignore binary, pong, continuation
            }
        }
    }

    // Remote clients only ever send small JSON commands; any frame declaring more
    // than this is hostile or corrupt. Without the cap, a declared 64-bit length
    // above Int.max would trap on conversion (remote pre-auth crash), and any huge
    // value would make the buffer grow unboundedly waiting for data that never comes.
    private static let maxInboundFrameLength = 1 << 20  // 1 MiB

    // Decodes one frame from the front of `buffer`. Returns nil if the buffer doesn't
    // contain a complete frame yet. Mutates `buffer` to remove the consumed frame.
    // Oversized declared lengths clear the buffer (the connection is desynced anyway).
    private static func decodeFrame(from buffer: inout Data) -> (opcode: UInt8, payload: Data)? {
        guard buffer.count >= 2 else { return nil }
        let bytes = [UInt8](buffer)
        let opcode = bytes[0] & 0x0F
        let masked = (bytes[1] & 0x80) != 0
        var length = Int(bytes[1] & 0x7F)
        var cursor = 2

        if length == 126 {
            guard bytes.count >= cursor + 2 else { return nil }
            length = (Int(bytes[cursor]) << 8) | Int(bytes[cursor + 1])
            cursor += 2
        } else if length == 127 {
            guard bytes.count >= cursor + 8 else { return nil }
            var l: UInt64 = 0
            for i in 0..<8 { l = (l << 8) | UInt64(bytes[cursor + i]) }
            guard l <= UInt64(maxInboundFrameLength) else {
                buffer.removeAll()
                return nil
            }
            length = Int(l)
            cursor += 8
        }
        guard length <= maxInboundFrameLength else {
            buffer.removeAll()
            return nil
        }

        var maskKey: [UInt8] = []
        if masked {
            guard bytes.count >= cursor + 4 else { return nil }
            maskKey = Array(bytes[cursor..<cursor + 4])
            cursor += 4
        }

        guard bytes.count >= cursor + length else { return nil }
        var payload = Array(bytes[cursor..<cursor + length])
        if masked {
            for i in 0..<payload.count {
                payload[i] ^= maskKey[i % 4]
            }
        }

        buffer.removeSubrange(0..<(cursor + length))
        return (opcode, Data(payload))
    }

    private static func encodeTextFrame(_ text: String) -> Data {
        return encodeFrame(opcode: 0x1, payload: Data(text.utf8))
    }

    private static func encodeCloseFrame() -> Data {
        return encodeFrame(opcode: 0x8, payload: Data())
    }

    private static func encodeFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data()
        frame.append(0x80 | (opcode & 0x0F)) // FIN + opcode

        let length = payload.count
        if length < 126 {
            frame.append(UInt8(length))
        } else if length <= 65535 {
            frame.append(126)
            frame.append(UInt8((length >> 8) & 0xFF))
            frame.append(UInt8(length & 0xFF))
        } else {
            frame.append(127)
            var l = UInt64(length)
            for _ in 0..<8 {
                frame.append(UInt8((l >> 56) & 0xFF))
                l <<= 8
            }
        }
        frame.append(payload)
        return frame
    }
}

// MARK: - Per-connection state

private final class ClientConnection {
    enum State { case awaitingHTTPRequest, websocket }

    let id = UUID()
    let connection: NWConnection
    var state: State = .awaitingHTTPRequest
    var buffer = Data()

    init(connection: NWConnection) {
        self.connection = connection
    }
}
