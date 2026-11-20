import SwiftUI

@main
struct PocketDisplayJoeMacApp: App {
    @ObservedObject private var model = AppModel.shared

    init() {
        #if DEBUG
        if let directory = UserDefaults.standard.string(forKey: "snapshotDir") { Snapshot.run(into: directory) }
        #endif
        AppModel.shared.start()
    }

    var body: some Scene {
        MenuBarExtra("app.name", systemImage: model.shown.isStreaming ? "iphone.gen3.radiowaves.left.and.right" : "iphone.gen3") {
            MenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
