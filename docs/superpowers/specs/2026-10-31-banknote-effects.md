# Banknote flight effects

Add «Рубли · 5 000 ₽» and «Доллары · $100» alongside the existing cards, preserving stored IDs. Reuse the depth-tested flying-paper pipeline and 3.4-second reversible Option+M/pinch animation, held-black state and input shielding.

Use a wide 1024:448 note shape, slight curl, an 8×6 screen layer (48 desktop-fragment backs) and three additional independent layers (144 printed notes). Two separate locally generated illustrations per currency: ruble brown/orange monument and bridge; dollar green portrait and building with a blue ribbon. Original illustrative artwork, no scans or downloads. Cache each pair of GPU textures by effect, so changing selection cannot reuse another currency or card artwork.

Verification: existing cards unchanged; primary layer covers desktop exactly; all four note illustrations opaque and distinct; GPU clear start, independent rear-note texture sampling, distinct middle frames and opaque black completion; existing reversal/input tests. Build, sign, install and push public repository.

## Verification

42 local tests in 14 suites passed, including GPU rendering at 512×512, distinct/opaque front and back artwork, banknote layer coverage and desktop-independent rear layers. Inspected synthetic banknote flight frames. Developer ID release 0.9.0 built, signature verified, installed and launched; both new effects are present in the mini-window and previews were exercised. Camera gestures are restored after UI verification.
