# Maze and campaign integration bug catalog

Generated October 4, 2026 using design-tests. Initial cross-system scope from approved Page revision 5. These are risk/contract entries, not completed tests or reproduced failures. Expand module-specific public interface, branches, dependencies and IO summaries after complete targeted code reads and before each test.

## Observable contracts and IO

The production surface is world entrance, scene return, battle outcomes, public campaign/save state, door/key use, contextual input, real revival, audio owner and shipped exports. Boundaries include JSON save IO and selected slots, scene destruction/reconstruction, async battle/film callbacks, seeded combat/roster RNG, elapsed-time triggers, Godot import/export and served web/native bytes. Actor/species IDs and encounter source IDs are separate from completion/reward IDs.

## Ranked risks and accepting tests

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

Bugs caught: none yet. Bugs characterized: none yet. Reproduction, script tests and deployed/native evidence remain pending. Do not promote risk entries to verified fixes without evidence.
