import SwiftUI

/// Video a schermo intero; sopra, la schermata di attesa finché non c'è uno stream.
struct RootView: View {
    let receiver: Receiver

    var body: some View {
        ScreenViewRepresentable(receiver: receiver)
            .ignoresSafeArea(edges: .vertical)   // in orizzontale evita solo notch/Dynamic Island
            .background(.black)
            .gestureHint(whenStreaming: receiver.isStreaming)
            .overlay { if !receiver.isStreaming { WaitingView(receiver: receiver).ignoresSafeArea().transition(.opacity) } }
            .animation(.easeInOut(duration: 0.35), value: receiver.isStreaming)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            .preferredColorScheme(.dark)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
                receiver.start()
            }
    }
}
