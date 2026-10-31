# Lid effects

Approved in chat: seven selectable lid effects, Option+B toggles blur on all displays; Escape is unchanged, compact control window and enabled login startup.

Extend the existing native Swift/AppKit/Metal application. Keep original depth effect as an eighth choice. Use Carbon registered hotkeys without Accessibility permission. Manual blur captures each display into memory, Gaussian-blurs a held image and covers every display; it is a visual convenience, not a screen lock. Stop lid capture during manual blur. Cancel pending captures on dismissal, sleep and display changes. No screenshots are saved or transmitted.

Mini window uses the existing native SwiftUI controls and spacing, with Russian effect names, clear selection, preview, permission/error status and startup toggle. System settings are the reference for native switches; existing SettingsView is the layout reference. Retain keyboard focus and accessible labels.

Add shader variants for CRT collapse, frosted glass, waves, paper curl, particles, edge light and cinematic fade. All return the unmodified desktop at progress zero. Effects stop on sleep. Store selection in UserDefaults. Use SMAppService for login startup with visible failure state. A new bundle identity isolates the custom build from the vendor app and its permissions. Preserve Apache license and upstream attribution. Push changes to a private GitHub fork if supported.

Validate with Swift tests including GPU shader compilation, release build, signature verification, startup registration and UI checks. Physical lid motion requires user verification.
