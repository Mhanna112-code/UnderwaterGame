# Cordys: individual opening defeats

## Module and public contract

Battle's reveal and normal Attack/move/target buttons own the encounter. The
shared CombatRules resolver owns ACC/EVA, STR/DEF, HP and effects. The production
PrologueOctopus adapter owns imported clips, scale, facing and fixed framing.
World listens only for the final `prologue_defeat`, then runs the existing
aftermath/recovery/save path. No intermediate death can finish or save the opener.

Current `_resolve_prologue_finisher` applies one Poison Breath to every living
party entry in one loop. All three HP values change in the same rendered frame.
The repair is three targeted strikes with individual animation/impact/reaction
and a readable interval, not staggered display over already-zeroed HP.

IO: authored animation timers, audio event owner, viewport/camera, final World
signal and later checkpoint. Branches: living/dead target, normal hit/Evasion
miss, damage/nonlethal, full wipe/survivors, genuine clips/fallback. Player moves
and statuses remain normal; high-stat diagnostic survivors must not be killed
to force the desired presentation. Boss status end-turn ticks once per response.

## Catalog and test mapping

| ID | Failure / blast radius | Why plausible | Cheapest meaningful gate |
| --- | --- | --- | --- |
| SOLO-001 | Three divers lose HP/die together, even if their fades are staggered | High: current all-target loop bypasses the requested individual reversal | Actual move-button response, per-render-frame HP changes; exactly three single-target changes and living counts 2/1/0 |
| SOLO-002 | Defeat is emitted after the first/second death or dead targets are hit again | High: World restores HP early or stalls | Same real sequence: sole final outcome only at zero living; no result at first/second death |
| SOLO-003 | Different labels disguise one reused/static clip, or attack clips clip outside the camera | Medium: semantic clip adapter/framing only admits old Poison Breath | Actual animation at each impact, three distinct deforming imported clips; live skin projection wide/narrow and rendered GIF |
| SOLO-004 | Damage becomes unconditional HP-zero, party-wide status or accuracy bypass | High: prior opening stat regressions | Existing high-HP and real-button differential/generator matrix; high-Evasion / high-DEF witnesses; untargeted HP/status unchanged |
| SOLO-005 | Separate strikes duplicate impact SFX, leak input or leave old active actor/controls | Medium: busy latch and same Battle survive the scene | Real click during response, sound trace one per resolved impact; target named and correct current actor; rendered views |
| SOLO-006 | Slower deaths break full opening pace or checkpoint recovery | High: multiple full clips replace one attack | Native full journey and full exported browser New Game, ordered strikes, normal final recovery/cold Load; retain two-minute goal |
| SOLO-007 | Cordys chains kills without intervening player choices | High: first draft chained three hits | Actual button choices from Maxilani, Musashi, Bucky; hold next menu for one second and assert no additional attack/HP change until input |

Self-critique: per-frame real HP, living counts, clips and final result reject a
cosmetically staggered AoE. No injected defeat or forced HP-zero proves this
sequence. High-HP/Evasion/DEF inputs are explicit diagnostic fixtures, not a
claim that the normal starting party can win. Existing bounded generated move
matrix remains the independent normal-rule differential oracle. The state
milestone matrix covers persistence; no additional durable death phases needed.

## Skipped / preserved

- User clarification: each remaining diver gets a real attack between Cordys's
  single-target responses. No automatic chain wipe, added QTE or training gate.
  Normal boss turn statuses tick once per actual response. Three starting divers
  mean three player choices and three boss turns, not one turn split cosmetically.
- Campaign bosses, ordinary encounters, Angler balance, cutscene duration,
  optional training, navigation and main URL: unchanged.
- New meshes, invented attack VFX or music: use the delivered clips and existing
  stat-result feedback/audio. Subjective pacing is inspected, not inferred from
  green structural import tests.

## Evaluation

Original red: all three HP values changed in one frame. First draft red after
user clarification: one player choice followed by an automatic three-hit wipe.
The corrected sequence returns real move/target menus after each surviving
turn; a one-second held decision cannot cause the next response.

Visual defects observed during iteration: combined new-clip hull made Cordys
miniature; sparse 19-point temporal samples missed Octo Stab's fast extreme.
Repair: offline 61-sample per-clip hull, fixed view per attack beat and normal
player-turn view, independently checked against live skin and target facings.
No frame-by-frame zoom or weakening the readability gate.

Final native wide/narrow renders and all target-facing moving-skin projections
pass; no new response defect observed in the bounded visual round. Exported
normal-entry Chromium/Metal proves three actual mouse-driven player attacks,
three separate stat-based deaths and cold title Load without opener replay.
Full wall time 119.376s; engaged 117.371s excludes only the measured 2.005s
deliberate no-input probes. The original cap is retained, movies and player turns
are unchanged. First timing-accounting failure and both earlier gameplay reds
remain in `docs/evidence/cordys-individual-turns/`; no result is rewritten.
