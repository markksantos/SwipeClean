import Vision
import Photos
import UIKit
import CoreImage

// MARK: - PhotoScore

struct PhotoScore {
    let item: PhotoItem
    let qualityScore: Float   // 0-1 composite score
    let hasFaces: Bool
    let sharpness: Float      // 0-1
    let saliencyScore: Float  // 0-1
}

// MARK: - PhotoAnalyzer

final class PhotoAnalyzer {

    /// Maximum number of photos analyzed concurrently via TaskGroup.
    private let maxConcurrency = 4

    // MARK: - Public API

    /// Analyzes an array of PhotoItems and returns them sorted by quality score (best first).
    /// Favorited photos get a 1.5x score multiplier (capped at 1.0).
    /// Uses TaskGroup to analyze photos in parallel for speed.
    func analyzeAndRank(
        _ items: [PhotoItem],
        progress: @escaping (Float) -> Void
    ) async -> [PhotoScore] {
        guard !items.isEmpty else { return [] }

        let totalCount = items.count
        let completed = Counter()

        let scores: [PhotoScore] = await withTaskGroup(
            of: PhotoScore.self,
            returning: [PhotoScore].self
        ) { group in
            var results: [PhotoScore] = []
            results.reserveCapacity(totalCount)

            // Feed items into the group, limiting concurrency by only adding
            // a new task when a previous one completes once we hit the cap.
            var iterator = items.makeIterator()
            var inFlight = 0

            // Seed the group with up to maxConcurrency tasks.
            while inFlight < maxConcurrency, let item = iterator.next() {
                group.addTask { [weak self] in
                    guard let self else {
                        return PhotoScore(item: item, qualityScore: 0, hasFaces: false, sharpness: 0, saliencyScore: 0)
                    }
                    return self.score(for: item)
                }
                inFlight += 1
            }

            // As each task completes, enqueue the next item.
            for await result in group {
                results.append(result)
                let done = await completed.increment()
                progress(Float(done) / Float(totalCount))

                if let nextItem = iterator.next() {
                    group.addTask { [weak self] in
                        guard let self else {
                            return PhotoScore(item: nextItem, qualityScore: 0, hasFaces: false, sharpness: 0, saliencyScore: 0)
                        }
                        return self.score(for: nextItem)
                    }
                }
            }

            return results
        }

        return scores.sorted { $0.qualityScore > $1.qualityScore }
    }

    // MARK: - Per-Item Scoring

    private func score(for item: PhotoItem) -> PhotoScore {
        // Videos get a flat score — they're usually intentional content.
        if item.mediaType == .video {
            return PhotoScore(
                item: item,
                qualityScore: 0.7,
                hasFaces: false,
                sharpness: 0.7,
                saliencyScore: 0.7
            )
        }

        let image = resolveImage(for: item)

        guard let image else {
            return PhotoScore(item: item, qualityScore: 0, hasFaces: false, sharpness: 0, saliencyScore: 0)
        }

        let analysis = analyzeImage(image)

        var composite = analysis.quality
        if item.isFavorited {
            composite = min(composite * 1.5, 1.0)
        }

        return PhotoScore(
            item: item,
            qualityScore: composite,
            hasFaces: analysis.hasFaces ?? false,
            sharpness: analysis.sharpness,
            saliencyScore: analysis.saliency ?? 0
        )
    }

    // MARK: - Image Resolution

    /// Returns the best available UIImage for a PhotoItem.
    /// Falls back to synchronously loading from the PHAsset at 600x600.
    private func resolveImage(for item: PhotoItem) -> UIImage? {
        if let full = item.fullImage { return full }
        if let thumb = item.thumbnail { return thumb }

        guard let asset = item.asset else { return nil }

        var result: UIImage?
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true

        let targetSize = CGSize(width: 600, height: 600)

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            result = image
        }

