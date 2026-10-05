# Earned campaign journey catalog — October 5

## Module responsibility and scope

First faithful journey slice: genuine normal chosen-slot New Game → real
non-skippable opening/initial Angler/Cordys defeat/recovery → normal physical
swimming with ordinary encounters enabled → Bomb Bot → Sword Slayer → Tethys
→ recovered-computer payoff. No stats/XP/spells/items/victory/position or route
milestone assignment. This first lab-first slice is NOT whole-campaign
acceptance; maze-first, maze puzzles/earning/recovery/puppets/Cordys and a seeded
casual/skilled matrix remain to be added after the first boundary is sound.

Read production opening video/prologue cinematic, full RouteState/SaveManager,
new-game/recovery/actual input/deep blocker/lab/result/maze handoff consumers,
SpellTree and Battle victory/status exit contracts. Existing route fixtures
were read fully: world_maze_route uses real swimming but completed-opening/
encounters-Off fixtures; lab_route_live teleports; lab_boss_balance grants XP.
Neither may support the broader earned-journey claim.

## Public interface and load-bearing contracts

- CLI `godot --headless --path . --script verify/earned_campaign_journey.gd --
  --policy=skilled --seed=64000` (casual policy also supported).
- TitleScreen's public chosen-slot New Game signal with a separately owned
  high-numbered slot, real InputEvent keys/mouse, visible enabled move/target/
  Continue/Close/Skip controls, actual terminal result and saved milestones.
- Initial movie/Cordys split is non-skippable; wait for real decoder/lifecycle
  or visible fallback acknowledgment. Lab's public Skip Cutscene is allowed.
- Normal wins grant no refill; production earned XP level-up/rest rules alone
  may recover. The same World party is retained throughout. Random encounters
  remain enabled for baseline/direct and ordinary rest-return probes. A
  separately labelled safe-return policy uses actual R to disable them only
  during emergency rest travel and restores On before the boss; never pool it
  into an always-On success rate. Optional training never supplies recovery.
- Route planner may inspect physical collision for waypoints, but moves only
  through real W/mouse inputs; it never teleports or removes collision.

## IO, branches and type contracts

IO: actual videos/physics/collisions/animation timing, seeded production RNG,
native slot/manual+auto+pending files, logs. Refuse **any** preexisting owned
slot file; cleanup only files belonging to this run. Engine time acceleration
changes run speed, never HP/XP/O2/RNG results or QTE success; no X input is given.
Branches: title/video/quiet spawn, battle/menu/turn/movie/recovery, policy,
affordability/learned move/living target/heal, paused reading, random encounter
reveal, route arrival/collision failure, lab state and Game Over. Phase/source/
blocker enums are owned by RouteState; enemy names/moves by Battle/actor data.

## Ranked catalog

| ID | Failure mode | Impact / plausibility | Cheapest faithful test |
|---|---|---|---|
| EARN-1 | A supposed earned lab route silently supplies progression or bypasses travel, hiding the first real attainability wall. | Critical / confirmed in old fixtures. | Actual New Game plus physical input and real wins; record every carried level/XP/spell/HP/O2 and terminal loss. |
| EARN-2 | Real recovery leaves a fresh level-one party unable to defeat mandatory blockers/lab without perfect dodges or borrowed healing. | Critical / no-refill economy and low HP. | Seeded casual/skilled normal move policies, no X; current source Battle consumer, earned kit only; later matrix floors fixed before results. |
| EARN-3 | Navigation or modal ownership strands the earned run before any balance result can be observed. | High / geometry, cutscene, pause and encounter handoff composition. | Collision-valid planned swim, real movie/popup controls, bounded actual-arrival progress and fail at first blocked boundary. |
| EARN-4 | The genuinely earned laboratory victory checkpoints the milestone but drops party resources/learned moves or replays the payoff after cold Title Load. | High / composed reward, modal and save boundary. | Compare the actual earned party with native saved JSON; destroy World, choose real Title Load, verify conserved party/milestones/bytes and no replay. |
| EARN-5 | An attrited party cannot physically reach an existing recovery point and return to the unlocked lab, making a recovery-aware strategy impossible. | High / one shallow rest point, travel attrition and persisted guard geometry. | Explicit optional recovery policy uses actual return swimming/contact, checks full party restoration and unchanged defeated guards, then physically returns; never calls fill/heal/save handlers. |

