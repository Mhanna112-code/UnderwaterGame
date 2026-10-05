# Approved maze and campaign integration plan snapshot

Source: https://chatgpt.com/space/page_ad5d8bc76f5481918cbf545ccce5fc58

Page revision: 5. Captured October 4, 2026. This is the approved decision snapshot, not completion evidence. The Page remains the decision overview; execution status belongs in the companion ledger and audit log. Reconcile future decisions explicitly.

# UnderwaterGame Maze and Campaign Integration Plan

Status: planning document, not an implementation or merge report. Updated October 4, 2026 to include Miguel's approved Cordys puppet encounter, following comparison with the earlier plans and executable roster/dispatch checks. The immediate goal is a combined feedback build, followed by final verification and approval. This document update changes no game code and creates no new playable build.

## Immediate delivery priority

Get the integrated game into playtesters' hands quickly. Do not hold a clearly labelled feedback preview until every final polish round is complete. Separate two milestones:

- **Combined feedback preview:** all agreed integration features are wired together, including the normal world entrance, carried party/inventory, Marc's maze, maze recovery, laboratory Tethys and the new campaign Cordys. Publish a stable preview alias with the exact build SHA and a concise review guide after critical smoke checks. Record unverified subflows and nonblocking defects honestly; do not call it merge-ready.

- **Approved release:** complete the regression matrix, full independent-route playthroughs, audio review, collaborator review and the final zero-observed-defect audit loop before merge or public promotion.

Preview-blocking failures include a boot/parse crash, unreachable normal maze entrance, party/inventory loss, broken mandatory progression, an incorrect boss substitution, save/recovery that replays the opening, or a missing/nonfunctional Cordys encounter. Fix those before asking people to play. Extensive balance comparisons, alternate-path coverage and nonblocking cosmetic refinements can continue against the preview while feedback arrives. This does not waive required final verification.

Offer normal entry as the primary link. Optional focused review starts can reduce repetitive setup, but must exercise the same production scenes/state and be labelled diagnostic rather than proof of normal reachability.

Plan both Windows and Linux native downloads, as Miguel requested. These are parallel deliverables to the web preview and may avoid a browser-specific failure; they are not a guaranteed fix for weak graphics hardware. The repository currently has only a Web export preset, so native export presets, packaging and launch checks are additional planned work.

## 1. Outcome and settled decisions

Integrate Marc's finalized maze with the reviewed campaign, assets, audio and opening from PRs #96 and #98, on top of current main. Preserve each system's deliberate behavior while replacing incompatible scene boundaries and unfinished boss placeholders.

The following decisions are settled, not questions to reopen:

- Respect Marc's maze encounter policy. His strong room forces random encounters; the campaign's R toggle must not disable that rule. Authored bosses remain authored.

- The maze and laboratory are independent destinations. Defeating Tethys is not required to enter the maze or pursue Cordys.

- Tethys belongs in the laboratory. Cordys is the maze's final boss and the payoff for the opening. Do not substitute another Tethys fight for Cordys or make the player defeat the laboratory boss twice.

- Published #97 does not yet implement that Cordys finale. Treat it as new integration work, using the recently added Octopus asset. Do not keep asking whether Marc has an unpublished implementation.

- The campaign Cordys encounter must be genuinely defeatable through attainable progression. It must not reuse the prologue's deliberately overwhelming stats or forced-defeat sequencing.

- Replace the maze secret-room Tethys placeholder with Cordys's puppets: one Angler, one Swordfish Duelist and one Frilled Shark in wave one, then one Bomb Bot and one Sword Slayer in wave two. This is one authored encounter with one completion/reward, not five new campaign bosses. The maze instances do not clear or require the laboratory blockers.

- Preserve Marc's rule that any maze key opens any maze door. Consumable maze keys must be separate from campaign relics used to unlock spells. Opening a door must not consume a spell-unlock relic.

- Full-party defeat in the maze uses the established Game Over and checkpoint-recovery flow, with an identifiable maze checkpoint. Neither recovery nor Load Game may replay the opening.

- Preserve the existing Bucky puzzle and the world path to the maze. Do not turn the small laboratory into the maze.

- Do not relitigate PR #88's disputed progression/storyboard decisions or silently undertake a global combat redesign as part of this integration.

Miguel has reviewed the newer draft and likes its presentation apart from the recorded audit findings. Marc has not yet reviewed that draft. Preserve it for a meaningful shared review rather than resolving conflicts by replacing entire files.

### Quality comparison with the earlier implementation plans

Assessment: the integration plan has a sound scope and ownership boundary, but its original version was more a comprehensive integration inventory than an executable work contract. PR #96 and the opening draft were more precise about observable state, interruption branches, phase exit evidence and artifact provenance. Incorporate that precision without importing superseded design decisions or repeating every historical log entry.

The useful lesson is not that the earlier process prevented all bugs. Both PRs had green checks followed by real defects. What worked was making those defects reproducible, tightening the accepting oracle and retaining failed evidence instead of declaring code presence complete.

| Earlier structure | Recorded benefit or limitation | Integration requirement |
| --- | --- | --- |
| Public RouteState and prologue phases/signals | Separated progression from debug flags and optional tutorial completion. Correct labels alone still missed bypasses and lost saves. | Extend the existing public state with scene/checkpoint/boss identity and verify real transitions. |
| Bug catalogs with public surfaces and independent oracles | Physical travel checks caught invisible barriers; a construction-only gate missed the reported Bomb Bot crash. | Catalog risks before changes; test actual movement, attacks, outcomes and return. |
| Phase status and explicit exit evidence | Distinguished technical implementation from still-open audible/human acceptance. | Maintain the phase ledger below; a phase is not complete merely because its file exists. |
| Normal-party earned-kit combat trials | Exposed baseline Tethys losses and an unusable earned Heavy Slam that a learning-only test missed. | Prove campaign Cordys through real turns and reachable rewards, including no-lab progression. |
| Rendered and adversarial inspection | Found the pale lab, hidden centered guards, upright rest ring and screen-filling Grapple reticle after geometry checks passed. | Inspect settled gameplay views and selected attack poses independently of geometry assertions. |
| Exact clean export and served-byte comparison | Revealed stale hosted builds and verified that fixes were in the review artifact. | Match source, local export, immutable host and stable alias; verify native archives separately. |
| Current ledger plus historical failed rounds | Kept timing failures and harness mistakes from becoming false acceptance. | Keep one current status; preserve old receipts without presenting them as current proof. |
| Context-free questions and listening matrix | Explicitly left motivation, comprehension and comfort to human review. | Ask short uncoached questions about route choice, keys, recovery and the Cordys rematch; do not automate emotional approval. |

Sources: PR #96's Dropbox IMPLEMENTATION_PLAN.md and its verification catalog; [opening implementation plan](https://github.com/Mhanna112-code/UnderwaterGame/blob/c3da257d115385b423306ef61e0214ebf7416f0c/docs/opening-prologue-implementation-plan.md); [emotional-contract audit](https://github.com/Mhanna112-code/UnderwaterGame/blob/c3da257d115385b423306ef61e0214ebf7416f0c/docs/opening-emotional-contract-audit.md); [current runtime evidence](https://github.com/Mhanna112-code/UnderwaterGame/blob/c3da257d115385b423306ef61e0214ebf7416f0c/docs/evidence/opening-emotional-audit/current-1fde43a/README.md).

