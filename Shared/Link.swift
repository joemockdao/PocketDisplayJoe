import Foundation
import Network
import os

/// Connessione bidirezionale con framing a messaggi, sopra `NWConnection`
/// (TCP, socket unix verso usbmuxd, o connessione accettata da un listener).
final class Link {
    enum Failure: Error { case closed, malformed }

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "pocketdisplay.link", qos: .userInteractive)
    private let pending = OSAllocatedUnfairLock(initialState: (count: 0, bytes: 0))

    init(_ connection: NWConnection) { self.connection = connection }

    convenience init(host: String, port: UInt16) {
        self.init(NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: Self.tcp()))
    }

    convenience init(unixPath: String) {
        self.init(NWConnection(to: .unix(path: unixPath), using: .tcp))
    }

    /// TCP a bassa latenza (niente Nagle) con keep-alive: un telefono sparito dalla rete si nota in ~10 s.
    private static func tcpOptions() -> NWProtocolTCP.Options {
        let options = NWProtocolTCP.Options()
        options.noDelay = true
        options.enableKeepalive = true
        options.keepaliveIdle = 4
        options.keepaliveInterval = 2
        options.keepaliveCount = 3
        return options
    }

    static func tcp() -> NWParameters { NWParameters(tls: nil, tcp: tcpOptions()) }

    /// TLS con chiavi pre-condivise (Wi-Fi). Il client passa la propria chiave, il server tutte quelle abbinate:
    /// si sceglie quella con la stessa identità. Senza una chiave valida l'handshake fallisce.
    static func secure(keys: [PairingKey]) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        for key in keys {
            sec_protocol_options_add_pre_shared_key(tls.securityProtocolOptions,
                                                    key.secret.withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData,
                                                    key.id.withUnsafeBytes { DispatchData(bytes: $0) } as __DispatchData)
        }
        sec_protocol_options_append_tls_ciphersuite(tls.securityProtocolOptions, tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)
        let params = NWParameters(tls: tls, tcp: tcpOptions())
        params.serviceClass = .interactiveVideo   // coda WMM "video" del Wi-Fi: meno attese e jitter
        return params
    }

    /// Più di qualche invio in coda: chi produce video deve saltare i frame *prima* di codificarli.
    var isCongested: Bool { pending.withLock { $0.count >= 3 } }
    var pendingBytes: Int { pending.withLock { $0.bytes } }

    func start() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let finished = OSAllocatedUnfairLock(initialState: false)
            @Sendable func finish(_ result: Result<Void, Error>) {
                guard finished.withLock({ let was = $0; $0 = true; return !was }) else { return }
                cont.resume(with: result)
            }
            connection.stateUpdateHandler = { [connection] state in
                switch state {
                case .ready: finish(.success(()))
                case .waiting(let error), .failed(let error):   // .waiting = rifiutata/irraggiungibile: fallire subito
                    connection.cancel(); finish(.failure(error))
                case .cancelled: finish(.failure(Failure.closed))
                default: break
                }
            }
            connection.start(queue: queue)
        }
    }

    func cancel() { connection.cancel() }

    // MARK: Byte grezzi

    func readExactly(_ count: Int) async throws -> Data {
        guard count > 0 else { return Data() }
        return try await withCheckedThrowingContinuation { cont in
            connection.receive(minimumIncompleteLength: count, maximumLength: count) { data, _, _, error in
                if let error { cont.resume(throwing: error) }
                else if let data, data.count == count { cont.resume(returning: data) }
                else { cont.resume(throwing: Failure.closed) }
            }
        }
    }

    func sendRaw(_ data: Data) {
        pending.withLock { $0.count += 1; $0.bytes += data.count }
        connection.send(content: data, completion: .contentProcessed { [pending, connection, size = data.count] error in
            pending.withLock { $0.count -= 1; $0.bytes -= size }
            if error != nil { connection.cancel() }
        })
    }

    // MARK: Messaggi

    func send(_ message: Message) { sendRaw(message.encoded()) }

    func receive() async throws -> Message {
        var header = ByteReader(try await readExactly(4))
        let length = Int(header.get(UInt32.self) ?? 0)
        guard (1...Wire.maxPayload).contains(length),
              let message = Message(payload: try await readExactly(length)) else { throw Failure.malformed }
        return message
    }
}
