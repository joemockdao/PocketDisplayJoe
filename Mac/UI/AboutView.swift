import SwiftUI

/// Pagina "Info" del pannello: cosa fa l'app, progetto e crediti, altre app. Si apre dall'icona ⓘ.
struct AboutView: View {
    let back: () -> Void
    /// Il contenuto scorre oltre questa altezza (nel pannello); `nil` = nessun limite (anteprime).
    var maxHeight: CGFloat? = 560

    private static let features = [("display.2", "display"), ("hand.tap", "touch"), ("lock.shield", "private")]

    var body: some View {
        VStack(spacing: 12) {
            backButton
            if let maxHeight { ScrollView(showsIndicators: false) { content }.frame(maxHeight: maxHeight) } else { content }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            hero
            section("about.features") {
                ForEach(Self.features, id: \.1) { symbol, name in
                    StepRow(symbol: symbol, title: .key("about.feature.\(name).title"), detail: .key("about.feature.\(name).detail"))
                }
            }
            section("about.project") {
                linkRow(url: AboutContent.projectURL) {
                    StepRow(symbol: "chevron.left.forwardslash.chevron.right", title: "about.source", detail: "about.source.detail")
                }
            }
            section("about.other") {
                ForEach(AboutContent.apps) { AppRow(app: $0) }
            }
        }
    }

    private var backButton: some View {
        HStack {
            Button(action: back) { Label("action.back", systemImage: "chevron.left").font(.callout.weight(.medium)) }
                .buttonStyle(.plain).foregroundStyle(Theme.accent).keyboardShortcut(.cancelAction)
            Spacer()
        }
    }

    private var hero: some View {
        VStack(spacing: 6) {
            AppLogo(kind: .mac, size: 64)
            Text("app.name").font(.system(.title2, design: .rounded).weight(.bold))
            Text("about.tagline").font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text(verbatim: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// Riga cliccabile se c'è un indirizzo, altrimenti solo testo.
    @ViewBuilder private func linkRow<Row: View>(url: URL?, @ViewBuilder row: () -> Row) -> some View {
        if let url {
            SwiftUI.Link(destination: url) { HStack { row(); Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.secondary) } }
                .buttonStyle(.plain)
        } else {
            row()
        }
    }
}

/// Un'altra app: icona, nome, frase e un pulsante per ogni negozio.
private struct AppRow: View {
    let app: AboutContent.App

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(app.icon).resizable().frame(width: 40, height: 40).clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: app.name).font(.subheadline.weight(.semibold))
                    Text(app.summary).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 6) { ForEach(app.stores) { StoreButton(store: $0) } }
            }
            Spacer(minLength: 0)
        }
    }
}

private struct StoreButton: View {
    let store: AboutContent.Store

    var body: some View {
        SwiftUI.Link(destination: store.url) {
            HStack(spacing: 3) { Text(verbatim: store.name); Image(systemName: "arrow.up.right").font(.system(size: 8, weight: .bold)) }
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(.white.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