Do not copy earlier 'Cordys deferred', duplicate boss placeholders, old tutorial requirements, or conflicting historic fanfare instructions. The current settled decisions govern. Do not impose PR #88's unrelated balance bands on this integration.

## 2. Snapshot and evidence boundaries

The inspected snapshots are:

| Component | Snapshot | Meaning |
| --- | --- | --- |
| Current main | f9ae00c | Includes the recent PR #86 Headbutt correction. |
| PR #96 | 27a5b5253256a26733f8a320c3c6b4f97c64dece | Parent deep-zone, lab, environmental and asset work. |
| PR #98 | c3da257d115385b423306ef61e0214ebf7416f0c | Reviewed opening branch, based on #96, not directly on current main. |
| PR #97 | 58c6ed07944676631002794e4649220d3c5bf264 | Refreshed October 4; initial 55e8515 plus portrait two-lane and switch/poster fixes integrated. |
| Common ancestor | c15abb0bfb71fa80f3443a4c8ee55f7b39fe6620 | Old shared base; 136 main commits followed it at inspection. |

Refresh this snapshot before implementation. An older file on #97 is not automatically an intentional new design decision. Compare changes since the common ancestor, not only two present-day files.

The opening review alias currently serves runtime commit 1fde43a818a1bf7b969798bf3c56678d4a40d68a; the later c3da257 changes are documentation/evidence only. Marc's review build is an isolated #97 build, not a combined campaign build. It contains disclosed review-only corrections for the Door.fbx filename case and optional entrance starting position. Those corrections still need proper source integration.

Existing opening evidence includes native/render checks, actual boss-balance trials, and browser opening/load/late-death checks. These do not prove a combined maze route. Marc's two starting paths rendered and navigation/inventory worked in the review copy; a complete maze-and-final-boss playthrough has not been verified.

No tests were run or fixes implemented by writing this document.

### Corrections to the earlier integration analysis

The earlier pasted analysis remains useful for branch ownership, old-base regression risks, shared state, revival, keys and audio. Three statements are now superseded by Miguel's decisions:

- 'The eventual campaign Cordys encounter remains deferred' is no longer the plan. A real, defeatable maze Cordys is required integration work.

- 'Marc must confirm whether maze Tethys encounters are intended or placeholders' is no longer an open boss-ownership question. Miguel has settled Tethys in the lab and Cordys at the maze finale.

- 'Combined preview after all implementation and verification' is too late for the current feedback goal. Ship the gated combined preview first; final readiness still requires the full audit.

Rechecking the actual trigger code also corrects stale comments: the secret encounter is started by approaching a patrolling Tethys and accepting a confirmation prompt, not by the red sigil described in an old comment. The main encounter uses a purple floor sigil. The old Swordfish/40–60-percent comment and unused boost constant do not describe the executed secret fight.

PR #97, PR #98 and current main still matched the documented SHAs at this recheck. This confirms source freshness, not a freshly deployed combined build.

## 3. What is new, inherited, and deliberately preserved

### Our campaign and opening

Preserve the reviewed opening: Mermaid Freak film, actual free swimming before the first encounter, a reduced-health Angler fought through normal combat rules, a victory/suspense beat, the Octopus introduction, player actions using normal stats between individual overpowering attacks, recovery, durable completion, and normal-world return.

Preserve the opening's separation of prologue completion from optional tutorial completion. No prologue XP/reward farming. Sonar and encounters are enabled after recovery. Loading a completed save or recovering from a later death must not replay the films, Angler or scripted Cordys defeat.

Also preserve the current audio manager, volume controls, quieter authored opening mix, contextual shallows/deep/Bucky guidance, timed escape hint, ordinary encounter preview, clean help media, environmental assets, visible centered laboratory blockers, and the targeted Tethys/accuracy repairs. These are not permission to declare the broader combat audit resolved.

Relative to its #96 parent, #98 did not replace Marc's new maze scene, map, key-door system, scene handoff, current/whirlpool systems, inventory/items, popup or slot files. The new #97 maze has not already been integrated.

### Marc's genuine maze additions

Preserve his updated maze geometry, perimeter/escape barriers, rotating walls, movable current puzzles, carry/repel/side-push behavior, taller whirlpools and their punishment, split-rock key puzzle, poster/portrait lane puzzle with its live explanation and feedback, secret item rocks and grapple orbs, hidden sphere room and SonarVision discovery, chests/keys, secret-room transitions, boss-room structure and map/fog/legend improvements.

Preserve the standalone inventory adapter, revived-actor visibility improvements, popup support for live Control demonstrations and its layering, lever/target-selection callbacks, and key-count door support. Reconcile them with the newer shared systems instead of discarding them wholesale.

The CurrentRide scene/script exists as a prototype but has no established normal-route transition. Do not list it as playable campaign content merely because its files exist.

### Older behavior in Marc's branch is not automatically new work

The older stat-growth rules, manual spell-learning/equip flow and equip cap, older ordinary encounter roster, and older minigame/help/video behavior come from its stale base. They must not accidentally replace newer main behavior.

The current pseudo-level system, automatic available-spell learning/equipping, newer help/tutorial/minigame repairs, and other already-merged features were not all unilateral decisions made by #98. Preserve their actual current-main ownership.

Current main's Headbutt stun is two turns. Our branch still carries the earlier Strength-dependent rule. Resolve this against the verified latest main correction rather than preserving a stale formula just because its baseline currently also yields two turns.

## 4. Normal-world route and independent destinations

October 4 clarification from Miguel supersedes the earlier separate-entrance-only interpretation: **the completed Bucky/grapple/three-plate puzzle exits directly into Marc's maze.** Swim through its opened doorway. The lab is a different destination and leads to Tethys; lab victory is not a maze prerequisite. Preserve the existing puzzle, not a new mandatory laboratory route.

The inspected layout places Deep beyond approximately world X=60. Its hub leads to two destinations:

- Laboratory route: Bomb Bot near X=120, Sword Slayer near X=145, and the laboratory/Tethys near X=175.

- Primary maze route: complete the shallow puzzle, then enter its opened exit around (47, 2, 10). Clearly label the doorway and show a concise local entrance instruction. Approaching an unsolved exit must not open the maze.

- The earlier blue-lit Deep entrance around (125, 2, -34) is retained only as an additional compatibility entrance for feedback saves; it is not the required route or the answer to finding the puzzle exit.

These coordinates are implementation references, not instructions to make a human reviewer navigate by numbers.

Persist shallow-puzzle completion so Load reopens its physical doors without replaying the completion beat. Persist the actual entry source so leaving the maze returns beyond that entrance's radius, with the same party, without an immediate scene-change bounce. Keep the independent laboratory and its blockers unchanged.

