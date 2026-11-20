import SwiftUI

/// iPhone abbinati (quelli che il Mac cerca anche sul Wi-Fi), con il pulsante per dimenticarli.
struct PairedList: View {
    let phones: [PairedPhone]
    let forget: (PairedPhone) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("mac.paired.title").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(phones) { phone in
                HStack(spacing: 10) {
                    Image(systemName: "iphone.gen3").foregroundStyle(Theme.accent)
                    Text(verbatim: phone.name).font(.subheadline)
                    Text(verbatim: String(phone.id.uuidString.prefix(4))).font(.caption.monospaced()).foregroundStyle(.secondary)
                    Spacer()
                    Button("mac.paired.forget") { forget(phone) }.buttonStyle(.plain).font(.caption).foregroundStyle(Theme.danger)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
