# Maze minimap navigation bug catalog

This slice ports the player-facing **dynamic maze/current navigation** intent
from raw PR #72.  It deliberately does not copy its decorative wall-derived
waves: a line that merely fits between two nearby walls can remain in the
wrong corridor, or face the wrong way, after `H` moves a real `WaterCurrent`.

| ID | Plausible failure | Player impact | Cheapest regression | Why this scope |
| --- | --- | --- | --- | --- |
| MAP-WALL-01 | The overview keeps endpoint pixels captured before `H` swings `CurrentWall1/2`. | The map directs a player through a wall or hides the opened route. | Compare the displayed `Line2D` endpoints with the current `CSGBox3D.global_transform` before and after a real H animation. | Existing maze tests prove collision traversal; this proves the visual follows that same collision geometry. |
| MAP-FLOW-02 | A current overlay follows a neighbouring wall or a stale corridor rather than the live `WaterCurrent.area` and `orientation`. | A blue line claims flow is present, absent, or moving in the wrong direction. | Compare each rendered arrow's world endpoints with the actual `WaterCurrent` collision box and orientation; repeat after H relocates Corridor 2's flow to Corridor 3. | This is the regression raw #72's wall-wave implementation cannot catch. |
| MAP-FLOW-03 | H parks Corridor 1's current and moves Corridor 2's current, but its old overlays remain. | The opening looks blocked or unsafe when the playable route is open. | Assert the displayed flow corridor set is exactly the `_currents_by_corridor` key set before and after H. | The game dictionary is the authoritative runtime state. |
| MAP-INPUT-04 | Shift+Right/Left also changes the selected hall because modifier and plain-arrow handlers both run. | A reviewer loses their wall selection while attempting to inspect flow. | Dispatch one production `InputEventKey` with `shift_pressed`; assert only the flow selection changes. | Directly covers the raw PR's documented input collision. |
| MAP-UX-05 | The large map has no legend, orientation, or stated objective. | A player can see lines but cannot infer what cyan flow or H means. | Assert the real overlay contains its title, legend, and H/relic objective copy; browser review checks readability. | Text alone does not prove visual hierarchy, so an exported manual review remains required. |
| MAP-FOG-06 | Navigation overlay reveals an undiscovered current or fails if no corridor has been seen. | It spoils the maze or crashes at launch. | Start closed, then reveal only through the production discovery function; assert no current line exists before discovery and each line is added only after its corridor is seen. | This preserves #70's existing discovery contract. |

## Test boundary

`verify/maze_minimap.gd` moves the existing standalone diver only to reveal
map data; it never teleports a diver through a route or calls a collision
bypass.  `verify/maze_traversal.gd` and `verify/maze_completion.gd` remain the
separate production-physics proof that the drawn H route is physically
swimmable and reaches the relic.

## Human review boundary

An exported `?maze=1` run must manually check the title/legend contrast,
visible player orientation, flow arrows, open-route state before and after H,
and a normal swim to the relic.  The automated test cannot establish that a
human can read an otherwise geometrically correct overlay.
