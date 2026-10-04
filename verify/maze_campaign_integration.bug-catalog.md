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

### INT-04 durable checkpoint contract

1. Surface: the existing SavePoint/SavePointMenu contact and P interaction, public save-request signal, TitleScreen chosen-slot Load and GameOverScreen Restart/Title actions. A genuine save must restore the selected scene plus party, inventory and puzzle ownership, not merely deserialize a party into World.
2. Load-bearing comments: SaveManager stages/flushed/readbacks before replacing a slot; BrowserCheckpoint verifies IndexedDB durability before acknowledgement. World validates full input before actor mutation, and invalid Load retains title/error instead of New Game. Maze currently has neither a SavePoint nor a checkpoint protocol and its loss branch heals and teleports while keeping unsaved geometry.
3. IO: JSON loses typed arrays/resource identity; selected slot can change; disk/IndexedDB failure must not acknowledge or select a failed checkpoint. Cold construction invalidates all node paths/references. The world context must remain separately available when leaving Maze.
4. Branches: old flat World saves versus versioned Maze checkpoints; completed/uncompleted opening; occupied/empty save slots; rest contact versus ordinary scene entry; saved versus unsaved doors/rocks/rewards; malformed/missing/version-unknown records; actual maze loss/Restart/Title; failed native/browser writes.
5. Types: ordered three model IDs, finite integer stats and float Oxygen, status dictionaries/temporary modifiers, earned kit and Sonar timers; plain stable maze geometry/discovery data. Checkpoint scene is explicit rather than inferred from route zone. Campaign relics and spendable maze keys retain distinct owners.
6. Tests: existing World persistence and load-failure gates remain mandatory. New `maze_checkpoint` reaches the normal maze proximity entrance, contacts its real save point, requests a selected isolated slot, destroys the scene and uses the actual title Load signal; independent resource/door/wall/reward assertions reject a fresh World or Maze. Fixture placement and direct rotation/door/rock APIs are disclosed. A later bounded property/negative suite generates valid state and malformed shape combinations; real enemy-caused defeat and browser denied-storage remain separate accepting checks.

Self-critique: a saved party without scene/puzzle restore must fail the scene, collision and reward assertions. No private serializer is treated as acceptance by itself. Test slot is uniquely owned outside user slots and refuses pre-existing data. Saving intentionally restores all party members, matching established save-point behavior; live transitions must still not heal. No injected victory or inflated HP is used. Skipped here: full human maze navigation and browser/native durability are not proven by this headless native checkpoint case.

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

### INT-04 World return/re-entry module contract

1. Public interface: physical World maze entrance, an explicit E exit at the maze entrance, real SavePointMenu and Title Load, party resources/kit, RouteState, physical doors/walls and inventory. The current maze has no World exit; World always creates a new CampaignSession on entry, discarding previous maze history.
2. Comments/invariants: live transition is not rest or checkpoint recovery. Preserve actual resource identity, downed members and kit. Returning must restore the outer-world geometry and location, not use maze coordinates or put the player inside the automatic entrance radius. Independent lab flags must survive both branch orders.
3. IO boundaries: scene replacement destroys actors; pending handoff is single-use; World save must carry maze history without making Title Load resume in the wrong scene. Failed scene change clears pending ownership; existing checkpoint write failures remain subject to their gates.
4. Branches: first/repeated maze entry, World versus Maze checkpoint scene, maze-first/lab-first state, each active diver/living-downed companion, transient puzzle/modal preventing exit, old flat World save without history. Normal E exit must not fire through map/modal/ability selection or auto-exit a newly spawned party.
5. Types: same CampaignSession and versioned CampaignCheckpoint contract, explicit world/maze scene ID, plain snapshot history, separate maze keys/campaign relics, outer positions, complete stats/kit and selected slot. Shared RouteState remains the current campaign state, not a stale pre-maze copy.
6. Test: `maze_world_return` uses actual proximity entry, E exit, public door interaction, real Save menu request and Title Load, then proximity re-entry. Bounded 3 active × 2 companion states × 2 independent lab states = 12 cases. Trigger placement and lab-state fixtures prove conservation, not lab victory/full traversal. Assertions independently require unchanged live resource identity/HP/Oxygen/earned kit, no entrance bounce, physical open door with spent key after cold World Load/re-entry, and unchanged lab flags. Wrong-but-stable fresh party or blank maze fails. Excluded here: full navigation, rendered exit design, actual lab victories and browser durability; those remain release gates.

