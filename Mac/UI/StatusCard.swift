import SwiftUI

extension LinkState {
    var title: LocalizedStringKey { LocalizedStringKey.key("state.\(key).title") }
    var detail: LocalizedStringKey { LocalizedStringKey.key("state.\(key).detail") }

    var symbol: String {
        switch self {
        case .permissions: "lock.shield"
        case .device: "cable.connector"
        case .app: "iphone.gen3"
        case .connecting: "arrow.triangle.2.circlepath"
        case .streaming: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .outdated: "arrow.down.app"
        case .disconnected: "iphone.slash"
        }
    }

    var tint: Color {
        switch self {
        case .permissions, .outdated: Theme.warning
        case .streaming: Theme.success
        case .failed: Theme.danger
        default: Theme.accent
        }
    }
}

/// Stato corrente: icona colorata, titolo, spiegazione e, in streaming, codec / risoluzione / fps.
struct StatusCard: View {
    let state: LinkState
    var disconnect: () -> Void = {}
    var reconnect: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepRow(symbol: state.symbol, title: state.title, detail: state.detail, tint: state.tint)
            if case .streaming(let info) = state {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 10) {
                    GridRow { stat("detail.connection", info.transport.rawValue); stat("detail.codec", info.codec.label) }
                    GridRow { stat("detail.resolution", "\(info.width)×\(info.height)"); stat("detail.fps", "\(info.fps)") }
                }
                ActionButton(title: "action.disconnect", symbol: "eject.fill", prominent: false, action: disconnect)
            } else if state == .disconnected {
                ActionButton(title: "action.reconnect", symbol: "arrow.clockwise", prominent: true, action: reconnect)
            }
        }
        .card()
        .animation(.easeInOut(duration: 0.25), value: state)
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(verbatim: value).font(.callout.monospacedDigit().weight(.semibold))
        }
    }
}

/// Pulsante a tutta larghezza: pieno (azione principale) o discreto (azione secondaria).
private struct ActionButton: View {
    let title: LocalizedStringKey
    let symbol: String
    let prominent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(prominent ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.white.opacity(0.10)),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
