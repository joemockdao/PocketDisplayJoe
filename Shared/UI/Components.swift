import SwiftUI

/// Icona in tessera + titolo + dettaglio: riga standard di liste e passi.
struct StepRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var tint = Theme.accent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

/// I tre passi per usare l'app: identici sull'iPhone e sul Mac. Le chiavi sono `step.<nome>.title/.detail`.
struct HowItWorks: View {
    private static let steps = [("cable.connector", "cable"), ("laptopcomputer", "mac"), ("iphone.gen3", "phone")]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Self.steps, id: \.1) { symbol, name in
                StepRow(symbol: symbol, title: LocalizedStringKey.key("step.\(name).title"),
                        detail: LocalizedStringKey.key("step.\(name).detail"))
            }
        }
    }
}

/// Pallino che pulsa: "sto aspettando".
struct PulseDot: View {
    var color = Theme.accent
    @State private var on = false

    var body: some View {
        Circle().fill(color).frame(width: 9, height: 9)
            .overlay(Circle().stroke(color.opacity(0.6)).scaleEffect(on ? 2.4 : 1).opacity(on ? 0 : 1))
            .onAppear { withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true } }
    }
}
