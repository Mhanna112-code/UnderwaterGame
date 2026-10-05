# Bug catalog: moving maze walls

Generated with design-tests, October 5. Scope is MazeLevel's three public
rotatable wall sets, their transient motion owner and checkpoint restoration.

## Responsibility and public contract

`rotatable_wall_sets()` supplies the same rotate actions used by the navigation
map. Rotation blocks steering/saving until all walls finish. Walls normally
carry intersected divers; Marc's bba8b80 explicitly exempts occupants of the C5
passage from walls 10/11. Those walls and their under-floor skirts must have no
physical collision during the swing, then become solid again. World owns the
three live actors, so removing/restoring the maze cannot strand their locks.

Load-bearing comments explain rigid hinge motion, zero steering but live
currents, solid skirts and saveable stable geometry. Branches include an already
moving request, zero/one/multiple live Tweens, home/open rotation, C5 versus
outside, wall/skirt collision, completion versus killed Tween, active/inactive
owner, direct restore and removed owner. Names are the public map set IDs, not
arbitrary dispatch strings. IO is real physics, frame-time/Tweens and plain
checkpoint JSON; this first probe writes no player save slot.

Existing draft tests exercise rotations with actors parked away from the swept
area. They prove passages, not safety for a diver inside the moving geometry.
Older traversal tests retain obsolete H input; they are not a substitute.

| ID | Failure | Impact and plausibility | Test | Status |
|---|---|---|---|---|
| WALL-1 | Walls 10/11 collide with or sweep C5 occupants out of the passage. | High: strands the player; current sweep has no zone exception and collisions stay enabled. | Actual published rotation, independent C5 bounds, physical wall/skirt rays and generated three-capsule positions through both directions. | Original collision red caught; C5 exception repaired. |
| WALL-2 | Finished/interrupted rotation leaves walls ghosted or input/save permanently locked. | High: gameplay cannot resume; Tween.finished never fires after kill, current tracker retains stale entries. | Mid-motion JSON restore, actual owner removal, stopped Tween and repeated rotation; verify stable geometry/collision and real post-release swimming. | Adapted lifecycle verified; not claimed as an original-baseline failing test. |
| WALL-1a | Wall10's attached split-rock collider still shoves C5 divers after disabling the wall and skirt. | High: the initial narrow port leaves a moving solid child; actual slide collision identified SplitRock/Body. | Same generated real-capsule test, no rock removal or mocked collisions. | Red caught after first port; repaired by preserving/suspending all attached collision layers. |
| WALL-3 | Outside-C5 riders lose the wall or finish buried in static geometry. | High: invalid landing; the integration only pushes overlapping capsules rather than retaining authored rider ownership. | Real swept-wall contact followed through multiple physics frames, independent capsule/solid-volume landing queries and owner teardown. | Deferred within the moving-wall batch, after WALL-1 is green. |

## Test self-critique

WALL-1 must not accept just a disabled property: physical queries and capsule
position conservation catch wrong-but-stable behavior. Inputs are generated
across actor, side and direction; candidate locations come from actual swept
geometry but clear initial/final placement is checked independently. Public
rotation and JSON restore survive helper refactoring. Fixtures isolate rotation;
they do not claim normal campaign traversal or earned map acquisition.

WALL-2 uses public restoration/lifecycle and real swimming, not a private cleanup
call. A stale tracker or delayed old Tween rewriting a loaded wall fails.

## Skipped / still required

- Full earned map route and browser controls: preserved existing gates, final
  campaign/browser acceptance remains separate.
- Poster barrier, hall whirlpools and autosaves: separately catalog/test before
  their port; not silently covered by this wall test.
- Full campaign balance and opening pivot: unrelated to the geometry probe.

## Evaluation

- Caught: original moving wall/skirt solidity, and the split-rock child shove
  exposed after the first port. Original baseline and child-collider red logs
  are retained in the evidence folder.
- Verified after adaptation: checkpoint cancellation (no delayed geometry
  overwrite), killed scheduler, inactive owner/re-entry, and teardown restoring
  non-default layers without destroying World actors. These were not separately
  run as original-baseline reds; do not inflate the caught-bug count.
- One test parse error (untyped `world.divers` actor inference) was corrected
  before the accepted original red. It is a verifier mistake, not a product fix.
- Early restore-loop labels repeated the same selected actor. Final tests change
  actual checkpoint `active`, assert both World/Maze selection and swim each
  selected diver. Only the corrected receipts support three-actor restore claims.
- The current-on branch bounds displacement only while the actor remains in C5;
  the actual water may legally carry them beyond it. The relocated-current branch
  keeps clear capsules stationary. Neither turns current behavior off globally.
- WALL-3 remains pending; do not present C5 safety as retained-rider completion.
