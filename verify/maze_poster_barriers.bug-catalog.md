# Bug catalog: poster-wall boundary integration

October5, design-tests. Scope: MazeLevel's start/poster fences, static perimeter,
shared-area entrance and compatible checkpoint restoration.

## Responsibility / interface / boundaries

Marc's current poster-wall contract closes the water beyond both ends of
HallwayEndWall: east to Box6 and west to the actual maze edge. The public player
interface is ordinary swimming and the map's rotatable actions. World owns the
party; the embedded west perimeter deliberately has a physical entry gap after
the laboratory. The earned map chest must still be reachable before map ownership.
Scene setup generates fences once; save JSON restores durable walls and flags,
not a second set of independent fence owners.

Read code includes setup order (posters before fences; floors and skirts before
physics queries), perimeter corner aggregation, standalone versus embedded entry
opening, wall-set home/open barriers, spawn/restore and existing real map/ramp
route drivers. Important branches: missing poster, negative/zero fence span,
standalone versus World, home/open motion flags and old coordinate frame.
Strings name authored walls, not private test dispatch. IO: CSG/StaticBody
physics, SceneTree frame time and plain checkpoint JSON. No new player files.

| ID | Failure | Impact / plausibility | Test / status |
|---|---|---|---|
| POSTER-1 | Players swim around the western/eastern poster wall ends into the closed water. | High: bypasses authored corridor puzzle; both upstream fences are missing. | Fixed: original real-W red, then 48 real swimming cases and 636 physical rays. |
| POSTER-2 | The western extension blocks the embedded entry/ramp or earned-map path. | High: prevents normal progression; standalone perimeter differs from embedded opening. | Preserved: actual bidirectional ramp, real Box12/chest E/L and shared-World pre-map acquisition/return. |
| POSTER-3 | Loading old geometry buries actors in a newly introduced static fence. | High: previously valid saves become stranded; actor positions precede geometry restore. | Characterized: generated saved placements, old/current frame, depleted/downed resources, effects and actual post-load swimming. No additional production migration needed for these solid StaticBody fences. |

## Self-critique / generator

The crossing oracle observes which side of the authored wall line a real capsule
reaches under real input, not presence/name/size of a barrier node. Initial
capsules must be physically clear and controllable. The bounded generator is
three actors × two approach sides × two gap positions × both gaps × low/high
positions. High placement is derived from the actual physical ceiling and each
capsule, not a fixed Y that may be inside the ceiling. Physical
rays cover the continuous boundary and its seams independently of the builder.
Wrong-but-stable missing/truncated fences fail. Helper refactors keep passing.
Restore tests use JSON and input, not private migration helpers.

## Skipped

- Hall whirlpool shaft/lifecycle redesign: separately catalogued after this red
  is repaired; not claimed by fence tests.
- Autosaves and campaign pivot: later integration batches.
- Merely asserting fence node names: no player-visible oracle.
- Final browser/normal campaign balance: full integrated acceptance, not these
  deliberately isolated boundary placements.

## Evaluation / adversarial investigation

- Caught POSTER-1: at source77cd7b7, W moved from z37.13657 to43.05341,
  past the boundary z39.13657. After the authored east/west fences, the same
  movement stops at38.20691. Native Metal also stops at the same coordinate.
- Characterized POSTER-3: solid-box collision resolves overlapping saved
  capsules safely during normal physics; all three members can subsequently
  swim away. Unlike wholly buried concave CSG walls, these fences did not need
  a second custom relocation owner. JSON probes cover36 all-living and36
  one-downed-party cases (three selected actors × two coordinate frames ×
  two gaps × three side offsets), including selected Musashi at zero Oxygen.
  HP/Oxygen, current evasion, Bleed, inventory, map and generic keys survive.
- Observer failures are not product repairs: the first high-Y matrix fixture
  was inside the existing ceiling. Its approach oracle rejected it; the final
  generator measures a legal ceiling-clear height. The first effect comparison
  used Dictionary equality across JSON int/float values, falsely reporting
  loss although restored numbers were unchanged. The retained rejected log is
  disclosed; semantic level/turn comparisons resolve the observer error with
  no production stats change or relaxed gameplay assertion.
- No node-name/box-size-only test is used as acceptance. Authored barrier
  names are fixture diagnostics, while actual swim positions/rays are oracles.
- Native screenshot is a renderer/camera receipt of the blocked actor in dark
  water. An invisible fence cannot be proven by that still alone. It is not
  final representative campaign art/UI acceptance or browser proof.
- Full current/normal campaigns, hosted build, hall hazards and autosaves
  remain outside this bounded regression admission.
