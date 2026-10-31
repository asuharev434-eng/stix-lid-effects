# Dense faster card flow, 0.7.1

User requested faster flight while retaining the total duration through a larger number of cards. Increase from 52 to 208 tiles, a 26-by-8 grid representing four repetitions of the same 52-card artwork. Keep manual duration 3.4 seconds. Double the flight time multiplier from 2.3 to 4.6 and distribute launch delays across the timeline using a coprime permutation, so late cards sustain the flow.

Card geometry carries grid dimensions in the shared vertex data, preserving poker proportions and exact desktop coverage. Face lookup wraps IDs modulo 52. The existing atlas is reused, so image memory is unchanged. Back sides remain their corresponding desktop fragments. Reverse animation and gesture handling are unchanged.

Verification: 39 tests passed, including 208 unique card IDs, exact desktop coverage, all 52 face IDs, launch-time spread, GPU initial/black endpoints, mid-flight separation and visible cards at 88% of the unchanged duration. Synthetic GPU frames were visually inspected before the final timing adjustment.
