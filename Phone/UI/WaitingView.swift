import SwiftUI

/// Schermata mostrata finché il Mac non si collega: cos'è l'app, stato e i tre passi.
struct WaitingView: View {
    let receiver: Receiver

    var body: some View {
        HStack(spacing: 40) {
            VStack(alignment: .leading, spacing: 12) {
                AppLogo(kind: .phone, size: 76)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                Text("app.name").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("app.tagline").font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    PulseDot()
                    Text("phone.waiting").font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.white.opacity(0.08), in: Capsule())
                .padding(.top, 6)
            }
            .frame(maxWidth: 300, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                HowItWorks().card(padding: 20)
                wireless
            }
            .frame(maxWidth: 360)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.backdrop)
        .foregroundStyle(.white)
    }

    /// Stato del collegamento Wi-Fi: attivo dopo il primo abbinamento via cavo.
    private var wireless: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(receiver.wirelessActive ? "phone.wifi.ready" : "phone.wifi.pair",
                  systemImage: receiver.wirelessActive ? "wifi" : "wifi.slash")
                .font(.caption).foregroundStyle(receiver.wirelessActive ? Theme.success : .secondary)
            if receiver.pairedCount > 0 {
                Button("phone.forget", role: .destructive) { receiver.forgetMacs() }.font(.caption)
            }
        }
        .padding(.horizontal, 4)
    }
}