Self-critique: wrong-but-stable percentages/screenshots cannot pass EARN-1;
the actual chain and unchanged initial level-one/no-spell state must be seen.
No private handler or combat resolver is called. Node observations read state
but only public input/control signals change it. A behavior-preserving refactor
can retain the player action contract; planners/labels may need adapter updates
but assertions remain actual outcomes/resources, not helper-call counts.

## Skipped in first slice (required follow-up, not removed scope)

Full maze-first/lab-first completion, actual ability puzzle/required anchor,
earned chest/key/relic/puppets/Cordys/rest and save-return routes; matrix across
at least eight seeds per policy; measured human skill and visual/audio browser
acceptance. Do not label this first lab-only probe campaign-ready.
Deferred final Tethys opening/relocated Cordys intro remains untouched.

## Evaluation after initial runs

Observer defects, not game regressions: initial GDScript multiline syntax,
revisiting a modal freed by its Continue, selecting a named foe for Flash
Blast's `All enemies` target, base move `name` versus spell `display`, and
planning into a closed pressure-field center instead of its real approach.
All failed receipts are retained. Corrected skilled probe completed genuine
opening/recovery, four random fights, Bomb Bot, Sword Slayer and Tethys:
eight fight owners/42 move actions, earned level3 and cleared laboratory,
exit0 with no engine/script errors. No ordinary victory healing or X input.
This is one exploratory sample, not a guaranteed success rate or whole campaign.

Production global RNG is seeded, but native video/frame timing can change its
shared consumption: a seed is an input/receipt label, not a promised identical
roster on replay. Record actual encountered rosters and carried resources.
The future full-route matrix must retain the existing casual≥50%/skilled≥80%
floors with at least eight predetermined seeds per policy; one sample cannot
establish those floors. Loss is a measured outcome, not grounds to fabricate
kit, add removed heals, or silently weaken thresholds.

EARN-4 is the next test after the original slice is sound. Self-critique:
milestone-only or empty-party saves cannot pass the independently observed
earned HP/XP/level/spell comparison and no-repeat cold Load. Only normal
Title Load consumes the saved data; the observer never calls a restore helper.

Follow-up seed64002/skilled, **direct/no-rest** policy, lost to actual lab
Tethys after Sword Slayer killed Scuba. This is preserved, not changed to a
passing receipt. EARN-4 was not reached; no durability claim from that run.
This exposes a real attrition scenario, not yet a proved recovery-access bug.
Next examine the existing recovery system through a separately labelled
`--recovery=existing-save-point` policy. Do not compare that policy's win rate
with no-rest samples without identifying the policy difference. Base casual
and skilled move choices remain unchanged. EARN-5 uses public input plus
actual contact/resource/guard-conservation assertions. Source audit is needed
as well: replacing travel with a teleport could otherwise trigger the same
Area and fool outcome-only assertions. The current observer assigns no
position/stats/progression, calls no fill/restore helper, and uses no training.

The ordinary rest-return64002 probe also lost: after Sword Slayer left only
Bucky living at7HP, a genuine Swordfish encounter killed her before the shallow
save point. Recovery is physically distant and risky, not proved impossible.
Investigate existing player risk-management before adding new game mechanics:
`--recovery=existing-save-point-safe-return` uses real R inputs for the emergency
round trip only, then restores On. It is a different disclosed strategy, not
an always-On fix or a win-rate substitute. Casual64003/direct also lost at the
laboratory after entering with Scuba2HP, Musashi0HP, Bucky10HP; preserve it.

Skilled64004 reached an actual earned lab victory and native cold Title Load,
seven fights/34 actions, exact party/manual bytes conserved, no repeated
payoff or fight. Its conditional recovery branch was not taken: Bucky6HP did
not cross the half-health threshold. Therefore it proves EARN-4, **not** EARN-5
or the R-protected return. The explicit safe-return probe now schedules one
pre-boss visit independent of the damage threshold, making that branch
observable instead of depending on a particular random attack roster.

Scheduled safe-return64005 reached the actual shallow point and restored the
party's HP. Its strict Oxygen-max assertion saw Scuba97 instead of100 because
normal Sonar spent3 after restoration. This is an observer ownership/timing
defect, **not** a proved partial-heal game bug. The explicit rest policy now
uses real Q to suspend Sonar during the round trip, preserves the exact full
rest assertion, then restores the prior Sonar preference with Q before lab.
No stats or drain timers are assigned and the always-On baseline is unchanged.

