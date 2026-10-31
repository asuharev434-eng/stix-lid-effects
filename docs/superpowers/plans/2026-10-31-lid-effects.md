# Lid Effects Implementation Plan

**Goal:** Install a native Mac utility with seven lid effects, login startup and all-display blur via Option+B.
**Architecture:** Extend the upstream sensor and Metal pipeline; separate manual blur and hotkey lifecycle. Keep a compact SwiftUI control window.
**Tech Stack:** Swift 6 compiler, AppKit, SwiftUI, Metal, ScreenCaptureKit, Carbon, ServiceManagement.

## Global Constraints
macOS 14+, Apple silicon; no screenshot persistence or uploads; preserve upstream attribution. Option+B toggles; Escape is unchanged. Login startup enabled with visible errors.

### 1. Effect pipeline
- [x] Add tests compiling Metal shaders and checking finite progress/endpoints.
- [x] Add EffectStyle, preferences and a float4 shader uniform.
- [x] Implement seven independent GPU formulas and connect existing overlay.
- [x] Run swift test.

### 2. Manual blur and controls
- [x] Register Option+B using Carbon only; report registration conflicts.
- [x] Capture all screens with ScreenCaptureKit excluding this app; use Core Image Gaussian blur with clamped edges.
- [x] Cancel captures on toggle-off, sleep and screen changes; suppress lid effects during blur.
- [x] Add compact window, effect picker, preview, startup and error states using existing native SwiftUI patterns.

### 3. Delivery
- [x] Build release, verify signature and launch custom bundle with distinct identity.
- [x] Enable startup and verify SMAppService status; inspect UI and screenshot permission. Both confirmed in installed application.
- [x] Commit and push private GitHub fork; document tests and remaining physical-lid check.

## Verification limits
GPU pixel tests and the sensor probe passed on the target Mac. UI shows startup enabled and Screen Recording granted after restart. Automated shortcut input was blocked by concurrent user interaction; manual Option+B validation remains to be confirmed.
