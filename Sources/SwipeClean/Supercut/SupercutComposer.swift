import AVFoundation
import Photos
import UIKit

// MARK: - Cut Speed

enum CutSpeed: String, CaseIterable, Identifiable {
    case fast
    case medium
    case slow
    case beatMatch

    var id: String { rawValue }

    var duration: Double {
        switch self {
        case .fast: return 0.5
        case .medium: return 1.5
        case .slow: return 3.0
        case .beatMatch: return 0 // determined by audio analysis
        }
    }

    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .medium: return "Medium"
        case .slow: return "Slow"
        case .beatMatch: return "Match Beat"
        }
    }
}

// MARK: - SupercutComposer

/// Composes a montage video from a collection of photos and videos using AVFoundation.
final class SupercutComposer: ObservableObject {
    @Published var progress: Float = 0
    @Published var status: String = "Preparing..."
    @Published var isComplete = false
    @Published var outputURL: URL?
    @Published var error: String?

    private var isCancelled = false

    /// Cancel the current composition.
    func cancel() {
        isCancelled = true
    }

    // MARK: - Main Entry Point

    /// Generates a supercut video from the given photos and optional music.
    /// - Parameters:
    ///   - photos: sorted PhotoItems (best first, already scored by PhotoAnalyzer)
    ///   - musicURL: optional URL to an audio file
    ///   - cutSpeed: how long each photo shows
    ///   - maxDuration: maximum total video length in seconds
    @MainActor
    func compose(
        photos: [PhotoItem],
        musicURL: URL?,
        cutSpeed: CutSpeed,
        maxDuration: TimeInterval
    ) async {
        reset()

        guard !photos.isEmpty else {
            error = "No photos to compose."
            return
        }

        do {
            // Determine output size from first photo's aspect ratio.
            let renderSize = detectRenderSize(from: photos.first)

            // Compute cut durations per item.
            let cutDurations: [Double]
            if cutSpeed == .beatMatch, let url = musicURL {
                updateStatus("Analyzing beats...")
                let beats = await detectBeats(in: url, maxDuration: maxDuration)
                cutDurations = beatDurations(beats: beats, itemCount: photos.count, maxDuration: maxDuration)
            } else {
                cutDurations = uniformDurations(
                    perItem: cutSpeed.duration,
                    itemCount: photos.count,
                    maxDuration: maxDuration
                )
            }

            let totalDuration = cutDurations.reduce(0, +)

            // Write intermediate clip via AVAssetWriter.
            updateStatus("Rendering frames...")
            let rawVideoURL = try await writeRawVideo(
                photos: photos,
                durations: cutDurations,
                renderSize: renderSize
            )

            // Compose final output with optional audio.
            updateStatus("Mixing audio...")
            let finalURL = try await mixAudio(
                videoURL: rawVideoURL,
                musicURL: musicURL,
                totalDuration: totalDuration
            )

            // Clean up intermediate file.
            try? FileManager.default.removeItem(at: rawVideoURL)

            updateStatus("Done")
            progress = 1.0
            outputURL = finalURL
            isComplete = true
        } catch {
            if isCancelled {
                self.error = "Cancelled."
            } else {
                self.error = error.localizedDescription
            }
        }
    }

    // MARK: - Reset

    @MainActor
    private func reset() {
        progress = 0
        status = "Preparing..."
        isComplete = false
        outputURL = nil
        error = nil
        isCancelled = false
    }

    @MainActor
    private func updateStatus(_ text: String) {
        status = text
    }

    @MainActor
    private func updateProgress(_ value: Float) {
        progress = value
    }

    // MARK: - Render Size Detection

    private func detectRenderSize(from photo: PhotoItem?) -> CGSize {
        guard let image = photo?.fullImage ?? photo?.thumbnail else {
            return CGSize(width: 1080, height: 1920) // default portrait
        }
        let aspect = image.size.width / image.size.height
        if aspect >= 1.0 {
            // Landscape
            return CGSize(width: 1920, height: 1080)
        } else {
            // Portrait
            return CGSize(width: 1080, height: 1920)
        }
    }

    // MARK: - Duration Calculation

    private func uniformDurations(perItem: Double, itemCount: Int, maxDuration: TimeInterval) -> [Double] {
        let totalIfUniform = perItem * Double(itemCount)
        let clippedTotal = min(totalIfUniform, maxDuration)
        let usableCount = Int(clippedTotal / perItem)
        return Array(repeating: perItem, count: max(usableCount, 1))
    }

    private func beatDurations(beats: [Double], itemCount: Int, maxDuration: TimeInterval) -> [Double] {
        guard !beats.isEmpty else {
            // Fallback to medium speed if no beats detected.
            return uniformDurations(perItem: CutSpeed.medium.duration, itemCount: itemCount, maxDuration: maxDuration)
        }

        var durations: [Double] = []
        var previousTime = 0.0

        for beat in beats {
            guard beat <= maxDuration else { break }
            guard durations.count < itemCount else { break }
            let d = beat - previousTime
            if d > 0.2 { // skip beats that are too close together
                durations.append(d)
                previousTime = beat
            }
        }

        if durations.isEmpty {
            return uniformDurations(perItem: CutSpeed.medium.duration, itemCount: itemCount, maxDuration: maxDuration)
        }

        return durations
    }

