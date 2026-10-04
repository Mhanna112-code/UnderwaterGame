# Maze and campaign integration audit log

## October 4 2026 foundation inspection

Previous goal turn classification: progress. The saved plan was materially updated to include approved puppets and verification contracts. This continuation read the objective file and refreshed current sources; no previous integration process was live.

Observed sources: current main f9ae00c, PR96 27a5b52, PR98 c3da257, PR97 55e8515. Full IDs are in the runtime manifest. The isolated opening and maze review builds are not combined-build evidence.

Actions: created clean integration/maze-campaign checkout; preserved unrelated generated changes in the opening checkout; saved Page revision 5 and initial execution artifacts before functional changes.

Tests: none run in this entry. Runtime, audio, web/native and human acceptance remain unverified. Initial catalog risks are code-inspected or approved-contract gaps, not claimed reproductions.

Next: integrate baseline, record actual conflicts and first behavioral reproduction; preserve failed evidence and separate harness failures from game failures.

## October 4 2026 semantic merge reconciliation

Previous conversational turn supplied goal text without changing implementation; classified no implementation progress. Revalidated the active objective, unchanged PR heads and unfinished local merge, then took the next safe source action.

Baseline: 493b1d8 merges current main f9ae00c and reviewed opening c3da257. Pending maze parent: 55e8515. No unrelated opening-checkout edits were discarded. Generated import metadata was temporarily stashed separately before the maze merge and regenerated rather than blindly replayed.

Resolved eight runtime-file conflicts and the map-test conflict per hunk. Preserved GameAudio, current strings/status glossary, clean uncropped Grapple video and modern menu layout; added Marc's popup layer/live Control demos, standalone inventory adapter and revived stage actor handling. Retained Marc's maze-specific puzzle initialization, proximity discovery, L-map controls, independent wall/current manipulation, live geometry-derived current paths and map help. Removed duplicate map color constants caused by automatic merge. Map expectations now describe those real controls, not the obsolete H-driven current relocation.

Corrected the Door.fbx resource path's filename case. Disabled the sphere-room developer starting override for production. Obsolete import sidecars for three already-absent portrait sources were removed; the actual images had already been removed in the baseline. Conflicting portrait imports had identical settings except UIDs, so the current stable UIDs were preserved. Other generated metadata was regenerated; this did not delete source assets.

Godot import exited 0 with no script/parse errors. Generated missing-UID warnings were retained in /tmp/underwater-maze-campaign-merge-import.log, not misreported as a flawless cold checkout.

Focused existing gates: maze_minimap, enemy_moves, opening_prologue_state, deep_zone_maze_transition and ability_popup_video all exited 0 with no script errors; complete short receipts are saved alongside this audit. These are narrow baseline checks, not integrated campaign acceptance. The transition gate checks scene/HUD presence only; a fresh party still passes it. No real puppet/Cordys victory, coherent maze checkpoint, normal traversal, listening round, web export or native package is proven.

Next action: read the state consumers completely, write the INT-01 conservation reproduction, and repair the actual World-to-maze party/inventory boundary. Do not move to delivery with this known state-loss risk unresolved.

## October 4 2026 INT-01 live campaign handoff

Source before change: 2e19f29. Read World, MazeLevel, secret excursion, Diver, CombatantStats, RouteState, SaveManager, SceneHandoff, TitleScreen and relevant spell types completely; module contract saved in the bug catalog.

Reproduction: new accepting gate `maze_campaign_handoff` constructs six bounded valid party configurations (every active diver, with/without a downed companion). It uses actual SpellTree learning and the normal physics proximity entrance, not the private transition method. Expected stats, effects, kit, inventory, relics and campaign flags are independently recorded before scene replacement. All six failed, with 166 loss findings and no script errors. An initial invalid SpellTree fixture was corrected before reproduction and is not game-failure evidence.

