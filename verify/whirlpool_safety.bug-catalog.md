# Bug catalog: authored whirlpool ownership and physical safety

October5, design-tests. Whirlpool's complete module and its World/Maze setup,
physics and warning consumers were read, alongside Marc's upstream differential.

## Responsibility / public interface

Real Area3D overlaps warn and pull a shared Diver through a timed spiral,
then return it to an authored approach with bounded nonlethal damage. Public
settings describe warning/suction/pull geometry, bypass and reset position;
signals report warning and actual HP lost. SceneTree lifecycle, actor physics,
model visibility and resource state are observable interfaces, not private
helper call expectations.

Load-bearing contracts: grapple/suction owners are exempt; an inactive area
must not control shared actors; whirlpool damage is a scare, never knockout
or resurrection. Ordinary World/maze camera/HUD/save ownership remains singular.
IO includes engine shapes/rays, physics/render/Tween time, random damage and
static root warning state. No player-file IO is necessary for the first test.

Branches: armed/bypass, sphere versus tall cylinder, warning membership,
grapple/suction locks, missing/freed actor, drag versus catch, sink/vanish/reset,
owner exit and battle/menu/inactive state. An Actor cannot be cast safely
before validating a retained reference. Current code has no durable hazard
motion owner or cancellation boundary; that must be investigated explicitly.

| ID | Failure | Impact/plausibility | Test and status |
|---|---|---|---|
| WHIRL-1 | A warning/suction shape crossing a solid wall catches or drags a diver in the adjacent passage. | High: unavoidable damage/reset bypasses physical corridors; both callbacks lack upstream line-of-sight protection. | Fixed: original real World overlap red,24 generated obstructed/open pairs and native Metal repeat. |
| WHIRL-2 | Inactive maze, battle or exclusive reading/menu state still pulls actors or draws root-owned warnings. | High: two input/resource/HUD owners; scene-child areas/Tweens/static labels can outlive owning gameplay. | Actual shared area handoff, battle/modal and paused-warning checks. Pending. |
| WHIRL-3 | Restore, killed Tween or owner/actor teardown leaves a shared model hidden, rolled or suction-locked, or emits freed-reference errors. | High: irreversible gameplay stall; the current Tween is local/untracked and exit only clears captions. | Actual lifecycle interruption with live actor/model/mask/resource conservation and resumed swimming. Pending. |
| WHIRL-4 | Nonlethal damage revives a downed diver or reports negative damage. | High: corrupts combat/resource contract; max(1,hp-damage) unconditionally raises0HP. | Generated living/downed HP and damage values under actual overlaps. Pending. |
| WHIRL-5 | Hall layout/deep-shaft port blocks all safe lanes or regresses grapple visibility. | High: final route becomes impossible; current hall tuning/layout and deep visuals differ upstream. | Real avoidance/arrival/reset traversal plus physical columns/ceilings, native shaft/floor/ring/anchor view. Pending after first safety red. |

## First test / self-critique

WHIRL-1 places a real shared diver at a capsule-clear approach in World. A
real BoxShape wall separates it from a real Whirlpool's suction cylinder;
an independent ray verifies obstruction before checking lock, HP and position.
Removing the wall must then permit a real catch/reset/damage signal. No
synthetic body-enter callback or private LOS helper is called.

Wrong-but-stable always-disabled suction fails the positive leg; missing or
ineffective ray protection fails the negative leg. A callback/helper refactor
preserving real behavior keeps passing. The first case uses measured capsule
clearance, not an illegally overlapping actor or mocked environment. Once it
is green, generate three actors, two blocking orientations, solid StaticBody
versus CSG walls and sphere versus cylinder suction (24 paired cases). A
separate height/deep-hall generator belongs to WHIRL-5.

## Skipped / deferred

- No shape/node-name-only evidence; actual overlaps/rays/input are required.
- Hall deep holes, visual port and gentle lane tuning remain separate required
  acceptance, not claimed by the first LOS test.
- No new narration, enemy kit or ordinary victory recovery in this module.
- Final browser/campaign/audio and desktop packages remain in the full ledger.

## Evaluation / investigation

- WHIRL-1 caught at7ced43e: an intervening real wall did not prevent suction;
  the diver locked, lost2HP and reset from228.8 to226. LOS protection now
  leaves its pose/HP/lock unchanged. Removing that same wall permits actual
  catch/reset/release and2HP damage without spending Oxygen.
- 24 generated paired cases pass with each capsule, both wall types, both
  suction shapes and both wall orientations. Independent physical oracles
  require a clear approach/reset and a real intervening wall, then clear
  open sightline. Native Metal repeats the captured case. Existing real
  current-route and first-person grapple gates pass.
- Rejected fixture findings are retained, not presented as product repairs:
  rotating the reset direction put it in a lab ramp side rail; relocation to
  another alleged open-water area crossed a real World boundary. The final
  generator stays in validated water and uses the independently clear normal
  approach as reset. A still-blocked positive sightline is now a fixture
  failure, never an excuse to disable the production LOS check.
- WHIRL-2/3/4/5 remain open. No admission of inactive-area/paused warning,
  motion teardown, downed resource policy, deep shafts, gentle hall layout,
  browser or full campaign acceptance follows from these LOS cases.
