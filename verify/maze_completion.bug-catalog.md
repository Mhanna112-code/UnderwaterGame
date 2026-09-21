# Bug Catalog: `verify/maze_completion.gd`

**Created:** 2026-09-19  
**Scope:** the standalone `MazeLevel` player journey from the authored
`DiverEntry`, through the H-operated passage, to the authored `ItemRock`
reward and an observable completion state.

## System summary

`MazeLevel` is a standalone, player-controlled scene. Its public gameplay
surface is the H key and E ability key handled by `MazeLevel._unhandled_input()`,
normal `Diver.swim()` movement/collision, the Mech Pilot's shockwave, and the
reward rock's `CrackedWall.broken` signal. Before this
contract, the scene could spawn a golden orb but had no completion state or
finish UI. The reward rock is at the scene-authored `ItemRock` marker.

## IO boundaries

- `res://game/maze_level.tscn` scene construction and CSG collision.
- Godot physics frames and the 1.2 second H hallway animation.
- No file, network, randomness, or test-written player-position IO.

## Bug catalog

| ID | Failure mode | Blast radius | Why plausible | Test type | Status |
| --- | --- | --- | --- | --- | --- |
| MAZE-END-1 | A player can cross the repaired local junction but can never physically reach the authored reward. | The maze looks playable yet has no finishable run. | The reward marker was behind solid `CSGBox3D26`; existing tests stopped at the junction. | Captured end-to-end gameplay contract | fixed |
| MAZE-END-2 | Reaching and breaking the final reward gives no observable completion state. | A player cannot tell whether they finished; later flow cannot react. | `_on_item_rock_broken()` only instantiated an orb. | Captured completion-state contract | fixed |
| MAZE-END-3 | A future geometry change makes the test pass by a side/perimeter bypass rather than the H route. | Regression test could approve an unreachable intended route. | The maze is underwater and must constrain all three dimensions. | Negative-path invariant | characterized |
| MAZE-END-4 | The direct reviewer URL races World construction or silently boots the ordinary game instead of the maze. | Review evidence does not exercise the claimed scene. | `change_scene_to_file()` from `_ready()` mutates the scene tree during setup. | Launch-route lifecycle contract | fixed |

## Tests

### MAZE-END-1 and MAZE-END-2 — real player completes the maze

- **Test type:** captured end-to-end gameplay contract.
- **Observable contract:** starting at the authored `DiverEntry`, the normal
  player input opens H, the real `Diver` swims through the existing passage
  and the authored reward entrance, then presses E to shockwave the only
  `ItemRock`.
  `MazeLevel.is_completed()` becomes true and its completion label is visible.
- **What it catches:** a blocked reward room, a route that only works after
  teleporting, a reward that breaks without ending the maze, or a later change
  that quietly removes the completion signal.
- **Self-critique:** it does not inspect CSG transforms or call private movement
  helpers. It passes under any behavior-preserving rewrite that lets the real
  collider finish the run, and fails for stable-but-wrong geometry or UI.

### MAZE-END-3 — no perimeter/side bypass

- **Test type:** negative-path invariant.
- **Observable contract:** the trace must visit the opened CSGBox3D6/7 channel
  and enter the reward room through the authored southern entrance; it may not
  leave the level's collision perimeter or enter the room through its side
  walls.
- **What it catches:** a route test that reaches the goal only because a wall
  was removed wholesale or the player escaped around the level.
- **Self-critique:** it asserts authored route regions, not wall node names or
  placement helpers, so a behavior-preserving refactor remains valid.

### MAZE-END-4 — direct review launch is real and lifecycle-safe

- **Test type:** launch-route lifecycle contract.
- **Observable contract:** the native equivalent of `?maze=1`,
  `--maze-playtest`, is recognized by `World`; its deferred transition makes
  `MazeLevel` the active scene without emitting a Godot script error.
- **What it catches:** a reviewer URL that starts the normal world, or a
  synchronous scene replacement while `World._ready()` is still building its
  children.

## Skipped

- World-scene integration: `world.tscn` does not currently instantiate this
  standalone prototype. This contract is deliberately about the reviewable maze
  scene; promotion into World requires a separate product-flow decision.
- Lever puzzle semantics: the two existing levers are intentionally unwired and
  no agreed lever-to-current mapping exists. This test does not invent one.
- Camera composition: visual review owns third-person framing; it is not a
  completion correctness assertion.

## Evaluation

- **Bugs caught:** MAZE-END-1 failed red on the PR head: after H, the live
  swept-capsule search found no collision-safe route from the opened passage to
  `ItemRock` because the solid south reward-room wall (`CSGBox3D26`) sealed it.
  The first direct real-Diver attempt stopped at `(25.38, 0, 30.68)`; the
  collision-aware route then confirmed no alternative exists. Splitting only
  that wall around a 4.3m doorway repairs the topology while preserving both
  chamber sides.
- **Bugs caught:** MAZE-END-2 was confirmed by inspection during the red
  investigation: the reward callback spawned an orb only. Completion now has a
  public `is_completed()` state, signal, and visible `MazeComplete` label.
- **Bugs characterized:** MAZE-END-3 is protected by the required H-channel
  trace and southern reward-door trace. The planning grid respects the
  northbound one-way current by never routing the player back through it; the
  production `Diver` then swims every collision-planned grid leg with collision and
  currents enabled.
- **Additional finding:** a geometry-only path planner initially chose to
  reverse through WindCorridor3 after H. That is physically open but not
  player-traversable because the documented H state deliberately makes it
  northbound. The final contract carries the diver clear of that current before
  planning and rejects any path returning south through it.
- **Bugs caught:** MAZE-END-4 initially emitted `Parent node is busy
  adding/removing children` and repeatedly accessed a partially built World
  after a synchronous scene replacement. The route now disables outgoing
  processing and defers the transition; its native launch contract is gated.
