# Earned maze map and chest admission

October 4, 2026. Marc #97 `64c778a`, superseding developer grant removal
`c65cf93`, final acquired-item copy `1a9ba39`, solidity `2c32467` and chest
input ownership `1ec8be0`. Latest inspected #97 head `4ec6598`; its wider
gameplay/geometry changes remain separate admissions.

## Module understanding

MazeLevel builds the authored Control Room dome, owns real exploration keys,
party/maze inventory, chest Tweens, campaign snapshots and encounter admission.
MazeMiniMap is a separate input consumer: blocking MazeLevel alone cannot stop
L/selection/current keys. Items supplies inventory descriptions; maze door
consumption uses `keys_held`, not the string inventory. CampaignCheckpoint
validates the shared JSON envelope. These modules/contracts were read along
with the existing physical-route and checkpoint tests.

Public surfaces: swimming/click/SPACE/E/L/Escape input, visible chest/caption,
inventory ownership, opening map, actual doors and campaign save/load.
Time/physics/paused Tweens and scene destruction are the important boundaries.
No new independent maze save file is allowed. Acquiring the map must not grant
a consumable door key, heal the party or reconstruct it.

Branch inventory: no item versus acquired; inside versus outside map region;
opening versus closing L; unopened/in-flight/completed chest; pause/resume;
modal/battle/Swap versus exploration; fresh/dev/old-saved state; successful
reward versus interrupted scene; stable capture versus pending reward.

## Ranked catalog

| ID | Failure / blast radius / reason | Test and independent oracle | Status |
|---|---|---|---|
| EARN-1 | L remains free, or earning it becomes impossible because the chest needs L to reach. High: Marc's acquisition rule or mandatory route is lost. | `marc_earned_map.gd`: normal spawn, real L must remain closed; real SPACE/W/mouse navigation around actual collision bodies and active-current volumes to Control Room; real E/Tween grants one map, no door key; real L then opens. No teleport, wall rotation, current move, map grant or helper reward call. Pathfinding is only the observer's route planner. | Caught free L and stale footer; repaired. Headless and rendered acquisition/return pass. |
| EARN-2 | Saved acquired map disappears, chest resets, or opening a door consumes it. High: progress/reward loss. Existing string item array and separate key count must stay independent. | Round-trip through shared CampaignCheckpoint and actual cold scene; real ready-door E spends one consumable key but preserves map and campaign relics. Old saves without the new field must remain valid. | Characterized after admission: actual Save/Load, old-save migration, map/key/relic separation pass. |
| EARN-3 | Chest animation permits swimming, aim, Tab/abilities/R/map, or resumes after pause with lost/duplicate reward. High: moving camera/reward races. Sibling map handler and currents can bypass a single input guard. | Actual held movement/mouse and real keys during Tween; Escape pauses/resumes; reward arrives once only after resume; snapshot rejected in flight. Six action shapes require invariant coverage, not one preferred key. | Caught movement/Tab/aim/Q/R leakage; both chests × three real capsules/actions/pause/reward pass after repair. |
| EARN-4 | L works outside the maze or advertises an unavailable command; map remains open after leaving its region. Medium: wrong ownership/disorientation. | Actual input in generated inside/outside samples for each diver, visible HUD badge, map closure after crossing the region. Closing remains allowed. | 72 generated boundary/input/badge cases pass. Location fixtures exclude unrelated puppet prompts; no embedded-height ownership claim. |

Self-critique: failure is defined by visible input/ownership/resource results,
not internal helper invocation counts or a copied coordinate formula. The
physical route can fail on an invalid planner/fixture; such errors are excluded,
never counted as product reds. Rendered/native/browser admission remains
separate from collision or key-state tests.

## Skipped / deferred

- Full embedded World geometry, right-side discovery legend and underpass are
  separate admissions. Do not claim they exist from a chest test.
- Developer full-unlock start must not auto-grant the map. Current campaign
  spell diagnostic grants all key items; explicitly exclude this map there.
- Old lever ownership is superseded by Marc's removed Control Room levers.
  Migration must not index removed lever nodes on a cold load.
- Human discovery/readability and full normal-resource campaign completion
  are not proved by an algorithm finding a collision-free route.
- Platform audio, browser storage and Windows/Linux launch need their actual
  artifact/target checks. Native/headless tests are not substitutes.

## Initial analysis evidence

`/tmp/underwater-map-access-probe.log`: 2,401 cells expanded, 38.25m capsule-
clear route from actual normal spawn to dome at Y=2, excluding active currents.
This initial probe was geometry only. It has since been supplemented with
actual acquisition and return, and a real first-channel route after acquisition.

## Bounded receipts and exclusions

- Valid reds: `/tmp/underwater-marc-earned-map-red.log` (free L),
  `/tmp/underwater-marc-earned-map-footer-red.log` (unavailable L taught),
  chest action leakage before the ownership guard. A new acquired popup also
  exposed an untyped Array/typed API script error; fixed with typed pages.
  A printed clean result with that error was rejected.
- Clean earned-map/native receipt:
  `/tmp/underwater-marc-earned-map-actual-plane.log`; final chest, popup and
  overview frames in `/Volumes/Totallynotaharddrive/underwater-marc-earned-map.Ioi09P`
  inspected. Native route uses real inputs and no map grant. This proves a
  feasible route, not effortless human discovery or native performance.
- `/tmp/underwater-marc-chest-solidity-clean.log`: all six chest/actor cases.
  `/tmp/underwater-earned-regression-marc_earned_map_persistence.log`: actual
  isolated-slot save/cold Load/legacy Load and door key separation.
  `/tmp/underwater-marc-earned-map-region-clean.log`: 72 generated boundaries.
- Invalid observers: initial hardcoded chest clearance overstated Musashi's
  measured capsule radius; planner used Y=2 while native SPACE overshot to
  Y≈2.6. Corrected clearance and actual settled-height queries, rather than
  relaxing physical collision. The initial native rise timeout remains
  unaccepted; slow warm-up is a plausible explanation, not established fact.
- Boundary fixtures originally allowed a genuine puppet prompt to move the
  diver after Escape, invalidating the requested outside location. Excluding
  that separately tested prompt and requiring stable positions repairs the
  oracle, not a production region bug.
- A downstream checkpoint test waited at a legitimate QTE Continue screen,
  not completed defeat. Its driver now handles Continue and leaves dodge to
  time out; current seeded recovery runs have no such caption, so that branch
  is not newly claimed verified. Actual loss/Restart/Load still pass.
- Puppet reward's scene-global seed became fragile as procedural rocks consumed
  RNG. Reproduced losses are retained in `/tmp/underwater-earned-puppet-recheck.log`
  and `/tmp/underwater-earned-puppet-boundary-seed.log`. Combat-boundary seed
  64222 wins through 14 real attacks/heals with baseline HP and zero consumables;
  a downed diver stays down. This is an attainable consumer witness, not proof
  every roll or the complete earned campaign is balanced. No combat numbers
  were changed to produce it. After fast-forwarding PR100 e7072ab, actual
  authored-combat, puppet reward, checkpoint, chest, map persistence and
  generated region checks reran clean without script errors:
  `/tmp/underwater-earned-merged-*.log`.
- Browser acquisition, external Control Room discoverability, right legend,
  embedded geometry, full legal-resource route and full polish remain open.
- `menus_spell_title` initially expected every key-kind item in its spell
  sandbox, contradicting Marc's no-developer-map-grant rule. Reconciled the
  oracle to explicitly reject unearned `maze_nav_map` while preserving every
  existing spell prerequisite assertion. This is a stale test expectation,
  not a missing product map reward or an excuse to autogrant the map.
