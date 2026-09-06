# Grapple sphere collision proof

`grapple-sphere-collision-proof.gif` is a 3.75-second desktop-rendered capture of the live Grapple Intercept minigame after the collision fix. It shows the five incoming rocks remain separately spaced as they converge on the player, rather than starting interpenetrating and producing repeated bounce responses.

The automated companion check is `verify/grapple_intercept.gd`; it asserts a one-time elastic impulse for each contact and verifies that the live five-rock burst starts and remains non-overlapping during its first approach.
