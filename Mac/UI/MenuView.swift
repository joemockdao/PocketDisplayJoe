import SwiftUI

/// Contenuto del pannello nella barra dei menu.
struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var showAbout: Bool

    private let aboutScrolls: Bool

    init(model: AppModel, showAbout: Bool = false, aboutScrolls: Bool = true) {
        self.model = model
        self.aboutScrolls = aboutScrolls
        _showAbout = State(initialValue: showAbout)
    }

    var body: some View {
        Group {
            if showAbout { AboutView(back: { showAbout = false }, maxHeight: aboutScrolls ? 560 : nil) } else { main }
        }
        .padding(16)
        .frame(width: 340)
        .background(Theme.backdrop)
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .onAppear { launchAtLogin = LoginItem.isEnabled }
        .animation(.easeInOut(duration: 0.2), value: showAbout)
    }

    private var main: some View {
        VStack(spacing: 12) {
            header
            StatusCard(state: model.shown, disconnect: model.disconnect, reconnect: model.reconnect)
            if !model.missing.isEmpty {
                PermissionsCard(missing: model.missing)
            } else if !model.shown.isStreaming, model.shown != .disconnected {
                VStack(alignment: .leading, spacing: 12) {
                    Text("mac.howto").font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                    HowItWorks()
                }
                .frame(maxWidth: .infinity, alignment: .leading).card()
            }
            if !model.paired.isEmpty { PairedList(phones: model.paired, forget: model.forget) }
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            AppLogo(kind: .mac, size: 34)
            Text("app.name").font(.system(.headline, design: .rounded))
            Spacer()
            Text(verbatim: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                .font(.caption).foregroundStyle(.secondary)
            Button { showAbout = true } label: { Image(systemName: "info.circle").font(.system(size: 15)) }
                .buttonStyle(.plain).foregroundStyle(.secondary).help("about.title")
                .accessibilityLabel("about.title")
        }
    }

    private var footer: some View {
        HStack {
            Toggle("mac.launch_at_login", isOn: Binding(get: { launchAtLogin },
                                                       set: { LoginItem.set($0); launchAtLogin = LoginItem.isEnabled }))
                .toggleStyle(.switch).controlSize(.small)
            Spacer()
            Button("mac.quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain).foregroundStyle(.secondary).keyboardShortcut("q")
        }
        .font(.caption)
    }
}
