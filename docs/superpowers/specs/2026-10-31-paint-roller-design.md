# Paint roller effect

Add a selectable «Малярный валик» effect. A vertically mounted black roller with metal arm and navy handle paints three overlapping horizontal bands, travelling right, left, then right. Change rows outside the screen. Keep unpainted desktop pixels unchanged; paint remains opaque black behind the roller. Use restrained wet-edge texture, cylinder lighting and contact shadow.

Duration: 4.2 seconds. The existing Option+M/pinch state machine holds black indefinitely and reverses the exact scene on restoration, including mid-animation direction changes. Keep current input shielding and hidden pointer. Lid motion uses the same progress-based scene. Preserve existing stored effect IDs by appending the new case.

Use a standalone Metal source component interpolated into DepthShaders, with no assets, dependencies, capture changes or extra animation timers. Test the clear start, three accumulating bands, black endpoint, all existing effects and GPU compilation. Build, sign and install locally; publish source on the existing public GitHub repository.
