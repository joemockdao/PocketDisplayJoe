import SwiftUI

/// I due permessi richiesti, con lo stato di ciascuno e il pulsante per concederli.
struct PermissionsCard: View {
    let missing: [Permission]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Permission.allCases, id: \.name) { permission in
                HStack {
                    StepRow(symbol: permission.symbol,
                            title: LocalizedStringKey.key("perm.\(permission.name).title"),
                            detail: LocalizedStringKey.key("perm.\(permission.name).detail"),
                            tint: missing.contains(permission) ? Theme.warning : Theme.success)
                    if missing.contains(permission) {
                        Button("perm.grant") { permission.request(); permission.openSettings() }
                            .buttonStyle(.borderedProminent).controlSize(.small).tint(Theme.accent)
                    } else {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    }
                }
            }
            Text("perm.note").font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .card()
    }
}
