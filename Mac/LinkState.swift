import Foundation

/// Come è collegato l'iPhone. `rawValue` è anche l'etichetta mostrata (nomi tecnici, non tradotti).
enum Transport: String { case cable = "USB", wifi = "Wi-Fi" }

struct StreamInfo: Equatable {
    var codec: Codec
    var width: Int
    var height: Int
    var fps: Int
    var transport: Transport
}

/// Stato del collegamento con l'iPhone. `key` è il frammento usato nelle chiavi di localizzazione
/// (`state.<key>.title` / `.detail`).
enum LinkState: Equatable {
    case permissions, device, app, connecting, streaming(StreamInfo), failed, outdated, disconnected

    var key: String {
        switch self {
        case .permissions: "permissions"
        case .device: "device"
        case .app: "app"
        case .connecting: "connecting"
        case .streaming: "streaming"
        case .failed: "failed"
        case .outdated: "outdated"
        case .disconnected: "disconnected"
        }
    }

    var isStreaming: Bool { if case .streaming = self { true } else { false } }

    /// Con più sessioni attive, il pannello mostra quella "più avanti".
    var priority: Int {
        switch self {
        case .streaming: 4
        case .connecting: 3
        case .failed, .outdated, .disconnected: 2
        case .app: 1
        case .device, .permissions: 0
        }
    }
}
