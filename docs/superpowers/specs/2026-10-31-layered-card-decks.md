# Original-size cards with rear decks, 0.7.2

User requested restoration of the old card size and additional ordinary cards positioned behind the screen, rather than subdividing the desktop further.

Return geometry to 13 columns and 4 rows. The first 52 cards cover the desktop exactly at z=0 and retain their screen-fragment backs. Add three decks of the same physical card size at positive depth, 156 cards total. Their front sides use the original face atlas; their reverse sides use an independent procedural navy/gold pattern. They never sample the desktop image. They begin face-up behind the screen and are revealed as primary tiles depart. Start times are staggered by depth; deeper cards accelerate toward the viewer to sustain the fast flow.

Keep 208 total cards, the fast 4.6 flight multiplier and the 3.4-second manual duration. Depth testing hides all rear cards at progress zero, preserving the initial desktop. Reverse playback returns the additional decks behind the reassembled screen.

Verification: 39 tests pass. Geometry tests check 52 screen cards, 156 rear cards, the restored 13-by-4 dimensions and exact primary coverage. GPU tests render the rear decks against two different desktop textures and require identical output, confirming desktop independence. Initial/black endpoints and late-flight visibility pass. Synthetic GPU frames inspected for visible rear layers, card faces and independent backs. Signed release 0.7.2 built for installation.
