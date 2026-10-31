# More realistic glass, 0.3.1

User requested more realistic cracks and falling shards. Replace the regular 10-by-7 triangle field with impact-biased Voronoi glass plates and an independent Metal mesh pipeline. Existing Option+M, Option+B, lid sensor and black-screen hold remain as implemented.

Files: GlassFracture.swift generates deterministic clipped cells and vertex data; DepthRenderer.swift caches the mesh and depth attachment; DepthShaders.swift rotates and shades plates; ManualEffectController.swift gives glass a three-second sequence. Tests validate area coverage, varying sizes and release, repeatable geometry, vertex bounds and GPU endpoints. Optional synthetic test frames can be rendered via STIX_GLASS_TEST_FRAMES; these contain no desktop data.

Verified before installation: 24 tests passed including a 512-pixel GPU frame sequence. Visually inspected the crack and falling stages. The impact has dense small chips, edges have larger irregular plates, and fragments rotate independently in depth.

Installed verification: signed release 0.3.1 launched with existing permissions. Target Mac logs show style 8 running for three seconds and entering the held-black state; Option+M restored the normal controls.