Repair: a single-use SceneHandoff transfers a CampaignSession; MazeLevel retains the real CombatantStats resources and inventory and applies saved earned kit, ability lock and Sonar clock to its replacement nodes. Campaign relics remain separate from Marc's door-key list. Global encounter preference is retained without overriding the strong room's forced-encounter policy. The outer checkpoint/selected slot are retained by the session for subsequent persistence work. Failed scene construction releases the pending handoff and exposes retry rather than leaving stale state for another review.

Verification: new six-case gate, existing deep_zone_maze_transition, maze_minimap and opening_prologue_state all exit 0 with no script errors. Godot import and diff whitespace check pass. Receipts saved under docs/evidence/maze-campaign-integration/.

Limits: fixture deliberately begins near the entrance and skips onboarding; no normal-navigation or visual proof is claimed. This is a live handoff, not durable maze loading. Secret-room return still reconstructs state, Maze battles still contain placeholder Tethys dispatch and recovery, and campaign relic access in maze spell consumers remains to integrate. No web/native export or preview was published. Continue state/recovery before delivery.

## October 4 2026 INT-02 secret continuity

Source before change: 96f6752. Refreshed PR97/98 heads remain 55e8515/c3da257. Completed additional source reads for MazeMiniMap, ItemOrb, posters and interaction dependencies; catalog records the public contract. No unrelated workspace was modified.

Valid reproduction found that `_build_secret_wall_entrance` was never called. After restoring it, actual E/Esc scene transitions exposed seven state losses: active diver refill, inventory/key reset, party damage/downed reset, reclosed door/collision, reset wall, missing pending reward and respawned consumed rock. An initial missing-node test error was repaired before the valid reproduction and is excluded from evidence.

Repair carries CampaignSession through FlowField and records a plain-data maze snapshot: physical walls/currents, puzzle flags/home transforms, keys/doors, remaining rocks/pending pickups, poster permutations, levers, Sonar Vision, boss-trigger ownership and map discovery. A second meaningful failure showed that storing open transforms without rotation-home transforms left walls unable to close; now all three wall sets close to their real homes after return. Pickup construction options are applied before `_ready`. Pending puzzle/reward animation blocks transition; repeated scene entry is latched and scene-construction failure exposes retry.

New continuity gate plus handoff, map and opening-state regressions exit 0 without script errors. Gate registered in accepting suite. The older maze_completion gate fails at the first H-era waypoint; its now-obsolete route/current assumptions are recorded, not weakened into a green claim. Full normal traversal remains open. No cold saves, battles, visual/audio acceptance or deployment is claimed. Next: INT-04 durable scene/checkpoint recovery. Disk now has about 3.2 GiB free; avoid unnecessary export copies.

## October 4 2026 INT-04 native checkpoints and recovery

Source before change: dc2e207. Refreshed PR97/98 heads remain unchanged. Read checkpoint/menu/GameOver/BrowserCheckpoint consumers and existing persistence/load tests; added the six-section module contract before the new test. Valid red reproduction: normal maze had no identifiable save/recovery point. Invalid onboarding and numeric dictionary-equality fixtures were corrected and excluded from game-defect evidence.

Added an identifiable entrance-area SavePoint, existing SavePointMenu/P interaction and deliberate rest that restores all party HP/Oxygen. Versioned CampaignCheckpoint serializes actual earned kit, finite stats/Oxygen/effects and plain maze geometry, keys, posters, discovery and pending pickups. The complete record is shape-validated; scene references are checked before puzzle restoration. Old flat World checkpoints remain loadable, and legacy maze-entry checkpoints return to a usable outer entrance. Maze checkpoints route cold Load into Maze without replaying a completed opening. Real defeat now presents exclusive Game Over and uses the selected saved checkpoint, replacing silent healing/teleportation. Failed writes preserve the old checkpoint; browser rejection rolls the RAM file back using exact original bytes, although actual browser storage-denial acceptance remains pending.

New actual checkpoint test passes Save/P, cold Load, native write rejection, saved/unsaved physical state rollback and an enemy-caused defeat/Restart (six real player actions, no injected outcome). Generated IO test passes 24 valid party combinations and 40 malformed records, plus two actual actionable Title Load failures with unchanged bytes. Seven affected regressions also pass: handoff, secret continuity, map, opening state, World persistence, invalid load and slot switching. All nine final processes exited 0 with no script errors, registered accepting gates and clean diff whitespace.

