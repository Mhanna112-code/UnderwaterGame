# Maze and campaign integration bug catalog

Generated October 4, 2026 using design-tests. Initial cross-system scope from approved Page revision 5. These are risk/contract entries, not completed tests or reproduced failures. Expand module-specific public interface, branches, dependencies and IO summaries after complete targeted code reads and before each test.

## Observable contracts and IO

The production surface is world entrance, scene return, battle outcomes, public campaign/save state, door/key use, contextual input, real revival, audio owner and shipped exports. Boundaries include JSON save IO and selected slots, scene destruction/reconstruction, async battle/film callbacks, seeded combat/roster RNG, elapsed-time triggers, Godot import/export and served web/native bytes. Actor/species IDs and encounter source IDs are separate from completion/reward IDs.

## Ranked risks and accepting tests

### INT-01 module contract (complete source reads)

1. Public interface: World owns live divers, inventory, relics, RouteState and the selected save slot. Its normal proximity entrance changes scenes. MazeLevel owns the new playable divers and its real InventoryMenu; SceneHandoff currently carries only an active model for the secret excursion.
2. Comments versus implementation: saving before entry does not transfer state. Maze `_spawn_divers` builds baseline stats and empty spell lists, and maze inventory starts empty. A scene/HUD existence test cannot detect this.
3. IO/dependencies: scene replacement destroys World/Diver nodes; CombatantStats resources can survive through a retained owner. SaveManager writes an atomic JSON world checkpoint. Cold Load currently constructs World, not Maze: that separate INT-04 contract is not accepted by this test.
4. Branches: normal proximity entry requires completed prologue and an available maze door, independently of Tethys; explicit review entry bypasses this. Standalone maze review must still work without campaign state. All three active slots and living/downed party combinations matter.
5. Data and strings: fixed ordered model IDs identify party members; learned/equipped spell IDs, inventory counts and spell-unlock relics must be conserved. Maze consumable keys must remain separate from campaign relics. Stats include HP/Oxygen, level/XP/spell points, depleted EVA, statuses and temporary modifiers.
6. Existing tests: `deep_zone_maze_transition` checks scene/HUD only using a private trigger; opening-state and persistence gates characterize existing World behavior. New `maze_campaign_handoff` uses the normal physics proximity path and six bounded party cases with independent expected values. It deliberately places the fixture near the entrance: it does not prove navigation, cold maze loads or secret return.

### INT-02 maze excursion and snapshot contract

1. Surface: E at the secret panel opens FlowField; Esc or its far-end exit returns to MazeLevel. Live wall-set rotation and `KeyDoor.interact` are public gameplay APIs. Party, consumable count, door collision, wall transforms and pending rewards are actual consumers.
2. Load-bearing comments: Marc explicitly reloads the maze on return, resetting walls/currents/levers. That standalone shortcut conflicts with campaign continuity. Discovery must remain tied to live geometry, not stale coordinates or scene instance IDs.
3. IO: both scene changes free existing nodes; wall/gate/rock/chest tweens and deferred collision releases must finish or transitions must wait. Poster permutations are random. Maze snapshots must contain stable node paths, reward origins and plain data, not freed nodes or callbacks.
4. Branches: campaign entry versus standalone review; initial versus returning secret entry; each active model; living/downed members; opened/closed doors; consumed versus pending rock rewards; moved currents; solved/unsolved switch and path; fog discovered/undiscovered; in-flight animations. Cold disk restore is separately INT-04.
5. Types: maze keys are a spendable count plus collected IDs, separate from campaign relics. Rotation flags and collision barriers must match restored transforms. Poster `diver_index` and number pairs retain the same puzzle; Sonar Vision ownership and equipped state are distinct. Secret return chooses the prior active diver without healing or repaying rewards.
6. Tests: existing maze geometry/map checks do not leave and return. New `maze_secret_continuity` exercises actual rotation, key-door opening, a broken reward rock and E/Esc scene changes, then checks real party, inventory, key count, door collision, physical walls and uncollected reward. Direct fixture placement is disclosed; it is not complete normal-navigation acceptance. Map snapshot IO receives round-trip coverage with durable checkpoint work.

Self-critique: rebuilding a stable baseline must fail the resource, opened-door and physical-wall assertions; call counts and private trigger order are not asserted. The fixed single excursion is a captured cross-scene bug; bounded party combinations remain in INT-01. Durable maze-state shape variations will use generated round trips under INT-04 rather than pretend this one route proves all persistence branches.

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

## Test design and self critique

INT01–04/13–14 use production transition and save round-trip/differential checks with distinctive state, plus generated bounded valid state combinations once schemas are stable. Stable wrong output must fail conservation and identity assertions. Assert public results, not the number/order of private calls.

INT05/11–12 use actual battle construction/actions and outcomes. No injected victory may prove a real win. Cheap lifecycle characterization may use isolated fixtures but must be labelled narrow and followed by normal-action route proof.

INT06–07 require observable contextual input and actor/card/turn participation, not just flags or HP. INT08–10 combine independent script invariants with real rendering/listening/deployed provenance. Static imports, screenshots of startup and empty loops cannot prove full coverage.

Each test must name the catalog bug it catches. Write one test at a time, run it, repair a real failure before piling on more characterization. Register accepting tests in verify/gates.sh or a linked aggregate with bounded timeouts and script-error rejection.

## Skipped and separately tracked

- Global combat rebalance, stronger ordinary world-Deep table and rejected PR88 storyboards: outside integration scope; retain findings, do not claim fixed.
- CurrentRide normal route: unestablished prototype, no new connection requested.
- Emotional payoff and comfortable musical fit: not automatable; require uncoached human feedback.
- Windows/Linux launch on unavailable target machines: export is not launch proof; request and record actual target feedback.
- Cosmetic issues: not excluded from acceptance; inspect in the final visual/audio loop rather than private-helper unit tests.

## Post write evaluation

Bugs caught: INT-01. `maze_campaign_handoff` failed with 166 state-loss findings across all six generated active-diver/downed-state combinations. Its first setup draft used a nonexistent SpellTree API; that harness parse failure was corrected and is not counted as game reproduction. The valid reproduction had no script errors. After the live campaign-session repair, the same six-case conservation oracle passes. Existing normal-entry, map and opening-state checks also pass.

Bugs caught: INT-02. The valid first run found no constructed secret entrance; restoring its builder exposed seven real return resets. The first snapshot repair exposed another semantic loss: opened walls looked correct but could not close to their real home. The extended E/Esc test now verifies all six walls can close correctly, alongside active/downed party resources, inventory, spent keys, actual door collision and a pending reward. Initial harness missing-node errors were corrected and excluded from reproduction receipts.

Inspection added a construction-time issue: restored pickup properties must be set before `_ready`, otherwise a nongrappleable saved orb retains a grapple collision target. The constructor now receives saved properties before insertion. This is a source-inspected repair, not independently accepted input/raycast proof. Restored discovery data uses stable paths/IDs rather than freed nodes.

Remaining: INT-03–14 have not been accepted. Cold maze Load, selected-slot persistence, consumer spell-unlock relic access, full traversal, real combat/finale, rendered inspection and deployed/native evidence remain pending. Live maze snapshots are plain data but are not yet validated durable checkpoint records. The old maze-completion gate still assumes H-driven current relocation and fails; current-route acceptance remains open.
