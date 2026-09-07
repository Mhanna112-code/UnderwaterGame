# First-run tutorial player-path bug catalog

The stacked prototype is not considered complete because a state flag flips.
These cases map to the player-facing proof required for the opening route.

| ID | Fault / player-visible symptom | Meaningful regression check | Status |
|---|---|---|---|
| OB-01 | New Game leaves the world paused behind a tutorial modal. | Select New Game and assert a live HUD/unpaused tree. | `verify/onboarding.gd` |
| OB-02 | The opening begins without a visible physical cue, so the player has only prose to follow. | Assert the Shockwave cue object exists at the real rubble. | `verify/onboarding.gd` |
| OB-03 | The wrong diver/ability can satisfy the first obstacle. | Send actual Tab/E input and require Mech Pilot's real Shockwave to break the actual wall. | `verify/onboarding.gd` |
| OB-04 | An ordinary or guardian fight interrupts ability learning. | Invoke both trigger paths while onboarding and assert neither creates/pauses for combat. | `verify/onboarding.gd` |
| OB-05 | Hitting the near grapple ring, or merely hitting the far one before travel ends, advances the route. | Drive aimed E/click at near then far anchors; require the completed far pull before Swap. | `verify/onboarding.gd` |
| OB-06 | A casual Swap experiment at spawn skips to the final puzzle. | Drive Maxilani's actual E/Enter selector at nearby divers; retain Swap state. | `verify/onboarding.gd` |
| OB-07 | A correct across-whirlpool Swap fails to transition or has no non-text formation aid. | Drive E/Enter with Maxilani swapping into the far side; require door step, visual cue, and three halos. | `verify/onboarding.gd` |
| OB-08 | The door opens only because a test writes plate occupants, hiding a collision/input defect. | Place real CharacterBody3Ds on real Area3D plates and wait for physics to open all doors. | `verify/onboarding.gd` |
| OB-09 | The maze is present before the lock puzzle, or “maze open” is text only after it. | Require no maze before the first lesson and an embedded `MazeLevel` only when the door opens. | `verify/onboarding.gd` |
| OB-10 | First combat depends on a random encounter roll, appears before the lesson ends, or is not recoverably recorded when armed. | Require no early fight, then a visible Angler/trigger and persisted `first_combat_pending` after the door; suppress random handlers; swim the active diver into the trigger. | `verify/onboarding.gd` |
| OB-11 | Exiting mid-route loses the current objective and strands a player at the gate. | Serialize current onboarding step and rebuild its cue/step on restore. | `verify/onboarding.gd` |

## Visual language being checked by review

- **Cyan pulse** on rubble matches Mech Pilot's active marker: Shockwave.
- **Gold hoop** at the far anchor matches Musashi's marker: Grapple.
- **Purple linked rings** and target cursor match Maxilani: Swap.
- At the finale, permanent diver halos and plate colours use those same three
  colours; occupancy turns a plate green.
- A **red reticle** plus a visible Angler identifies the first deliberate
  combat beat after the door, rather than looking like an artifact marker.

The regression can establish that these assets exist and participate in the
real action path. Screenshot and interactive review still decide whether the
visual hierarchy is understandable at game scale.