Final scheduled64005 probe now passes EARN-5 and EARN-4: genuine rest contact
restores all three HP/O2, actual swim returns with guards preserved and R/Q
restored, Tethys is defeated in11 real moves, and native cold Title Load
conserves earned level3/XP60/spells/manual bytes. Eight fight owners/39 total
moves, terminal exit0, no engine/script errors. Source/receipt hashes and raw
failures are recorded in `docs/evidence/earned-balance-oct5/newgame-lab`.
No production runtime repair is claimed from the observer correction.

Adversarial observer boundary: unsupported policy exits1 before World or slot
ownership with a named finding; no engine/script error. Other unenumerated
risks remain preexisting-slot ownership and frame/RNG cross-feature timing.
The former is guarded for files and directories; the latter is disclosed,
not described as deterministic roster reproduction. Complete route/matrix
and browser durability acceptance remain unproven.

Fresh upstream f457098 changes the opening to direct Cordys and removes the
retained initial Angler. A current-runtime exploratory run exposed a false
positive in EARN-1: dispatch briefly labels the direct boss `prologue_angler`,
so source-only observation accepted it. Strengthen the boundary to observe
the actual visible roster before any action; Cordys-only must fail explicitly.
This pins Miguel's retained-Angler requirement, not the dispatch implementation.
No production opening repair is permitted during these intervening batches.
The existing historical lab receipts apply only to runtime6b8ea07, not these
new combat/recovery/tutorial/geometry changes. Source snapshots preserve that
distinction. A future intentionally approved opening-contract change must be
explicitly reconciled, not silently weaken this assertion.

## Current downstream observation, not opening approval

`--opening-contract=observe-current-cordys` is a separately labelled diagnostic:
it demands the actual current Cordys roster, plays its real defeat/recovery,
and measures downstream lab-first combat using only genuinely earned resources.
Every receipt explicitly records the retained Angler missing and the opening
unapproved. The default `retained-angler` assertion is unchanged and still
fails current main. Unsupported contracts fail before scene/slot mutation.
This avoids both fabrication of opening milestones and treating the postponed
opening review as a reason not to investigate current downstream balance.
It is not full campaign acceptance or a replacement for the eventual approved
opening plus eight-seed-per-policy maze-first/lab-first completion matrix.

First current-source observation on343e37c reaches genuine Cordys defeat and
full production recovery (level1/XP0/no spells), but the first ordinary Angler
fight times out before any move action. No loss or balance win is inferred
from that stalled boundary. Retain the raw failed receipt and investigate the
actual visible action/reading owners before changing combat balance. The
observer now records paused/busy/menu/actor state and visible buttons while
waiting; this diagnostic does not mutate the game or acknowledge unseen UI.

The follow-up UI receipt identifies an observer defect: the actual first
post-recovery fight is the guided tutorial, with its move list open directly.
The old driver waits for a hidden main menu. Follow enabled visible move
buttons and target inspection/click masks, as the standalone full-lesson
verifier does, without assigning a tutorial step or making a perfect X dodge.
Keep both timed-out receipts; do not label them combat losses. Normal battle
choice policies and the default retained-Angler opening failure stay intact.

The guided observer completes all real teaching moves and wins with no X input,
then exposes a second observer defect: post-combat ability pages offer Next
before Close. Waiting for Close alone leaves legitimate reading pause active
and falsely reports blocked swimming. Acknowledge the actual visible Next/Close
buttons page by page; do not close the modal by private method, change pause,
or supply movement/progression. Preserve this failed receipt as well.

Paged current observer reaches genuine level3/XP58 and defeats Bomb Bot after
seven ordinary random-fight wins, but then enters a first-special practice
site before Sword Slayer. The driver follows combat teaching but supplies no
minigame inputs and treats its soft loss as an ordinary party defeat. Two
overworld party members are still alive; this is not evidence that the party
cannot beat normal enemies. Record tutorial/special flags as well as the stale
`random` encounter-source label; fail explicitly at the unsupported special
boundary until genuine minigame or normal public return handling is added.
The raw original loss receipt is retained, not counted as a campaign pass,
ordinary-loss rate, lab victory, or whole-campaign balance result.
