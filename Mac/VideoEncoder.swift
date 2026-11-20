import CoreMedia
import VideoToolbox

/// Encoder hardware a bassa latenza (H.264 / HEVC): real-time, niente B-frame, un frame dentro / uno fuori.
final class VideoEncoder {
    struct Output {
        var data: Data                // AVCC
        var keyframe: Bool
        var parameterSets: [Data]?    // presenti sui keyframe
        var micros: UInt64            // istante di cattura
    }
    enum Failure: Error { case create(OSStatus) }

    var onOutput: ((Output) -> Void)?

    private let codec: Codec
    private var session: VTCompressionSession!
    private var lastPTS = CMTime.negativeInfinity

    init(codec: Codec, width: Int, height: Int, fps: Int, bitrate: Int) throws {
        self.codec = codec
        let type: CMVideoCodecType = codec == .hevc ? kCMVideoCodecType_HEVC : kCMVideoCodecType_H264
        let lowLatency = [kVTVideoEncoderSpecification_EnableLowLatencyRateControl: true] as CFDictionary

        var created: VTCompressionSession?
        var status = VTCompressionSessionCreate(allocator: nil, width: Int32(width), height: Int32(height), codecType: type,
                                                encoderSpecification: lowLatency, imageBufferAttributes: nil,
                                                compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                                compressionSessionOut: &created)
        if status != noErr {   // rate control a bassa latenza non disponibile: ripiega sul real-time classico
            status = VTCompressionSessionCreate(allocator: nil, width: Int32(width), height: Int32(height), codecType: type,
                                                encoderSpecification: nil, imageBufferAttributes: nil,
                                                compressedDataAllocator: nil, outputCallback: nil, refcon: nil,
                                                compressionSessionOut: &created)
        }
        guard status == noErr, let session = created else { throw Failure.create(status) }
        self.session = session

        VTSessionSetProperties(session, propertyDictionary: [
            kVTCompressionPropertyKey_RealTime: true,
            kVTCompressionPropertyKey_AllowFrameReordering: false,
            kVTCompressionPropertyKey_ProfileLevel: codec == .hevc ? kVTProfileLevel_HEVC_Main_AutoLevel
                                                                    : kVTProfileLevel_H264_High_AutoLevel,
            kVTCompressionPropertyKey_AverageBitRate: bitrate,
            kVTCompressionPropertyKey_ExpectedFrameRate: fps,
            kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 5,
            kVTCompressionPropertyKey_PrioritizeEncodingSpeedOverQuality: true,
        ] as CFDictionary)
        let prepared = VTCompressionSessionPrepareToEncodeFrames(session)
        guard prepared == noErr else { throw Failure.create(prepared) }   // es. HEVC non supportato da questo Mac
    }

    deinit { VTCompressionSessionInvalidate(session) }

    func encode(_ pixels: CVPixelBuffer, pts: CMTime, keyframe: Bool = false) {
        // I timestamp devono crescere in modo stretto, anche se ricodifichiamo l'ultimo frame.
        let time = max(pts, lastPTS + CMTime(value: 1, timescale: 1000))
        lastPTS = time
        let options = keyframe ? [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary : nil
        VTCompressionSessionEncodeFrame(session, imageBuffer: pixels, presentationTimeStamp: time, duration: .invalid,
                                        frameProperties: options, infoFlagsOut: nil) { [weak self] status, _, buffer in
            guard status == noErr, let buffer else { return }
            self?.emit(buffer)
        }
    }

    private func emit(_ sample: CMSampleBuffer) {
        guard let block = sample.dataBuffer else { return }
        let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[CFString: Any]]
        let keyframe = !(attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)

        var data = Data(count: CMBlockBufferGetDataLength(block))
        let copied = data.withUnsafeMutableBytes {
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: $0.count, destination: $0.baseAddress!)
        }
        guard copied == noErr else { return }
        let sets = keyframe ? sample.formatDescription.map(parameterSets) : nil
        onOutput?(Output(data: data, keyframe: keyframe, parameterSets: sets,
                         micros: UInt64(max(0, sample.presentationTimeStamp.seconds) * 1_000_000)))
    }

    private func parameterSets(of format: CMFormatDescription) -> [Data] {
        let get = codec == .hevc ? CMVideoFormatDescriptionGetHEVCParameterSetAtIndex
                                 : CMVideoFormatDescriptionGetH264ParameterSetAtIndex
        var count = 0
        _ = get(format, 0, nil, nil, &count, nil)
        return (0..<count).compactMap { index in
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            guard get(format, index, &pointer, &size, nil, nil) == noErr, let pointer else { return nil }
            return Data(bytes: pointer, count: size)
        }
    }
}
