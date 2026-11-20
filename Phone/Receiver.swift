import Network
import Observation
import UIKit

/// Riceve lo stream e lo passa al `VideoSink`. Due porte d'ingresso, una connessione alla volta:
/// - **cavo**: porta `Wire.port` solo su loopback (il Mac arriva via usbmuxd), senza cifratura;
/// - **Wi-Fi**: porta qualsiasi, annunciata con Bonjour e protetta da TLS con le chiavi dei Mac abbinati
///   (attiva solo dopo il primo abbinamento via cavo).
/// Il cavo ha la precedenza: una connessione Wi-Fi non scalza una sessione via cavo.
@Observable
@MainActor
final class Receiver {
    private(set) var isStreaming = false
    private(set) var config: StreamConfig?
    private(set) var pairedCount = PhoneKeys.all.count
    private(set) var wirelessActive = false

    let sink = VideoSink()
    private var cableListener: NWListener?
    private var wifiListener: NWListener?
    private var link: Link?
    private var linkViaCable = false
    private var viewPixels = CGSize.zero

    init() {
        sink.onNeedKeyframe = { [weak self] in Task { @MainActor in self?.send(.keyframeRequest) } }
    }

    func start() {
        startCableListener()
        refreshWireless()
    }

    /// Dimentica tutti i Mac abbinati: il Wi-Fi si spegne finché non si collega di nuovo il cavo.
    func forgetMacs() {
        PhoneKeys.removeAll()
        refreshWireless()
    }

    func send(_ message: Message) { link?.send(message) }

    func viewSizeChanged(_ pixels: CGSize) {
        viewPixels = pixels
        if link != nil { sendHello() }
    }

    // MARK: Listener

    private func startCableListener() {
        guard cableListener == nil else { return }
        let params = Link.tcp()
        params.requiredInterfaceType = .loopback
        cableListener = makeListener(params, port: Wire.port, onLink: { [weak self] in self?.accept($0, viaCable: true) },
                                     onFailure: { [weak self] in self?.cableListener = nil; self?.startCableListener() })
    }

    /// (Ri)crea il listener Wi-Fi con le chiavi correnti; senza chiavi non annuncia nulla sulla rete.
    private func refreshWireless() {
        wifiListener?.cancel()
        wifiListener = nil
        let keys = PhoneKeys.all
        pairedCount = keys.count
        guard !keys.isEmpty else { wirelessActive = false; return }
        wifiListener = makeListener(Link.secure(keys: keys), port: nil,
                                    service: NWListener.Service(type: "_pocketdisplay._tcp",
                                                                txtRecord: NWTXTRecord(["id": Identity.phoneID.uuidString])),
                                    onLink: { [weak self] in self?.accept($0, viaCable: false) },
                                    onFailure: { [weak self] in self?.refreshWireless() })
        wirelessActive = wifiListener != nil
    }

    private func makeListener(_ params: NWParameters, port: UInt16?, service: NWListener.Service? = nil,
                              onLink: @escaping @MainActor (Link) -> Void, onFailure: @escaping @MainActor () -> Void) -> NWListener? {
        guard let listener = try? port.map({ try NWListener(using: params, on: NWEndpoint.Port(rawValue: $0)!) }) ?? NWListener(using: params)
        else { return nil }
        listener.service = service
        listener.newConnectionHandler = { connection in Task { @MainActor in onLink(Link(connection)) } }
        listener.stateUpdateHandler = { state in
            if case .failed = state { Task { @MainActor in onFailure() } }
        }
        listener.start(queue: .main)
        return listener
    }

    // MARK: Sessione

    private func sendHello() {
        guard viewPixels.width > 0 else { return }
        send(.hello(Hello(width: Int(viewPixels.width), height: Int(viewPixels.height),
                          supportsHEVC: true,   // ogni iPhone con A10+ decodifica HEVC in hardware
                          id: Identity.phoneID, name: UIDevice.current.name)))
    }

    private func accept(_ new: Link, viaCable: Bool) {
        if !viaCable, link != nil, linkViaCable { new.cancel(); return }   // il cavo ha la precedenza
        link?.cancel()
        link = new
        linkViaCable = viaCable
        Task {
            do {
                try await new.start()
                sendHello()
                while true { handle(try await new.receive()) }
            } catch {}
            if link === new { link = nil; isStreaming = false }
        }
    }

    private func handle(_ message: Message) {
        switch message {
        case .config(let config):
            sink.configure(config, playout: linkViaCable ? 0 : VideoSink.wifiPlayout)
            self.config = config
            isStreaming = true
        case .parameterSets(let sets): sink.setParameterSets(sets)
        case .frame(let data, let keyframe, let time): sink.enqueue(data, keyframe: keyframe, time: time)
        case .pair(let key) where linkViaCable:   // la chiave si accetta solo dal cavo, mai dalla rete
            if !PhoneKeys.all.contains(key) { PhoneKeys.add(key); refreshWireless() }
        default: break
        }
    }
}
