# Essential World guidance restoration

Miguel explicitly authorized restoration and merging PR 103 on October 14.
These prompts are essential: without an instruction at the relevant location or
moment, a new player cannot know what action to take or when to take it. Keep
the current Shallows fallback objective; nearby intact reward rocks override it.
Do not modify any maze source, maze guidance, maze rules or maze test contract.

## Boundary and responsibilities

World owns the active diver, route milestones, live breakables, visible objective
panel, R setting and Battle result handoff. CrackedWall reacts to real F
Shockwave and emits consumption before deferred deletion. The escape cue is
information only, owns a three-second absolute timer and must never toggle
encounters or change party resources. Battle's real Run roll supplies `fled`.

Public actions are W movement, Tab switching, F Shockwave, R toggle, Run and
normal Title Load. Observable outputs are the visible instructions, reward and
consumed state, current encounter setting and the cue disappearing on time.
IO boundaries are scene/physics frames, RNG, timers, owned disposable saves and
native/Web rendering. The separate QA user directory is mandatory for tests.
Route state literals come from RouteState; `entrance_blockade`, `rock_` IDs and
ambush exclusions come from World's authored breakable construction.

Branches: incomplete opening/training; Deep versus Shallows; active/inactive
diver; nearby/far/high/scenery/ambush/intact/consumed rock; ordinary objective
versus local wall/loot instruction; successful/failed Run; setting On/Off;
menu pause, new battle and cold Load.

## Catalog and test design

| ID | Failure and impact | Cheapest effective oracle | Status |
| --- | --- | --- | --- |
| RESTORE-1 | Blockade omits Bucky/Tab/F/Shockwave, stranding a new player | Existing real World contact/leave/return, Tab/F destruction and consumed-state Load; semantic caption assertions | Red reproduced; green and rendered pass |
| RESTORE-2 | Nearby reward rock has no action/reward explanation, or generic Shallows goal hides it | Actual W approach; 36 generated proximity samples across first three rocks; Tab/F reward/Load; negative distant/high/ambush and fallback cases | Red reproduced; extended green and three-size rendered pass |
| RESTORE-3 | Run never teaches R, or cue persists indefinitely/forces Off | Actual encounter + real Run with seeded probability, visible R instruction, untouched On expiry, failed Run negative; real R update without timer reset | Red reproduced; expanded real-action green |
| RESTORE-4 | Restored captions clip or compete with current HUD | Render 1280x720, 720x480 and 360x640; bounds plus inspected frames, not snapshots alone | Initial narrow cue obscured by minimap; placement repaired; all three final sizes pass and are visually inspected |

Self-critique: exact punctuation is not the contract; named keys, action, reward
and timer semantics are. Generic but stable text fails. Tests exercise actions
and scene ownership, not a copied helper condition. Seeded spatial samples test
a class of proximity states. A saved completed opening is explicitly a focused
fixture, not proof of earning the opening. Existing tests asserting absence of
these three prompts must be replaced, not left to prohibit approved behavior.

## Skipped

- Maze destination/sonar/hallway/save-point changes: explicitly forbidden.
- New Shallows wording, balance, geometry, opening story and friendly fire:
  outside this restoration.
- Whole campaign/browser Full-lesson victory: earlier limits still apply.

## Evaluation

Retain red/green and rendered receipts under the October 14 evidence folder.
Record actual failures and any fixture/harness limitation separately. No main
merge until relevant restored actions and existing tutorial/save gates pass.

The first blockade red also exposed a stale fixture: loading a completed save
over a still-running interrupted-opening cinematic falsely left F locked. A
fresh World followed by normal completed Title Load isolates that scenario;
the original missing-caption failures are retained, not erased as fixture noise.
The rock test now pins the same valid Load boundary. Native images and test
inputs are focused completed-opening fixtures, not a fresh browser playthrough.
The prior tutorial/browser receipts still apply to their identified source;
this source-only restoration has not been exported. Miguel requested that the
auto-build agent handle the public Web build after the merge.

The complete isolated tutorial/save regression runner finished with exit 0 on
restoration source `5bf6f19`. The retained log includes success/timeout/Help,
real skip/completion/items/loss/Retry/Exit, embedded practice, four separate
prepare/cold Load pairs, normal beam handoff, full curriculum and ability return.
No maze source, guidance or test oracle was edited by this restoration; existing
embedded checks were rerun unchanged as integration regression coverage.

Final headless escape regression additionally observes the On cue actually
changing contrast, no duplicate objective/badge during it, and normal objective
and encounter status returning after expiry. Actual R updates the cue without
resetting its deadline; failed Run does not produce it. These are native real
scene/action checks, not browser-pointer or complete-campaign acceptance.