Limits: native headless state/recovery evidence only. Full route/boss balance, World return/re-entry and saved maze history, actual IndexedDB denial, human checkpoint discoverability/input usability, listening/rendered audits and exports remain open. No preview published and no main/public build modified. Next concrete action: World return/re-entry conservation before advancing state acceptance.

## October 4 2026 INT-04 World return and saved maze history

Source before change: a5c8f15. The new accepting reproduction failed cleanly: there was no explicit normally reachable campaign return from Maze. Catalog records the six-section contract and bounded 12-case generator before implementation.

Added an explicit E exit at the entrance, without changing Marc's puzzle geometry or auto-exiting newly spawned players. It is blocked during unstable puzzle/modal/map/swap state. A single-use return handoff restores outer-world geometry and the actual live party resources/kit, not a healed or reconstructed party. Return positions lie outside the automatic entrance radius in its protected approach. Failed scene construction clears pending handoff and permits retry. World checkpoints now carry versioned maze history with explicit world scene identity; repeated entry reuses that history rather than creating a blank maze. Checkpoint envelopes are not recursively nested. Tethys/lab/blocker ownership stays independent.

Actual proximity entry → public key-door interaction → physical E exit → World menu save → cold Title Load → proximity re-entry passes all 12 combinations (three active divers, living/downed companion, maze-first/lab-first flags). Checks require actual live resource identity, unchanged damaged/downed HP/Oxygen and earned kit before rest, no immediate entrance bounce, retained inventory/relic/preference and physical open door/spent key after cold reload. Lab-state setup is disclosed as a conservation fixture, not a real boss victory. Nine affected native regressions also pass, all exit 0 without script errors.

Limits: exit label/menu presentation still needs rendered inspection; browser storage denial, full puzzle traversal and real independent-route wins remain open. No export/deployment performed. Next: inspect current entrance/checkpoint at actual viewports and continue consumer/input integration.

## October 4 2026 INT-08 checkpoint presentation

Source before change: 529ba0d. PR97/98 heads remain 55e8515/c3da257. Godot 4.7.1 Compatibility/OpenGL on the local macOS display rendered actual entrance, checkpoint contact and mouse-operated slot picker at 1280x720, 720x480, 720x900 and 360x640. No user slot was written. Native captures exposed oversized world labels, clipped narrow-screen HUD/menu controls and overlapping recovery/instruction text.

The valid isolated old-menu reproduction clips all three slot buttons and Back at 360x640. A stabilized real mouse test at 1280x720 passes with the old menu: the earlier missed-click result was a test timing/global-position defect, not a game input bug. That diagnosis is explicitly retracted; it is not counted as red game evidence.

Repair removes menu hard width floors, wraps maze controls within minimap clearance, constrains captions to the viewport and gives recovery announcements exclusive ownership of the bottom reading area. Smaller landmark labels suppress partial edge/upper-HUD fragments. All four rendered tests pass; twelve final entrance/contact/slot images were inspected. Seven affected headless checks passed before the final label-visibility-only adjustment; checkpoint/map/World-return checks are rerun on the final increment. Label suppression is only checked at these sampled views, not every camera angle.

This scoped UI evidence does not accept the full maze art, current-route traversal, actor/attack framing, browser storage, audio or the complete zero-defect audit loop. Next: campaign relic consumers and contextual input ownership. No export/deployment or public/main change.

## October 4 2026 INT-03 actual relic consumers

Source before change: e2d0024. Battle's victory path ignored all pre-owned relics
when its owner was Maze rather than World. Actual strong-room victory with Reef
Plate and five unspent points left Bucky without Tidal Revival. The same run
exposed a repeated caption resize-signal connection error. Early harness API-name
errors were corrected and excluded; they are not green runs or game defects.

