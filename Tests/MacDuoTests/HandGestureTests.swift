import Foundation
import Testing
@testable import MacDuo

struct HandGestureTests {
    private func openHand() -> HandPose {
        var joints: [HandJoint: HandLandmark] = [:]
        func put(_ joint: HandJoint, _ x: Double, _ y: Double) { joints[joint] = HandLandmark(x: x, y: y, confidence: 0.95) }
        put(.wrist, 0.5, 0.15)
        put(.thumbTip, 0.10, 0.52)
        let fingers: [(HandJoint, HandJoint, HandJoint, HandJoint, Double, Double, Double)] = [
            (HandJoint.indexMCP, .indexPIP, .indexDIP, .indexTip, 0.4, 0.40, 0.90),
            (.middleMCP, .middlePIP, .middleDIP, .middleTip, 0.5, 0.42, 0.96),
            (.ringMCP, .ringPIP, .ringDIP, .ringTip, 0.6, 0.40, 0.90),
            (.littleMCP, .littlePIP, .littleDIP, .littleTip, 0.7, 0.37, 0.80)
        ]
        for (mcp, pip, dip, tip, x, base, end) in fingers {
            put(mcp, x, base); put(pip, x, base + (end - base) * 0.45)
            put(dip, x, base + (end - base) * 0.75); put(tip, x, end)
        }
        return HandPose(joints: joints, aspectRatio: 1)
    }
    @Test func recognisesOpenPalmAndPinchRegardlessOfMirroring() {
        let hand = openHand()
        #expect(HandGestureClassifier.classify(hand) == .openPalm)
        let rotated = HandPose(joints: hand.joints.mapValues {
            HandLandmark(x: 1 - $0.x, y: 1 - $0.y, confidence: $0.confidence)
        }, aspectRatio: 1)
        #expect(HandGestureClassifier.classify(rotated) == .openPalm)
        var pinch = hand
        pinch.joints[.thumbTip] = HandLandmark(x: 0.405, y: 0.895, confidence: 0.95)
        #expect(HandGestureClassifier.classify(pinch) == .pinch)
        pinch.joints = pinch.joints.mapValues { HandLandmark(x: 1 - $0.x, y: $0.y, confidence: $0.confidence) }
        #expect(HandGestureClassifier.classify(pinch) == .pinch)
    }
    @Test func rejectsFistDistantHandsAndLowConfidence() {
        var hand = openHand()
        hand.joints[.indexTip] = HandLandmark(x: 0.4, y: 0.43, confidence: 0.95)
        hand.joints[.thumbTip] = HandLandmark(x: 0.405, y: 0.435, confidence: 0.95)
        #expect(HandGestureClassifier.classify(hand) == nil)
        hand = openHand()
        hand.joints[.wrist] = HandLandmark(x: 0.5, y: 0.15, confidence: 0.1)
        #expect(HandGestureClassifier.classify(hand) == nil)
        hand = openHand()
        hand.joints = hand.joints.mapValues { HandLandmark(x: $0.x * 0.1, y: $0.y * 0.1, confidence: $0.confidence) }
        #expect(HandGestureClassifier.classify(hand) == nil)
    }
    @Test func heldGestureFiresOnceAndNeedsNeutralBeforeAnotherGesture() {
        var latch = HandGestureLatch()
        var actions: [HandGesture] = []
        for i in 0...30 {
            if let action = latch.update(.pinch, at: Double(i) / 10) { actions.append(action) }
        }
        #expect(actions == [.pinch])
        let update1 = latch.update(.openPalm, at: 3.1)
        #expect(update1 == nil)
        let update2 = latch.update(.openPalm, at: 4.2)
        #expect(update2 == nil)
        _ = latch.update(nil, at: 4.3)
        _ = latch.update(nil, at: 4.9)
        for i in 0...10 {
            if let action = latch.update(.openPalm, at: 5 + Double(i) / 10) { actions.append(action) }
        }
        #expect(actions == [.pinch, .openPalm])
    }
    @Test func cameraManifestRequestsVideoWithoutMicrophone() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        func plist(_ path: String) throws -> [String: Any] {
            try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: root.appendingPathComponent(path)), format: nil) as? [String: Any])
        }
        let info = try plist("Resources/Info.plist")
        let entitlements = try plist("Resources/Entitlements.plist")
        #expect(!(info["NSCameraUsageDescription"] as? String ?? "").isEmpty)
        #expect(info["NSMicrophoneUsageDescription"] == nil)
        #expect(entitlements["com.apple.security.device.camera"] as? Bool == true)
        #expect(entitlements["com.apple.security.device.audio-input"] == nil)
    }
    @Test func aSingleFrameOrBriefGestureNeverTriggers() {
        var latch = HandGestureLatch()
        let update3 = latch.update(.openPalm, at: 0)
        #expect(update3 == nil)
        let update4 = latch.update(nil, at: 0.2)
        #expect(update4 == nil)
        let update5 = latch.update(.openPalm, at: 2)
        #expect(update5 == nil)
        let update6 = latch.update(.openPalm, at: 3)
        #expect(update6 == nil) // Too few observations.
    }
}