        return result
    }

    // MARK: - Vision Analysis

    /// What a single photo's analysis produced.
    ///
    /// Saliency and faces are optional because the Vision requests behind them can
    /// be genuinely unavailable — on the simulator they fail outright with "failed
    /// to create espresso context", since there is no neural backend. Treating a
    /// missing component as a zero silently deleted 40% of the score and ranked
    /// every photo the same; `quality` renormalises over whatever actually ran.
    struct Analysis {
        var sharpness: Float
        var saliency: Float?
        var hasFaces: Bool?

        /// Weighted composite over the available components, 0-1.
        var quality: Float {
            var weighted: Float = sharpness * Weight.sharpness
            var total: Float = Weight.sharpness

            if let saliency {
                weighted += saliency * Weight.saliency
                total += Weight.saliency
            }
            if let hasFaces {
                weighted += (hasFaces ? 1 : 0) * Weight.faces
                total += Weight.faces
            }

            guard total > 0 else { return 0 }
            return min(max(weighted / total, 0), 1)
        }

        enum Weight {
            static let sharpness: Float = 0.3
            static let saliency: Float = 0.4
            static let faces: Float = 0.3
        }
    }

    /// Analyzes a single photo: Laplacian-variance sharpness, attention-based
    /// saliency, and face presence.
    func analyzeImage(_ image: UIImage) -> Analysis {
        guard let cgImage = image.cgImage else {
            return Analysis(sharpness: 0, saliency: nil, hasFaces: nil)
        }

        return Analysis(
            sharpness: computeSharpness(of: cgImage),
            saliency: computeSaliency(in: cgImage),
            hasFaces: detectFaces(in: cgImage)
        )
    }

    // MARK: Face Detection

    /// nil when Vision could not run, which is different from "no faces here".
    func detectFaces(in cgImage: CGImage) -> Bool? {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let results = request.results else { return nil }
        return !results.isEmpty
    }

    // MARK: Saliency

    /// Mean attention across Vision's attention heat map, 0-1.
    ///
    /// This previously read `observation.salientObjects`, which an
    /// **attention**-based request never populates — only the objectness-based
    /// request returns bounding boxes. So the `let salientObjects` binding always
    /// failed and every photo scored 0 for saliency. The heat map lives in
    /// `observation.pixelBuffer` and has to be read directly.
    /// nil when Vision could not run at all.
    func computeSaliency(in cgImage: CGImage) -> Float? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = request.results?.first as? VNSaliencyImageObservation else {
            return nil
        }
        return Self.meanValue(ofOneComponentFloatBuffer: observation.pixelBuffer)
    }

    /// Averages a `kCVPixelFormatType_OneComponent32Float` buffer, which is what
    /// Vision's saliency heat map is.
    private static func meanValue(ofOneComponentFloatBuffer buffer: CVPixelBuffer) -> Float {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return 0 }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer)
        guard width > 0, height > 0 else { return 0 }

        var total: Float = 0
        for row in 0..<height {
            // Row-by-row: the buffer is padded to its stride, so it cannot be
            // walked as one flat array of width*height floats.
            let rowStart = base.advanced(by: row * stride).assumingMemoryBound(to: Float.self)
            for column in 0..<width {
                total += rowStart[column]
            }
        }

        return min(max(total / Float(width * height), 0), 1)
    }

    // MARK: Sharpness (Laplacian Variance)

    /// Computes image sharpness using Laplacian variance.
    ///
    /// Approach:
    /// 1. Convert to grayscale via CIFilter.
    /// 2. Apply CIConvolution3X3 with a Laplacian kernel.
    /// 3. Read the result back as 32-bit float and take the variance.
    /// 4. Normalize to 0-1.
    ///
    /// The read-back has to be float. Rendering to `.RGBA8` clamped the
    /// convolution's negative values — half of a Laplacian's output — to zero, and
    /// paired an RGBA format with a one-channel grey colour space, so the variance
    /// came out at essentially zero for every image. Combined with the saliency
    /// bug above, that made every quality score 0.
    func computeSharpness(of cgImage: CGImage) -> Float {
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        let ciImage = CIImage(cgImage: cgImage)

        // Convert to grayscale.
        guard let monoFilter = CIFilter(name: "CIColorControls") else { return 0 }
        monoFilter.setValue(ciImage, forKey: kCIInputImageKey)
        monoFilter.setValue(0.0, forKey: kCIInputSaturationKey)

        guard let grayImage = monoFilter.outputImage else { return 0 }

        // Apply 3x3 Laplacian kernel: [0, 1, 0, 1, -4, 1, 0, 1, 0]
        let laplacianKernel: [CGFloat] = [
            0,  1, 0,
            1, -4, 1,
            0,  1, 0
        ]
        let kernelVector = CIVector(values: laplacianKernel, count: 9)

        guard let convFilter = CIFilter(name: "CIConvolution3X3") else { return 0 }
        convFilter.setValue(grayImage, forKey: kCIInputImageKey)
        convFilter.setValue(kernelVector, forKey: "inputWeights")
        convFilter.setValue(0.0, forKey: "inputBias")

        guard let outputImage = convFilter.outputImage else { return 0 }

        // Render a downscaled version to keep memory and CPU usage reasonable.
        let maxDim: CGFloat = 256
        let extent = outputImage.extent
        let scale = min(maxDim / extent.width, maxDim / extent.height, 1.0)
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        // Trim the outer ring. A 3x3 convolution has no real neighbours at the
        // image edge, so those pixels read as a hard edge and gave even a flat
        // grey image a non-zero variance — a constant offset on every score.
        let scaledExtent = scaledImage.extent.insetBy(dx: 2, dy: 2)
        guard !scaledExtent.isEmpty else { return 0 }

        let width = Int(scaledExtent.width)
        let height = Int(scaledExtent.height)
        guard width > 0, height > 0 else { return 0 }

        let pixelCount = width * height
        let bytesPerRow = width * 4  // one Float32 per pixel
        var pixelData = [Float](repeating: 0, count: pixelCount)

        ciContext.render(
            scaledImage,
            toBitmap: &pixelData,
            rowBytes: bytesPerRow,
            bounds: scaledExtent,
            // Single-channel float keeps the convolution's negative lobes, which
            // carry as much edge information as the positive ones.
            format: .Rf,
            colorSpace: nil
        )

        var sum: Float = 0
        var sumSq: Float = 0
        for value in pixelData {
            sum += value
            sumSq += value * value
        }

        let mean = sum / Float(pixelCount)
        let variance = max((sumSq / Float(pixelCount)) - (mean * mean), 0)

        return min(variance / Self.sharpVariance, 1)
    }

    /// Laplacian variance that counts as fully sharp.
    ///
    /// Core Image works in 0-1 intensities rather than 0-255, so this is small in
    /// absolute terms. Only the ordering it produces matters — the tests assert a
    /// sharp image outscores a blurred copy of itself rather than pinning a value.
    private static let sharpVariance: Float = 0.02
}

// MARK: - Counter (Actor)

/// Simple actor-based counter for thread-safe progress tracking.
private actor Counter {
    private var value = 0

    func increment() -> Int {
        value += 1
        return value
    }
}
