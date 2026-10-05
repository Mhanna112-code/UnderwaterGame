# Maze destination versus retained health HUD — October 5

The actual earned-map browser run on source6606c5b, pack5098f894, failed:
the Oxygen bar painted over the destination's final Cordys line. The rejected
1280x720 screenshot is retained. This was a real rendering bug, not a desired
removal of the maze goal or of Marc's shared health HUD.

The bounded repair reserves the actual HP/Oxygen band and, on short landscape
screens, uses the free column beside the visible party rows. Narrow screens
retain the full-width destination below those rows. It does not restore the
retired generic hint, change milestones, or grant campaign state.

Native generated milestone/legacy-ID cases and actual R/Escape/L/Tab/F owners
pass at360x640 and720x480. Actual Metal360x640 rendering passed and the retained
map/after-owner images were inspected. Desktop1280x720 and a matching exported
earned-map browser run are still required before publication.

Two observer issues are recorded rather than called production bugs: the
party VBox retains blank space for its hidden active-member row (bounds log),
and a headless default viewport is not a1280x720 desktop. The test now declares
that viewport and checks painted, visible rows; active HP/Oxygen bounds and
whole-viewport containment remain strict. Supplied native checkpoints isolate
layout, not earned route balance. Browser map acquisition is separate evidence.
