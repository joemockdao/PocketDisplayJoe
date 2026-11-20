import AVFoundation
import CoreMedia

/// Riceve frame compressi (AVCC) e li passa al renderer: la decodifica hardware la fa
/// `AVSampleBufferDisplayLayer` da sola, senza VTDecompressionSession.
final class VideoSink {
    /// Margine di riproduzione sul Wi-Fi: assorbe il jitter della radio (cavo: nessun margine).
    static let wifiPlayout = 0.05

    let layer = AVSampleBufferDisplayLayer()
    var onNeedKeyframe: (() -> Void)?
    /// Statistiche di ricezione ogni 3 s (solo diagnostica).
    var onStats: ((String) -> Void)?

    private var codec = Codec.hevc
    private var format: CMVideoFormatDescription?
    private var waitingForKeyframe = true

    // Riproduzione regolare: ogni frame viene mostrato a `timestamp + latenza minima del percorso + margine`.
    private var playout = 0.0
    private var minTransit: Double?       // minimo di (arrivo − timestamp): latenza "migliore" osservata
    private var lastDue = -Double.infinity
    private var stats = Stats()
    private struct Stats { var start = 0.0, frames = 0, late = 0, maxGap = 0.0, lastArrival = 0.0 }

    private static func hostTime() -> Double { CMClockGetTime(CMClockGetHostTimeClock()).seconds }

    init() {
        layer.videoGravity = .resize   // stream e vista hanno lo stesso aspect ratio
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if let timebase {
            CMTimebaseSetTime(timebase, time: CMClockGetTime(CMClockGetHostTimeClock()))
            CMTimebaseSetRate(timebase, rate: 1)
            layer.controlTimebase = timebase
        }
    }

    func configure(_ config: StreamConfig, playout: Double = 0) {
        codec = config.codec
        format = nil
        waitingForKeyframe = true
        self.playout = playout
        minTransit = nil
        lastDue = -.infinity
        layer.sampleBufferRenderer.flush()
    }

    func setParameterSets(_ sets: [Data]) {
        let buffers = sets.map { set -> UnsafeMutableBufferPointer<UInt8> in
            let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: set.count)
            _ = buffer.initialize(from: set)
            return buffer
        }
        defer { buffers.forEach { $0.deallocate() } }
        let pointers = buffers.map { UnsafePointer($0.baseAddress!) }
        let sizes = buffers.map(\.count)

        var created: CMVideoFormatDescription?
        let status = codec == .hevc
            ? CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: nil, parameterSetCount: sets.count, parameterSetPointers: pointers,
                                                                  parameterSetSizes: sizes, nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &created)
            : CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil, parameterSetCount: sets.count, parameterSetPointers: pointers,
                                                                  parameterSetSizes: sizes, nalUnitHeaderLength: 4, formatDescriptionOut: &created)
        guard status == noErr, let created else { return }
        if let format, CMFormatDescriptionEqual(format, otherFormatDescription: created) { return }
        format = created
    }

    func enqueue(_ data: Data, keyframe: Bool, time: UInt64) {
        let due = playout > 0 ? schedule(time: Double(time) / 1_000_000) : nil
        guard let format, let sample = makeSample(data, format: format, keyframe: keyframe, due: due) else { return }
        let renderer = layer.sampleBufferRenderer
        if renderer.status == .failed {   // tipico dopo il ritorno dal background
            renderer.flush()
            waitingForKeyframe = true
            onNeedKeyframe?()
        }
        if waitingForKeyframe {
            guard keyframe else { return }
            waitingForKeyframe = false
        }
        renderer.enqueue(sample)
    }

    /// Istante (orologio locale) in cui mostrare il frame. I frame in ritardo risultano nel passato e partono subito.
    private func schedule(time: Double) -> Double {
        let now = Self.hostTime()
        let transit = now - time
        minTransit = min(transit, (minTransit ?? transit) + 0.00002)   // risale piano: segue variazioni durature
        let due = max(time + minTransit! + playout, lastDue + 0.001)   // sempre crescente
        lastDue = due
        record(now: now, late: due < now)
        return due
    }

    private func record(now: Double, late: Bool) {
        guard onStats != nil else { return }
        if stats.start == 0 { stats.start = now; stats.lastArrival = now }
        stats.frames += 1
        stats.late += late ? 1 : 0
        stats.maxGap = max(stats.maxGap, now - stats.lastArrival)
        stats.lastArrival = now
        guard now - stats.start >= 3 else { return }
        onStats?(String(format: "%.0f fps · in ritardo %d%% · pausa max %.0f ms · margine %.0f ms",
                        Double(stats.frames) / (now - stats.start), stats.late * 100 / max(stats.frames, 1), stats.maxGap * 1000, playout * 1000))
        stats = Stats(start: now, lastArrival: now)
    }

    private func makeSample(_ data: Data, format: CMVideoFormatDescription, keyframe: Bool, due: Double?) -> CMSampleBuffer? {
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: data.count, blockAllocator: nil,
                                                 customBlockSource: nil, offsetToData: 0, dataLength: data.count, flags: 0,
                                                 blockBufferOut: &block) == noErr, let block,
              data.withUnsafeBytes({ CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: data.count) }) == noErr
        else { return nil }

        let pts = due.map { CMTime(seconds: $0, preferredTimescale: 1_000_000) } ?? CMClockGetTime(CMClockGetHostTimeClock())
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var size = data.count
        var sample: CMSampleBuffer?
        guard CMSampleBufferCreateReady(allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1,
                                        sampleTimingEntryCount: 1, sampleTimingArray: &timing, sampleSizeEntryCount: 1,
                                        sampleSizeArray: &size, sampleBufferOut: &sample) == noErr, let sample,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true) as? [NSMutableDictionary]
        else { return nil }
        if due == nil { attachments[0][kCMSampleAttachmentKey_DisplayImmediately] = true }   // cavo: latenza minima
        if !keyframe { attachments[0][kCMSampleAttachmentKey_NotSync] = true }
        return sample
    }
}
