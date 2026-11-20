#if DEBUG
import AppKit
import SwiftUI

/// Solo debug: `PocketDisplayJoeMac -snapshotDir <cartella> [-AppleLanguages "(it)"]` disegna il pannello in
/// ogni stato su file PNG ed esce. Serve a controllare grafica e traduzioni senza aprire la barra dei menu.
@MainActor
enum Snapshot {
    static func run(into directory: String) -> Never {
        let stream = StreamInfo(codec: .hevc, width: 2494, height: 1206, fps: 60, transport: .wifi)
        let cases: [(String, LinkState, [Permission])] = [
            ("permissions", .permissions, Permission.allCases), ("device", .device, []), ("app", .app, []),
            ("connecting", .connecting, []), ("outdated", .outdated, []), ("disconnected", .disconnected, []), ("streaming", .streaming(stream), []), ("failed", .failed, []),
        ]
        for (name, state, missing) in cases {
            let model = AppModel()
            model.preview(state, missing: missing, paired: [PairedPhone(id: UUID(), name: "iPhone", key: .random())])
            let renderer = ImageRenderer(content: MenuView(model: model))
            renderer.scale = 2
            if let image = renderer.cgImage,
               let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: "\(directory)/\(name).png"))
            }
        }
        let about = ImageRenderer(content: MenuView(model: AppModel(), showAbout: true, aboutScrolls: false))
        about.scale = 2
        if let image = about.cgImage, let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: "\(directory)/about.png"))
        }
        exit(0)
    }
}
#endif
