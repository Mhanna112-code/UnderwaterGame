# Bug Catalog: `verify/maze.gd`

**Updated with /design-tests on 2026-09-16**
**Scope:** `game/maze_level.gd` and its standalone maze verification entry
point.

## What this file does

`MazeLevel` builds the standalone swimmable puzzle maze. Its public gameplay
control is the H-key hallway toggle: two `CSGBox3D` walls move while the paired
water currents move between corridors. `verify/maze.gd` now validates both the
finished geometry and the in-motion geometry that a player sees.

## Public interface

| Symbol | Type | Purpose |
|---|---|---|
| `MazeLevel._rotate_hallway_1_2()` | gameplay action | Toggle the two-wall hallway and its currents. |
| `MazeLevel._wall_flush_target()` | geometry query | Compute a wall's finished 90-degree continuation transform. |
| `verify/maze.gd` | headless SceneTree | Verify the maze's observable completed and in-motion geometry. |

## IO boundaries

- Scene loading: `res://game/maze_level.tscn`
- Time: Godot tweens and timers drive the 1.2-second hallway motion.
- Input: the gameplay route calls the same toggle from the H key.
- No network, file writes, or randomness are involved in wall placement.

## Bug catalog

| # | Bug | Blast radius | Plausibility | Test type | Status |
|---|---|---|---|---|---|
| 1 | A wall linearly interpolates between correct endpoints instead of rotating around its attachment pivot, cutting visibly through the neighbouring corridor mid-swing. | High — the player sees the broken maze shown in Marc's screenshot and can collide with transient geometry. | `_tween_wall_to()` independently tweened position and yaw. | Captured bug + motion invariant | fixed |
| 2 | A future wall change loses the final CSGBox3D6/CurrentWall1 join while changing sizes or rotation. | High — it reopens a maze boundary or creates a visible gap. | The maze mixes static and future transforms. | Completed-state geometry invariant | characterized |
| 3 | Open then close accumulates transform drift. | Medium — repeated puzzle use eventually misaligns walls/currents. | State is retained across two separate tweens. | Round-trip transform invariant | fixed |
| 4 | A wall follows an arc but lands at a different final transform from the designed flush target. | High — an animation-only repair regresses the static layout. | Arc motion derives a pivot from start/target transforms. | Differential final-state invariant | fixed |

## Test plan

### Bug #1 — diagonal hallway translation

- **Test type:** captured bug + motion invariant.
- **Description string:**
  > `maze: moving walls preserve their derived attachment pivot — guards against diagonal corridor crossing`
- **What it catches:** a midpoint position whose radius from the pivot shrinks,
  as happens under linear position interpolation.
- **Self-critique:**
  - Could this pass for wrong-but-stable output? No; it samples the in-progress
    transform and checks the geometric invariant of a hinge rotation.
  - Could this fail under a behavior-preserving refactor? No; any animation
    implementation that rotates about the same pivot passes.

### Bug #2 — static outer wall join

- **Test type:** completed-state geometry invariant.
- **Description string:**
  > `maze: CSGBox3D6 meets CurrentWall1's rotated outer join — guards against static-frame gap`
- **What it catches:** a misplaced barrier at the completed H state.
- **Self-critique:**
  - It measures the named physical join rather than restating the placement
    helper's decision.

### Bug #3 — toggle drift

- **Test type:** round-trip invariant.
- **Description string:**
  > `maze: H open-close restores both hallway wall transforms — guards against toggle drift`
- **What it catches:** a close operation that does not return exact home
  transforms.

### Bug #4 — arc misses final target

- **Test type:** differential final-state invariant.
- **Description string:**
  > `maze: arc motion ends at the precomputed flush transforms — guards against correct animation ending in wrong geometry`
- **What it catches:** an arc with a wrong pivot/direction that looks smoother
  but lands away from the intended layout.

## Skipped

- Full diver collision traversal during the moving wall — deferred: the
  headless harness proves geometry but does not synthesize physics-player
  navigation reliably.
- Visual styling of walls and camera framing — cosmetic; covered by
  player-camera review evidence rather than a geometry test.
- Current relocation behavior — out of this wall-motion repair; existing
  current gates need their own focused tests.

## Post-write evaluation

- **Bugs caught:** Bug #1. Before this repair, the midpoint pivot-radius
  errors were 2.5491 m / 3.9432 m. After it, both are 0.0000 m.
- **Bugs characterized:** CSGBox3D6's completed outer join is already correct
  in the captured build; its physical gap measures 0.0000 m.
- **Bugs discovered during writing:** the earlier final-state-only test did
  not sample the motion shown in Marc's screenshot.
- **Tests removed:** none.
