# Quick tutorial integration and morning review

## Purpose and deadline

Prepare a review PR by October 14, 2026, 11:00 a.m. America/Chicago. A playtester declined to play because the tutorial was too long. Miguel authorized a short tutorial based on the earlier review, the longer tutorial as an optional activity, and explanations of battle stats from both battle and inventory menus. Do not merge or promote to canonical production.

Worktree: `/Users/tomriddle1/underwatergame-quick-tutorial-oct14`.
Branch: `feature/quick-tutorial-oct14`.
Starting main: `2e183cc` (PR 102 merged).
PR 101 inspected head: `cbac7813a1451ef97ef038fd902a9dda8eb3ae04`.
Local combined integration commit: `2b65b82` (tutorial implementation `cbc9e84` plus PR 101). Main and PR 101 remain unmerged by this work.
Hourly thread follow-up: `tutorial-integration-review-overnight`, expires at the deadline.

The old blocked campaign goal and its historical attachment are not the objective for this new request. Do not resume the old global campaign integration or re-open its settled design questions.

## Source findings and current decisions

Current main is not the October 5 version. PR 102 deliberately removed the free-swim Angler prologue and victory bridge. The current opening is opening video, octopus cinematic, Cordys, recovery, then a mandatory beam-led combat lesson. Preserve this latest opening. Do not restore the older Angler prologue or substitute Tethys without new direction.

Main's combat lesson scripts five moves and includes multiple long explanatory waits, a forced timing dodge, a real-fight finale, and a subsequent ability-video carousel. Inventory already has a stat glossary and tutorial replay, but the replay is the same long lesson and ability help is hidden until previously seen. Battle has move tooltips but no direct stat-reference action. PR 101 supplies a reviewed compact exploration HUD, not a tutorial repair.

PR 88 has a useful separation between a short opening profile and optional five-move interactive training. Port the idea selectively, not its older Battle/World files, encounter balance, storyline, geometry or rendering. Preserve Marc's newer skips, combat presentation, spell math, content, map and progression.

Provisional implementation contract, grounded in the earlier approved short lesson:

- Normal combat training teaches one actual Electric Touch choice, a visible target/damage preview, and one actual timing dodge. Keep prose short and attached to the current task. Use normal combat resolution, not fixed fake damage or guaranteed wins represented as normal combat.
- Finish the short practice after those taught actions with a brief explicit Continue/Return to World action. Do not require five scripted moves, a prolonged grind or the ability-video carousel before normal play.
- Retain a persistent visible Skip/Exit action during the lesson. Completing or exiting it releases normal gameplay; optional instruction remains reachable.
- Offer clearly distinguished **Quick Combat Practice**, **Full Combat Lesson**, and **World Abilities** in Inventory > Combat Help. Full Combat Lesson retains the genuine interactive five-move script. Do not replace it with a prose guide and claim it is playable.
- Offer **Combat Help** from the battle action surface. Open a concise, scrollable reference for HP, O2, Strength, Defense, Agility, Accuracy and Evasion, plus existing effect/status explanations. Inventory uses the same text source.
- Reading help must not consume a turn, change a target, advance enemy attacks or QTE timing, lose menu focus, unpause an already paused owner, or capture controls intended for the modal.
- Existing tutorial/special-encounter practice does not grant actual site items, XP or campaign progress. Replays should not overwrite a real checkpoint with an in-progress battle or accidentally heal/change earned party resources. Record existing replay behavior before choosing the smallest safe repair.
- Keep opening completion separate from tutorial completion. Old completed saves stay completed. Saves created during/after recovery and short practice load into a coherent world without replaying videos/Cordys. Any new completion state requires a migration default and cold-load tests.
- Keep Sonar/encounter defaults, current map, strong-room encounter policy, lab/maze routes, items, authored bosses and real combat rules unchanged.
- Use user-facing text without em dashes. Do not cram paragraphs into the queue bar or hide names. No required hover-only discovery for touch/keyboard users.

## Storage safety

