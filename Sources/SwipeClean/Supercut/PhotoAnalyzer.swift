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

        // Composite: sharpness 30%, saliency 40%, face presence 30%.
        var composite: Float = analysis.sharpness * 0.3
            + analysis.saliency * 0.4
            + (analysis.hasFaces ? 0.3 : 0.0)

        if item.isFavorited {
            composite = min(composite * 1.5, 1.0)
        }

        return PhotoScore(
            item: item,
            qualityScore: composite,
            hasFaces: analysis.hasFaces,
            sharpness: analysis.sharpness,
            saliencyScore: analysis.saliency
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

    /// Analyzes a single photo using the Vision framework.
    ///
    /// Runs:
    /// 1. Face detection — determines whether faces are present
    /// 2. Attention-based saliency — how "interesting" the image is
    /// 3. Laplacian-variance sharpness — higher variance = sharper
    private func analyzeImage(_ image: UIImage) -> (sharpness: Float, hasFaces: Bool, saliency: Float) {
        guard let cgImage = image.cgImage else {
            return (sharpness: 0, hasFaces: false, saliency: 0)
        }

        let hasFaces = detectFaces(in: cgImage)
        let saliency = computeSaliency(in: cgImage)
        let sharpness = computeSharpness(of: cgImage)

        return (sharpness: sharpness, hasFaces: hasFaces, saliency: saliency)
    }

    // MARK: Face Detection

    private func detectFaces(in cgImage: CGImage) -> Bool {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            if let results = request.results {
                return !results.isEmpty
            }
        } catch {
            // Face detection failed — treat as no faces.
        }

        return false
    }

    // MARK: Saliency

    private func computeSaliency(in cgImage: CGImage) -> Float {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            if let observation = request.results?.first as? VNSaliencyImageObservation,
               let salientObjects = observation.salientObjects, !salientObjects.isEmpty {
                // Use the maximum confidence among salient regions as the score.
                let maxConfidence = salientObjects.map(\.confidence).max() ?? 0
                return maxConfidence
            }
        } catch {
            // Saliency detection failed.
        }

        return 0
    }

    // MARK: Sharpness (Laplacian Variance)

    /// Computes image sharpness using Laplacian variance.
    ///
    /// Approach:
    /// 1. Convert to grayscale via CIFilter.
    /// 2. Apply CIConvolution3X3 with a Laplacian kernel.
    /// 3. Read back pixel data and compute variance of intensities.
    /// 4. Normalize to 0-1 (clamped; empirical max around 2500).
    private func computeSharpness(of cgImage: CGImage) -> Float {
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])
        var ciImage = CIImage(cgImage: cgImage)

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
        let scaledExtent = scaledImage.extent

        let width = Int(scaledExtent.width)
        let height = Int(scaledExtent.height)
        guard width > 0, height > 0 else { return 0 }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)

        ciContext.render(
            scaledImage,
            toBitmap: &pixelData,
            rowBytes: bytesPerRow,
            bounds: scaledExtent,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceGray()
        )

        // Compute variance of the red channel (grayscale, so R=G=B).
        let pixelCount = width * height
        guard pixelCount > 0 else { return 0 }

        var sum: Float = 0
        var sumSq: Float = 0

        for i in 0..<pixelCount {
            // After convolution values can be negative, stored as unsigned.
            // We only need the magnitude spread (variance).
            let value = Float(pixelData[i * bytesPerPixel])
            sum += value
            sumSq += value * value
        }

        let mean = sum / Float(pixelCount)
        let variance = (sumSq / Float(pixelCount)) - (mean * mean)

        // Normalize: empirically, variance above ~2500 indicates very sharp images.
        let normalized = min(max(variance / 2500.0, 0), 1)
        return normalized
    }
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