Verify the actual entrance landmark, approach, trigger and arrival in normal gameplay. The existing trigger is planar and does not check depth; decide whether the vertical reach matches its visible entrance and fix an incorrect transition volume when implementation is authorized. Query flags may accelerate diagnostics but cannot prove normal reachability.

Maintain the laboratory's concealed rock-shell presentation and separated door model. Maze integration must not reintroduce a see-through lab or relocate both bosses into one room.

## 5. Shared campaign state and scene handoff

This is a major semantic integration gap, not just a merge conflict.

The current world destroys its scene when entering the maze. Marc's maze constructs fresh baseline divers and its own inventory. That would lose the real party's condition and progression. A clean textual merge can still leave this completely broken.

Define one shared campaign-state owner and a versioned scene-handoff/save contract. The exact implementation can follow the repository's existing mechanisms, but it must not maintain competing copies that silently diverge.

Required handoff data:

- Party identity, HP, Oxygen, downed status, XP/display level, spell points, learned moves/spells and equipped state.

- Campaign items, consumables and spell-unlock relics, kept separate from consumable maze keys.

- Active diver, relevant ability/equipment state and discovery state.

- Prologue and tutorial completion, completed world blockers, lab progress and maze progress.

- Current scene, destination entry, checkpoint identity and restore position.

- Sonar, encounter preference and explicit maze-area override.

- Music/SFX settings, mute and volume preferences.

Test values before and after the actual world-to-maze transition. A fresh-party constructor must not masquerade as a successful transfer. Already-dead divers must not silently revive on entry, and earned spells/items must not disappear.

The standalone Battle inventory adapter must obtain the same authoritative inventory. Automatic spell-learning currently falls back to an empty relic list when no World is present; the maze needs a real campaign-relic source, not merely its local key inventory.

### Observable contract before implementation

Use the existing RouteState, SaveManager and party/inventory mechanisms wherever possible. Define these semantics before wiring scene changes; the names may fit existing APIs. This is not a demand to rewrite the entire game's architecture or add redundant managers.

| Observable value | Required meaning |
| --- | --- |
| Scene identity and entry | World, maze or secret excursion, with the destination's legitimate entry and active diver. |
| Runtime phase | Exploring, modal, battle or restoring; transient animations/timers/decoder objects are not saved. |
| Encounter identity | Distinguish prologue_octopus, lab_tethys, maze_secret_guardian, maze_cordys and ordinary sources. A generic boss boolean cannot choose all actors. |
| Effective encounter policy | Global preference plus named local override; Marc's forced strong-room policy is visible and authoritative there. |
| Objective and signals | One scene-appropriate visible instruction; world 'find lab' does not leak into maze navigation. Preserve the world objective for returning rather than erasing progression. |
| Checkpoint identity | Selected slot, scene, safe spawn and snapshot revision, separate from unsaved live maze mutations. |
| Boss/puzzle lifecycle | Explicit available/in_progress/defeated or solved state as appropriate; loading an interrupted fight cannot award victory. |
| Save schema/version | Backward-compatible default rules and validated coherent party, inventory, geometry and reward data. |

Consumers must observe changes through the existing signals or equivalent public notifications. Do not make the HUD, audio and tests independently infer state from private helper order.

Keep the existing opening migration rule intact: missing opening fields in old saves do not mean a new player has never played. Missing maze data defaults only the new maze state. Do not reset prologue/tutorial completion, claim a boss win or fabricate rewards.

Distinguish entering from recovering: normal first entry carries the party's actual condition; death recovery restores the chosen checkpoint according to the agreed campaign rule. Creating a scene is not permission to heal everyone.

## 6. Maze persistence, keys and recovery

Marc's SceneHandoff currently carries only limited return information for the secret room. Returning constructs a fresh maze and can reset mutable puzzle state. Persist the meaningful state rather than treating a return flag as sufficient.

Save/restore at least:

- Opened doors and remaining maze keys.

- Wall orientations, current positions/modes and lever state.

- Poster solution/gate state, split-rock completion, broken secret/item rocks and collected orbs.

- Chest/reward collection, SonarVision state and campaign reward ownership.

- Secret guardian and Cordys completion, without conflating those with laboratory victory.

- Map discovery and once-only explanatory modals.

- Current scene, selected save slot, checkpoint, position and active diver.

Returning from the secret room, loading a save, and recovering after defeat must not duplicate rewards, restore consumed keys, close legitimately saved doors, erase campaign items or replay already-dismissed puzzle films.

Keep any-maze-key/any-maze-door behavior. Door checks and consumption must use the maze key collection only. Display a useful count and verify exactly one key is consumed per successful opening.

Replace the maze's current automatic full heal/entrance return on party defeat with the agreed Game Over/checkpoint flow. Establish a clearly identified maze checkpoint, preferably before forced-risk sections, using the existing save/recovery product behavior. The checkpoint restores its saved state, not arbitrary later unsaved mutations.

Cover selected-slot handling, cold reload, missing/corrupt saves and failed writes. Never advance durable completion merely because a save was attempted. Never set opening completion from unrelated maze events, and never treat the maze's legacy rock/puzzle completion flag as proof of Cordys victory.

### Save and interruption decision table

The following branches are required test cases, not claims that implementation already handles them:

| Boundary | Required result |
| --- | --- |
| World-to-maze entry | One scene transition, same party/resources/preferences, valid normal entry; duplicate trigger does not create a second scene/battle. |
| Secret excursion and return | Preserve live maze mutations and reward ownership; do not reconstruct a blank maze. |
| Door opened with a key, then saved | Open door and spent key restore together; relics remain unchanged. |
| Door/reward mutation after checkpoint, then death | Restore geometry and inventory to the same saved moment; no split rollback. |
| Reward source broken before pickup, then saved | Persist the pending reward exactly once, or use an explicitly atomic pickup contract; never lose or duplicate it. |
| Maze save interrupted or rejected | Retain the prior coherent checkpoint and active slot; show actionable retry/error, not false success. |
| Missing/corrupt/incompatible save | Existing safe load behavior and clear action; no partial state application or automatic replay of the opener. |
| Save during transient fight/modal/transition | Normalize to a documented safe maze state; do not serialize UI owners, grant a boss win or double-consume a key. |
| Maze death followed by Restart or cold title Load | Both restore the correct scene/checkpoint and completed opening; actual enemy-caused defeat exercises the production flow. |
| Old world save without maze fields | Normal old-world continuation with valid defaults for the new branch; no invented maze completion. |

Respect player saves: use isolated disposable test slots/profiles and never 'repair' real completion flags or overwrite a player's existing slot to make a harness pass. Test atomic reward conservation across source, pending pickup and inventory, following the proven checkpoint contract rather than checking JSON fields alone.

## 7. Encounter policy and input integration

Respect Marc's strong-room decision: its random encounters remain forced. Outside that exception, preserve normal world encounter toggling and authored encounter policies.

The global encounter preference and a local enforced policy are different things. A player arriving with encounters disabled must not bypass the strong room. Leaving it must not permanently corrupt their global preference.

