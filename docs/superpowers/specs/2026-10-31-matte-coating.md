# Matte coating, 0.5.0

User asked for a separate button with an Apple matte anti-glare coating style effect. Implement a visual imitation of nano-texture, not physical reflection removal. Reference: Apple Studio Display nano-texture description, https://www.apple.com/studio-display/ (scattering ambient light is a property of the glass).

Use a small deterministic neutral premultiplied-alpha grain tile, repeated at native backing scale. A static translucent view at a window level just below the manual overlays slightly softens tonal contrast without blurring content. WindowServer composites it over live applications. There is no screen capture, polling timer, keyboard shortcut or input shield for this mode. Mouse and keyboard remain usable.

A dedicated button toggles coating on all displays; the visible strength slider covers 15–100%, default 60%. Save strength and enabled state. At login restore the saved choice. On topology changes rebuild surfaces; on termination remove surfaces without overwriting the user's preference.

Files: MatteTexture.swift defines deterministic texture and validation; MatteOverlayController.swift owns click-through surfaces; EffectsPanel.swift adds controls; AppDelegate.swift restores/stops the independent controller.

Verification: 32 tests passed, including low alpha, neutral colour, deterministic grain and bounded settings. Signed 0.5.0 installed on the target Mac. CUA verified the standalone button, slider increase/decrease and removal of the coating, with controls remaining responsive. Coating left off after the test.