Battle now receives an explicit campaign-relic source, separate from Maze's key
IDs/count. Eight bounded relic-present/absent cases use actual World entry, real
door consumption and visible battle/move/target buttons. All finish won in three
normal actions; all four independent gated spell expectations hold. XP preparation
is an attainable-state fixture, not full-route grinding/balance proof. No HP/stat
inflation, injected outcome, perfect timing dodge or save write occurs. The real
Party Spells menu exposes learned Tidal Revival only in its eligible case.

Captions now share one owning resize callback; multiple captions resize together
at 360px without duplicate signal errors. Disconnecting only the relic handoff
reproduces skill/menu loss cleanly; restoring it passes. Native checkpoint and
menus/title regressions also pass. Receipts distinguish initial reproduction,
clean disconnected-handoff mutation and repaired evidence. Full maze navigation,
combat revival, contextual input, waves/finale, browser/audio and deployment remain
open. Next: prevent map/save/swap surfaces from taking each other's inputs.

## October 4 2026 INT-06 contextual input ownership

Source before change: c58b26f. Actual L/P at the contacted checkpoint reproduced
two simultaneous surfaces: overview map and SavePointMenu. Repair lets the map
own inputs before checkpoint/inventory/abilities, and gives Swap selection
priority before save keys. MazeMiniMap cannot open over an active selection.
Marc's L/E/R controls and local forced-room decision remain intact.

Nine generated owner × active-diver cases pass via parsed press/release events;
save/map/Swap never stack or steal active identity. Actual E rotates a discovered
wall and R moves the same live current while campaign encounters remain Off.
Nine local-policy cases verify outside-room/no battle, inside developer Off/no
battle and inside local On/actual Battle despite campaign Off. Swapping activation
uses the public selector fixture; only Maxilani has Swap in normal play. Placement
near interactions and public encounter events do not prove full navigation.

Map, actual checkpoint/death recovery and twelve World return/history regressions
pass. Native 360x640 and 1280x720 P/mouse checks pass; six final checkpoint/menu
captures were inspected. This is not complete four-size overview/route/battle art
acceptance. Initial wrongly named checkpoint was a harness script error, excluded.
All accepted final processes exited 0 with no script/engine errors. No preview,
export, main/public update or user-save writes from new input/presentation tests.

Available disk is approximately 1.9 GiB; package/export planning must avoid
duplicating heavy output, but it has not blocked these state/input checks. Next:
real downed-diver combat revival, then current-input physical route verification.

Test-oracle hardening on 8ba4c92: caption resizing now checks actual visible HUD
Label rectangles against the viewport instead of a private caption registry.
Current placement finds the real CollisionShape3D rather than depending on child
index order. The same eight real relic wins and all generated input/policy cases
pass after this behavior-preserving fixture change, with no runtime errors.

## October 4 2026 INT-07 initially downed combat recovery

Source before change: 50b3b0a. A real earned Tidal Revival restored HP/card and
actual turn, but enlarged an initially downed actor by reversing a shrink it never
underwent and lifted it above its home. An initial captured-scalar fixture error
falsely reported no usable turn; corrected observation storage cleanly isolated
the two real scale/home findings. That contaminated run is not counted as proof.

Spell revival now uses the existing potion stage rebuild, retaining the source
resource and discarding old hidden/faded visual state. Five supported identity ×
method cases pass actual visible Attack/Items/target actions, exact payment,
normal HP maximum, actor/card restoration and a genuine next-turn attack. Native
OpenGL runs also pass; all five captures were inspected. Three affected checks
(combat lifetime, eight relic-consumer wins, menus/title) pass with no engine/script
errors. Receipts and the six-section catalog disclose direct Battle/XP fixtures.

This is recovery consumer evidence, not normal-route resource attainment or full
battle polish. Newly downed combat, downed world steering/caster eligibility and
browser durability remain separate. Native spell captures expose dark +10 HP text
against water; recorded as open INT-08 feedback contrast rather than overlooked.
No export/deployment/public update. Next: physical traversal with Marc's actual
current/map controls, not the stale H-era completion route.

