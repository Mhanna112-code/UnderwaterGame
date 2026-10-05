# October 5 separate late intake — PR97 bba8b80

Observed during verification of the bounded Sonar Vision batch, after the
frozen #97 4ec6598 intake. PR97 is now
`bba8b80337c07298763a28c9c1109382091bc480`; PR99 remains
`86878faedb71e81072b1d200f4ccbfc6f0507210`. One new commit:
**Maze tweaks, Box 12 draft, autosave slots**. Complete four-file diff inspected:
316 insertions/146 deletions in maze_level, save_manager, title_screen and World.

This is a separate intake, not code silently added to a source batch under
verification. The Box12/retired Control Room route portion is now admitted by
`docs/evidence/maze-box12-route-oct5`; the remaining rows below stay pending.
Existing frozen-intake requirements and verified campaign/save repairs remain.

| Authored behavior | Disposition / next admission requirements |
|---|---|
| One-way Box12 draft from 12/13 hall to water outside Control Room | Admitted using shared safe-tunnel owner. Actual No/reapproach/Yes, three capsules/240 motion samples, high/wrong-side/paused negatives, three blocked exits and three owner removals pass. Native wide/true narrow visuals inspected; overhead framing fixes below-floor chase-camera collapse. Browser/human full-route acceptance remains open. |
| Remove PathButton and rotating/raised 12/13 path; add Box8-to-dome fence | Admitted semantic replacement. Captured old actual-E JSON, 36 generated old/current-frame × actor × map × placement cases, raw old cold Title Load and swimming pass. Overlapping migrated capsules avoid both solids and active pull zones. Actual Box12-to-chest E/L plus normal pre-map shared-entry/chest/return pass. Full campaign/browser acceptance remains open. |
| Swung 10/11 do not carry divers out of C5; collision disabled during movement, restored afterward | Pending rider/physics reconciliation. All three actors inside C5 stay safely within it; actors outside ride where intended. Verify actual capsule behavior, moving skirts/state barriers, intermediate motion, teardown and cold restore. Do not copy an unguarded finished callback that leaves collision off after interruption. |
| Poster-wall western barrier extends to maze edge | Pending continuous-boundary traversal checks; must not block independent lab/ramp or intended new Box12 path after embedding/rebasing. |
| Hall whirlpools spread across safe lanes with smaller/gentler pull | Pending deterministic lane/column clearance, actual approach/avoidance/suction, damage and recovery checks. Retain independent positions in save handling if randomness is persisted. |
| Separate autosave every 180 active seconds, safe moments only, one per selected slot | Pending dedicated IO/UI batch. Preserve atomic writer errors, browser durable-confirmation/rollback, stable campaign snapshot locks, independent manual checkpoint and selected slot. Do not announce success after a rejected write or silently truncate the last usable autosave. |
| Load-menu autosave row per slot; New Game clears that slot's old autosave | Pending responsive short/narrow menu, real selected-slot/manual-vs-auto load and malformed/failed-write tests using disposable files only. Clear an old run only as part of a confirmed new-run write, not before a failing New Game save. Explicit recovery policy must preserve the manual checkpoint. |
| `--dev --secret-room` placement shortcut | Diagnostic-only candidate; never normal New Game, kit grant, milestone or campaign acceptance proof. Keep isolated from player-save writes. |
| Map lesson removes instruction about swimming into R-enabled special spots | Pending special-site explanation reconciliation with actual trigger contract. Preserve current synchronous/responsive first-open and discovery-only legend; no unsupported narration rewrite. |

No Sonar/G/pickup changes in this late delta; the bounded Sonar port continues
to reconcile the already-authorized 4ec6598 behavior. Main/canonical deployment
remain untouched. The full completion ledger must include this intake visibly;
only the explicitly verified Box12/retired-route behavior is admitted. PR100
does not yet contain the complete bba8b80 scope.