Check `df -k /Users/tomriddle1` before imports, downloads, exports, and every continuation, plus after each large operation. Stop all work immediately below 3 GB free (conservatively 3 GiB). Do not delete user files, caches, old builds or unrelated work to continue. Report the safety condition and suspend further scheduled work until Miguel resolves it. Do not launch an operation whose expected footprint would cross the floor. Reuse installed Godot/templates; avoid new asset copies, new native packages, redundant browser downloads and unrestricted full-suite artifacts.

Initial check: 9,494,144 KiB available; after the isolated checkout: 8,853,100 KiB available. RAM and disk are distinct; this is the requested disk-space safety guard.

## Work phases and gates

1. **Intake and preserved baseline.** Read relevant tutorial content, Battle dispatch/skip/QTE/reward logic, World save/replay/recovery contracts, and current tests. Compare PR 88 concepts and PR 101 changes to main. Record upstream SHAs and a semantic integration matrix. No wholesale file replacements.
2. **Defect catalog and tests.** Pin real failures before repairs where feasible. Use actual scene actions/signals and normal resolution; injected win/loss results may test only result plumbing, never prove playable completion. New tests must be named by the bug they catch and join the accepting gate.
3. **Short and full profile implementation.** Keep all five stages reachable only by explicit full-lesson selection; make starter text succinct. Demonstrate short completion, QTE success/failure, skip at every caption/action, retry/loss exit and re-entry. Check input and lifecycle under real rendering.
4. **Shared stat reference.** Definitions must match CombatRules and CombatantStats, including formula-based damage, strict ACC > current EVA, spent/refilled EVA, AGI re-sorting, O2 costs and downed recovery. Verify both real entry points, scrolling, close/Escape/focus, and return to the same actor/menu without a turn advancing.
5. **Integration and regression.** Preserve PR 101's newer GUI or explicitly document its independent status. Test saves, opening handoff, inventory/maze ownership, tutorial resource/reward isolation and current main's regressions. Re-fetch immediately before pushing; reconcile relevant Marc changes without silently overwriting them.
6. **Review preview and final audit.** Fresh import/export, public preview accessible without authentication, exact-source build metadata and served PCK hash. Give normal New Game and directly usable quick/full/help review instructions. Do not substitute test flags for normal reachability. Repeat a fresh complete scoped visual/play/input audit after fixes until one round has no observed defects. Report remaining limitations honestly. Deliver PR, preview, source, evidence and outstanding approval choices before the deadline, even if incomplete.

## Verification matrix

| Flow | Required observable result |
| --- | --- |
| Fresh normal run | Current opening preserved; short lesson does not invoke five-move lecture or mandatory carousel |
| Quick practice | Actual attack/target preview and one live dodge; clean completion in a bounded number of interactions |
| Full lesson | All five intended moves and their live explanations remain accessible and completable |
| Skip during captions/hover/target/QTE | No waiting coroutine reopens UI, no deadlock, no stray rewards or leftover actors |
| Dodge success and natural timeout | Both resolve, completion possible in either case; no perfect-input assumption |
| Completed opening + training save and cold load | No replay of opening/Cordys; no permanently locked controls |
| Existing save, incomplete training, skip, replay | Appropriate state migration; replay is optional and repeatable |
| Battle reference open/close | Same actor, HP/O2/EVA, queue and selected action; no timer advance; Escape restores correct owner |
| Inventory reference and optional lesson selection | Buttons usable from normal world and supported embedded maze; no hidden prerequisite |
| Wide and narrow rendering | 1280x720, 720x480, 360x640; all text/controls readable, no clipped names or offscreen Close/Skip |
| Deployment | Latest reviewed source, fresh export, exact hosted PCK, normal-browser input and storage checks |

Human readability and emotional engagement remain human acceptance, not outcomes proved by green tests.

## Defect and evidence ledger