## October 4 2026 first physical current channel

Source: d0fe9ed. New current-route catalog precedes the physical test. The old H
traversal expectations no longer match Marc's published controls. No maze geometry,
current strength, collision or encounter policy was modified for this check.

Normal scene spawn → actual Tab to Bucky → parsed W/mouse discovery → L/E to open
walls → R to move current1 → physical outer approach → Shift-arrow/R to relocate
current3 → physical channel crossing passes headless and native OpenGL. Trace
must cross the current channel's interior, not a side/perimeter bypass. Production
physics never stops; no diver position is written and no rotation helper is called.
The deliberate leave-current3 negative variant fails at the live current edge
with actual push, proving the driver cannot simply swim through an active block.

Initial undiscovered-wall/far-end/whole-boundary-interior assumptions and a typed
fixture parse warning were corrected and excluded from game-defect evidence. Two
native captures were inspected: visible Bucky, unobscured wide-screen HUD and
discovered map/control lines. This is one channel, not full puzzle/secret/finale
traversal or four-size map presentation. Only the obsolete local H traversal gate
is replaced; full legacy completion stays open. No preview/export/public change.

## October 4 2026 recovery feedback and support gesture

Source: df4fdf2 plus the recorded INT-07 visual follow-up. Real Tidal Revival
casts produced a valid red in both recipient cases: glyph opacity faded while
the separate black outline remained opaque. Repair holds readable text briefly,
then fades glyph and outline together over the unchanged total lifetime. The
existing feedback handler already restored the actor; its redundant late rebuild
was removed so that restoration has one owner.

Production-speed native captures exposed a second defect: Bucky's fallback Hammer
arms obscured the healed recipient. Runtime inspection confirmed the delivered
1.15-second Proto5 thumbs-up Start gesture. Only Mending Current and Tidal Revival
use it; actual attack mappings remain unchanged. The before pictures are retained.
Both new hold pictures and all five later potion/spell pictures were inspected:
normal actor scale/home, visible recipients and readable cyan healing text during
its hold, followed by a clean fade. Five actual recovery cases pass headless and
native 1x; clip inventory, three-rig animation, eight actual relic battles, combat
content and 20 effect-pool cases are clean without script errors.

An 8x native PNG/readback run exhausted the one-second label lifetime and produced
an invalid missing-label finding. It is excluded; native capture now runs at 1x
and does not lengthen production feedback to accommodate the harness. Hammer
attack framing, newly downed recovery and whole battle-art acceptance remain open.
Disk recovered to about 6.6 GiB before this checkpoint; no assets were deleted by
this work. No export/deployment/public change. Next: real puppet-wave dispatch.

## October 4 2026 continuous puppet encounter

Real guard proximity/Yes starts the authored three-enemy wave; actual moves clear
it into Bomb Bot/Sword Slayer without Battle reconstruction, XP, refill or final
outcome. Six O2/potion cases conserve exact party/actor identities and HP/O2,
statuses, evasion, temporary costs, inventory and progression. The legal level-5
baseline with 10-HP divers wins in 14 actions and awards both waves' 92 XP once.
This is a consumer fixture, not an earned-kit/full-maze playthrough claim.

Native 1x inspection exposed and repaired overlap, a grey wave-handoff stage gap
and stale NOW/Next/cursor at victory. Wave1/2/final and guard approach/confirmation
were visually inspected at 1280x720. Wrong-camera fixture was corrected via actual
mouse aim; no production camera change was made to accommodate it. Native and
headless receipts are saved alongside the PNGs. Reward/save/loss/escape, full
attack framing, other viewports and listening remain open.

Affected prologue, tutorial handoff, initially downed recovery, secret continuity,
input ownership and combat feedback checks pass. Eight relic consumers pass an
isolated rerun; a prior one-frame resize finding under concurrent load is retained
as unresolved timing evidence. A missing-script exit 0 is excluded, not accepted.
No export/deployment/public change. Next: defeatable campaign Cordys.
