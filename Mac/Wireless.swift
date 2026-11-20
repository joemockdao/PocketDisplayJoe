import Foundation
import Network

/// Scoperta degli iPhone sulla rete locale (Bonjour) e connessione cifrata (TLS con chiave pre-condivisa).
enum Wireless {
    static let serviceType = "_pocketdisplay._tcp"

    struct Peer: Equatable {
        let id: UUID               // identità dell'iPhone, dal record TXT
        let endpoint: NWEndpoint
    }

    /// Flusso dell'elenco aggiornato degli iPhone visibili sulla rete.
    static func peers() -> AsyncStream<[Peer]> {
        AsyncStream { continuation in
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: serviceType, domain: nil), using: .tcp)
            browser.browseResultsChangedHandler = { results, _ in continuation.yield(results.compactMap(Peer.init)) }
            continuation.onTermination = { _ in browser.cancel() }
            browser.start(queue: .main)
        }
    }

    static func connect(to peer: Peer, key: PairingKey) async throws -> Link {
        let link = Link(NWConnection(to: peer.endpoint, using: Link.secure(keys: [key])))
        try await link.start()
        return link
    }
}

private extension Wireless.Peer {
    init?(_ result: NWBrowser.Result) {
        guard case .bonjour(let txt) = result.metadata, let raw = txt["id"], let id = UUID(uuidString: raw) else { return nil }
        self.init(id: id, endpoint: result.endpoint)
    }
}
