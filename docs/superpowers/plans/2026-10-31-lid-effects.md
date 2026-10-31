# Lid Effects Implementation Plan

**Goal:** Install a native Mac utility with seven lid effects, login startup and all-display blur via Option+B.
**Architecture:** Extend the upstream sensor and Metal pipeline; separate manual blur and hotkey lifecycle. Keep a compact SwiftUI control window.
**Tech Stack:** Swift 6 compiler, AppKit, SwiftUI, Metal, ScreenCaptureKit, Carbon, ServiceManagement.

## Global Constraints
macOS 14+, Apple silicon; no screenshot persistence or uploads; preserve upstream attribution. Option+B toggles, Escape dismisses. Login startup enabled with visible errors.

### 1. Effect pipeline
- [ ] Add tests compiling Metal shaders and checking finite progress/endpoints.
- [ ] Add EffectStyle, preferences and a float4 shader uniform.
- [ ] Implement seven independent GPU formulas and connect existing overlay.
- [ ] Run swift test.

### 2. Manual blur and controls
- [ ] Register Option+B using Carbon and Escape only while active; report registration conflicts.
- [ ] Capture all screens with ScreenCaptureKit excluding this app; use Core Image Gaussian blur with clamped edges.
- [ ] Cancel captures on toggle-off, sleep and screen changes; suppress lid effects during blur.
- [ ] Add compact window, effect picker, preview, startup and error states using existing native SwiftUI patterns.

### 3. Delivery
- [ ] Build release, verify signature and launch custom bundle with distinct identity.
- [ ] Enable startup and verify SMAppService status; inspect UI and screenshot permission.
- [ ] Commit and push private GitHub fork; document tests and remaining physical-lid check.