Our escape hint teaches R in normal exploration. Do not show an actionable 'disable encounters with R' hint where Marc deliberately forbids that action. Use valid retreat/recovery feedback there without weakening his system.

L-map controls use R to manipulate currents; the campaign uses R for encounters. Consume input in the active context so one press cannot both move a current and toggle encounters. Similarly prioritize map, popup, lever, door and ability uses of E. Verify with real key events, not direct method calls alone.

Marc's strong/ambush boost currently modifies several stats by roughly 5–15 percent, but rounding and caps can leave small stats unchanged. Its older party-scaling can also dominate that local boost. Preserve the intended policy while measuring the actual effect after integration with the modern roster.

Do not claim stronger ordinary enemies throughout world Deep merely because the maze strong room has a boost. The campaign audit found no distinct stronger ordinary deep-zone table. That remains a separately tracked finding unless explicitly brought into implementation scope.

Keep the secret-room reward/key chain. Replace its Tethys placeholder with the approved two-wave Cordys puppet encounter specified below. The guardian assignment is settled; the old Swordfish comment and the later single-Frilled recommendation are not the implementation contract.

### How the two Tethys encounters actually execute in PR 97

1. The secret room builds a visible PatrollingTethys actor. Approaching it opens a Yes/No prompt; Yes calls _start_battle("secret_boss").

2. The main room builds a purple Area3D sigil. Entering it with the active diver calls _start_battle("main_boss"), provided no battle/modal is already active.

3. Both branches create a fresh Battle, set boss_encounter = true, pass the party/local inventory and connect its finished signal.

4. Battle sees that boolean and constructs TethysBoss, including its stats, model, move behavior and intro. It receives no distinct Cordys boss identity. The main and secret labels change the maze's messages/rewards, not the spawned species.

5. Winning the secret battle removes its patrolling trigger actor and grants abyss_key. Winning the main battle removes its sigil, announces "Tethys is defeated!" and returns. There is no chained Octopus battle or game-ending Cordys payoff.

The correction requires explicit encounter identity and actor construction, not merely changing announcement text or placing an Octopus mesh in the room. Preserve the secret encounter's approach/confirmation mechanic and reward chain, replace its patrolling Tethys presentation with the approved puppets, and dispatch campaign Cordys for the main encounter.

