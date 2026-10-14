# Quick tutorial and combat reference bug catalog

Generated October 14, 2026. Scope: short/full tutorial dispatch, Battle/World handoff, inventory lesson selection and shared combat reference. This is not a global combat balance audit.

## Responsibilities and public interface

Battle builds the live fight, presents move/target menus, dispatches real resolution/QTEs and emits its result. World owns the party, save slots, opening milestones, tutorial beacon and inventory replay actions. InventoryMenu supplies Combat Help and optional activities. TutorialContent supplies the explanations. Inputs are visible buttons, hover/pointer, Enter/Space/X, Escape and normal save/load choices.

Load-bearing rules: opening completion is independent of training; practice grants no XP or items; a forced scripted actor advances only its own stage; QTE has its own input/wait state; skip must interrupt every outstanding caption/action wait; paused help must restore its previous pause/focus owner. The latest five-move lesson contains stat/hover teaching and HP floors that must not leak into ordinary combat.

IO boundaries: Godot scene construction/import, animation/tween scheduling, QTE time, disk/browser checkpoints, title/World/maze ownership and Web pointer input. Branches: normal/special/boss/prologue, quick/full, scripted/free actor, target scope, win/loss/skip/flee, current/legacy save, World/embedded maze, prior pause/focus ownership.

## Catalog

| ID | Failure mode | Blast radius and plausibility | Cheapest useful test | Status |
| --- | --- | --- | --- | --- |
| QT1 | Startup still requires all five move lessons and long narration | High; single fixed script supplies every tutorial | Live quick completion with action/QTE count | Reproduced/repaired; native completion passes |
| QT2 | Full lesson is removed or a prose guide is mislabeled interactive | High; selective port can discard older stages | Explicit full choice, real five-move completion | Actual Inventory full completion passes |
| QT3 | Completing/skipping quick lesson launches a mandatory ability carousel | High; current World unconditionally defers first-time popups | Real short result to unpaused World, optional ability button | Short/Skip/initial-loss/optional abilities native checks pass |
| QT4 | Player cannot inspect stat definitions during combat | High; no menu action exists | Real Battle Help button to readable reference | Red retained; rendered six-case matrix passes |
| QT5 | World abilities remain hidden until previously seen | Medium; inventory button has seen-state guard | Inventory choices on a fresh recovered run | Explicit optional ability action/camera handoff passes |
| QT6 | Practice heals earned party or saves its transient resources | High; replay and finish mutate real resources | Earned-party resource/save round trip for each outcome | Quick/full entry, Skip, win/item, actual loss/Retry/Exit pass |
| QT7 | Reference clips at narrow width or unpauses its parent incorrectly | High; existing TutorialBook fixed 560px and unconditional unpause | Generated viewport/paused-owner decision table and Escape | Responsive reference passes; native screenshots inspected |
| QT8 | Definitions describe obsolete math/costs | Medium; shared text predates newer formulas and Sonar | Contract examples plus content review against real rules | Exposed definitions updated; Sonar stale-cost suspicion retracted |
| QT9 | Shortened lesson skips live timing dodge or stalls after success/timeout | High; script length and enemy counter share finale conditions | Actual QTE success and natural timeout through real result | Both outcomes pass; Full QTE retained/rendered |
| QT10 | Mid-step skip revives stale menus or leaves waiting coroutines | High; hover/caption/QTE await unrelated signals | Skip decision table at each actual input state | 274 World/288 maze checks pass with original-effect markers; initial Retry classification repaired |
| QT11 | New state causes cold Load to replay videos or force full training | High; existing milestone migrations already regressed | Real serialized save/load with opening/training states | Native processes pass completion/Skip/legacy downed/fidelity; earned browser manual checkpoint reload also passes |

## Test design and self critique

