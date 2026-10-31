import CoreImage

/// Neutral Gaussian blur: preserve window colours and silhouettes, with no tint.
/// Each instance is owned by one capture queue.
final class WindowBlurRenderer {
    private let context = CIContext(options: [.cacheIntermediates: false])
    func render(_ source: CIImage, cursor: BlurCursorStamp? = nil) -> CGImage? {
        guard !source.extent.isEmpty, !source.extent.isInfinite else { return nil }
        let stamped = cursor?.composite(over: source) ?? source
        let blurred = stamped.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 14.0])
            .cropped(to: source.extent)
        return context.createCGImage(blurred, from: source.extent)
    }
}
