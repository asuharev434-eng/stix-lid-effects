import Foundation
import simd

enum HandGesture: String, Sendable {
    case pinch, openPalm
    var title: String { self == .pinch ? "Щипок" : "Раскрытая ладонь" }
}
enum HandJoint: Sendable {
    case wrist, thumbTip
    case indexMCP, indexPIP, indexDIP, indexTip
    case middleMCP, middlePIP, middleDIP, middleTip
    case ringMCP, ringPIP, ringDIP, ringTip
    case littleMCP, littlePIP, littleDIP, littleTip
}
struct HandLandmark: Sendable {
    let x: Double
    let y: Double
    let confidence: Float
}
struct HandPose: Sendable {
    var joints: [HandJoint: HandLandmark]
    let aspectRatio: Double
}

enum HandGestureClassifier {
    static func classify(_ pose: HandPose) -> HandGesture? {
        guard pose.aspectRatio.isFinite, pose.aspectRatio > 0 else { return nil }
        func point(_ joint: HandJoint) -> SIMD2<Double>? {
            guard let p = pose.joints[joint], p.confidence >= 0.55,
                  p.x.isFinite, p.y.isFinite, (0...1).contains(p.x), (0...1).contains(p.y) else { return nil }
            return SIMD2(p.x * pose.aspectRatio, p.y)
        }
        guard let wrist = point(.wrist), let middle = point(.middleMCP),
              let index = point(.indexMCP), let little = point(.littleMCP),
              let thumbTip = point(.thumbTip), let indexTip = point(.indexTip) else { return nil }
        let width = simd_distance(index, little)
        guard simd_distance(wrist, middle) >= 0.06, width >= 0.045 else { return nil }
        if simd_distance(thumbTip, indexTip) / width < 0.23,
           simd_distance(wrist, indexTip) > simd_distance(wrist, index) * 1.2 {
            return .pinch
        }
        func straight(_ a: SIMD2<Double>, _ b: SIMD2<Double>, _ c: SIMD2<Double>) -> Bool {
            let first = a - b, second = c - b
            let lengths = simd_length(first) * simd_length(second)
            return lengths > 0.00001 && simd_dot(first, second) / lengths < -0.86
        }
        let fingers: [(HandJoint, HandJoint, HandJoint, HandJoint)] = [
            (.indexMCP, .indexPIP, .indexDIP, .indexTip),
            (.middleMCP, .middlePIP, .middleDIP, .middleTip),
            (.ringMCP, .ringPIP, .ringDIP, .ringTip),
            (.littleMCP, .littlePIP, .littleDIP, .littleTip)
        ]
        for finger in fingers {
            guard let mcp = point(finger.0), let pip = point(finger.1),
                  let dip = point(finger.2), let tip = point(finger.3),
                  straight(mcp, pip, dip), straight(pip, dip, tip),
                  simd_distance(wrist, tip) > simd_distance(wrist, pip) * 1.1 else { return nil }
        }
        guard simd_distance(thumbTip, index) > width * 0.5 else { return nil }
        return .openPalm
    }
}

/// One action per held gesture. A neutral interval is mandatory before any next action.
struct HandGestureLatch {
    private var candidate: HandGesture?
    private var candidateSince: TimeInterval = 0
    private var neutralSince: TimeInterval?
    private var lastObservation: TimeInterval?
    private var samples = 0
    private(set) var isLatched = false
    private(set) var progress: Double = 0

    mutating func update(_ gesture: HandGesture?, at now: TimeInterval) -> HandGesture? {
        guard now.isFinite else { return nil }
        defer { lastObservation = now }
        if isLatched {
            if gesture == nil {
                if neutralSince == nil { neutralSince = now }
                if now - (neutralSince ?? now) >= 0.45 {
                    isLatched = false; candidate = nil; samples = 0; progress = 0
                }
            } else { neutralSince = nil }
            return nil
        }
        guard let gesture else {
            candidate = nil; samples = 0; progress = 0
            return nil
        }
        if candidate != gesture || now - (lastObservation ?? now) > 0.35 {
            candidate = gesture; candidateSince = now; samples = 0
        }
        samples += 1
        progress = min(max((now - candidateSince) / 0.65, 0), min(Double(samples) / 6, 1))
        guard progress >= 1, samples >= 6 else { return nil }
        isLatched = true
        neutralSince = nil
        return gesture
    }
}
