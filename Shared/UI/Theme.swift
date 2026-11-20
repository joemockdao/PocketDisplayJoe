import SwiftUI

/// Palette e stili condivisi dalle due app.
enum Theme {
    static let accent = Color(red: 0.30, green: 0.55, blue: 1.00)
    static let success = Color(red: 0.20, green: 0.84, blue: 0.55)
    static let warning = Color(red: 1.00, green: 0.72, blue: 0.20)
    static let danger = Color(red: 1.00, green: 0.38, blue: 0.40)

    static let backdrop = LinearGradient(
        colors: [Color(red: 0.05, green: 0.07, blue: 0.17), Color(red: 0.13, green: 0.10, blue: 0.31)],
        startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension View {
    /// Pannello in vetro con bordo sottile.
    func card(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.10)))
    }
}

extension LocalizedStringKey {
    /// Chiave costruita a runtime (`.key("step.\(name).title")`). Scrivere `LocalizedStringKey("…\(x)…")`
    /// sarebbe un'interpolazione e cercherebbe una chiave con `%@`: qui l'argomento è una String normale.
    static func key(_ raw: String) -> LocalizedStringKey { LocalizedStringKey(raw) }
}
