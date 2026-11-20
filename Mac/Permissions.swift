import AppKit
import ApplicationServices

/// Permessi di macOS necessari all'app. `name` è il frammento delle chiavi `perm.<name>.title/.detail`.
enum Permission: CaseIterable {
    case screen, accessibility

    static var missing: [Permission] { allCases.filter { !$0.isGranted } }

    var name: String { self == .screen ? "screen" : "accessibility" }
    var symbol: String { self == .screen ? "rectangle.dashed.badge.record" : "hand.point.up.left" }

    var isGranted: Bool {
        switch self {
        case .screen: CGPreflightScreenCaptureAccess()
        case .accessibility: AXIsProcessTrusted()
        }
    }

    /// Mostra il prompt di sistema (una sola volta per permesso, poi serve Impostazioni).
    func request() {
        switch self {
        case .screen: _ = CGRequestScreenCaptureAccess()
        case .accessibility: _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        }
    }

    func openSettings() {
        let pane = self == .screen ? "Privacy_ScreenCapture" : "Privacy_Accessibility"
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!)
    }
}
