import AppKit
import CoreImage
import ScreenCaptureKit

/// Captures a display excluding only our overlay windows, not the app's UI.
@MainActor
final class WindowBlurStream {
    private let stream: SCStream
    private let receiver: Receiver

    init(display: SCDisplay, excluding windows: [SCWindow], size: CGSize,
         onFrame: @escaping @MainActor (CGImage) -> Void,
         onError: @escaping @MainActor (String) -> Void) throws {
        let filter = SCContentFilter(display: display, excludingWindows: windows)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(size.width))
        configuration.height = max(1, Int(size.height))
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.sRGB
        configuration.showsCursor = false
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 15)
        configuration.queueDepth = 3
        receiver = Receiver(onFrame: onFrame, onError: onError)
        stream = SCStream(filter: filter, configuration: configuration, delegate: receiver)
        try stream.addStreamOutput(receiver, type: .screen,
                                   sampleHandlerQueue: DispatchQueue(label: "STIX.windowBlur.frames", qos: .userInitiated))
    }
    func start() async throws { try await stream.startCapture() }
    func stop() {
        receiver.cancel()
        let closing = stream
        Task { try? await closing.stopCapture() }
    }

    // Frame rendering is confined to the serial capture queue; shared delivery state is locked.
    private final class Receiver: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
        private let renderer = WindowBlurRenderer()
        private let onFrame: @MainActor (CGImage) -> Void
        private let onError: @MainActor (String) -> Void
        private let lock = NSLock()
        private var pending: CGImage?
        private var scheduled = false
        private var cancelled = false

        init(onFrame: @escaping @MainActor (CGImage) -> Void,
             onError: @escaping @MainActor (String) -> Void) {
            self.onFrame = onFrame
            self.onError = onError
        }
        func cancel() {
            lock.lock()
            cancelled = true
            pending = nil
            lock.unlock()
        }
        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard type == .screen, CMSampleBufferIsValid(sampleBuffer),
                  let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let status = attachments.first?[.status] as? Int, status == SCFrameStatus.complete.rawValue,
                  let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            lock.lock()
            let stopped = cancelled
            lock.unlock()
            guard !stopped else { return }
            autoreleasepool {
                guard let image = renderer.render(CIImage(cvPixelBuffer: buffer)) else { return }
                lock.lock()
                guard !cancelled else { lock.unlock(); return }
                pending = image
                let needsDelivery = !scheduled
                scheduled = true
                lock.unlock()
                guard needsDelivery else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    lock.lock()
                    let latest = cancelled ? nil : pending
                    pending = nil
                    scheduled = false
                    lock.unlock()
                    if let latest { MainActor.assumeIsolated { self.onFrame(latest) } }
                }
            }
        }
        func stream(_ stream: SCStream, didStopWithError error: Error) {
            let message = error.localizedDescription
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                lock.lock()
                let stopped = cancelled
                lock.unlock()
                if !stopped { MainActor.assumeIsolated { self.onError(message) } }
            }
        }
    }
}
