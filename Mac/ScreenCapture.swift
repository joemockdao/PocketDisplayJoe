import CoreMedia
import ScreenCaptureKit

/// Cattura di un display via ScreenCaptureKit: NV12 già scalato alla dimensione dello stream.
/// SCK emette frame solo quando il contenuto cambia (schermo fermo = zero banda).
final class ScreenCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    enum Failure: Error { case displayNotFound }

    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    var onStop: ((Error?) -> Void)?

    private var stream: SCStream?
    private let queue: DispatchQueue

    init(queue: DispatchQueue) { self.queue = queue }

    func start(displayID: CGDirectDisplayID, width: Int, height: Int, fps: Int) async throws {
        let display = try await findDisplay(displayID)
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
        config.queueDepth = 3
        config.showsCursor = true

        let stream = SCStream(filter: SCContentFilter(display: display, excludingWindows: []),
                              configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        try? await stream?.stopCapture()
        stream = nil
    }

    /// Il display virtuale compare in SCShareableContent con un lieve ritardo.
    private func findDisplay(_ id: CGDirectDisplayID) async throws -> SCDisplay {
        for _ in 0..<30 {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            if let display = content.displays.first(where: { $0.displayID == id }) { return display }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw Failure.displayNotFound
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let info = (CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
                          as? [[SCStreamFrameInfo: Any]])?.first,
              let raw = info[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete,
              let pixels = buffer.imageBuffer else { return }
        onFrame?(pixels, buffer.presentationTimeStamp)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) { onStop?(error) }
}