    // MARK: - Beat Detection

    /// Simple amplitude-peak beat detection from an audio file.
    private func detectBeats(in url: URL, maxDuration: TimeInterval) async -> [Double] {
        do {
            let audioFile = try AVAudioFile(forReading: url)
            let format = audioFile.processingFormat
            let sampleRate = format.sampleRate
            let totalFrames = AVAudioFrameCount(audioFile.length)
            let maxFrames = AVAudioFrameCount(min(Double(totalFrames), maxDuration * sampleRate))

            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: maxFrames) else {
                return []
            }
            try audioFile.read(into: buffer, frameCount: maxFrames)

            guard let channelData = buffer.floatChannelData?[0] else { return [] }

            // Compute RMS energy in windows, detect peaks.
            let windowSize = Int(sampleRate * 0.05) // 50ms windows
            let hopSize = windowSize / 2
            var energies: [(time: Double, energy: Float)] = []

            var i = 0
            while i + windowSize <= Int(maxFrames) {
                var sum: Float = 0
                for j in i..<(i + windowSize) {
                    let sample = channelData[j]
                    sum += sample * sample
                }
                let rms = sqrt(sum / Float(windowSize))
                let time = Double(i) / sampleRate
                energies.append((time, rms))
                i += hopSize
            }

            guard !energies.isEmpty else { return [] }

            // Find peaks: points where energy is above the local average.
            let avgEnergy = energies.map(\.energy).reduce(0, +) / Float(energies.count)
            let threshold = avgEnergy * 1.5

            var beats: [Double] = []
            var lastBeatTime = -0.3

            for entry in energies {
                if entry.energy > threshold, entry.time - lastBeatTime > 0.25 {
                    beats.append(entry.time)
                    lastBeatTime = entry.time
                }
            }

            return beats
        } catch {
            return []
        }
    }

    // MARK: - Raw Video Writing

    /// Writes photos and video clips into a single video file using AVAssetWriter.
    private func writeRawVideo(
        photos: [PhotoItem],
        durations: [Double],
        renderSize: CGSize
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("supercut_raw_\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(renderSize.width),
            AVVideoHeightKey: Int(renderSize.height)
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourcePixelAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(renderSize.width),
            kCVPixelBufferHeightKey as String: Int(renderSize.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourcePixelAttributes
        )

        writer.add(writerInput)
        guard writer.startWriting() else {
            throw writer.error ?? ComposerError.writerFailed
        }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 30
        var frameIndex: Int64 = 0
        let itemCount = min(photos.count, durations.count)

        for i in 0..<itemCount {
            if isCancelled { throw ComposerError.cancelled }

            let photo = photos[i]
            let clipDuration = durations[i]
            let framesForClip = Int64(clipDuration * Double(fps))

            if photo.mediaType == .video, let asset = photo.asset {
                // Extract frames from video asset.
                let avAsset = try await loadAVAsset(from: asset)
                let extractDuration = min(clipDuration, 3.0) // cap at 3 seconds
                try await writeVideoFrames(
                    from: avAsset,
                    duration: extractDuration,
                    renderSize: renderSize,
                    writerInput: writerInput,
                    adaptor: adaptor,
                    startFrame: &frameIndex,
                    fps: fps
                )
            } else {
                // Write still image as video frames.
                guard let image = photo.fullImage ?? photo.thumbnail else { continue }
                guard let pixelBuffer = createPixelBuffer(from: image, size: renderSize) else { continue }

                for _ in 0..<framesForClip {
                    if isCancelled { throw ComposerError.cancelled }

                    while !writerInput.isReadyForMoreMediaData {
                        try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                    }

                    let presentationTime = CMTime(value: frameIndex, timescale: fps)
                    adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    frameIndex += 1
                }
            }

            await updateProgress(Float(i + 1) / Float(itemCount) * 0.8) // 80% for rendering
        }

        writerInput.markAsFinished()
        await writer.finishWriting()

        if writer.status == .failed {
            throw writer.error ?? ComposerError.writerFailed
        }

        return outputURL
    }

    // MARK: - Video Frame Extraction

    /// Loads an AVAsset from a PHAsset.
    private func loadAVAsset(from phAsset: PHAsset) async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            options.deliveryMode = .highQualityFormat

            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    let err = info?[PHImageErrorKey] as? Error
                    continuation.resume(throwing: err ?? ComposerError.assetLoadFailed)
                }
            }
        }
    }

    /// Writes frames extracted from an AVAsset video into the writer.
    private func writeVideoFrames(
        from avAsset: AVAsset,
        duration: Double,
        renderSize: CGSize,
        writerInput: AVAssetWriterInput,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        startFrame: inout Int64,
        fps: Int32
    ) async throws {
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = renderSize
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.05, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.05, preferredTimescale: 600)

        let frameCount = Int(duration * Double(fps))
        let timeIncrement = duration / Double(frameCount)

        for f in 0..<frameCount {
            if isCancelled { throw ComposerError.cancelled }

            let requestTime = CMTime(seconds: Double(f) * timeIncrement, preferredTimescale: 600)

            let cgImage: CGImage
            do {
                let (image, _) = try await generator.image(at: requestTime)
                cgImage = image
            } catch {
                continue // skip frames that fail to extract
            }

            let uiImage = UIImage(cgImage: cgImage)
            guard let pixelBuffer = createPixelBuffer(from: uiImage, size: renderSize) else { continue }

            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let presentationTime = CMTime(value: startFrame, timescale: fps)
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
            startFrame += 1
        }
    }

    // MARK: - Pixel Buffer Creation

    /// Creates a CVPixelBuffer from a UIImage, scaled to fill the target size.
    private func createPixelBuffer(from image: UIImage, size: CGSize) -> CVPixelBuffer? {
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        guard let cgImage = image.cgImage else { return nil }

        // Scale-to-fill: compute a rect that fills the target size, cropping as needed.
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let targetAspect = size.width / size.height

        var drawRect: CGRect
        if imageAspect > targetAspect {
            // Image is wider: fill height, crop sides.
            let scaledWidth = size.height * imageAspect
            drawRect = CGRect(
                x: (size.width - scaledWidth) / 2,
                y: 0,
                width: scaledWidth,
                height: size.height
            )
        } else {
            // Image is taller: fill width, crop top/bottom.
            let scaledHeight = size.width / imageAspect
            drawRect = CGRect(
                x: 0,
                y: (size.height - scaledHeight) / 2,
                width: size.width,
                height: scaledHeight
            )
        }

        // Fill with black first.
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        context.draw(cgImage, in: drawRect)

        return buffer
    }

    // MARK: - Audio Mixing

    /// Mixes an optional audio track into the video, producing the final output.
    private func mixAudio(videoURL: URL, musicURL: URL?, totalDuration: TimeInterval) async throws -> URL {
        guard let musicURL else {
            // No audio — just return the raw video as-is.
            return videoURL
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("supercut_final_\(UUID().uuidString).mp4")

        let composition = AVMutableComposition()

        // Add video track.
        let videoAsset = AVURLAsset(url: videoURL)
        guard let videoAssetTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
              let compositionVideoTrack = composition.addMutableTrack(
                  withMediaType: .video,
                  preferredTrackID: kCMPersistentTrackID_Invalid
              ) else {
            throw ComposerError.trackNotFound
        }

        let videoDuration = try await videoAsset.load(.duration)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: videoDuration),
            of: videoAssetTrack,
            at: .zero
        )

        // Add audio track.
        let audioAsset = AVURLAsset(url: musicURL)
        if let audioAssetTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
           let compositionAudioTrack = composition.addMutableTrack(
               withMediaType: .audio,
               preferredTrackID: kCMPersistentTrackID_Invalid
           ) {
            let audioDuration = try await audioAsset.load(.duration)
            let trimmedDuration = min(audioDuration, videoDuration)

            try compositionAudioTrack.insertTimeRange(
                CMTimeRange(start: .zero, duration: trimmedDuration),
                of: audioAssetTrack,
                at: .zero
            )

            // Apply fade-out on the last 2 seconds of audio.
            let fadeOutDuration = CMTime(seconds: 2.0, preferredTimescale: 600)
            let fadeOutStart = CMTimeSubtract(trimmedDuration, fadeOutDuration)

            if CMTimeCompare(fadeOutStart, .zero) > 0 {
                let audioMix = AVMutableAudioMix()
                let params = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
                params.setVolumeRamp(
                    fromStartVolume: 1.0,
                    toEndVolume: 0.0,
                    timeRange: CMTimeRange(start: fadeOutStart, duration: fadeOutDuration)
                )
                audioMix.inputParameters = [params]

                // Export with audio mix.
                return try await exportComposition(composition, audioMix: audioMix, to: outputURL)
            }
        }

        return try await exportComposition(composition, audioMix: nil, to: outputURL)
    }

    /// Exports an AVMutableComposition to a file.
    private func exportComposition(
        _ composition: AVMutableComposition,
        audioMix: AVAudioMix?,
        to outputURL: URL
    ) async throws -> URL {
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            throw ComposerError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.audioMix = audioMix

        await exportSession.export()

        await updateProgress(1.0)

        switch exportSession.status {
        case .completed:
            return outputURL
        case .failed:
            throw exportSession.error ?? ComposerError.exportFailed
        case .cancelled:
            throw ComposerError.cancelled
        default:
            throw ComposerError.exportFailed
        }
    }

    // MARK: - Errors

    enum ComposerError: LocalizedError {
        case writerFailed
        case assetLoadFailed
        case trackNotFound
        case exportFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .writerFailed: return "Video writer failed."
            case .assetLoadFailed: return "Could not load video asset."
            case .trackNotFound: return "No video track found."
            case .exportFailed: return "Export failed."
            case .cancelled: return "Cancelled."
            }
        }
    }
}
