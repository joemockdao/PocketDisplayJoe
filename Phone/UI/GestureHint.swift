import SwiftUI

/// Promemoria dei gesti, mostrato per qualche secondo quando parte lo streaming.
struct GestureHint: View {
    var body: some View {
        HStack(spacing: 22) {
            item("cursorarrow.click", "gesture.one")
            Divider().frame(height: 26)
            item("arrow.up.arrow.down", "gesture.two")
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.12)))
        .padding(.bottom, 18)
    }

    private func item(_ symbol: String, _ key: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.title3).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 0) {
                Text(LocalizedStringKey.key("\(key).title")).font(.caption.weight(.semibold))
                Text(LocalizedStringKey.key("\(key).detail")).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ShowTemporarily: ViewModifier {
    let trigger: Bool
    @State private var visible = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if visible { GestureHint().transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .onChange(of: trigger) { _, on in
                withAnimation(.spring(duration: 0.4)) { visible = on }
                guard on else { return }
                Task {
                    try? await Task.sleep(for: .seconds(4))
                    withAnimation(.easeIn(duration: 0.4)) { visible = false }
                }
            }
    }
}

extension View {
    /// Mostra `GestureHint` per 4 secondi ogni volta che `isStreaming` diventa vero.
    func gestureHint(whenStreaming isStreaming: Bool) -> some View { modifier(ShowTemporarily(trigger: isStreaming)) }
}

#Preview(traits: .landscapeLeft) { Color.black.overlay(GestureHint(), alignment: .bottom) }
