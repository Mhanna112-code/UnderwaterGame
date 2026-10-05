# INT-11–14: one continuous Cordys puppet encounter

October 4, 2026. Full Battle/MazeLevel/type reads carried forward; stage,
turn, outcome, enemy actor and secret patrol consumers re-read at 85cb116.

## Module contract

1. Public surface: Battle's pre-tree encounter_source, party_source, inventory
   and campaign relics; actual move/target menus, player_swing_staged and finished.
   Maze's real guard proximity and Yes/No confirmation owns the authored start.
2. Load-bearing rules: defeated enemies normally end a fight immediately; the
   normal win awards XP and partial recovery. Neither may happen at wave one.
   Party CombatantStats resources are shared, not rebuilt for another wave.
3. IO: seeded enemy choice, timed actor moves/deaths, queued turn callbacks,
   stage/UI ownership and maze save/reward callbacks. No new durable wave state.
4. Branches: puppet versus ordinary/lab/prologue; first versus final clear;
   living versus downed party; loss/escape versus win; saved versus unsaved
   completion. Both lab order flags remain independent of the maze outcome.
5. Types: existing encounter_source String provenance becomes executable for
   maze_puppets. Exact first roster is Angler/SwordfishDuelist/FrilledShark;
   second is BombBot/SwordSlayer, all existing Goblin-compatible actors. Maze
   consumes secret_boss completion and abyss_key, separately from campaign relics.
6. Existing gates: ordinary relic wins accept actual actions, but no gate checks
   waves. Lab/prologue actor gates cannot accept a maze finale or puppet battle.

## Ranked catalog

| Failure mode | Blast radius / plausibility | Cheapest meaningful oracle |
| --- | --- | --- |
| Secret identity constructs Tethys or a random pack | Blocks approved content; both old maze branches set generic boss boolean | Public Battle source dispatch exact actor roster, then real approach/confirmation |
| First clear emits won, XP or recovery instead of wave two | Critical; existing _advance_turn directly calls _win | Clear through actual menu moves; no outcome/XP/refill, exact second actors |
| Handoff resets shared HP/O2/effects or retains dead targets/queue | Critical; stage constructor also constructs party | Observe same stats/resources, consumables and turn/effects under actual second-wave actions |
| Puppet win clears lab blockers or grants repeat maze keys | Critical; reward/scene ownership is outside Battle | Actual maze final callback and save/load, independent lab flags, once-only trigger/reward |
| Mixed silhouettes obscure each other or cards/targets clip | High; current lane was tuned for small ordinary packs/solo blockers | Native actual stage/attack/handoff captures, not a model gallery |
| Removing NOW at the handoff shrinks the turn bar but leaves a grey stage gap | Medium; stage top only refits on unrelated bottom-menu changes | After real wave signal and layout frames, rendered rectangles must meet; reproduced in all six resource shapes |
| Final victory still shows a turn cursor/NOW and a defeated opponent as Next | Medium; _win hides menus but not queue/cursor ownership | After actual final finished, visible victory UI has no active-turn labels or cursor |

## First test and self-critique

Start an actual Battle with public encounter_source=maze_puppets and the three
normal source divers. Require exactly the first three existing actor identities.
Random-but-stable output cannot pass; a private helper is not the entry point.
Direct scene construction is a disclosed consumer fixture, NOT normal maze
reachability, difficulty, wave continuity, reward or visual acceptance.

After that red is repaired, clear the first wave through available real move and
target buttons. Require one continuous Battle with the second roster, unchanged
source identity and no intermediate finished/XP/recovery. Later generated cases
cover varied active/downed/resources where the state invariant permits it.

## Skipped / not accepted yet

Global combat rebalance, stronger ordinary Deep enemies and rejected PR88 story
boards are out of scope. Full maze navigation, reachable kit/resource paths,
campaign Cordys, browser storage and audio listening have their own gates.
No artificial HP, forced winner, direct damage helper, perfect QTE or injected
finished signal may serve as legitimate-win evidence.

## Evaluation

Caught and repaired: public puppet identity produced an ordinary pack; first
clear ended the encounter and awarded XP; real maze confirmation still dispatched
Tethys. Native inspection exposed overlapping silhouettes, a grey handoff strip
(all six resource shapes) and stale NOW/cursor/dead-next UI at final victory.
Formation, resize ownership and victory ownership were repaired and inspected.

O2 [100,84,67] × potion [0,2] cases conserve exact stats/actor identities, HP/O2,
XP, level, evasion pool, base stats, statuses, temporary costs and inventory at
the real wave boundary. No intermediate finished signal or XP is accepted.
The legal level-5, 100-O2/two-potion consumer clears both waves in 14 real menu
actions with normal 10-HP divers, no injected QTE success or damage/outcome.
One diver dies; both waves' 92 XP is awarded once at actual final victory.
This is not proof that normal maze travel supplies that kit/resources.

Threat-first accurate attacks won; targeting Bomb Bot's armour and inaccurate
Heavy Slam lost. These strategy probes do not justify a global stat rewrite.
Native 1x wave/final/approach/confirmation pictures were inspected at 1280×720.
Other viewports, full attack envelopes, once-only maze-key reward, interrupted
recovery, browser storage/input and audio listening remain unaccepted.

Excluded fixture findings: wrong source-model name, observing a freed actor
without caching its public identity, wrong scene extension and native approach
facing away from the guard. The latter was corrected with parsed mouse aim,
not a production camera change. A nonexistent regression script returned exit 0
with a Godot error; it is not a pass. Prologue combat, tutorial win handoff,
initial-down recovery, secret continuity and input ownership are clean.
The isolated relic-consumer rerun passes eight actual wins. Its earlier one-frame
narrow-resize finding under concurrent load remains an unresolved layout-timing
observation, not a claimed repaired game defect.