`quick_tutorial.gd`: begin with QT4, activating a real Battle button, checking visible rendered reference and closing via actual Escape. Compare actor, queue, HP/O2 and pause state before/after. Inventory opens its real Help tab and exposes the same seven stat concepts. Generate viewports and prior pause states (>5 combinations), assert visible controls stay in viewport and content is scrollable. Semantic assertions catch wrong-but-stable UI; internal callback counts are not the oracle. Button names aid lookup but observable Help text, visibility, action result and actor resources are the contract.

Then add one test at a time for QT1/QT9, QT2, QT3/QT5, QT6/QT11 and QT10. Each first failing run is retained. A fixture that sets saved milestones is not proof of earned progression; a replay that emits `won` is not proof of successful combat. Capture real completion separately.

## Skipped

- Global battle balance, final boss win path, enemy animations and maze redesign: out of this tutorial/help request.
- Original free-swim Angler/victory bridge: current main intentionally removed them in PR 102.
- Fixing every historical glossary sentence unrelated to exposed mechanics: only update demonstrably stale shared contracts; keep broader review visible.
- Pixel snapshots as sole acceptance: semantic/input tests and visual inspection are required.

## Post write evaluation

QT4 was caught against main (absent Battle Help). QT7 was caught during implementation (Close below the viewport from stale wrapped-text minimum size). QT1 was caught against the original >100-word caption. QT6 was caught against optional entry mutating all three earned party members' HP/O2. Focused headless reference/quick/practice tests and rendered reference tests now pass. Full lesson's real five-stage victory passed. These are bounded component/scene checks, not hosted-browser or full campaign acceptance. Remaining matrix cases stay pending.

## Expanded wave findings

QT15: the real browser's completed starter manual checkpoint contained Bleed 2 and spent Evasion, while live post-free stats and a later autosave were clean. `manual-checkpoint-effects-red.log` reproduced the write/destructor race with real missed-dodge input. Existing Battle cleanup is now idempotently invoked before World result serialization; practice cleanup happens while its stats are still temporary, before restoring original members. Saved/cold-loaded stats are now checked alongside route/control flags. **Do not globally erase effects from older valid saves:** `embedded_maze_checkpoint.gd` explicitly requires full resource/status fidelity. A trial blanket-load normalization was removed before commit; preserve its diagnostic logs as a rejected approach, not accepted evidence. New cold-preparation and old-resource fidelity cases join the focused gate.

QT14: real browser Help worked in the prologue, but the guided starter's own caption mentioned Help while hiding its containing main menu. Reproduced by `quick_combat_lesson.gd --help-steps` at its live instruction. Help now has a persistent tutorial action beside Skip, with H access and no focused-button Enter trap. Reference open/Escape must preserve step, narration wait, actor, queue and HP/O2/EVA. Disable it during live QTE/attack rather than pausing an action partway. Native help-phase and compact rendered checks pass; keyboard H/Enter and final-source regression/browser confirmation remain separate checks.

QT12: a fixed-width result popup put Retry/Exit offscreen at 360x480; repaired responsive popup passes 64 rendered/action checks. QT13: a functional short lesson initially collapsed the 3D stage to zero at 360x640; compact caption/menu/status presentation now passes wide/narrow actual-action captures. The implementation resize loop was caught and fixed, not masked with a higher memory limit. Native screenshots were visually inspected.

QT16 preventive oracle: inspection raised a possible mismatch between the Full Precise Tap caption's green Accuracy explanation and its highlighted preview. An actual rendered five-stage run confirms the ACC value uses `STAT_COLOR_UP`; the suspected defect is retracted, not recorded as a repaired failure. `tutorial_win_handoff.gd` now asserts that color during the real caption so a future neutral preview cannot pass on text/geometry alone.

Final-source fresh browser opening/short completion, earned IndexedDB manual-checkpoint inspection, cold manual Load, optional choices/Skip, shared Help and narrow scrolling have passed. The final scoped visual round has no additional observed tutorial/help defect. A full browser Full victory and full campaign acceptance remain unverified. Detailed evidence and retained background-document pointer-lock rejections are documented in docs/quick-tutorial-overnight-plan.md. Special-encounter replay is outside the new quick/full resource-isolation claim.