Sources: [maze battle dispatch and outcome](https://github.com/Mhanna112-code/UnderwaterGame/blob/55e851556c69e3745fdc38ddd2b381244e087b05/game/maze_level.gd#L717), [secret patrol and prompt](https://github.com/Mhanna112-code/UnderwaterGame/blob/55e851556c69e3745fdc38ddd2b381244e087b05/game/maze_level.gd#L1513), [main sigil](https://github.com/Mhanna112-code/UnderwaterGame/blob/55e851556c69e3745fdc38ddd2b381244e087b05/game/maze_level.gd#L1588), [Battle constructs Tethys](https://github.com/Mhanna112-code/UnderwaterGame/blob/55e851556c69e3745fdc38ddd2b381244e087b05/game/battle.gd#L983).

### Cordys puppet encounter

Miguel approved the narrative and roster: defeat Cordys's puppets, then face their master. This replaces the secret-room Tethys fight; it does not add another route or change the maze puzzles. Preserve the existing approach and Yes/No confirmation, using a readable puppet-guard presentation instead of PatrollingTethys. No new cutscene or new creature asset is required.

Asset evidence supports the connection, but not the whole fiction: the delivered Octopus FBX contains named Sword Fish, Angler Terror, Frilled Shark, Bomb Bot, Sword Slayer, Sea Urchin and Merfolk corpse components. Treat control of living puppets as the approved narrative interpretation, not an already implemented model behavior. The playable Angler is not proven identical to the Angler Terror component. Sea Urchin and Merfolk remain excluded because they lack working combat implementations. Source: [Octopus FBX](https://github.com/Mhanna112-code/UnderwaterGame/blob/c3da257d115385b423306ef61e0214ebf7416f0c/art/deep_zone/Octopus_Boss.fbx).

| Stage | Authored opponents | Required outcome |
| --- | --- | --- |
| Approach | Visible, recognizable puppet guards with the existing confirmation interaction | A concise line such as “His puppets guard the way. Break their hold.” establishes the connection; accepting starts exactly one encounter. |
| Wave one | One Angler, one Swordfish Duelist, one Frilled Shark | Clearing all three advances to wave two, not exploration or final victory. |
| Wave two | One Bomb Bot, one Sword Slayer | Clearing both completes the puppet encounter and grants its existing maze-key reward exactly once. |
| Finale | Campaign Cordys in the main boss room | Separate genuinely defeatable encounter; Tethys remains solely in the lab. |

Use existing authored enemy move catalogues and normal combat rules. Record encounter-specific tuning against reachable no-lab resources rather than importing prologue stats or inflating every enemy arbitrarily. Sword Slayer currently shares Swordfish Duelist's attack catalogue; the different model does not imply a new move set. Frilled Shark has two authored moves. This encounter is not authorization for a global rebalance or extra enemy-kit work.

The same battle owns both waves. Carry actual HP, Oxygen, downed status, consumable use and applicable battle effects across the handoff under normal turn rules; no accidental healing, revival, refill or party reconstruction. Clear defeated-wave actors, targets and pending callbacks before constructing the next wave. Rebuild turn order for its living participants without stale entries, duplicate enemy turns or bypassing surviving players. Make the arrival of wave two legible without another tutorial or long text.

Do not emit final “won”, play a victory sequence, restore exploration or grant XP/key rewards after wave one. Award the encounter's documented rewards only after both waves are defeated, using the existing reward/progression rules and once-only ownership. Defeat in either wave follows the campaign checkpoint flow. Any supported escape must leave the encounter incomplete and rewardless, not skip wave two.

Transient wave progress is not a durable victory. Loading an interrupted encounter or recovering from defeat restores the coherent checkpoint and restarts the incomplete encounter from wave one; do not serialize animations, duplicate pickups or award a key for partial progress. A saved completed encounter stays completed and cannot be farmed. Test saved versus unsaved completion using the existing checkpoint rollback rules.

Keep maze_secret_guardian completion separate from lab Bomb Bot, lab Sword Slayer, lab Tethys and maze Cordys completion. Maze-first play must work without lab victory; puppet victory must not remove lab guards or open their gates. Lab-first play must not pre-complete or remove these puppets.

“Gain the right to face the puppet master” is the narrative payoff and existing key reward, not a new hard prerequisite. Preserve Marc's any-maze-key/any-maze-door rule. Do not silently require a puppet-completion flag to open the final door if a player legitimately holds another maze key.

Use the existing battle INTRO then LOOP continuously across both waves, with no music restart or intermediate victory cue. Reserve the Final Boss INTRO/LOOP for Cordys. Verify distinct silhouettes, readable cards/targets, Frilled Shark's long body, both large second-wave models, attack poses and handoff timing in the real combined stage.

Acceptance requires an actual normal-entry trigger and legitimate two-wave win using attainable resources without lab victory, plus loss/recovery and cold-load checks. Record turns, HP/Oxygen and consumables after each wave and the resource path to Cordys. A five-actor spawn check, injected “won”, immortal party or gallery render cannot accept this encounter. Human review must separately establish whether players recognize the puppets as preparation for Cordys.

## 8. Cordys finale: new playable integration work

Replace the main maze boss placeholder with the actual Octopus/Cordys actor and a campaign-specific encounter. Reuse the validated mesh/material/animation adapter where appropriate, not the prologue's forced outcome.

The prologue can remain overpowering. The final rematch must use its own tuned stats, normal combat resolution, authored attacks, meaningful player turns, correct Accuracy/Evasion/Defense/status/Oxygen behavior and actual win/loss conditions.

Balance against legitimately attainable parties and resources:

- Entering the maze without defeating Tethys must remain a valid route.

- Baseline HP and the pseudo-level system do not suddenly become stat growth.

- Progression must use spells/items/knowledge actually obtainable in the combined game.

- Do not assume lab-only rewards, unlimited potions, perfect minigame success or inflated test HP.

- Account for attrition before the boss and access to a valid checkpoint.

Document each attack's gameplay effect and actual asset clip, target pattern, telegraph and feedback. Do not add an animation-only boss with invisible/no-op attacks, or a technically winnable encounter whose normal players cannot understand its responses.

Verify real victories through normal battle actions with reachable loadouts. Record HP/Oxygen, turns, resources and strategy. Compare plausible damage-focused and mechanic-aware approaches; a test that injects 'won', gives everyone 500 HP, or uses an impossible loadout is not victory evidence.

Preserve the emotional contrast: opening humiliation, later capability, actual defeat of the same teased enemy. Provide a clear final victory/closure state and persist it. Final narration or a bespoke ending film remains a content item to confirm; do not claim it exists or expand the asset/story scope silently.

## 9. Combat, death and recovery regressions to avoid

Keep Marc's improvement that revived actors reappear in battle, but reconcile it with the current battle stage and party ownership. Test revival of a diver who was down before battle began, not only someone who died after spawning.

Older victory recovery can heal zero-HP divers automatically even where branch descriptions imply otherwise. Follow the current campaign's agreed behavior and make stats, cards, actors and recovery consistent; do not inherit contradictory rules accidentally.

Existing audit findings include downed divers remaining pilotable in exploration and some caster/revival paths lacking consistent downed checks. Carry these into the integration defect register. Do not hide them behind a successful scene transition or claim that fixing one potion presentation solves all death-state behavior.

The broader combat audit also remains open: mostly static green labels, misleading previews, omitted Agility context, repeatedly dominant free/high-power attacks, limited practical utility payoff, and pseudo-level progression misunderstandings. Maze integration and a beatable Cordys do not prove a global rebalance.

Tethys's targeted adjustment and prior actual-win evidence must survive integration. Re-run attainable lab victories against the combined code; preserving her file without exercising the shared battle system is insufficient.

## 10. Conflict and shared-system reconciliation map

The inspected merge diagnostic found eight meaningful runtime conflicts plus a maze-map test conflict. This is a snapshot, not a promise that the eventual count will stay unchanged.

| Surface | Required reconciliation |
| --- | --- |
| character_ability_popup.gd | Retain Marc's live Control demo/layering and current clean video sizing/media lifecycle. Do not restore the old cropped grapple presentation. |
| content/tutorial_content.gd | Preserve current tutorial/help content and optional access, adding only maze-specific material that is genuinely new. |
| game/battle.gd | Preserve modern combat, opening and audio; add standalone inventory and revived-actor improvements; wire normal campaign Cordys. |
| game/inventory_menu.gd | Support campaign and maze sources without replacing current spell/help behavior or mixing keys and relics. |
| game/maze_level.gd | Preserve Marc's layout/puzzles/policy; add shared state, persistence, normal entry and correct boss ownership. |
| game/maze_mini_map.gd | Preserve his map/fog/icons and newer compatibility; verify live geometry and input contexts. |
| project.godot | Reconcile autoloads, resources, input actions and export settings deliberately. |
| slot.gd | Preserve current party/progression behavior and Marc's genuine UI callbacks. |
| verify/maze_minimap.gd | Update expectations to actual current maze behavior; do not delete assertions just to obtain green tests. |

Shared currents, whirlpools and popup changes can affect the shallow Bucky puzzle and opening, even when they merge without conflict. Test those consumers too.

Separate generated .import/.uid noise from source decisions. Rebuild imports consistently, preserve unrelated local changes and verify assets by source hashes. Correct the source Door.fbx filename case for case-sensitive web exports. Production entry must not retain Marc's developer sphere-room spawn override.

Do not resolve conflicts with blanket 'ours' or 'theirs'. A semantic preservation matrix is required even for files that merge automatically.

## 11. Audio, assets and deployment

The world currently stops music before entering the maze, while the new maze has no integrated music owner. Wire it into the existing central audio system so entry is not unintentionally silent.

Preserve Phoenix's Intro-to-Loop instruction: play INTRO, then LOOP immediately and loop it, with no crossfade between those paired files. Retain volume/mute settings, restrained SFX and browser user-gesture requirements. Avoid overlapping music owners or stacked loops during maze entry, secret-room returns, battles, death and reload.

### Maze music using the existing delivered tracks

The canonical Phoenix ZIP contains exploration ambience, battle INTRO/LOOP, Mermaid Boss LOOP, Final Boss INTRO/LOOP, title, victory and game-over tracks. There is no separate maze-labelled track. Use prepared runtime derivatives from the authoritative ZIP, not older Dropbox rough sketches or the Final Boss DEMO MP3.

Recommended first-preview mapping, based on authored roles and the music Miguel already liked, not a new listening approval:

| Situation | Existing cue | Direction |
| --- | --- | --- |
| Maze traversal and puzzle-solving | exploration_loop.ogg | Keep the established underwater ambience. If needed, use a modest local trim so puzzle feedback stays clear; do not alter the user's volume setting. |
| Strong-room exploration | Same exploration ambience | Let the room warning/encounter policy establish danger; do not continuously play battle music before a fight. |
| Ordinary maze fight, ambush or puppet encounter | battle_intro.ogg then battle_loop.ogg | Preserve Phoenix's immediate handoff and existing combat identity. Continue through both puppet waves without restarting the INTRO or playing an intermediate victory cue. |
| Campaign Cordys reveal and fight | final_boss_intro.ogg then final_boss_loop.ogg | Reuse the opening's Cordys musical identity as a rematch payoff. Start once at the authored encounter reveal; do not restart the intro each turn. |
| Laboratory Tethys | tethys_loop.ogg | Keep the Mermaid track attached to the laboratory boss, not generic maze exploration. |
| Victory and Game Over | Existing victory sequence / game_over.ogg | Preserve outcome feedback; return to the correct maze ambience when exploration resumes. |

Start with the existing Cordys trims as a safe baseline, then judge the full rematch mix. The prologue's dramatic ducking/forced-defeat beats must not accidentally become the final fight's music controller. Do not infer that a file called 'verb tail' is an INTRO or revive unapproved candidate joins.

Listen through traversal, a battle INTRO-to-LOOP join, return to exploration, the full Cordys join/loop and a recovery/load cycle. The earlier waveform audit includes historical wiring descriptions; current runtime code is the authority for what is now connected. Automated playback and edge measurements do not establish musical fit, comfortable loudness or subjective seam approval.

Check Octopus meshes, textures, scale, facing, floor alignment, attack clips and target staging. Preserve environmental rocks/trees and concealed lab presentation. Verify model resources and movies are included in a clean web export, not only available in a local import cache.

Publish the combined feedback preview as soon as the immediate-delivery smoke gates pass, rather than waiting for final release polish. Use one stable combined-review alias, attach its source SHA/build manifest and keep updating that alias. Disclose diagnostic starting options and open defects. Do not label an isolated #97 or old #98 deployment as the combined game.

Prepare both native packages from the same integrated source commit as the web preview:

- Windows: an initial x86-64 executable ZIP containing all required runtime resources and short launch instructions.

- Linux: an initial x86-64 archive containing the executable/resources, preserving executable permissions and documenting the tested distribution/graphics setup.

Use release exports, matching Godot export templates and explicit renderer checks appropriate to the intended machines. Include version/SHA, checksums, known issues and honest signing status. Verify video/audio, input, normal maze entry, save/load and recovery on each target; successful cross-export on this Mac is not a Windows or Linux launch test. Use available target-machine testing or clearly request/report the remote smoke test.

Do not ship raw source as a player-ready executable or recommend bypassing operating-system security automatically. Browser saves may not be present natively; document a new-game path or an actually supported save transfer. Native archives must not include developer saves or private local files.

Native-build readiness check: the installed Godot is 4.7.1, and its local export-template directory currently contains only Web templates. Install the matching Windows and Linux templates during implementation before attempting native exports. The project advertises Forward Plus, while the OpenGL flag is in editor-only run arguments and only the mobile renderer is explicitly Compatibility. Do not assume an exported desktop executable inherits that editor flag. Evaluate an explicit Compatibility configuration for the initial lower-spec native builds, checking that maze lighting, models and effects still render correctly. This is a packaging risk discovered in the recheck, not a completed renderer fix.

Both Windows and Linux are requested targets. Publish each package as it becomes exportable and verified; do not delay the web link solely because target-machine confirmation for one native package is pending. Distinguish 'exported', 'launch tested' and 'playtest verified' for each platform. The initial x86-64 architecture is a proposed default, not a claim that ARM machines are covered.

Public main and underwatergame.vercel.app stay unchanged until combined verification and review approval are complete. Previous authority to deploy earlier work is not proof that this new integration is approved for an immediate public merge.

## 12. Execution sequence and defect tracking

All steps below are planned, not completed. The first delivery is an integrated feedback preview; the later release gate remains stricter.

1. Refresh branch/main SHAs; retain clean snapshots and record meaningful local changes. Establish the feature-preservation matrix and a bug catalog with repro steps and cheapest reliable test for each integration risk.

2. Form a current-main baseline with the intended #96/#98 work and current-main fixes preserved. Integrate Marc's genuine maze changes selectively. Review semantic diffs before treating conflict resolution as finished.

3. Implement and verify shared state, independent destinations, keys/relic separation, input contexts, scene persistence and checkpoint recovery.

4. Wire Marc's full maze puzzle/door/reward route through the real world entrance and smoke-test critical traversal, key spending and checkpoint recovery. Retain his strong-room rules and remove production developer defaults. Keep remaining full-route verification explicitly open until performed.

5. Implement the approved two-wave puppet encounter and actual Cordys rematch, with explicit identities, normal combat and correct win/loss behavior. Prove an initial legitimate puppet-and-Cordys route using reachable resources without lab victory. Preserve laboratory Tethys and both independent lab blockers. Do not block the preview on bespoke ending narration.

6. Connect the proposed existing music cues and media/assets, export and deploy the combined feedback preview, verify provenance and run the critical smoke checks against that exact build. Share its normal-entry link and short review checklist promptly. Prepare Windows and Linux native packages from the same commit, recording each platform's actual export/launch/playtest status without delaying the web preview unnecessarily.

7. Continue the complete regression matrix, attainable-boss comparisons and full normal-entry/alternate-route journeys while playtest feedback is collected. Reproduce and log incoming findings; fix integration blockers promptly and update the same preview alias. Then run the final repeated visual/audio audit below.

8. Present the final evidence and remaining scope limits to both collaborators. Obtain review approval before merging or promoting to the canonical public deployment. An early preview is not evidence that this approval has already happened.

Each defect record needs an ID, affected surface, observed versus expected behavior, source/deployed SHA, exact reproduction, severity, likely cause, test/evidence, owner, status and remaining uncertainty. Mark 'observed', 'diagnosed', 'fixed locally', 'verified natively', 'verified on deployed build' and 'human accepted' separately.

Do not declare a phase complete while its required work has unresolved defects. A feedback preview can be shared with disclosed nonblocking findings before final verification finishes, but not with known boot, state-loss, mandatory-route or recovery blockers. If an asset, content decision or collaborator approval blocks completion, report it explicitly. Existing out-of-scope combat/design findings remain visible and are not silently declared fixed.

### Phase ledger and exit evidence

Keep this compact ledger current during execution. All implementation phases are initially planned. Technical implementation, deployed verification and human approval are separate statuses.

| Phase | Required output | Exit evidence |
| --- | --- | --- |
| Foundation | Exact branch/base and feature-preservation matrix; repository contract snapshot and defect catalog. | Planning-only initial diff, unrelated changes preserved, known baseline risks labelled observed or code-inspected. |
| State and recovery | Carried party, independent destinations, keys/relics, coherent saves and input contexts. | Actual transitions plus old/new/interrupted/denied-write decision table; no opening replay. |
| Maze integration | Marc's geometry, puzzles, map, encounters, secret-room return and production entry. | Real reachable critical route, functioning controls and rewards, no forced-room bypass or state reset. |
| Puppet encounter | One authored encounter: Angler/Swordfish/Frilled, then Bomb Bot/Sword Slayer; independent maze identity and once-only key reward. | Real two-wave win, correct turn/resource carryover, no early reward/victory; loss/load recovery and lab-first/maze-first isolation. |
| Cordys rematch | Explicit actor/encounter identity, moves, legitimate victory/loss and persisted payoff. | Actual attainable victory using reachable resources without lab victory; prologue isolation and visible attack checks. |
| Feedback delivery | Web alias and Windows/Linux packages with provenance, review instructions and known issues. | Critical web smoke gates on exact bytes; separate exported/launch-tested/playtested status for each native target. |
| Release acceptance | Complete regression, normal/alternate routes, listening and repeated polish. | Full scoped clean round and collaborator approval; no automated claim of human motivation or comfort. |

During implementation, save the current decisions as a repository integration-plan snapshot before functional changes, with companion bug catalog, runtime/asset manifest and dated audit log. This Page remains the decision overview; the repository execution ledger tracks concrete work. Reconcile changes deliberately so the two do not become competing sources.

Commit meaningful, reviewable increments as work proceeds: contracts and red characterization, state/recovery, maze adapters, boss dispatch/rematch, audio/platform packaging, then focused repairs/evidence. Do not hand-merge generated PCK binaries; regenerate them from the identified accepted source. Avoid mixing unrelated imported metadata or existing user edits into those commits.

Each progress entry records current source SHA, last verified runtime SHA, changed contract, focused result, open defect, current artifact and next concrete step. Report failed/skipped/blocked checks explicitly. No numerical percentage or 'done' status inferred from the number of files changed.

### Initial integration defect catalog

These entries define risks and accepting oracles. Baseline reproduction is still required before calling an unexecuted case a reproduced defect.

| ID | Failure to catch | Cheapest meaningful oracle |
| --- | --- | --- |
| INT-01 | Fresh maze divers erase the real party. | Transition with distinctive HP/Oxygen, downed state, earned kit and inventory; compare actual consumers after arrival. |
| INT-02 | Secret return resets puzzles/keys/rewards. | Mutate, leave and return through production paths; inspect geometry and ownership, not only a return flag. |
| INT-03 | Door consumes a campaign spell relic. | Open with a maze key, verify one key consumed and relic/unlocked spell unchanged through reload. |
| INT-04 | Checkpoint rollback splits inventory and world state. | Saved and unsaved door/rock/pending-pickup sequences, actual death Restart and cold Load. |
| INT-05 | Boss labels change but Battle still builds Tethys. | Actual main trigger produces campaign Cordys stats/model/moves; real victory changes only its own progression. |
| INT-06 | Map R also changes encounters, or global Off bypasses the strong room. | Real contextual key events; observe current movement and effective encounter policy independently. |
| INT-07 | Revival updates HP but not model/card/turn participation. | Initially downed diver, actual consumable/ability, restored battle actor and next-turn use. |
| INT-08 | Framing/import test passes but a selected attack hides actors/UI. | Real rendered mesh/animation extremes and target facings at wide/narrow/tall sizes, plus inspection. |
| INT-09 | Scene/battle/film music stacks or never resumes. | Semantic owner/cue trace across repeat transitions plus exact-build listening. |
| INT-10 | Reviewer plays stale web/native output. | Local-to-served PCK digest, build SHA, immutable/stable comparison and per-native archive/resource manifest. |
| INT-11 | Clearing wave one ends battle, grants rewards or bypasses wave two. | Actual wave-one clear launches exactly Bomb Bot and Sword Slayer; no final outcome/reward until their defeat. |
| INT-12 | Wave handoff reconstructs/heals party or leaves stale actors, targets and turns. | Carry distinctive HP/Oxygen, downed state, used items and active effects; actual next-wave targeting/actions and actor/card checks. |
| INT-13 | Maze puppets clear the lab blockers or depend on lab victory. | Both route orders; inspect independent encounter flags, world guard models and gate ownership after puppet victory. |
| INT-14 | Partial/interrupted puppet encounter farms keys or persists a false win. | Lose/escape/load after wave one; recover coherently and restart incomplete fight without rewards; saved final victory rewards once and survives return/reload. |

Add focused tests to verify/gates.sh or an explicitly linked aggregate runner; do not leave them outside the accepting suite. Carry forward its bounded timeouts, script-error detection and seeded randomness. A process exiting zero with a script error is failure. Skipped web/render/native checks are not passes.

Where feasible, prove red against the broken production behavior, then green after repair with the same oracle. Choose invariants/decision tables before expensive end-to-end repetition. Reserve full real-input and deployed checks for boundaries cheaper tests cannot cover.

### Harness discipline and visual operating conditions

Wait for actual phase/signals, usable controls, settled chase camera and film EOF rather than fixed two-frame assumptions or arbitrary wall-clock guesses. Require the expected actors/objects to exist so a zero-object loop cannot pass vacuously. Name and seed both gameplay randomness sources where needed.

If an observer fails, reproduce and distinguish a game defect from a harness defect. Fix an invalid fixture without weakening its valid assertion, changing the gameplay threshold or hiding the original failed receipt. Synthetic completion and immortal parties remain allowed only for explicitly labelled narrow tests, never route/balance proof.

Use real rendered windows at 1280x720, 720x480 and 720x900; include 360x640 for affected recovery/menu surfaces. Reload the Godot web app after viewport changes before treating captures as accurate layout evidence. Test the actual shipped renderer, not only the editor's launch configuration. Inspect selected Cordys clips throughout their moving bounds and across targets; a static import/gallery shot is insufficient.

Use the game's scripted verification for deterministic state and battle checks. Use browser/native play for deployed input, graphics, audio, save storage and human experience. Preserve timestamps and separate gameplay timing from screenshot/OCR overhead without guessed subtraction.

### Bounded tuning and uncoached review

Treat campaign Cordys stats, camera framing and mix trims as recorded hypotheses. Establish the reachable no-lab kit and resource budget before setting difficulty; record tuning changes with source, seeds/policies, outcome and resource use. Do not import prologue one-shot stats, assume cosmetic levels increase HP, or manufacture growth rewards.

For the first feedback build, prove at least an actual legitimate win and normal loss/recovery. Before release, compare reachable baseline, attrited and mechanic-aware kits with failed as well as successful QTEs, carrying real rewards and consumables. Do not invent a universal win-rate or strategy threshold absent an approved design requirement.

Ask an uncoached tester: Where can you go next? What opens this door? What happens if the party dies? Can you pursue the maze without clearing the lab? Does this final enemy read as the Cordys from the opening, and does defeating it feel like a payoff? Their answers and listening feedback remain human evidence, not agent-certified emotions.

Keep the available music mapping provisional until heard in the combined build at 100%, 50%, Music mute and SFX mute, ideally speakers and headphones. Reuse the existing audio owner; do not create another sequencing system for the maze.

## 13. Verification matrix and acceptance

| Contract | Required evidence |
| --- | --- |
| State handoff | Real world-to-maze transition with distinctive HP/Oxygen, downed diver, earned spells/items and active diver retained. |
| Independent routes | Enter maze and pursue Cordys without lab victory; separately verify the lab/Tethys route still works. |
| Keys | Any maze key opens a door once; no campaign relic consumed; counts and rewards persist without duplication. |
| Persistence | Cold save/load, secret-room return and later death preserve the appropriate saved maze state and selected scene/slot. |
| Recovery | Maze Game Over restores its identified checkpoint; opening never replays; failed writes/corrupt saves handled honestly. |
| Encounter/input policy | Strong-room forcing survives R; ordinary areas still honor normal policy; L-map R affects only currents. |
| Maze puzzles | Full normal traversal, poster puzzle, split rock, levers/currents, secret discovery and doors exercised with actual input. |
| Combat ownership | Tethys in lab, approved puppets in the secret room, Cordys at maze finale; independent lab blocker flags and no prologue forced-loss logic reused for final combat. |
| Puppet waves | Actual mixed three-enemy first wave then two-enemy second wave; correct resources/effects/turns, clear framing, no premature victory, once-only reward and interruption recovery. |
| Attainable victories | Real lab, two-wave puppet and Cordys wins with reachable loadouts, normal actions and measured resources, not injected result flags. |
| Revival | Diver initially down can be restored; model/card/turn participation match HP and remain correct after scene changes. |
| Media/audio | Clean readable clips, no duplicate/cropped video; correct Intro-to-Loop joins, no stacking, persistent controls and browser audio startup. |
| Web provenance | Clean export boots normal entry; correct case/resources, production spawn, deployed SHA and evidence match. |

Run existing relevant gameplay/combat gates plus new integration tests. Prefer the game's verification/playtesting systems for repeatable checks; use real browser interaction where deployment, pointer input, visual presentation or audio requires it.

A green unit test is not proof of normal reachability. A rendered starting scene is not proof of a maze clear. A debug flag is not proof of a campaign route. Tests, native playthrough, deployed playthrough and human visual/emotional review are complementary evidence.

## 14. References and carry-forward audit

- [PR #96: campaign foundation](https://github.com/Mhanna112-code/UnderwaterGame/pull/96)

- [PR #97: Marc's Maze finalizations](https://github.com/Mhanna112-code/UnderwaterGame/pull/97)

- [PR #98: opening branch](https://github.com/Mhanna112-code/UnderwaterGame/pull/98)

- [PR #86: current-main Headbutt correction](https://github.com/Mhanna112-code/UnderwaterGame/pull/86)

- [Saved PR #98 combat and recovery audit](https://chatgpt.com/space/page_8a7b90bcdcd48191aff032b4b42554bc)

- [Inspected Marc maze source](https://github.com/Mhanna112-code/UnderwaterGame/blob/55e851556c69e3745fdc38ddd2b381244e087b05/game/maze_level.gd)

- [Inspected campaign world source](https://github.com/Mhanna112-code/UnderwaterGame/blob/c3da257d115385b423306ef61e0214ebf7416f0c/game/world.gd)

- [Opening review build, isolated not combined](https://underwatergame-opening-prologue-review.vercel.app/)

- [Marc maze entrance review, isolated not combined](https://underwatergame-pr97-maze-review.vercel.app/?maze=1&entry=entrance)

- [Marc maze review guide](https://underwatergame-pr97-maze-review.vercel.app/review.html)

Repository contracts to carry forward: docs/opening-prologue-implementation-plan.md, docs/opening-emotional-contract-audit.md, docs/opening-prologue-visual-audit-log.md, verify/lab_boss_balance.bug-catalog.md and verify/deep_zone_blockers.bug-catalog.md. Consult their current versions rather than assuming prior green results cover new shared-system changes.

Keep the separate combat/recovery findings and PR #88 history as evidence. This document does not authorize rewriting the blind-playtest record or reopening rejected storyboard work.

The secret guardian assignment is settled: Cordys's approved two-wave puppet encounter. The remaining bounded content item is exact final victory/ending presentation; a clear functional closure can serve the feedback preview without bespoke narration. Do not reopen the settled decisions in section 1.

### October 4 follow-up reconciliation: PR99, new PR97 and character delivery

This is a new execution delta, not retrospective acceptance of the earlier
preview. PR100's last delivered source is dcb7650 until the runtime manifest
identifies a newer artifact. Main/public remain unchanged.

- Partial downloaded FBXs: admit nine authored spell clips through animation-
  only libraries while preserving complete existing models/motions. Verify
  source hashes/rig paths/rest transforms, actual deformation, real spell
  outcomes, finished gestures and narrow/full-party framing. The inventory
  names exact covered and uncovered spells. Local checks pass; export proof
  is a separate boundary.
- Marc's PR99 initially inspected at 11857ae: preserve real carrier text
  through the first usable turn, with content-fitting log layout. Rewardless
  lab blockers must not promise an item. This subset is repaired locally.
  Learned-spell enemy bonus, Goblin 5–10% boost/EVA exclusion and objective/
  blockade arrow remain separate pending increments; do not import a second
  objective owner over existing region-sensitive guidance.
- New remote snapshots now observed: PR99 7e52dfc adds objective repositioning,
  log below captions and pause backdrop; PR97 bbadaaf adds carrier/pause
  changes plus 6719ad2 floors/special sites/save pads/map polish, c943218
  first-person Grapple/rotating-wall collision handling, and bbadaaf
  whirlpool occlusion/fake-rock ambushes/Sonar Vision/door reach. These later
  maze changes are NOT integrated yet. Compare the nine-file semantic delta
  rather than replacing our maze, inventory, state or Battle wholesale.
- Preservation oracles for the new maze delta: route geometry/current map,
  Grapple mouse aim/fire/cancel restoration, actual caught wall movement,
  ambush versus real item identity, campaign checkpoint save/Load/rollback,
  key/relic separation, independent lab/maze bosses and contextual input.
  Adapt Marc's standalone `maze_save.json` pads to the established campaign
  checkpoint owner; never introduce a second save product that loses the
  reviewed opening or actual party state. Shared Whirlpool changes require
  outer-world regression too.
- PR96 Chrome Bomb Bot report: actual attack/victory/World-return checks pass
  on bundled Chromium/Apple M1 Metal and native Godot, including the reported
  PR96 URL. This does NOT establish Marc's Chrome/hardware crash cause or
  close his report. A no-input control fails instead of passing on ambient
  animation. Keep exact target/browser evidence and remaining uncertainty.
- PR96 progression discussion is not authorization for a global combat
  rebalance; keep that audit separate. The local animation/UI work neither
  claims final balance nor substitutes for full earned-route/polish evidence.

Commit and verify each delta against the same stable feedback alias. Refresh
remote heads before declaring all collaborator changes reconciled. Keep the
complete visual/audio audit loop below as the last release gate.

## 15. Final visual and audio polish audit loop

This is the final release-readiness gate, not a prerequisite for sharing the early combined feedback preview. Keep repeating complete audit rounds until one entire round finishes with zero observed defects within the declared integration scope.

For each round:

1. Record the exact combined source/deployed build, viewport sizes, save state and route.

2. Play from the normal entry through opening recovery, shallow puzzle, both independent destinations, full maze/secret-room route including both puppet waves, Cordys, defeat/recovery and cold load. Exercise the alternate branch order and inspect that puppet outcomes never clear the lab guards.

3. Inspect readability, clipping, overlaps, controls, feedback, media scale, model placement, collisions, lighting, transitions, music/SFX loudness and joins, revived actors, objective/checkpoint clarity and final-boss payoff.

4. Capture every observed defect with reproducible evidence. A passing harness must not overrule visible broken behavior.

5. When authorized, fix the defect, add the appropriate regression coverage, rerun affected gates and start a fresh complete round. A partial spot-check does not count as the clean round.

6. Stop only when a full round has no observed defects and the combined evidence matches the exact build presented for approval.

Report the scope and limits of the clean round honestly. Do not claim the entire game is globally bug-free, globally rebalanced or emotionally approved by players merely because the integration passes. Any unresolved blocking integration defect prevents a ready-to-merge claim. Record human approval separately before publishing the combined build.
