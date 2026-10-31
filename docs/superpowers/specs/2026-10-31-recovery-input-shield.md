# Reverse restoration and scoped input shield, 0.4.1

Approved user scope: all effects restore from black; hide the pointer and block trackpad/keyboard in manual blackout, retaining only Option+M. Apply the same input suppression to Option+B, retaining Option+B as its exit shortcut and leaving a frozen cursor image under the blur.

Playback uses one continuous coordinate, 0 clear and 1 black. Repeated toggles during animation reverse direction from the current coordinate. From black, fresh display snapshots exclude only overlay windows and are prepared at progress 1. The opaque cover stays up until every GPU initial frame has completed. The same chosen effect then runs from 1 to 0. Geometry and shaders are shared across directions. Late captures are invalidated by generation tokens. No screenshot is retained during the held-black phase.

BlackoutInputGuard installs a temporary HID event tap after Accessibility permission is present. It drops events except the current mode's Option+M or Option+B and the required Option/release events. It never stores or transmits keystrokes. Cursor hide/show counts are balanced. Errors, capture cancellation, termination and tap failure tear down the shield. The mode cannot start when permission or event-tap creation fails. Sleep/display changes retain manual black with its exit shortcut; blur closes and restores control.

For blur, capture the cursor image/position before hiding the hardware pointer. Stamp it into each applicable display source, then Gaussian-blur the composite. Display streams remain at 15 fps and exclude only their own overlay windows.

Validation: 30 tests passed, including reverse-state continuity, blocked input policy, blurred pointer compositing and transparent cursor alpha. Signed release 0.4.1 installed and launched. User approved Accessibility permission and the system setting is on. Target logs confirm held black, reverse animation and restoration to clear; live blur starts successfully.

## Cursor and capture corrections

Each manual overlay installs a transparent cursor rectangle. Cursor ownership is activated for the duration of the shield and the previous foreground application is restored on exit. Cursor hiding is reasserted at frame readiness and black-window handoff without increasing its hide count. The blur contains an immutable cursor image rendered before Gaussian blur, while the actual hardware pointer is transparent.

Blur capture excludes the owning application with explicit exceptions for its ordinary UI windows; this avoids feedback even when transparent overlay windows are absent from ScreenCaptureKit's window list. Display-parameter notifications only trigger cleanup when display IDs or frames actually change, avoiding resets caused by non-topology display updates. The other manual shortcut is also rejected by the application coordinator while a mode is active.
