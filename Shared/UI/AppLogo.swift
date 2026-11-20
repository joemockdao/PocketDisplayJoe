import SwiftUI

/// Logo delle due app, disegnato in SwiftUI: fonte unica per interfaccia e icone (vedi `Tools/icongen`).
/// - `.phone`: l'iPhone che riceve il desktop, collegato dal cavo.
/// - `.mac`: il display del Mac con l'iPhone che lo estende.
struct AppLogo: View {
    enum Kind { case phone, mac }

    var kind: Kind
    var size: CGFloat
    var masked = true   // false = quadrato pieno (icona iOS: la maschera la applica il sistema)

    private let ink = Color(red: 0.04, green: 0.06, blue: 0.14)
    private var s: CGFloat { size }

    var body: some View {
        ZStack {
            LinearGradient(colors: kind == .phone ? [Color(red: 0.38, green: 0.34, blue: 1.0), Color(red: 0.12, green: 0.58, blue: 0.98), Color(red: 0.08, green: 0.82, blue: 0.84)]
                                                  : [Color(red: 0.20, green: 0.12, blue: 0.52), Color(red: 0.42, green: 0.22, blue: 0.86), Color(red: 0.90, green: 0.40, blue: 0.70)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if kind == .phone { phoneIcon } else { macIcon }
        }
        .frame(width: s, height: s)
        .clipShape(RoundedRectangle(cornerRadius: masked ? s * 0.2237 : 0, style: .continuous))
    }

    // MARK: iPhone — un telefono orizzontale con il desktop, cavo che arriva da destra

    private var phoneIcon: some View {
        ZStack {
            cable(x: 0.80, y: 0.5)
            device(width: 0.70, height: 0.38, bezel: ink, radius: 0.08, island: true)
                .shadow(color: .black.opacity(0.35), radius: s * 0.03, y: s * 0.02)
                .offset(x: -s * 0.05)
        }
    }

    // MARK: Mac — display con la finestra che "esce" sull'iPhone davanti

    private var macIcon: some View {
        ZStack {
            VStack(spacing: 0) {   // display + piede
                device(width: 0.68, height: 0.44, bezel: Color(red: 0.86, green: 0.88, blue: 0.93), radius: 0.045, island: false)
                Rectangle().fill(Color(red: 0.70, green: 0.72, blue: 0.80)).frame(width: s * 0.09, height: s * 0.06)
                Capsule().fill(Color(red: 0.86, green: 0.88, blue: 0.93)).frame(width: s * 0.26, height: s * 0.022)
            }
            .shadow(color: .black.opacity(0.30), radius: s * 0.03, y: s * 0.02)
            .offset(x: -s * 0.04, y: -s * 0.05)

            ZStack {
                device(width: 0.36, height: 0.19, bezel: ink, radius: 0.045, island: true, windows: false)
                    .overlay(RoundedRectangle(cornerRadius: s * 0.045, style: .continuous).strokeBorder(.white.opacity(0.9), lineWidth: s * 0.01))
                    .shadow(color: .black.opacity(0.4), radius: s * 0.025, y: s * 0.015)
            }
            .offset(x: s * 0.20, y: s * 0.27)
            cable(x: 0.88, y: 0.77, scale: 0.8)
        }
    }

    // MARK: Elementi

    /// Cavo USB orizzontale (coordinate frazionarie del lato): connettore attaccato in `x`, filo fino al bordo destro.
    private func cable(x: CGFloat, y: CGFloat, scale: CGFloat = 1) -> some View {
        let plug = s * 0.07 * scale
        return ZStack {
            Rectangle().fill(.white.opacity(0.92)).frame(width: s * (1.1 - x), height: s * 0.02 * scale)
                .position(x: s * (x + 1.1) / 2, y: s * y)
            RoundedRectangle(cornerRadius: s * 0.012).fill(.white.opacity(0.92)).frame(width: plug, height: s * 0.05 * scale)
                .position(x: s * x + plug / 2, y: s * y)
        }
        .frame(width: s, height: s)
    }

    /// Dispositivo con schermo-desktop (sfondo al tramonto, barra dei menu, finestra).
    private func device(width: CGFloat, height: CGFloat, bezel: Color, radius: CGFloat, island: Bool, windows: Bool = true) -> some View {
        let w = s * width, h = s * height, inset = s * 0.02
        return ZStack {
            RoundedRectangle(cornerRadius: s * radius, style: .continuous).fill(bezel)
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [Color(red: 1.0, green: 0.80, blue: 0.35), Color(red: 1.0, green: 0.45, blue: 0.45), Color(red: 0.55, green: 0.30, blue: 0.85)],
                               startPoint: .top, endPoint: .bottomTrailing)
                Rectangle().fill(.white.opacity(0.35)).frame(height: h * 0.12)
                HStack(spacing: s * 0.008) { ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.85)).frame(width: h * 0.045) } }
                    .padding(.leading, w * 0.08).padding(.top, h * 0.038)
                if windows {
                    RoundedRectangle(cornerRadius: s * 0.014, style: .continuous).fill(.white.opacity(0.88))
                        .frame(width: w * 0.42, height: h * 0.5).offset(x: w * 0.2, y: h * 0.3)
                }
                if island {
                    Capsule().fill(ink).frame(width: s * 0.014, height: h * 0.2).offset(x: s * 0.01, y: h * 0.4)
                }
            }
            .frame(width: w - inset * 2, height: h - inset * 2)
            .clipShape(RoundedRectangle(cornerRadius: s * radius * 0.72, style: .continuous))
        }
        .frame(width: w, height: h)
    }
}
