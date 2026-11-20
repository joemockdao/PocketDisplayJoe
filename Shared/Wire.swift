import Foundation

/// Protocollo Mac ⇄ iPhone. Frame: `[u32 lunghezza][u8 tipo][corpo]`, tutto big-endian.
enum Wire {
    /// Porta TCP su cui l'iPhone ascolta (raggiunta via usbmuxd).
    static let port: UInt16 = 9000
    static let maxPayload = 16 << 20
}

enum Codec: UInt8 {
    case h264, hevc
    var label: String { self == .hevc ? "HEVC" : "H.264" }
}

/// iPhone → Mac: dimensioni dell'area visibile in pixel, capacità e identità del telefono.
struct Hello: Equatable {
    var width: Int
    var height: Int
    var supportsHEVC: Bool
    var id: UUID
    var name: String
}

/// Mac → iPhone: formato dello stream che sta per partire.
struct StreamConfig: Equatable {
    var codec: Codec
    var width: Int
    var height: Int
    var fps: Int
}

/// iPhone → Mac: input puntatore. x/y normalizzati 0…1 (origine in alto a sinistra);
/// dx/dy in punti, usati solo da `.scroll`.
struct Touch: Equatable {
    enum Phase: UInt8 { case began, moved, ended, scroll }
    var phase: Phase
    var x: Float
    var y: Float
    var dx: Float = 0
    var dy: Float = 0
}

enum Message: Equatable {
    case hello(Hello)
    case config(StreamConfig)
    case parameterSets([Data])
    case frame(Data, keyframe: Bool, time: UInt64)   // campioni AVCC (lunghezza a 4 byte); `time` = istante di cattura in µs
    case touch(Touch)
    case keyframeRequest
    case pair(PairingKey)      // Mac → iPhone, solo via cavo: chiave per i collegamenti Wi-Fi
}

extension Message {
    private enum Kind: UInt8 { case hello = 1, config, parameterSets, frame, touch, keyframeRequest, pair }

    /// Frame completo pronto per il socket.
    func encoded() -> Data {
        var body = ByteWriter()
        let kind: Kind
        switch self {
        case .hello(let h):
            kind = .hello
            body.put(UInt16(h.width)); body.put(UInt16(h.height)); body.put(UInt8(h.supportsHEVC ? 1 : 0))
            let name = Data(h.name.utf8.prefix(60))
            body.put(h.id.data); body.put(UInt8(name.count)); body.put(name)
        case .config(let c):
            kind = .config
            body.put(c.codec.rawValue); body.put(UInt16(c.width)); body.put(UInt16(c.height)); body.put(UInt8(c.fps))
        case .parameterSets(let sets):
            kind = .parameterSets
            body.put(UInt8(sets.count))
            for set in sets { body.put(UInt16(set.count)); body.put(set) }
        case .frame(let data, let keyframe, let time):
            kind = .frame
            body.put(UInt8(keyframe ? 1 : 0)); body.put(time); body.put(data)
        case .touch(let t):
            kind = .touch
            body.put(t.phase.rawValue); body.put(t.x); body.put(t.y); body.put(t.dx); body.put(t.dy)
        case .keyframeRequest:
            kind = .keyframeRequest
        case .pair(let key):
            kind = .pair
            body.put(key.id); body.put(key.secret)
        }
        var out = ByteWriter()
        out.put(UInt32(body.data.count + 1)); out.put(kind.rawValue); out.put(body.data)
        return out.data
    }

    /// Decodifica un payload (tipo + corpo, senza la lunghezza). nil se malformato.
    init?(payload: Data) {
        var r = ByteReader(payload)
        guard let raw = r.get(UInt8.self), let kind = Kind(rawValue: raw) else { return nil }
        switch kind {
        case .hello:
            guard let w = r.get(UInt16.self), let h = r.get(UInt16.self), let hevc = r.get(UInt8.self),
                  let id = r.bytes(16), let n = r.get(UInt8.self), let name = r.bytes(Int(n)) else { return nil }
            self = .hello(Hello(width: Int(w), height: Int(h), supportsHEVC: hevc != 0,
                                id: UUID(data: id), name: String(decoding: name, as: UTF8.self)))
        case .config:
            guard let c = r.get(UInt8.self).flatMap(Codec.init(rawValue:)),
                  let w = r.get(UInt16.self), let h = r.get(UInt16.self), let fps = r.get(UInt8.self) else { return nil }
            self = .config(StreamConfig(codec: c, width: Int(w), height: Int(h), fps: Int(fps)))
        case .parameterSets:
            guard let count = r.get(UInt8.self) else { return nil }
            var sets: [Data] = []
            for _ in 0..<count {
                guard let n = r.get(UInt16.self), let set = r.bytes(Int(n)) else { return nil }
                sets.append(set)
            }
            self = .parameterSets(sets)
        case .frame:
            guard let key = r.get(UInt8.self), let time = r.get(UInt64.self) else { return nil }
            self = .frame(r.rest(), keyframe: key != 0, time: time)
        case .touch:
            guard let p = r.get(UInt8.self).flatMap(Touch.Phase.init(rawValue:)),
                  let x = r.float(), let y = r.float(), let dx = r.float(), let dy = r.float() else { return nil }
            self = .touch(Touch(phase: p, x: x, y: y, dx: dx, dy: dy))
        case .keyframeRequest:
            self = .keyframeRequest
        case .pair:
            guard let id = r.bytes(PairingKey.idSize), let secret = r.bytes(PairingKey.secretSize) else { return nil }
            self = .pair(PairingKey(id: id, secret: secret))
        }
    }
}

extension UUID {
    var data: Data { withUnsafeBytes(of: uuid) { Data($0) } }
    init(data: Data) { self.init(uuid: data.withUnsafeBytes { $0.loadUnaligned(as: uuid_t.self) }) }
}
