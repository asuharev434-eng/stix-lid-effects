# Camera hand gestures, 0.6.0

User requested pinch as an alternative to Option+M and open palm as an alternative to Option+B. Use the same AppDelegate routing and mode guards as the existing hotkeys, not synthesized keypresses. Gestures can therefore release blackout/blur despite the hardware event shield. Existing shortcuts stay available.

AVFoundation captures video only, preferring the built-in camera. Use a small capture preset and at most 15 Vision analyses per second on a dedicated serial queue, discarding late frames. VNDetectHumanHandPoseRequest detects up to two hands; accept exactly one. Scale-normalized thumb/index proximity identifies pinch, with fingertip extension checks rejecting a fist. Open palm requires straight long fingers and a separated thumb. Reject low confidence, invalid coordinates and distant small hands.

A latch requires 0.65 seconds and six observations. It fires once and cannot accept another gesture until at least 0.45 seconds of neutral/no-hand input. A direct pinch-to-palm change does not trigger another action. Late asynchronous results are generation-checked. Sleep pauses capture; waking restores it only if previously enabled. Camera failures stop capture and show status. Video is never saved or transmitted and no microphone input is configured.

UI: explicit camera toggle, gesture mapping, current recognition status and hold progress. Default off. Saved enablement is restored only when already authorized. Info.plist declares the Russian camera purpose; hardened signing embeds only the camera device entitlement.

Files: HandGesture.swift, CameraGestureCapture.swift, CameraGestureController.swift, EffectsPanel.swift, AppDelegate.swift, camera manifest/entitlements and build.sh.

Before camera permission: 37 tests pass, including mirror/rotation recognition, fist/low-confidence/small-hand rejection, one-shot latching/rearming and video-only permissions. Signed release 0.6.0 installed, camera entitlement verified, new camera toggle visible and off. Live camera and real hand checks remain after user approval.
