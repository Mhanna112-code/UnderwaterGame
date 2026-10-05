# Bug catalog: embedded World/maze ownership

Scope: World and MazeLevel's production construction, physical-area handoff,
and campaign checkpoint boundary. October 5, 2026.

## Responsibility and public interface

World constructs the campaign and receives Title New/Load events. MazeLevel
constructs authored geometry, exposes entrance/bounds and snapshot contracts,
and receives actual movement, encounter signals, input events and save requests.
The player must swim between areas with the same three live actors, not merely
receive equivalent stats on three replacements.

## Load-bearing rules and types

CampaignSession retains live CombatantStats/inventory identity; CampaignCheckpoint
is the versioned JSON boundary. RouteState owns independent lab/maze milestones.
MazeCoordinateFrame treats missing origin as legacy standalone coordinates.
Maze key items are distinct from campaign relics. Building walls currently moves
the active diver; this standalone debug behavior must not affect embedded actors.

## IO and branches

Scene instantiation/readiness, physical movement/Area signals, camera selection,
input dispatch, pause/modal state, deferred scene changes, RNG encounters and
SaveManager/BrowserCheckpoint are boundaries. Branches: standalone vs embedded;
World vs maze active; open/pause/battle/cutscene; review vs normal entry; old flat,
world envelope or maze envelope load; stable vs moving snapshot; failed write.

## Existing evidence

maze_world_return, maze_checkpoint, puzzle_maze_exit and checkpoint IO prove
parts of the old separate-scene contract. Coordinate-frame generated cases pin
spatial migration. Those checks do not establish shared Node identity or a ramp.

## Ranked bugs

| ID | Failure | Blast radius / plausibility | Test | Status |
|---|---|---|---|---|
| EMBED-1 | Maze construction or entry replaces/moves the World party and steals camera/HUD | High: formerly spawned a new party and changed scene | Real World construction and physical entry invariant | Fixed within this batch |
| EMBED-2 | Both areas swim or process input/encounters simultaneously | High: sibling processing and shared signals | Real input, motion, inactive battle negative paths | Fixed double-entry step; scoped ownership checks pass |
| EMBED-3 | Old maze saves restore to the old frame, or World saves discard maze progress | High: former loaders changed scene and snapshots had separate party positions | Generated conservation + actual cold Load | 48 JSON cases and legacy cold Load pass |
| EMBED-4 | Ramp remains at the blockade or is obstructed by perimeter/floor/lab geometry | High: old coordinates overlapped current laboratory | Capsule traversal through actual geometry in both directions | Real both-way floor and route checks pass |

## Self-critique

EMBED-1 asserts live actor identity/positions, sole viewport camera and visible
HUD ownership, not calls to a private helper. Wrong-but-stable replacements fail.
Input/physics entry is the public interface; preserving that behavior permits a
different internal handoff implementation. EMBED-2 observes actor displacement,
selected diver and battle state after actual events. EMBED-3 varies all three
active divers and depleted/downed states, asserting state conservation rather
than recomputing the serializer. EMBED-4 uses real capsule motion, not node-count
or coordinate-only checks. More than five state shapes require generated cases.

## Skipped

- Full campaign balance, finale and new Mermaid asset: subsequent batches.
- Pixel polish: later browser evidence; ownership alone is not visual acceptance.
- Exact authored wall naming: only persistence identifiers are wire contracts.
- Old portal implementation: being replaced, not pinned as intended behavior.

## Evaluation

Bugs caught: World originally had no embedded maze. After construction was
implemented, the real crossing check caught a doubled movement step (0.166687 m
instead of the 0.083343 m single-frame step). A subsequent cold-launch assertion
caught inactive maze construction advancing the opening's octopus milestone.
Both repairs pass their unchanged assertions. These are game regressions;
incorrect camera direction, missing fixture modifier fields and strict JSON
numeric dictionary equality were harness errors and are not counted.

Characterized: same live actors and CombatantStats through physical entry/return;
sole camera/HUD ownership; real Tab once; R mirrored to the save owner; no World
random battle from maze movement; parked inactive-maze Sonar does not drain O2.
The explicit inactive-battle helper rejection is only a narrow defensive check,
not proof of every Area/hazard callback. Full hazard/encounter integration remains
in the completion ledger.

EMBED-3 generates three active divers × eight downed patterns × two checkpoint
areas (48 cases), half with legacy missing-origin data. Assertions preserve
positions, statuses, temporary modifiers, depleted resources, map/key ownership,
inventory and independent laboratory state. A real disposable file is loaded
through a fresh World's Title screen; old separate-scene maze saves migrate to
the shared actors without replacing the World scene. Fixture physics is disabled
only for state isolation; this is not traversal or balance proof.

Physical evidence: actual held movement crosses the lab-side floor/perimeter gap
in both directions, including sink-held descent and uphill return. The separate
spawn-to-maze gate reaches this entrance with lab guards undefeated. Normal
rotation/hazard traversal elsewhere is not accepted by these ramp tests.

Adversarial investigation: the old all-alive one-HP loss fixture sometimes won
an unrelated fight and failed recovery assertions. One later diagnostic reached
Cordys and lost; the cause of the earlier fight is not established. The accepting
recovery fixture now requires encounter_source=maze_cordys and uses a one-HP
Bucky with zero evasion and two already downed members. It accepts actual boss
damage, exclusive Game Over and cold Restart, never an injected result. This
characterizes recovery only, not campaign difficulty or encounter priority.
