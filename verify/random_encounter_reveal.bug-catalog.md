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

- REVEAL-01 failed against the previous direct-to-Battle implementation; the
  real signal/reveal/identity/freeze/duplicate handoff now passes.
- REVEAL-02: 32 real Battles across four party levels preserve selected identity
  and count, with the existing level-one/two/later formation bands unchanged.
- REVEAL-03/05: duplicate signal, title retirement, actual checkpoint Load and
  teardown during a pending reveal pass without stat/pause/preference leaks.
- REVEAL-04: a camera on the entrance-blockade face exposed hidden/intersecting
  previews. Preserved red log; temporary clear-camera origin, silhouette sight
  lines and proportional foreground travel fix it. Ninety formations across
  wide/narrow viewports, three camera pitches/yaws, open/low-floor/wall-side
  origins and five rosters pass at three actual animation samples each.
- Native wide/narrow render inspection exposed a face-only Shark silhouette;
  the admitted three-quarter angle now exposes its body. Capture fixtures with
  a manually resized viewport have stale unrelated world HUD layout; the real
  narrow World entry separately checks the actual compact HUD/reveal surface.
- Existing guardian exclusion, all site dispatches, normal-stat prologue combat,
  player turns between individual Cordys defeats, tutorial win handoff and
  invalid-checkpoint recovery pass. No entry path was redesigned.
- Browser verification is separate from these fixture gates: natural swimming
  and the complete ordinary opening are required before refreshing the alias.
  Initial existing bridge assertion used delayed Node console receipt times
  while synchronous OCR was running; preserved failed recording and switched
  to read-only browser-source timing, not wider game timing tolerances.
- Final affected browser contract: Frilled Shark (1646ms) and Swordfish
  (1839ms), matching actual battle HUD and usable controls, no runtime errors.
  Separate full-opening timing overruns (120.991s / 134.803s engaged) remain
  explicitly OPEN. A later escape assertion demanded already-expired text;
  the retained HUD shows R correctly Off. No gameplay timer was lengthened.