| ID | Finding | Status | Next action |
| --- | --- | --- | --- |
| QT1 | Original startup invoked the full five-move script and long captions | Reproduced and repaired; actual quick/beam checks pass | Browser interaction/readability audit |
| QT2 | Short/full lesson distinction from PR 88 was absent | Restored; actual full five-stage victory passes | Explicit Inventory full selection/return |
| QT3 | First normal tutorial completion automatically opened ability carousel | Removed for short; real beam release passes | Cold Load and normal-browser confirmation |
| QT4 | No direct battle-menu stat reference | Repaired; rendered ownership checks pass | Real browser Help interaction |
| QT5 | Ability replay hidden until previously seen | Source guard removed | Fresh World/maze Inventory choice tests |
| QT6 | Tutorial replay healed the actual party and wrote a save after practice | Reproduced; temporary resource transaction passes entry/Skip | Win/loss/item/save/maze expanded matrix |
| QT7 | Existing TutorialBook has fixed 560px width and unconditional unpause | Battle uses a separate responsive owner; clipping defect caught/repaired | Fresh complete visual-audit round |
| QT8 | Historical glossary treats all damage as base power plus Strength; O2 lacks its own stat entry | Repaired shared text; readability audit pending | Compare exposed text with runtime rules |

Initial runtime progress (02:16 a.m. Chicago): missing Battle stat Help reproduced in `reference-red.log`; a real >100-word starter caption reproduced in `lesson-red.log`. Headless and rendered reference checks pass at 1280x720, 720x480 and 360x640, including prior pause ownership, Escape and unchanged queue/resources. A first layout repair was required after `reference-layout-failure.log` exposed Close beyond the viewport. The starter completes one real attack and one QTE with three brief confirmations, including natural missed-dodge timeout. The full lesson completes all five actual stages and a real enemy defeat (`full-lesson.log`).

Optional practice initially changed all three earned divers' HP/O2 (`practice-red.log`). A temporary party-resource/inventory transaction now passes normal quick-practice entry/Skip without changing those earned resources (`practice-green.log`). Win/loss/item consumption, cold saves and embedded-maze practice still require expanded coverage. The separate full-lesson Battle test does not prove Inventory/World replay handoff.

Sonar-cost text was rechecked: main's 3 O2 per 3 seconds matches the current Diver constants, so the earlier suspected stale-cost claim is retracted; do not change gameplay billing in this PR.

No Web export, hosted browser acceptance or complete clean visual-audit round is claimed yet. Current implementation is a draft. Append dated source-specific evidence and failed checks here. A phase cannot be declared accepted while its required flow has an unresolved defect.

Combined-source checkpoints: `34a3eb5` includes main `2e183cc`, PR 101 `cbac781`, and tutorial code `cbc9e84`. `hud-integrated.log` passes 4,646 rendered checks. `combined-quick.log`, `combined-reference.log`, and `combined-practice.log` pass on the combined source. `normal-beam-handoff.log` enters the actual beacon via W swimming, resolves real attack/QTE input, returns to movable World without a mandatory carousel, and checks the stored opening/tutorial milestones. This is not yet a cold-reload or full fresh-opening test.

Draft review PR: https://github.com/Mhanna112-code/UnderwaterGame/pull/103. It is not ready to merge. Any automatically generated preview of repository `docs/` must be treated as stale until this task explicitly publishes a fresh identified Web export.

## Next continuation

Start with the completed/pending `hud-integrated.log` and re-run quick/reference/isolation on the combined source. Expand practice outcomes and old-save/normal-beam paths. Retained legacy tutorial verifiers sometimes implicitly expect the long script or mandatory ability carousel; explicitly select Full for long-script tests, or replace only obsolete starter expectations with stronger real short-route assertions. In particular, audit `tutorial_qte.gd`, `tutorial_camera_handoff.gd` and loss/exit tests rather than hiding their failures.

Then retain wide/narrow actual rendered captures, visually inspect them, export only once the critical handoff/persistence/input paths are accepted, and publish an identified review-only Vercel preview. Read the relevant deployment/verification skills before deploying. Do not publish any existing `docs/` Web bundle as if it contains these changes. The old campaign goal is still separate; the active overnight continuation is this saved plan and thread heartbeat.

## Handoff rule

At completion or the deadline, report the actual PR and exact-source preview, what passed, what failed, what remains untested, and remaining free space. Keep the PR unmerged for Miguel/Marc review. Stop after a storage safety condition instead of continuing to consume space.