### INT-08 checkpoint presentation contract

1. Public surface: native Compatibility viewport, physical checkpoint contact, P menu and real mouse-clicked Save/slot picker. The checkpoint and exit labels must be visibly distinguishable at normal entry. Save slots must remain on-screen and actionable; no actual user-slot write is needed to inspect the picker.
2. Invariants/comments: headless rectangles cannot accept a rendered UI. Existing SavePoint fade should prevent its prism hiding the diver. The explicit exit is not an automatic portal. Native capture complements, rather than replaces, browser/target-platform audit.
3. IO: real viewport scaling/camera, frame presentation and generated PNG captures; real input events. Read-only slot summaries must not modify saves.
4. Branches: entrance/exploration versus Save menu versus slot picker; wide, narrow, tall and small viewports. Hidden controls must not own input, and visible buttons must fit the viewport.
5. Types: Control global rectangles, viewport Rect2, SavePoint occupancy and real Button actions. Screenshot is inspected independently, not a stable pixel snapshot oracle.
6. Test: `maze_checkpoint_presentation` reaches real maze through proximity, captures settled entry, uses P at actual checkpoint, mouse-clicks the real Save button, asserts the slot picker and all visible button bounds, captures it and closes without writing. Cases are four specified sizes, not a generated input-space property. Captures reveal overlap/framing errors that state-only checks miss. Excluded: full maze artwork, audio fit, IndexedDB and final clean audit round.

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

Bugs caught: INT-04 native checkpoint boundary. The valid first reproduction found no actual maze SavePoint. The accepting test now contacts it, uses P and the real menu request, destroys the scene and cold-loads through TitleScreen, checks physical door/wall/reward rollback, and runs actual enemy damage through defeat and Restart. A failed FileAccess write retains the prior checkpoint bytes/selected slot and produces visible failure. Generated JSON tests cover 24 active/downed configurations and 40 malformed records, followed by actual Title Load rejection of malformed data and nonexistent geometry references. The initial onboarding fixture and JSON numeric dictionary-equality mismatch are excluded as harness defects. Source-inspected exact-byte rollback also preserves corrupt previous slots on web sync rejection; actual browser denial remains unaccepted.

Bugs caught: INT-04 World return/history. First valid run found no campaign exit. The repaired real E exit and World cold-save/re-entry pass twelve bounded active/downed/lab-state combinations, retaining actual live resource identity/kit/resources before rest, avoiding an entrance bounce, and conserving door collision/spent keys and independent lab ownership after reload. No inflated HP or injected outcomes are involved; lab flags and trigger placement are disclosed fixtures. Nine affected regressions pass.

Bugs caught: INT-08 checkpoint UI scope. Old fixed-width menu clips all three slot buttons and Back at 360x640; actual native views also expose oversized labels and overlapping announcements/HUD. Four native real-P/mouse checks and twelve inspected entrance/contact/slot captures now fit and separate these surfaces without writing user slots. The old wide-screen menu passes after stabilizing the fixture; early missed clicks were test timing/global-position defects, retracted rather than counted as game failures. Sampled landmark visibility is not exhaustive camera-angle coverage.

Remaining: INT-04 still requires browser denied-storage. INT-03, INT-05–07 and INT-09–14 are unaccepted; INT-08 is accepted only for this checkpoint/menu scope, not full route/battle art. Consumer spell-unlock relic access, full traversal, real finale/wave wins, final rendered audit and deployed/native-platform evidence remain pending. The old maze-completion gate still assumes H-driven current relocation and fails; current-route acceptance remains open.
