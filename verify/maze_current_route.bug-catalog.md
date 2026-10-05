# Maze current-route physical acceptance

October 4, 2026. Target MazeLevel, MazeMiniMap, Diver and WaterCurrent complete
reads carried forward; current setup/control/physics/geometry consumers reread.

## Module contract

1. Surface: parsed movement/mouse, Tab and L/E/Ctrl+E/Ctrl-arrow key input; actual
   CharacterBody3D collision, WaterCurrent Areas and discovered map selection.
2. Load-bearing: walls and currents move independently now. Opening hallway
   walls does not vacate either current. Current3 begins southbound, obstructing
   entry until relocated to Corridor4. Old H-era route tests are not acceptance.
3. IO: CSG physics, frame time, delayed wall sweep/camera, map discovery, optional
   onboarding modal. No file writes or changes to colliders/current strengths.
4. Branches: nearest versus manual map selection; undiscovered current excluded;
   opening/closing walls; current1/3 source/destination; map versus world E/R;
   wall animation temporarily owns steering; grappling/suction also owns motion.
5. Types: physical capsule radius/height and current-axis projection; real wall
   set/current Area identities. Driver reads geometry for path planning, never
   teleports, calls private rotation helpers or synthesizes completion.
6. Existing tests: maze_minimap covers discovery/geometry; maze_completion and
   maze_traversal still assume H simultaneously moved currents and use old spawn.

## Catalog and first test

| Bug | Impact / plausibility | Oracle / status |
| --- | --- | --- |
| Player cannot physically traverse the first channel with the current documented controls | High: all deeper content remains unreachable; old H test can approve wrong geometry/state | Characterized: original L/E/R route passed headless/native; latest Ctrl+E route passes fresh headless physics |
| A route fixture passes by teleporting or bypassing the authored passage | High: invisible barrier remains in shipped gameplay | Physical trace crosses interior; leaving current3 in place fails actual traversal |

The first gate opens the real map, rotates the revealed hallway walls, moves
current1, physically approaches the channel, discovers/relocates current3 and
crosses the two-wall channel. Collision-aware planning only proposes a route;
actual key-controlled Diver must swim it. No geometry/state helper accepts a leg.

Self-critique: stable blocked movement fails regardless of path planner output.
No removed-H expectations or hardcoded authored old entry coordinates. Geometry
query/named authoring references are driver scaffolding, not the completion oracle.
No camera/usability or whole-maze completion claim follows from this local test.

## Skipped

Full switch/poster/sphere/lever/secret/finale route is not accepted by this first
channel check; extend only after this channel is genuinely traversable. Battle
resources, save durability, camera polish and browser input have separate gates.

## Evaluation

Latest October 4 contract uses Ctrl+E and Ctrl+arrows, superseding the R and
intermediate Shift bindings. Fresh physical channel run passes without captured
script errors: `/tmp/underwater-marc-map-route-final.log`. This rerun is headless;
the older native/negative receipts below are historical, not fresh Ctrl-native
or fresh Ctrl-negative acceptance. The driver still uses actual key-controlled
swimming through the physical current region, not an injected completion.

First physical channel passes headless and native OpenGL without game changes.
It starts normally, switches to Bucky with actual Tab, physically discovers the
first wall, uses real L/E/R and discovers/relocates current3 before entering it.
Movement is parsed W/mouse input; production Maze physics stays running. A separate
negative input variant deliberately leaves current3 in place; the same route then
stops at its upstream/side edge with actual push (-4.2, 0, -7), rather than passing
through. This characterizes Marc's intended constraint, not a newly fixed bug.
Native channel and map captures were inspected: actor and controls are visible,
the discovered wall/current map matches the traversed passage. Full map sizing,
all route puzzles and battle paths remain unaccepted.

Excluded harness findings: initially asking to rotate walls before physically
discovering them, choosing the far rather than near first-wall endpoint, selecting
the whole 80m boundary's centre as the short channel interior, one untyped Basis
parse error and reusing a generated click event. Corrected without game changes;
none count as production defects or accepting red receipts. The deliberate
unrelocated-current run is the valid negative oracle. The old H traversal is
superseded in the runner; the broader old completion test remains pending update.
