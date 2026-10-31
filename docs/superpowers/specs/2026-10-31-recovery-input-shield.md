# Reverse restoration and scoped input shield, 0.4.0

Approved user scope: all effects restore from black; hide the pointer and block trackpad/keyboard in manual blackout, retaining only Option+M. Apply the same input suppression to Option+B, retaining Option+B as its exit shortcut and leaving a frozen cursor image under the blur.

Playback uses one continuous coordinate, 0 clear and 1 black. Repeated toggles during animation reverse direction from the current coordinate. From black, fresh display snapshots exclude only overlay windows and are prepared at progress 1. The opaque cover stays up until every GPU initial frame has completed. The same chosen effect then runs from 1 to 0. Geometry and shaders are shared across directions. Late captures are invalidated by generation tokens. No screenshot is retained during the held-black phase.

BlackoutInputGuard installs a temporary session event tap after Accessibility permission is present. It drops events except the current mode's Option+M or Option+B and the required Option/release events. It never stores or transmits keystrokes. Cursor hide/show counts are balanced. Errors, capture cancellation, termination and tap failure tear down the shield. The mode cannot start when permission or event-tap creation fails. Sleep/display changes retain manual black with its exit shortcut; blur closes and restores control.

For blur, capture the cursor image/position before hiding the hardware pointer. Stamp it into each applicable display source, then Gaussian-blur the composite. Display streams remain at 15 fps and exclude only their own overlay windows.

Validation before permission activation: 29 tests passed, signed release 0.4.0 installed and launched. UI exposes the Accessibility permission action. System-level live checks require granting the installed app that permission.
