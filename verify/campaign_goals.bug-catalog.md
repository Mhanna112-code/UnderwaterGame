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
| GOAL-4 | Restoring the destination also restores retired control hints or draws a goal through notices, map lessons/overview, Inventory or grapple aim. | Actual R/Escape/L/Tab/F UI-owner transitions plus unchanged milestone text | Corrected fixture/native and rendered owners pass; exported browser pending |
| GOAL-5 | The longer aim/swap title forces the control column beyond a narrow viewport, clipping the fire/cancel instructions. | Actual F aim and control-column viewport containment at 360px, rendered inspection | Native red one finding; final separated action lines/rendered 360px green; exported browser pending |
| GOAL-6 | The public diagnostic maze entrance has no destination because it correctly bypasses the opening without earning its completion flag. | Actual --maze-playtest startup: visible Control Room goal, no fabricated opening/lab/map milestones; exported browser entrance | Exact browser screenshot and native red; native repaired flag route/non-mutating guidance green; new export pending |
| GOAL-8 | Retained World HP/Oxygen covers the maze destination, hiding the next target (including Cordys). | Actual earned-map browser OCR and generated-state viewport/visible-bar rectangle invariants at desktop, short-landscape and narrow sizes | Browser red; original native short layout gives 120 overlap findings; local repair verification in progress |
| GOAL-9 | World health bars draw above embedded Inventory, obscuring its title, tabs and body although the maze goal correctly yields. | Actual Escape reading-owner transition must hide shared exploration health, then restore it on close; earned-map browser title/tabs are independently readable | Actual browser screenshot reproduced; native red1 -> green0; matching export acceptance pending |
| LAB-1 | Actual laboratory victory never acknowledges computer/controller payoff or suggests the puzzle/maze. Current handler sets enter_maze and silently saves. | Real legal-move Tethys victory, visible payoff, Continue/save/load | Caught actual 12-action win with absent payoff; repaired locally |
| LAB-2 | Payoff popup fits, but stale encounter warnings/gameplay HUD compete behind it. Rendered 360-width native page exposed this despite semantic success. | Actual rendered payoff, hidden HUD and restored HUD on Close | Caught visually; repaired locally |
| LAB-3 | World pauses the laboratory-arrival announcement during battle/payoff and replays it after actual victory. It falsely announces a new Tethys arrival when Close restores HUD. | Actual legal-move victory → Close → no obsolete boss-arrival notice | Browser visual witness, native red one finding → local repair green |

## Self-critique

GOAL-8 checks actual visible HP/Oxygen bands and visible party rows, not their
parent's unused allocation. At 360x640 the VBox retains a 286px three-row
allocation although the active member's row is hidden: the two visible rows
end at y396, not y496. The initial narrow observer falsely counted that blank
space as painted content; raw bounds are retained. Bottom-band overlap was
independently witnessed in the browser screenshot and remains a strict
assertion. Changing the layout without hiding destinations or moving painted
content over them should pass. Earned-map browser screenshots are required
separately; this fixture matrix does not establish route balance.

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
- LAB-3 browser visual inspection exposed an obsolete arrival after Close.
  Native added assertion reproduced exactly one failure; laboratory combat
  already owns its arrival log, so no World FIFO arrival is queued for this
  encounter. Other pending exploration announcements and reference boss
  behavior remain unchanged. Actual 12-action native win/Close/cold Load is
  green; matching exported/hosted recheck is still required.

Fresh f457098 regression: all40 existing GOAL-1 cases fail because the maze
always hides both Controls and GoalLabel. The local repair restores only the
milestone-aware destination, not retired generic controls/status notes or the
E/F suffix. Map/modal/announcement/aim remain exclusive owners. The old red
receipt is retained in `docs/evidence/main-intake-f457098/campaign-goals.log`.
Native/rendered/exported acceptance and publication of this repair are not
implied by the historical successful batch above.

GOAL-4 self-critique: only visibility/text outcomes and actual public controls
are asserted, not private visibility-helper calls. Wrong-but-stable hidden
goal fails before input; always-visible goal fails each reading owner; generic
Controls or E/F suffix restoration fails even when destination words are right.
All-actors-inside-maze/map fixtures isolate caption ownership and avoid falsely
claiming earned acquisition or traversal. The state product remains generated
by GOAL-1, while this new sequence probes the cross-feature ownership boundary.

GOAL-4 observer corrections: the initial ownership fixture at the maze boundary
was outside the earned-map navigation region, and Tab legitimately queues a
four-second 'Now playing' notice. Actual L rejection and hidden destination
through that notice were correct production behavior, not three new bugs.
The corrected fixture uses the authored DiverEntry and waits for the genuine
switch notice to drain; all 40 cases and actual owner transitions pass.

GOAL-5 asserts actual instruction-column bounds, not a private wrapping call
or exact line breaks. A stable clipped title fails; changing the layout while
keeping it readable should pass. Full map acquisition remains separate from
the native caption fixture. The browser check earns its map with swimming/E.
