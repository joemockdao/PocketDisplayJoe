import Foundation

/// Client minimale di usbmuxd (il demone macOS che parla USB con gli iPhone):
/// rileva gli iPhone collegati e apre un tunnel verso una porta TCP dell'app sul telefono.
enum Usbmux {
    struct Device: Equatable { let id: Int; let serial: String }
    enum Event { case attached(Device), detached(id: Int) }
    enum Failure: Error { case refused(Int), badReply }

    private static func open() async throws -> Link {
        let link = Link(unixPath: "/var/run/usbmuxd")
        try await link.start()
        return link
    }

    /// Pacchetto usbmuxd: header little-endian [lunghezza, versione=1, tipo=8 (plist), tag] + plist XML.
    private static func send(_ link: Link, _ fields: [String: Any]) throws {
        let plist = try PropertyListSerialization.data(
            fromPropertyList: fields.merging(["ClientVersionString": "PocketDisplayJoe", "ProgName": "PocketDisplayJoe"]) { a, _ in a },
            format: .xml, options: 0)
        var packet = Data()
        for value in [UInt32(16 + plist.count), 1, 8, 1] {
            withUnsafeBytes(of: value.littleEndian) { packet.append(contentsOf: $0) }
        }
        link.sendRaw(packet + plist)
    }

    private static func read(_ link: Link) async throws -> [String: Any] {
        let header = try await link.readExactly(16)
        let length = Int(UInt32(littleEndian: header.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }))
        let body = try await link.readExactly(length - 16)
        guard let plist = try PropertyListSerialization.propertyList(from: body, format: nil) as? [String: Any]
        else { throw Failure.badReply }
        return plist
    }

    /// Flusso di iPhone collegati/scollegati via USB (include quelli già collegati all'avvio).
    static func events() -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let link = try await open()
                    continuation.onTermination = { _ in link.cancel() }
                    try send(link, ["MessageType": "Listen"])
                    _ = try await read(link)   // risposta "Result"
                    while true {
                        let message = try await read(link)
                        switch message["MessageType"] as? String {
                        case "Attached":
                            if let id = message["DeviceID"] as? Int,
                               let props = message["Properties"] as? [String: Any],
                               props["ConnectionType"] as? String == "USB" {
                                continuation.yield(.attached(Device(id: id, serial: props["SerialNumber"] as? String ?? "")))
                            }
                        case "Detached":
                            if let id = message["DeviceID"] as? Int { continuation.yield(.detached(id: id)) }
                        default: break
                        }
                    }
                } catch { continuation.finish(throwing: error) }
            }
        }
    }

    /// Tunnel verso `port` dell'app sul dispositivo; dopo l'handshake il socket è un pipe di byte.
    static func connect(to device: Device, port: UInt16) async throws -> Link {
        let link = try await open()
        try send(link, ["MessageType": "Connect", "DeviceID": device.id, "PortNumber": Int(port.byteSwapped)])  // htons
        let code = try await read(link)["Number"] as? Int ?? -1
        guard code == 0 else { link.cancel(); throw Failure.refused(code) }
        return link
    }
}
