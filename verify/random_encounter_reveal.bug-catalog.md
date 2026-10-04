# Random encounter reveal contract

2026-10-04. Scope: the ordinary distance-roll signal after prologue recovery,
world presentation, and its handoff to the existing combat system.

## Module / boundaries

`Diver.encounter_triggered` is the production event. World first rejects
ineligible actors, encounters-Off, unfinished prologue and protected Deep
spaces; mapped item sites retain priority. Ordinary pack size uses Battle's
level policy and species use EnemyRoster's separate presentation RNG. Actor
identity is Goblin's `enemy_id()` contract. Combat stats/rewards remain Battle's.
The reveal owns only transient actors and elapsed real time, never save data.
Title, successful checkpoint restoration, another encounter and teardown must
cancel it. Camera/frustum and environment physics are real external boundaries.

## Bugs and tests

| ID | Failure / impact | Why plausible | Verification |
|---|---|---|---|
| REVEAL-01 | Combat replaces exploration with no warning or world enemy. | World directly constructs Battle on the signal. | Public signal: actual rendered-world actors for at least one second, no Battle yet, then exactly one Battle. |
| REVEAL-02 | Preview species/count disagree with the fight. | Battle previously rolled independently during stage construction. | Differential identity/order comparison against actual Battle actors; formation properties across levels and rosters. |
| REVEAL-03 | Duplicate signals stack previews/fights or input/stat timers continue. | A transition adds a window before `battling`. | Repeated signal; frozen position/HP/O2 and unchanged encounter preference; one handoff. |
| REVEAL-04 | Fish clip off-screen, into terrain, or behind the camera. | Long Shark mesh, narrow view and arbitrary camera orientation. | Actual visual-bounds/frustum and collision properties over camera/roster/viewport variations, plus rendered wide/narrow inspection. |
| REVEAL-05 | A retired preview starts combat after title/load. | Delayed callbacks survive an interrupted flow. | Cancel through title, wait beyond duration, assert no fight; successful load cancellation. |
| REVEAL-06 | Opening/tutorial/site/boss flows acquire an unintended reveal. | All fights share World entry points. | Existing prologue, tutorial and guardian gates; encounters-Off/unfinished-prologue negatives. |

These assertions distinguish wrong-but-stable output (missing actor, wrong
identity, stacked fight, clipped bounds) from legitimate internal refactors.
Public signal and displayed actors are the primary oracle, not helper call counts.

## Skipped / limits

- No encounter-rate, balance, story or spawn-table redesign.
- No reveal for authored guardians, special minigames or scripted opening bosses.
- World geometry properties do not substitute for checking actual rendered lighting,
  occlusion by divers and animation silhouettes. Human visual audit is required.
- A fixture emitting the production signal proves dispatch, not natural swim RNG;
  a separate player/browser check must cover natural triggering.

## Evaluation

Pending red/green runs and visual audit. Do not claim complete from headless alone.
