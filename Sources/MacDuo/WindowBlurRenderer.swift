import CoreImage

/// Neutral Gaussian blur: preserve window colours and silhouettes, with no tint.
/// Each instance is owned by one capture queue.
final class WindowBlurRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    func render(_ source: CIImage) -> CGImage? {
        guard !source.extent.isEmpty, !source.extent.isInfinite else { return nil }
        let blurred = source.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14.0])
            .cropped(to: source.extent)
        return context.createCGImage(blurred, from: source.extent)
    }
}
