# Paint Roller Implementation Plan

**Goal:** Three-pass black paint effect with a visible roller and reversible playback.

**Architecture:** Extend EffectStyle and reuse the full-screen Metal pipeline. Isolate the roller drawing and cumulative coverage in PaintRollerShader. Keep capture, input guards and playback state unchanged.

**Tech Stack:** Swift, AppKit, Metal, Swift Testing; macOS 14+.

## Tasks

- [x] Add GPU regression checks for sequential painted bands, unchanged unpainted regions and fully black completion; observe missing effect compilation failure.
- [x] Append paintRoller, add shared manualDuration property and route the controller through it.
- [x] Implement cumulative three-pass coverage, roller geometry, shading and endpoint transitions in Sources/MacDuo/PaintRollerShader.swift; integrate DepthShaders.
- [x] Export synthetic GPU frames and inspect each pass; run full swift test.
- [x] Update README and version, build/sign/install, verify process and signature, commit and push public repository.

## Verification

40 tests passed locally, including GPU pixel tests at 512×512. Inspected synthetic first/second pass frames. Signed Developer ID release 0.8.0 installed and launched; the new effect is selected in the control panel, preview completes, camera gestures were restored to enabled. Existing effect IDs and mode-specific input policy are unchanged.
