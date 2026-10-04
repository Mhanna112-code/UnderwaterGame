# INT-03: campaign relics must reach victory-time spell consumers

October 4, 2026. Targeted complete reads: Battle, MazeLevel, SpellTree,
CombatantStats, InventoryMenu, Items, Cast and EnemyRoster. This is a consumer
integration gate, not proof of legitimate full-route progression or balance.

## Module contract

1. Public surface: normal World proximity entrance transfers party and relics;
   `KeyDoor.interact` consumes a maze key; a diver's `encounter_triggered` signal starts
   the actual strong-room Battle. Visible attack/move/target buttons win it.
   Victory automatically learns/equips affordable spells on the actual divers.
2. Load-bearing comments: SpellTree deliberately receives relics from its caller
   and assumes no World owner. Battle's old comment says World is inventory-only,
   but its victory path also reads World.key_items and otherwise supplies nothing.
3. IO: scene destruction, randomized roster/turns, asynchronous animations and
   victory announcements. No save writes. Fixture XP uses ordinary gain_xp and
   automatic learning without changing baseline HP/stats or synthesizing a win.
4. Branches: World versus Maze Battle owner; relic present versus absent; prerequisite
   learned versus not yet learned; reward relic versus pre-owned relic; downed
   members still earn XP. This gate covers pre-owned relics and normal living party.
5. Types: campaign `Array[String]` relic IDs are distinct from Maze's spendable
   key count/IDs. Independent expected spell IDs are tidal_revival, guard_break,
   riptide_slash and tidal_burst; current_pearl requires earlier riptide_slash.
6. Prior gates: handoff/checkpoint tests retain relic arrays, but never win a
   maze battle. Lab balance tests construct Worldless fights with no relics.

## Catalog and tests

| Bug | Impact / plausibility | Test / status |
| --- | --- | --- |
| Worldless maze victories silently miss owned relic-gated spells | High: earned progression disappears; victory explicitly falls back to [] | Caught and repaired; real win red→green |
| Maze door keys are treated as campaign spell relics | High: ownership conflation grants/consumes unrelated content | Characterized: eight bounded present/absent cases with real door consumption and spell consumers |
| A second caption repeats the resize connection and logs an error | Medium: common battle announcement path emits an engine error and loses resize ownership | Caught during real battle; repaired with one owning viewport callback and all registered captions resized |

First test: reef_plate carried through actual entrance and door use must unlock
and equip Bucky's Tidal Revival after a real strong-room victory. After its repair,
enumerate four relic IDs × present/absent, placing the absent-case ID only in the
maze key list. Independent spell expectations reject both a silently empty source
and accidentally reading Maze.key_items. Each case must finish a real battle win.

Self-critique: no serializer/private win call or source-text assertion substitutes
for gameplay. Menu paging is exercised, not hidden move signals. Source state is
fixture-arranged but attainable via XP; it does not prove navigation or grinding.
Refactoring the relic owner preserves these semantic assertions. Wrong-but-stable
empty relics fail the expected skill; merged key owners fail the absent case.

## Skipped

- Full route/boss balance, downed-diver revival, reward-only relic learning and
  durable learned-kit reload are separate gates; not accepted by this test.
- Audio, art, mouse hit testing and human readability require rendered checks.

## Evaluation

The original real battle won in three normal actions but Bucky retained only
Heavy Slam/Mending Current, with five unspent points. It also emitted a duplicate
size_changed connection error. After the repair, eight real wins learn/equip the
independently expected spell only with its campaign relic; the revival is offered
by Party Spells. Multiple captions also resize together at 360px width.

Removing only the production relic assignment again makes the identical oracle
fail both learned/equipped skill and actual Party Spells availability, with no
script/engine errors. This is a disconnected-handoff mutation check, not a second
independent defect. Actual checkpoint and menus/title regressions pass.

Early nonexistent popup close/signal names were harness errors, corrected and
excluded from game evidence. The initial failed run and clean disconnected run
are distinguished in saved receipts. No saves were written by this consumer test.
