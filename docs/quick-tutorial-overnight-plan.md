# Quick tutorial integration and morning review

## Current status (morning review candidate)

Draft PR [#103](https://github.com/Mhanna112-code/UnderwaterGame/pull/103), gameplay/export source `bda7ff68634d1a4557e7849538d9e599f61530f4`. Fresh [playtest](https://underwatergame-pr103-quick-tutorial.vercel.app/) and [review guide](https://underwatergame-pr103-quick-tutorial.vercel.app/review.html) are reachable anonymously. Hosted PCK SHA256 `606dd91965fb5b02d8a42530aedcd6cf870211fb44fe49f2337ae46d1509c99b` matches the local export (126,226,636 bytes). Canonical production and main are unchanged.

Four combined focused native rounds passed. Final-source legacy downed-party cold preparation and separate-process Load also passed. Individual real-action skips, actual Quick/Full completion and temporary item use, adversarial damage-driven loss/Retry/Exit, embedded-maze return, separate-process native cold Load, shared stat-reference ownership and optional ability camera return have passed. Rendered inspection caught and repaired additional compact-layout failures; final compact Full captures passed, with highlighted numeric teaching retained in scrollable pages.

Final-source **fresh browser New Game** completed in isolated session `uw-tutorial103-final`: real videos, three alternating party actions/Cordys strikes, recovery, W movement into the beam, short attack/target preview, live dodge naturally missed, and movable World return without a forced carousel. The earned manual checkpoint has completed opening/training flags, empty statuses and refilled EVA. A browser reload and the real **Slot 1 Save Point** button returned directly to movable World, not the opening. Inventory definitions, Quick/Full entry and Skip, optional World Abilities entry/close, and narrow Full reading/scrolling were exercised. No fixture save or review flag substituted for that route.

The final scoped native/browser visual round finished without another observed tutorial/help defect. **This is ready for Miguel's review, not merged or approved by him.** Full five-stage victory, loss, items and embedded-maze replay were verified natively; a complete optional Full victory in a real browser, Safari/mobile-device behavior, and a full campaign/boss/balance playthrough remain unverified. Human readability and the emotional pacing of the preserved opening remain review decisions. Earlier dated snapshots below are evidence history, not current acceptance status. Export source remains `bda7ff6`; subsequent documentation/test-only commits do not change the deployed gameplay.

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

At the initial 02:16 a.m. checkpoint, no Web export or browser acceptance existed. Current status is above; the evidence chronology below retains what was known at each stage. A phase cannot be declared accepted while its required flow has an unresolved defect.

Combined-source checkpoints: `34a3eb5` includes main `2e183cc`, PR 101 `cbac781`, and tutorial code `cbc9e84`. `hud-integrated.log` passes 4,646 rendered checks. `combined-quick.log`, `combined-reference.log`, and `combined-practice.log` pass on the combined source. `normal-beam-handoff.log` enters the actual beacon via W swimming, resolves real attack/QTE input, returns to movable World without a mandatory carousel, and checks the stored opening/tutorial milestones. This is not yet a cold-reload or full fresh-opening test.

Draft review PR: https://github.com/Mhanna112-code/UnderwaterGame/pull/103. It is not ready to merge. Automatic previews of repository `docs/` remain stale; only the explicitly identified fresh PR 103 preview above contains this work.

## Expanded verification, 03:43 a.m. Chicago

The branch still preserves main `2e183cc` and PR 101 `cbac781`; a fresh fetch found no newer main/Marc source to integrate. The existing review PR is #103, still draft and unmerged.

- **Real skip/callback matrix:** 235 checks passed through visible Quick/Full Inventory actions. The same matrix in embedded maze passed 249 checks, returning to the correct maze owner/camera. Retained failed fixture logs distinguish hidden HUD from closing Title without loading, JSON number-type differences, legitimate Sonar billing, and an incorrect maze camera-property lookup; these were not gameplay regressions.
- **Actual optional completion/item use:** 34 checks passed with real quick/full attacks and a temporary Focus Tonic. No earned resource, inventory or checkpoint mutation.
- **Actual practice loss:** 36 checks passed for Exit and Retry/Skip with an explicitly adversarial stronger-enemy/fragile-party fixture. Damage and turns produce defeat; no injected result. This proves lifecycle/resource isolation, not that the normal practice Angler is difficult or that global balance is correct.
- **Cold native saves:** separate preparation and fresh Godot-process Load passed after real quick completion and real Skip. A legacy downed Maxilani/unfinished-training save reproduced a genuine missing taught-move softlock. The one-time initial lesson now regroups the party first; optional replays still borrow isolated resources. Repaired legacy cold Load also passed. These are recovered-opening fixtures, not browser IndexedDB or a complete freshly played cinematic.
- **Initial Retry/Exit/voluntary training:** result-handler plumbing exposed Retry being treated as optional replay and Exit re-forcing the tutorial/carousel. A dedicated initial-training completion helper now releases the beacon and milestone. Optional training chosen before the first beam lesson also releases that milestone only on completion/Skip, after restoring resources. The plumbing check passes; it explicitly does not pretend injected loss proves actual combat defeat.
- **Visual defects caught:** at 360x640 the starter initially collapsed the 3D stage to zero. Reading beats now focus on the short caption, the guided choice shows only its taught move, and narrow quick-practice status cards are compact. An implementation resize-loop failure was caught and repaired by assigning the final width once, not increasing memory limits. Final native wide/narrow captures show actors, captions, target, timing dodge and Skip. Full curriculum content is retained.
- **Recovery popup:** fixed 440px geometry put Retry/Exit below the screen at 360x480. Responsive width, scrollable body and flowing buttons now pass 64 checks; screenshots inspected.
- **Reference/ownership:** final rendered shared stat reference passes, with narrow/wide screenshots inspected. Explicit World Abilities selection and post-modal mouse/camera handoff pass. Retained long-profile QTE success/timeout layout checks now explicitly select Full and pass under real rendering.

Player-save safety: the isolated native QA project is `/Users/tomriddle1/underwater-tutorial-qa.HcDiFh`, sharing source/assets by symlink but using `UnderwaterGameQA/quick-tutorial-oct14` as its separate user directory. `verify/tutorial_qa_directory.gd` refuses other user directories. Use `TUTORIAL_QA_PATH=/Users/tomriddle1/underwater-tutorial-qa.HcDiFh GATE_TIMEOUT_SECONDS=350 bash verify/gates.sh --quick-tutorial-only`. Do not export this alternate project: Web must export the real source `project.godot` and its canonical save identity.

The new focused gate runner is executing a combined fresh round. Native results are substantial but **not release acceptance**. No fresh hosted export or final clean browser audit is claimed yet. Full optional lesson/mobile layout and separate special-encounter replay resource behavior are not covered by the short/full replay claims. Do not expand a bounded result into full campaign acceptance.

Last free-space check: 11,997,824 KiB available (about 11.4 GiB), above the 3 GiB stop. Continue checking before/after export.

## Final scoped acceptance, 06:07 a.m. Chicago

Gameplay remains `bda7ff6`; final native starter/reference/Full/result logs pass. The rendered Full run also confirms Precise Tap's real green ACC preview, now asserted by a preventive oracle (QT16 suspicion retracted, no gameplay change). Screenshots inspected include final 360x640 starter/target/finish, 720x480 Full caption/numeric stages, reference and recovery layouts, and final-source browser wide/narrow views.

`uw-tutorial103-final` genuinely earned manual slot 0, sequence 4. `browser-earned-starter-save-bda7ff6.log` and its assertion witness prove opening/training complete, empty statuses and reset EVA after the actual natural missed dodge. `pr103-final-manual-cold-world.png` records the actual manual Save Point Load after browser reload. No videos or lesson replayed; W returned movement. Optional Quick/Full were selected from Inventory, skipped, and returned normally; World Abilities was opened and closed. Narrow Inventory tabs wrap; Full reading scrolls while Continue/Help/Skip stay reachable. `browser-after-optional-practice-bda7ff6.log` retains the same manual checkpoint sequence/resources.

The console retains five Chromium pointer-lock rejections during the first rapid popup-close attempt while native rendering owned foreground focus. This was not silently dropped. With native rendering stopped and the browser focused, repeated access/close succeeded without new rejection; `browser-camera-return-bda7ff6.log` reports `focused=true, locked=true` after the real canvas click, mouse movement and normal menu return. No Godot script exception was captured. A full optional Full browser victory remains unverified; native full real victory is not misrepresented as browser proof.

The last scoped round has no further observed tutorial/help defect. PR #103 may be marked ready for **review**, never merged automatically. Exact-source preview and hash are above. Storage at 06:04 a.m. was 11,516,036 KiB free (about 11 GiB), safely above the stop threshold. Final docs/evidence commits may advance the PR tip without changing exported gameplay; preserve that distinction in metadata and review text.

Final review-page/metadata refresh: deployment `dpl_CnpqygmpkrgKKgt2yEX74zWQE2dq`, immutable `https://underwatergame-csqy8a6e4-immortaldemongods-projects.vercel.app/`, same verified `bda7ff6` gameplay/PCK carried unchanged. Only the review guide and acceptance status changed. Stable alias remains `https://underwatergame-pr103-quick-tutorial.vercel.app/`. The real-browser screenshots used the prior immutable URL with this exact PCK, not a separately rebuilt artifact.

## Next continuation: read-only until the deadline

Implementation and the scoped acceptance round are complete. Do not resume the old campaign goal or continue polishing unrelated systems. Until October 14 at 11 a.m. Chicago, only check available disk space, relevant main/Marc branch movement, and whether the PR/review preview remain reachable. If relevant upstream changes appear, report their exact SHA/scope before claiming this candidate includes them. Stay quiet for unchanged checks. At the deadline report actual PR/link/source, evidence limitations and available storage; do not merge or update production.

## Historical implementation snapshots (superseded)

The following paragraphs deliberately retain prior failures, pending gates and deployment checkpoints. Their imperative wording describes what remained **at that time**, not new instructions to redo accepted work. The current status and continuation above take precedence.

Candidate deployment now includes QT15: source `bda7ff6` pushed/exported cleanly, deployment `dpl_7SvPK6PTzQCbE6dfvN5PHvyKAjEq`, immutable URL `https://underwatergame-4s0dabz1y-immortaldemongods-projects.vercel.app`. Stable review alias points there; anonymous metadata/PCK hash match. No uncommitted gameplay change remains. A fresh final browser session `uw-tutorial103-final` is genuinely playing New Game on the immutable URL (no old saves/flags/fixtures), to validate the future manual checkpoint and cold Load. The earlier session is retained with its red witness for contrast.

Final native visual round is running: starter narrow + live Help, six reference owner/layout cases, Full 720x480 with live between-stage Help, responsive result popup. Existing-source browser proof already covers real H/Escape/Enter, one real move/natural dodge timeout, first World movement/no carousel, Inventory definitions, optional Full entry/Skip and ordinary Battle Help. Full browser completion remains honestly unverified unless subsequently completed. At acceptance, stop code changes, record any remaining unverified paths, mark the PR ready for review (not merged), and leave only relevant upstream/disk checks through 11 a.m.

QT15 validation checkpoint: fourth focused round passed with real prepare/cold pairs for completion, Skip, downed starter and existing-resource fidelity. The unchanged embedded restore matrix passes 48 cases (24 legacy-origin cases) and checkpoint IO passes. Additional original-effect markers pass 274 World skip checks, 40 real completion/item checks, 42 actual loss/Retry/Exit checks and 288 maze checks. The first outer maze retry timed out at 125 seconds before the full matrix finished; the same inputs completed with the existing 350-second gate budget. Retain the timeout log as an incomplete harness run, not a passing result or a silently removed defect.

Browser Full entry and its long Combat Basics page are visible and reachable from the real Inventory button. Skip returned to normal gameplay; while the reviewer session sat idle, an ordinary random encounter began (expected after returning with encounters on), and real ordinary Battle Help opened without spending Maxilani's turn. Browser is now paused inside that reference. Do not mistake this later normal damage (HP 7) for optional replay resource damage. Native completion/resource isolation is fully exercised; complete optional Full in the browser is still unverified and must be labelled that way if not completed before delivery.

QT15 checkpoint race, approximately 05:00 a.m.: actual browser completed quick attack + natural missed dodge and returned movable World without an ability carousel. Its read-only IndexedDB snapshot (`browser-earned-starter-save-2308333.log`) had `tutorial_complete=true`, but manual save sequence 4 still held Musashi Bleed 2/EVA 0; autosave sequence 5 was clean. Battle's existing `_exit_tree` clears effects only after World result-driven saves. New red native missed-dodge test proves the same race. `Battle.clear_battle_effects()` now runs synchronously before result checkpoints and defensively/idempotently in teardown. Original optional-practice resources are restored **after** temporary cleanup; loss/Retry/Exit resource checks still pass. Newly prepared clean manual checkpoint/cold Load pass.

A blanket clear-on-Load idea was rejected before commit: existing embedded maze checkpoint tests explicitly preserve status/pool fields. Do not weaken those or silently reinterpret older valid saved resources. `legacy-ended-effects-red/green` are diagnostic evidence of that rejected oracle/migration, not accepted repairs. The revised legacy fidelity case and separate cold Load preserve HP 7/O2 53, Bleed and spent EVA without rewriting its input file; current runner now includes four real prepare/cold pairs. Run `embedded_maze_checkpoint.gd` and `maze_checkpoint_io.gd` to prove preservation alongside the tutorial cases.

This QT15 code repair is local beyond `2308333`; it must be verified, committed, pushed, exported and deployed before final acceptance. Do not claim the current 230 preview contains it. Browser is paused in Inventory > Combat Help on its genuinely earned completed-training save. It has visually reachable Quick/Full/World Abilities buttons and the shared definitions. Actual first-course movement and no-carousel handoff screenshots exist. Finish browser cold Load/optional replay/Full entry/World Abilities on the final refreshed build; keep the two manual/autosave lanes explicit in saved-data evidence. The current browser session and checkpoint remain available; do not seed or reset them.

Latest deployment: guided Help repair pushed as `2308333`, fresh export without captured engine/script errors, deployment `dpl_B4TTbep9JN1ZUYF9VycckZTzTu37`, immutable URL `https://underwatergame-omsqsy1a7-immortaldemongods-projects.vercel.app`. Stable PR103 alias now points there; anonymous metadata and PCK hash match. It includes all locally repaired gameplay code. Only docs/evidence are still accumulating.

Browser actually completed the preserved videos and three alternating party actions/individual Cordys defeats, pressed the real recovery Continue, and reached the world. Read-only IndexedDB witness `browser-earned-opening-save-a75cfb3.log` proves opening/prologue complete and training still incomplete on the actual owned browser slot 0. It was not seeded. The browser is now reloaded after the deployment refresh, so Load the actual save and follow the beam to complete the quick lesson on `2308333`. Verify H/Help, return without a carousel, actual movement, stored tutorial completion, then a fresh browser reload/Load. Keep the existing named session and its earned save; do not replace it with a fixture to make the gate pass.

Guided Help defect, approximately 04:20 a.m.: the real browser confirmed Battle Help in the prologue, but the starter's own caption mentioned a control hidden by its guided main-menu layout. New red `guided-help-red.log` proves that failure. Help is now a persistent tutorial action beside Skip, labelled `Combat Help (H)`, with direct H access and no Enter-focus trap. It is available in narration and choice waits, not during live QTE/attack. Native help-phase preservation, H/Escape/Enter, natural dodge timeout, compact 720x480/360x640 captures and a complete Full lesson with between-stage reference use pass. Source repair is local beyond `a75cfb3` and **must be pushed, exported and redeployed before final browser acceptance**. Existing preview is still explicitly `a75cfb3` until that refresh. Add QT14 to the final regression/audit round; do not call the previous two rounds final for the new repair.

Browser session `uw-tutorial103` has genuinely played title/video/Cordys progression (no fixture seed or review flags). Battle Help opened via actual pointer and Escape returned to unchanged Maxilani/HP/turn. Actual Electric Touch and Precise Tap produced normal damage, followed by the scripted individual Cordys strikes. Currently Bucky's prologue move menu is being reviewed. Screenshots are under `output/playwright/`; `.playwright-cli/console-2026-10-14T08-59-41-425Z.log` records phases, actions and strikes. Browser console has no game errors so far. One CLI snippet syntax failure was a harness mismatch, corrected using the CLI's documented async page function; it did not change gameplay.

Deployment checkpoint, 04:00 a.m.: code and first expanded evidence pushed as `a75cfb39fd69a071d3857ff04501e1364554920b`. Fresh export completed without captured engine/script errors. PCK is 126,226,284 bytes, SHA256 `d46ebf80924d87109f19c771daa8899c9fa6ed03c0dcfb901d46916beb3d228c`. Preview deployment `dpl_5cXr8mmcEYH6n8mgU9eW9HLugQ7i`, immutable URL `https://underwatergame-50nl3frvp-immortaldemongods-projects.vercel.app`, stable review alias `https://underwatergame-pr103-quick-tutorial.vercel.app/`. Alias assignment completed and anonymous HTTP/build-info returned 200. Served-pack hashing is running; canonical production was not changed. The staging build-info/review page explicitly says browser/final acceptance pending.

Real browser opened with the Playwright skill's CLI wrapper, isolated named session `uw-tutorial103`; do not use or modify Miguel's Safari saves. Native verifiers still use the separate QA directory. Final-source combined runner `focused-gates-round2.log` is still running. Fresh Web input/storage and a complete normal opening/handoff are the next critical gates. Do not confuse earlier recovered-native fixtures with earned browser opening progression.

Additional visual pass, approximately 04:00 a.m.: the first combined focused gate runner completed with exit 0 and no captured engine/script errors. Subsequent visual checks found a clipped full-lesson page at 720x480 and width overflow at 360x640. Long optional pages now use a scrollable reading area, temporarily hide inactive action menus, retain the highlighted numeric stat panels, and use a flowing stat comparison with width-appropriate wording. Duplicate overhead cards are suppressed while this compact numeric teaching pane is up, not during the actual QTE/combat. Short-window starter also needed compact cards and removal of its redundant small-window stat row; actual 720x480 short actions now pass with visible stage/controls. Failures remain in `full-short-window-audit.log`, `full-narrow-audit.log` and the successive short-window logs. Final-source Full captures, the second focused runner, and a reference-flow regression are running. **Do not declare a final clean round or release acceptance until these and browser checks finish.**

Prepared (empty until fresh export) staging directory: `/Users/tomriddle1/underwater-pr103-preview.GvR6A3`, explicitly linked and re-inspected as existing Vercel project `prj_lmBlQo6J11hkjA5tjmHIlhiPAr5e`, scope `immortaldemongods-projects`. Its static-only config is separate from the source repo's stale `docs/` export. Deploy as preview only; never `--prod`/promote. Recheck disk before/after exporting real source into this directory. A planned per-PR alias is `underwatergame-pr103-quick-tutorial.vercel.app`; no new deployed URL exists yet.

Start with `focused-gates-round1.log` and its process status. Retain all failures; fix a real failure before export. Finish the fresh scoped native visual-audit round (including 720x480 and optional Full presentation), then export from the real source project into a separate staging directory. Check recovered saves again on final source, and test normal New Game/browser input and actual browser cold Load. The legacy QTE/camera/Skip tests have been updated to explicit Full or optional-carousel semantics without weakening actor/input/ownership assertions.

Then retain wide/narrow actual rendered captures, visually inspect them, export only once the critical handoff/persistence/input paths are accepted, and publish an identified review-only Vercel preview. Read the relevant deployment/verification skills before deploying. Do not publish any existing `docs/` Web bundle as if it contains these changes. The old campaign goal is still separate; the active overnight continuation is this saved plan and thread heartbeat.

## Handoff rule

At completion or the deadline, report the actual PR and exact-source preview, what passed, what failed, what remains untested, and remaining free space. Keep the PR unmerged for Miguel/Marc review. Stop after a storage safety condition instead of continuing to consume space.
