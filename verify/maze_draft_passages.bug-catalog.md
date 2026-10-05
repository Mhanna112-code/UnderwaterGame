# Maze draft passage integration

October 5, 2026. Read Marc's complete authored underpass/return block at
4ec6598 and the current MazeLevel construction, floor/perimeter, wall targets,
barriers, physical movement, modal/input, checkpoint and rider consumers.
Diver capsule and suction-lock, ConfirmPromptModal and Whirlpool contracts read.

## Responsibility / public surface

The Break Room draft offers a one-way outgoing passage below Wall11EndCap.
The separate passage under swung wall 11 automatically brings an outside diver
back to the 10/11 hall. This is a continuous-area movement sequence, not a
second secret scene. Observable surface: real approach/swimming, Yes/No input,
wall rotation via the published rotatable-wall-set callable, party selection,
exclusive modal/motion ownership and stable snapshot/save/load contracts.

## Invariants, dependencies and IO

Latest upstream comments supersede the earlier bidirectional Break Room draft.
Outgoing prompt only exists on the Break Room side; No latches until departure.
Automatic return only exists once wall 11 finishes swinging, from its outside.
Both must finish at a collision-clear position and release the actor lock.
The same World party/stats must survive; passage is not a rest or reward.
Floor/CSG baking, real physics space/capsules, tweens, input dispatch, owner
teardown, modal lifecycle and checkpoint JSON are boundaries. Types are actual
Diver, CSGBox3D, ConfirmPromptModal, wall-state bools and versioned snapshots.

Branches: standalone/embedded; maze active/inactive; each diver; home/swung/
moving walls; outgoing/incoming/opposite side; prompt Yes/No/reapproach;
battle/map/selection/pause; stable/in-flight save; fresh/old restored geometry;
owner teardown. No gameplay resource or completion milestone may be invented.

## Ranked bugs and tests

| ID | Failure / blast radius and plausibility | Cheapest accepting test | Status |
|---|---|---|---|
| DRAFT-1 | Missing or wrong-side outgoing draft strands an explorer; starting integration had no passage | Real approach, actual No/Y, one-way and reapproach movement | Missing approach reproduced; port passes |
| DRAFT-2 | Passage ends inside a solid floor/wall and actor cannot swim away; upstream endpoint search may return a blocked fallback, and concave CSG queries miss capsules wholly inside boxes | Actual all-diver traversals, independent surface and solid-interior checks, fully blocked exit negative, and held-key departure | Floor/skirt clipping and buried blocked exit reproduced; repaired |
| DRAFT-3 | Incoming draft is absent, wrong-way, or triggers before wall motion finishes; starting integration had neither latest target alignment nor return | Real published wall rotation, outside approach and directional negatives | Latest pair ported; 12 actor/state/direction cases and moving-wall negative pass |
| DRAFT-4 | Input/save/encounter/teardown races passage tween, swaps actors or leaves suction lock forever | Actual Tab/F/L/P/R attempts while motion owns actor, snapshot negative, teardown release | Buried teardown actor reproduced; all three actor teardown cases pass |
| DRAFT-5 | Load restores older target geometry or buries a saved actor in its migrated wall | JSON round trip, real cold Title Load and actual restored passage for all actors | Misalignment and migrated solid-interior reds; six restores and cold Load pass |

## Self-critique / generated cases

First check drives a real production World and approaches the physical Break Room
landmark. It requires a visible question and actual input response, not the
existence of a function or particles. Fixtures place actors near the relevant
geometry, explicitly not full earned-route proof. Capsule overlap is independently
queried, and later key movement must work; a stationary or clipped endpoint fails.
Bounded actor × wall-state × direction cases exceed five and will be generated.
Stable snapshots must preserve resources and geometry while rejecting in-flight
capture. No exact helper name, label punctuation or tween duration is the oracle.

## Skipped / separate acceptance

- Full maze journey, enemy-site minigames and earned campaign balance: later gates.
- Exact particle count/style: native/browser inspection, not state assertions.
- Old Wall27 scene passage: superseded, do not pin it as normal route.
- Whole moving-wall rider/floor admission: this test only accepts passage-related
  wall geometry and safe endpoints; remaining geometry stays in the ledger.

## Evaluation

Caught against the real production path: missing outgoing approach question;
floor and wall-skirt clipping during motion; owner teardown resealing the slab
around a shared actor; concave CSG accepting a wholly buried exit; old saved
wall alignment; old clear party placement now inside the relocated wall.
Native inspection additionally caught the dark marker hiding the descending
diver and stale "swinging" copy after wall motion completed. Marker hides
while the tunnel is open, and settled status now follows actual Tween completion.

Characterized: safe No/default focus and departure rearming; no reverse E;
exclusive Tab/F/L/P/R and unstable-save rejection; clear endpoints and actual
held-key departure; three outgoing capsules; 12 incoming state/direction cases;
476 independent live-path checks (CSG solid interior plus capsule surface),
solid floor outside the bounded hole and resealing afterward; moving-wall
incoming/save negative. Six JSON restores and a disposable-slot cold Title
Load preserve shared HP/Oxygen/inventory and actually use the return passage.
Three separate actor-owner teardown runs release at their original safe approach.

Rejected evidence: one verifier shadowed its loop variable and failed parsing;
that is a harness mistake, not a product red. Initial endpoint-only and concave-
surface-only greens were too weak; whole-motion and solid-interior checks
replaced them. The first supposed overlapping saved-position probe was outside
the affected volume; corrected placement caught the actual buried save.
The old input-ownership fixture expected a separate-scene portal and failed at
entry. Its setup now actually swims across the embedded boundary and retains
the shared World/party owner; its map/save/Swap/R/current/strong-room assertions
remain, with all three actor cases passing.

Receipts and fixture limitations: `docs/evidence/maze-drafts-oct5/README.md`.
No whole geometry, browser, normal campaign, balance, export or merge-readiness
claim follows from these focused results. Remaining rider/floor/hazard routes
and all full-plan requirements stay on the completion ledger.
