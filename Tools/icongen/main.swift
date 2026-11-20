// Genera le icone delle app dal logo SwiftUI: `Tools/icongen/make-icons.sh`.
import AppKit
import SwiftUI

@MainActor
func write<V: View>(_ view: V, size: CGFloat, to path: String) {
    let renderer = ImageRenderer(content: view.frame(width: size, height: size))
    renderer.scale = 1
    guard let image = renderer.cgImage,
          let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        fatalError("render fallito: \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

MainActor.assumeIsolated {
    let out = CommandLine.arguments[1]
    // iOS: quadrato pieno senza trasparenza. macOS: squircle al 82% con ombra, su tela trasparente.
    write(AppLogo(kind: .phone, size: 1024, masked: false), size: 1024, to: "\(out)/phone-1024.png")
    write(AppLogo(kind: .mac, size: 840).shadow(color: .black.opacity(0.35), radius: 22, y: 14), size: 1024, to: "\(out)/mac-1024.png")
    write(AppLogo(kind: .phone, size: 512), size: 512, to: "\(out)/phone-preview.png")
    write(AppLogo(kind: .mac, size: 512), size: 512, to: "\(out)/mac-preview.png")
}
