import Foundation
import os

/// Tiene una sessione attiva per ogni iPhone raggiungibile: via cavo (usbmuxd) o su Wi-Fi (Bonjour + TLS).
/// Opzioni di test: `-tcpHost 127.0.0.1` (app iOS nel simulatore), `-wifiOnly YES` (ignora il cavo).
@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()
    private static let log = Logger(subsystem: "it.joe.pocketdisplay.mac", category: "session")

    /// Stato di ogni sessione (chiave: `usb-<id>`, `wifi-<uuid>`, `tcp`).
    @Published private(set) var states: [String: LinkState] = [:] { didSet { Self.log.info("stato: \(String(describing: self.shown), privacy: .public)") } }
    @Published private(set) var missing = Permission.missing
    @Published private(set) var paired = PairedPhones.all

    var state: LinkState { states.values.max { $0.priority < $1.priority } ?? .device }
    /// Stato da mostrare: i permessi mancanti hanno la precedenza su tutto.
    var shown: LinkState { missing.isEmpty ? state : .permissions }

    private var tasks: [String: Task<Void, Never>] = [:]
    private var links: [String: Link] = [:]
    /// Sessioni scollegate dall'utente: restano ferme finché non si preme "Ricollega" (o il telefono sparisce).
    private var held: Set<String> = []
    private var wireless: Task<Void, Never>?

    func start() {
        missing.forEach { $0.request() }
        Task { while true { refreshPermissions(); try? await Task.sleep(for: .seconds(1.5)) } }

        if let host = UserDefaults.standard.string(forKey: "tcpHost") {
            run("tcp", .cable) { try await self.tcp(host) }
            return
        }
        if !UserDefaults.standard.bool(forKey: "wifiOnly") { Task { await watchCable() } }   // -wifiOnly: prova il Wi-Fi anche col cavo inserito
        watchWireless()
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "selfTest") {   // prova: scollega dopo 20 s, ricollega dopo altri 12
            Task { try? await Task.sleep(for: .seconds(20)); disconnect(); try? await Task.sleep(for: .seconds(12)); reconnect() }
        }
        #endif
    }

    var canDisconnect: Bool { states.values.contains { $0.isStreaming || $0 == .connecting } }

    /// Scollega gli iPhone in uso: il display virtuale sparisce e il Mac non si riconnette da solo.
    func disconnect() {
        for (key, state) in states where state.isStreaming || state == .connecting {
            held.insert(key)
            states[key] = .disconnected
            links[key]?.cancel()
        }
    }

    /// Annulla lo scollegamento: la connessione riparte entro un secondo.
    func reconnect() {
        for key in held { states[key] = .app }
        held.removeAll()
    }

    /// Dimentica un iPhone: smette di collegarsi su Wi-Fi finché non viene riabbinato col cavo.
    func forget(_ phone: PairedPhone) {
        PairedPhones.forget(phone.id)
        paired = PairedPhones.all
        end("wifi-\(phone.id)")
        if paired.isEmpty { wireless?.cancel(); wireless = nil }
    }

    #if DEBUG
    func preview(_ state: LinkState, missing: [Permission], paired: [PairedPhone] = []) {
        states = ["preview": state]; self.missing = missing; self.paired = paired
    }
    #endif

    // MARK: Sessioni

    private func run(_ key: String, _ transport: Transport, connect: @escaping () async throws -> Link) {
        states[key] = .app
        tasks[key] = Task { await serve(key, transport, connect: connect) }
    }

    private func end(_ key: String) {
        tasks.removeValue(forKey: key)?.cancel()
        links.removeValue(forKey: key)
        held.remove(key)
        states.removeValue(forKey: key)
    }

    /// Riprova finché il dispositivo c'è: l'app sul telefono potrebbe non essere ancora aperta.
    private func serve(_ key: String, _ transport: Transport, connect: () async throws -> Link) async {
        while !Task.isCancelled {
            if missing.isEmpty, !held.contains(key) {
                do {
                    let link = try await connect()
                    links[key] = link
                    states[key] = .connecting
                    try await StreamSession(link: link, transport: transport).run { info in
                        Task { @MainActor in
                            guard !self.held.contains(key) else { return }
                            self.states[key] = .streaming(info); self.didStream(over: transport)
                        }
                    }
                } catch {
                    links[key] = nil
                    Self.log.error("sessione \(key, privacy: .public) terminata: \(String(describing: error), privacy: .public)")
                    switch error {
                    case _ where held.contains(key): states[key] = .disconnected
                    case StreamSession.Failure.incompatible: states[key] = .outdated
                    case is StreamSession.Failure, is ScreenCapture.Failure, is VideoEncoder.Failure: states[key] = .failed
                    default: states[key] = .app
                    }
                }
            }
            try? await Task.sleep(for: .seconds(1))
        }
    }

    /// Dopo una sessione via cavo l'iPhone è abbinato: da qui in poi lo si cerca anche sul Wi-Fi.
    private func didStream(over transport: Transport) {
        guard transport == .cable else { return }
        paired = PairedPhones.all
        watchWireless()
    }

    // MARK: Cavo

    private func watchCable() async {
        do {
            for try await event in Usbmux.events() {
                Self.log.info("usbmux: \(String(describing: event), privacy: .public)")
                switch event {
                case .attached(let device): run("usb-\(device.id)", .cable) { try await Usbmux.connect(to: device, port: Wire.port) }
                case .detached(let id): end("usb-\(id)")
                }
            }
        } catch { states["usbmux"] = .failed }
    }

    private func tcp(_ host: String) async throws -> Link {
        let link = Link(host: host, port: Wire.port)
        try await link.start()
        return link
    }

    // MARK: Wi-Fi

    /// Cerca sulla rete gli iPhone abbinati. Parte solo se ce n'è almeno uno (così il permesso
    /// "Rete locale" non viene chiesto a chi usa solo il cavo).
    private func watchWireless() {
        guard wireless == nil, !paired.isEmpty else { return }
        wireless = Task {
            for await peers in Wireless.peers() {
                let visible = Set(peers.map { "wifi-\($0.id)" })
                for key in tasks.keys where key.hasPrefix("wifi-") && !visible.contains(key) { end(key) }
                for peer in peers where tasks["wifi-\(peer.id)"] == nil {
                    guard let phone = paired.first(where: { $0.id == peer.id }) else { continue }
                    run("wifi-\(peer.id)", .wifi) { try await Wireless.connect(to: peer, key: phone.key) }
                }
            }
        }
    }

    private func refreshPermissions() {
        let now = Permission.missing
        if now != missing { missing = now }
    }
}
