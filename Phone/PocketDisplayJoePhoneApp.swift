import SwiftUI

@main
struct PocketDisplayJoePhoneApp: App {
    @State private var receiver = Receiver()

    var body: some Scene {
        WindowGroup { RootView(receiver: receiver) }
    }
}
