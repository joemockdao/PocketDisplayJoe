import CoreGraphics
import Foundation

/// Monitor virtuale macOS grande quanto lo schermo dell'iPhone.
/// Il display esiste finché questo oggetto è vivo.
final class VirtualDisplay {
    let id: CGDirectDisplayID
    private let display: CGVirtualDisplay

    /// Altezza minima in punti: sotto questa soglia macOS rifiuta il modo (o la UI diventa inutilizzabile).
    private static let minPointHeight = 600.0

    /// `pixelWidth/Height`: pixel dell'iPhone. Il desktop è HiDPI (2x) con densità 1:1 sui pixel del
    /// telefono quando possibile; sui telefoni piccoli i punti salgono a 600 di altezza e lo stream
    /// viene ridotto da ScreenCaptureKit.
    init?(name: String, serial: UInt32, pixelWidth: Int, pixelHeight: Int, fps: Double = 60) {
        let density = min(2.0, Double(pixelHeight) / Self.minPointHeight)
        let pointsWide = Int((Double(pixelWidth) / density).rounded())
        let pointsHigh = Int((Double(pixelHeight) / density).rounded())
        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(.main)
        descriptor.name = name
        descriptor.vendorID = 0x5343
        descriptor.productID = 0x4C4B
        descriptor.serialNum = serial   // distinto per iPhone: due telefoni = due display
        descriptor.maxPixelsWide = 8192
        descriptor.maxPixelsHigh = 8192
        descriptor.sizeInMillimeters = CGSize(width: Double(pixelWidth) / 460 * 25.4,
                                              height: Double(pixelHeight) / 460 * 25.4)   // ~460 ppi

        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = [CGVirtualDisplayMode(width: UInt(pointsWide), height: UInt(pointsHigh), refreshRate: fps)]
        let display = CGVirtualDisplay(descriptor: descriptor)
        guard display.apply(settings), display.displayID != 0 else { return nil }
        self.display = display
        self.id = display.displayID
        self.points = (pointsWide, pointsHigh)
    }

    private let points: (wide: Int, high: Int)

    /// macOS attiva di default il modo 1x (UI minuscola): seleziona esplicitamente quello HiDPI.
    /// Il display compare con un lieve ritardo, quindi si riprova per ~2 s.
    func ensureHiDPI() async {
        let options = [kCGDisplayShowDuplicateLowResolutionModes: true] as CFDictionary
        for _ in 0..<20 {
            if let current = CGDisplayCopyDisplayMode(id), current.width == points.wide, current.pixelWidth == 2 * points.wide { return }
            if let modes = CGDisplayCopyAllDisplayModes(id, options) as? [CGDisplayMode],
               let mode = modes.first(where: { $0.width == points.wide && $0.height == points.high && $0.pixelWidth == 2 * points.wide }) {
                var config: CGDisplayConfigRef?
                CGBeginDisplayConfiguration(&config)
                CGConfigureDisplayWithDisplayMode(config, id, mode, nil)
                CGCompleteDisplayConfiguration(config, .forSession)
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Rettangolo del display nello spazio globale (punti).
    var bounds: CGRect { CGDisplayBounds(id) }
}
