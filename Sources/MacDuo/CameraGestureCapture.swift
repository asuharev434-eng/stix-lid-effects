import AVFoundation
import QuartzCore
import Vision

struct CameraGestureSample: Sendable {
    let gesture: HandGesture?
    let action: HandGesture?
    let progress: Double
    let latched: Bool
    let handCount: Int
}

/// All capture/session/Vision state is confined to one queue; video is never persisted.
final class CameraGestureCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "STIX.cameraGestures", qos: .userInitiated)
    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let request = VNDetectHumanHandPoseRequest()
    private let onSample: @MainActor @Sendable (CameraGestureSample) -> Void
    private let onError: @MainActor @Sendable (String) -> Void
    private var latch = HandGestureLatch()
    private var lastAnalysis: TimeInterval = 0
    private var running = false
    private var errorObserver: NSObjectProtocol?
    private var failures = 0

    init(onSample: @escaping @MainActor @Sendable (CameraGestureSample) -> Void,
         onError: @escaping @MainActor @Sendable (String) -> Void) {
        self.onSample = onSample
        self.onError = onError
    }
    func start() {
        queue.async { [self] in
            do {
                session.beginConfiguration()
                defer { session.commitConfiguration() }
                if session.canSetSessionPreset(.vga640x480) { session.sessionPreset = .vga640x480 }
                else if session.canSetSessionPreset(.medium) { session.sessionPreset = .medium }
                else { throw CaptureError.configuration }
                guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified)
                        ?? AVCaptureDevice.default(for: .video) else { throw CaptureError.noCamera }
                let input = try AVCaptureDeviceInput(device: camera)
                guard session.canAddInput(input), session.canAddOutput(output) else { throw CaptureError.configuration }
                session.addInput(input)
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                output.setSampleBufferDelegate(self, queue: queue)
                session.addOutput(output)
                request.maximumHandCount = 2
                if camera.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 15 && $0.maxFrameRate >= 15 }) {
                    try camera.lockForConfiguration()
                    camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 15)
                    camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                    camera.unlockForConfiguration()
                }
            } catch {
                report(error.localizedDescription)
                return
            }
            errorObserver = NotificationCenter.default.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                                                    object: session, queue: nil) { [weak self] note in
                let message = (note.userInfo?[AVCaptureSessionErrorKey] as? Error)?.localizedDescription ?? "Камера стала недоступна."
                self?.queue.async { [weak self] in self?.report(message) }
            }
            running = true
            session.startRunning()
            if !session.isRunning { report("Не удалось запустить камеру. Возможно, она занята другим приложением.") }
        }
    }
    func stop() {
        queue.async { [self] in
            running = false
            output.setSampleBufferDelegate(nil, queue: nil)
            if session.isRunning { session.stopRunning() }
            if let errorObserver { NotificationCenter.default.removeObserver(errorObserver) }
            errorObserver = nil
            for input in session.inputs { session.removeInput(input) }
            for output in session.outputs { session.removeOutput(output) }
            latch = HandGestureLatch()
        }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard running, now - lastAnalysis >= 0.06, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastAnalysis = now
        do {
            try VNImageRequestHandler(cvPixelBuffer: pixels, orientation: .up).perform([request])
            failures = 0
            let hands = request.results ?? []
            let gesture: HandGesture?
            if hands.count == 1, let hand = hands.first {
                let points = try hand.recognizedPoints(.all)
                let mapping: [(HandJoint, VNHumanHandPoseObservation.JointName)] = [
                    (.wrist, .wrist), (.thumbTip, .thumbTip),
                    (.indexMCP, .indexMCP), (.indexPIP, .indexPIP), (.indexDIP, .indexDIP), (.indexTip, .indexTip),
                    (.middleMCP, .middleMCP), (.middlePIP, .middlePIP), (.middleDIP, .middleDIP), (.middleTip, .middleTip),
                    (.ringMCP, .ringMCP), (.ringPIP, .ringPIP), (.ringDIP, .ringDIP), (.ringTip, .ringTip),
                    (.littleMCP, .littleMCP), (.littlePIP, .littlePIP), (.littleDIP, .littleDIP), (.littleTip, .littleTip)
                ]
                var joints: [HandJoint: HandLandmark] = [:]
                for (joint, vision) in mapping {
                    if let p = points[vision] { joints[joint] = HandLandmark(x: p.location.x, y: p.location.y, confidence: p.confidence) }
                }
                gesture = HandGestureClassifier.classify(HandPose(joints: joints,
                    aspectRatio: Double(CVPixelBufferGetWidth(pixels)) / Double(CVPixelBufferGetHeight(pixels))))
            } else { gesture = nil }
            let action = latch.update(gesture, at: now)
            let update = CameraGestureSample(gesture: gesture, action: action, progress: latch.progress,
                                            latched: latch.isLatched, handCount: hands.count)
            Task { @MainActor [onSample] in onSample(update) }
        } catch {
            failures += 1
            if failures >= 8 { report("Не удалось распознать положение руки: \(error.localizedDescription)") }
        }
    }
    private func report(_ message: String) {
        running = false
        Task { @MainActor [onError] in onError(message) }
    }
    private enum CaptureError: LocalizedError {
        case noCamera, configuration
        var errorDescription: String? {
            switch self {
            case .noCamera: return "Камера не найдена."
            case .configuration: return "Не удалось настроить видеопоток камеры."
            }
        }
    }
}
