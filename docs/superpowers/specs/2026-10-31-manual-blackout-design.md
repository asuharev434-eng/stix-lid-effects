# Manual effect and blackout

User requested Option+M to play the selected effect and hold black until the same combination is pressed again, plus a cracking screen with falling shards.

Use the shared Metal renderer and one DepthOverlay per screen. Capture current windows once, animate for 1.6 seconds (2.2 for cracking glass), then replace animated overlays with plain black windows. The black phase holds no captured images, timer or rendering pipeline. Option+M cancels immediately from preparing, animating or black. The state machine rejects late asynchronous starts. Sleep or display topology changes retain blackout over current displays. Termination closes every overlay. Black windows consume clicks so hidden controls are not activated.

Option+B is ignored while manual blackout is active. Starting Option+M dismisses manual blur. Lid animation is suppressed during either manual mode. Carbon registers both shortcuts and tracks key release; the control panel disables manual blackout if its shortcut cannot register.

Cracking glass uses a shared jittered triangular mesh in the fragment shader. Cracks propagate from an impact point, then triangles rotate and fall under accelerating displacement. At zero progress the desktop remains clear. Manual mode adds a terminal fade so every selected effect reaches full black. Lid mode reuses the same effect without permanent blackout.

Verification: 22 Swift tests pass, including GPU pixel endpoints and playback state tests. Release 0.3.0 built and signed on the target Mac. Installed application logged shatter animation followed by holding-black state; CUA Option+M restored the normal UI. No new screen permission was needed because bundle identity and signing identity were preserved.
