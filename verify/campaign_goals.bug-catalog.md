# Campaign goal presentation catalog — 2026-10-05

Scope: World route-zone/objective renderer and embedded ownership handoff,
Maze goal renderer/earned map/relic milestones; RouteState and DeepZoneLayout
read end-to-end. These consumers select guidance, not campaign access locks.
Existing deep/local guidance and embedded checkpoint/traversal gates inspected.

## Responsibility/public interface

Display useful next destinations for the active area and earned milestones.
Read valid JSON checkpoint fixtures through World.restore_checkpoint, then
exercise physical area handoff and observe the visible World/Maze HUD. No
private goal-helper assertions, injected victory, or journey-attainability claim.
Load-bearing contract: laboratory victory is optional for maze entry; generic
keys and independent progress survive returns; a relic is not game completion.

## IO and branches

JSON restore/legacy stale objective IDs; physics-position area changes; HUD
visibility and orange-message/modal ownership; learned map/relic state. Branches:
unfinished opening, Shallows/Deep/Maze, uncleared/cleared lab, unavailable/live/
defeated Cordys, missing/earned map, missing/earned relic, stale objective text,
near blockade/loot rock versus regional guidance. Tests generate the independent
lab/map/relic × stale-objective input product rather than five hand-picked cases.

| ID | Failure/blast radius/plausibility | Test | Status |
|---|---|---|---|
| GOAL-1 | Cleared laboratory or early maze/return shows stale lab/relic instructions; players pursue already completed content or miss actual final boss. Current strings use legacy objective and only map, not completion milestones. | Generated restored-state presentation + physical enter/return | Caught 136 failures over 40 cases; repaired locally |
| GOAL-2 | Recovery leaves no laboratory direction and the player wanders without an actionable wider purpose. Existing shallow guidance only says fight. | Normal recovered Shallows presentation with local hint precedence preserved | Caught missing wider direction; repaired locally |
| GOAL-3 | Maze repeats the same map search instruction on status and goal labels. New rendered goal exposed an existing status string with duplicate ownership. | Separate neutral map status and actionable goal over generated cases | Caught visually; repaired locally |
| LAB-1 | Actual laboratory victory never acknowledges computer/controller payoff or suggests the puzzle/maze. Current handler sets enter_maze and silently saves. | Real legal-move Tethys victory, visible payoff, Continue/save/load | Caught actual 12-action win with absent payoff; repaired locally |
| LAB-2 | Payoff popup fits, but stale encounter warnings/gameplay HUD compete behind it. Rendered 360-width native page exposed this despite semantic success. | Actual rendered payoff, hidden HUD and restored HUD on Close | Caught visually; repaired locally |

## Self-critique

GOAL-1 semantic words/destinations, not exact punctuation. Wrong-but-stable E/F
or find-lab text after clearance fails. Concrete input product gives independent
oracles: cleared Deep points to maze ramp; uncleared Deep keeps laboratory and
optional maze direction; no-map Maze points to Control Room; earned relic Maze
points to Cordys rather than finding that relic again. All physical entries keep
lab status unchanged, then return guidance matches that status. Fixtures isolate
guidance, not proof a new player can reach/earn these sites. Failure under a
behavior-preserving goal/helper refactor is not intended. Full earned routes
remain in the subsequent balance batch.

## Skipped

Final opening swap/Cordys film is review-gated. No final narration rewrite,
new dialogue tutorial, boss/key/geometry tuning, compulsory laboratory lock,
new map spoiler, or audio change. Browser/layout and actual lab-result checks
are separate acceptance, not implied by a semantic native matrix.

## Evaluation

- GOAL-1 baseline 40 restored lab/map/relic/stale-objective combinations gave
  136 semantic failures. Revised production consumers pass all 40 plus physical
  area changes, preserving independent lab states and replacing wrong targets.
- GOAL-2 added after GOAL-1 was green: baseline lacked laboratory/deeper-water
  purpose. Local repair passes; legacy local hint tests deliberately now permit
  a contextual *future* laboratory destination while still rejecting stale
  immediate Deep/wall copy. Not a weakened no-goal assertion.
- LAB-1 baseline real 12-action Tethys win showed no payoff. Local one-page
  existing surface passes actual win, Close/resource conservation, fresh World
  Title Load/no repeated popup, exact checkpoint bytes and independent Cordys.
- LAB-2 and GOAL-3 discovered by rendered inspection, not predicted in the first
  semantic test. Actual narrow payoff had gameplay HUD/stale encounter notice;
  early maze duplicated map instructions. Repair gives exclusive payoff HUD
  ownership and separate navigation status. Rendered pages inspected at
  1280/720/360; goal fixtures captured separately, not complete route proof.
- Existing Deep, Shallows, real local puzzle hint and embedded physical ramp/
  floor/aim/party ownership checks pass. No ordinary victory healing added.
- Initial LAB fixture incorrectly matched an all-enemy target by prefix. UI
  witness showed `All enemies\nTethys`; corrected the observer to select that
  actual displayed target. These first fixture failures were not production
  bugs and are not counted as caught lab failures.
- Browser checkpoint durability, complete earned journeys, full suite and
  publication remain pending. No new opening/Cordys film changes included.
