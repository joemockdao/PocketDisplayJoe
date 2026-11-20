import CoreMedia
import Foundation
import os

/// Una sessione di streaming con un iPhone: hello → display virtuale → cattura → encoder → rete,
/// e in senso inverso tocchi → eventi mouse. Termina quando il collegamento cade.
private extension UUID {
    /// 32 bit stabili derivati dall'UUID (FNV-1a): stesso iPhone = stesso display.
    var serial: UInt32 { data.reduce(2_166_136_261) { ($0 ^ UInt32($1)) &* 16_777_619 } }
}

final class StreamSession {
    enum Failure: Error { case unexpectedMessage, displayCreation, incompatible }

    static let fps = 60
    private static let bitsPerPixel = 0.1

    private let link: Link
    private let transport: Transport
    private let queue = DispatchQueue(label: "pocketdisplay.pipeline", qos: .userInteractive)

    /// Contatori del secondo corrente (scritti da più thread), stampati nel log `stats`.
    private struct Stats { var encoded = 0, skipped = 0, bytes = 0, keyframes = 0, maxPending = 0 }
    private let stats = OSAllocatedUnfairLock(initialState: Stats())
    private static let log = Logger(subsystem: "it.joe.pocketdisplay.mac", category: "stats")

    // Stato della pipeline: toccato solo da `queue`.
    private var encoder: VideoEncoder?
    private var lastFrame: (pixels: CVPixelBuffer, pts: CMTime)?
    private var needsKeyframe = true
    private var retryScheduled = false

    init(link: Link, transport: Transport) { self.link = link; self.transport = transport }

    /// `onStreaming` è chiamato quando il video parte; `run` ritorna (o lancia) quando la sessione finisce.
    func run(onStreaming: @escaping (StreamInfo) -> Void) async throws {
        defer { link.cancel() }
        let first: Message
        do { first = try await link.receive() }
        catch Link.Failure.malformed { throw Failure.incompatible }   // app dell'iPhone di una versione diversa
        guard case .hello(let hello) = first else { throw Failure.unexpectedMessage }

        // Via cavo (canale già autenticato) l'iPhone riceve la chiave per i collegamenti Wi-Fi.
        if transport == .cable { link.send(.pair(PairedPhones.ensure(id: hello.id, name: hello.name))) }

        let (width, height) = (hello.width & ~1, hello.height & ~1)
        guard let display = await MainActor.run(body: { VirtualDisplay(name: hello.name, serial: hello.id.serial, pixelWidth: width, pixelHeight: height) })
        else { throw Failure.displayCreation }   // il display vive finché `display` è referenziato

        let (encoder, codec) = try Self.makeEncoder(preferHEVC: hello.supportsHEVC, width: width, height: height)
        encoder.onOutput = { [link, stats] out in
            if let sets = out.parameterSets { link.send(.parameterSets(sets)) }
            link.send(.frame(out.data, keyframe: out.keyframe, time: out.micros))
            stats.withLock { $0.encoded += 1; $0.bytes += out.data.count; $0.keyframes += out.keyframe ? 1 : 0; $0.maxPending = max($0.maxPending, link.pendingBytes) }
        }
        queue.sync { self.encoder = encoder }

        let input = InputInjector { display.bounds }   // tiene vivo `display` fino a fine sessione
        let capture = ScreenCapture(queue: queue)
        capture.onFrame = { [weak self] pixels, pts in self?.handle(pixels, pts) }
        link.send(.config(StreamConfig(codec: codec, width: width, height: height, fps: Self.fps)))
        await display.ensureHiDPI()
        try await capture.start(displayID: display.id, width: width, height: height, fps: Self.fps)
        onStreaming(StreamInfo(codec: codec, width: width, height: height, fps: Self.fps, transport: transport))

        let reporter = Task { [stats] in   // una riga al secondo, solo se c'è attività
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                let s = stats.withLock { let v = $0; $0 = Stats(); return v }
                if s.encoded + s.skipped > 0 {
                    Self.log.info("fps=\(s.encoded) saltati=\(s.skipped) kB/s=\(s.bytes / 1024) keyframe=\(s.keyframes) codaMax=\(s.maxPending / 1024)kB")
                }
            }
        }
        defer { reporter.cancel(); Task { await capture.stop() }; queue.sync { self.encoder = nil } }
        while true {
            switch try await link.receive() {
            case .touch(let touch): input.handle(touch)
            case .keyframeRequest: queue.async { self.needsKeyframe = true; self.encodeLast() }
            default: break
            }
            withExtendedLifetime(display) {}
        }
    }

    /// HEVC se l'iPhone lo decodifica e questo Mac lo codifica; altrimenti H.264 (più banda: +50%).
    private static func makeEncoder(preferHEVC: Bool, width: Int, height: Int) throws -> (VideoEncoder, Codec) {
        func make(_ codec: Codec) throws -> (VideoEncoder, Codec) {
            let bitrate = Double(width * height * fps) * bitsPerPixel * (codec == .h264 ? 1.5 : 1)
            return (try VideoEncoder(codec: codec, width: width, height: height, fps: fps, bitrate: Int(bitrate)), codec)
        }
        #if DEBUG
        let forceH264 = UserDefaults.standard.bool(forKey: "forceH264")   // prova del ripiego: `-forceH264 YES`
        #else
        let forceH264 = false
        #endif
        guard preferHEVC, !forceH264 else { return try make(.h264) }
        do { return try make(.hevc) } catch { return try make(.h264) }
    }

    // MARK: Pipeline (su `queue`)

    private func handle(_ pixels: CVPixelBuffer, _ pts: CMTime) {
        lastFrame = (pixels, pts)
        encodeLast()
    }

    /// Se la rete è intasata il frame viene scartato *prima* della codifica (i riferimenti P restano
    /// validi) e ritentato a breve, così uno schermo che si ferma non resta mai con l'immagine vecchia.
    private func encodeLast() {
        guard let (pixels, pts) = lastFrame, let encoder else { return }
        guard !link.isCongested else { stats.withLock { $0.skipped += 1 }; return scheduleRetry() }
        encoder.encode(pixels, pts: pts, keyframe: needsKeyframe)
        needsKeyframe = false
    }

    private func scheduleRetry() {
        guard !retryScheduled else { return }
        retryScheduled = true
        queue.asyncAfter(deadline: .now() + .milliseconds(20)) { [weak self] in
            self?.retryScheduled = false
            self?.encodeLast()
        }
    }
}
