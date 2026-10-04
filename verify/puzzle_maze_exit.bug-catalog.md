# Shallow puzzle → maze integration

October 4, 2026. World/party/checkpoint modules read completely earlier; current
puzzle, plate/door, normal input, transition and restoration consumers reread.

## Contract and boundaries

User's clarified topology supersedes plan section 4: finish the shallow Bucky /
grapple / three-plate puzzle, swim through its opened exit, enter Marc's maze.
The independent laboratory still leads through its blockers to Tethys. Existing
Deep-landmark entry may remain for compatibility with feedback saves, not as the
required maze route. Real proximity/input owns entry, not an explicit test call.

Fixture: skip opener and place all three divers on the real plates. Physics
Areas and the production puzzle poll must solve it. This isolates completion,
exit movement and cold checkpoint restoration; it does NOT prove grapple/Swap
or the full puzzle journey. Save/restore uses an unused owned slot. No forced
maze state, battle outcome, transition helper or disabled physics is allowed.

## Bugs

| ID | Failure and impact | Test / status |
| --- | --- | --- |
| PX-01 | Puzzle opens sliding doors but swimming through them never reaches the maze | Captured user bug; actual solved exit + parsed movement, pending red |
| PX-02 | Loading a solved-puzzle checkpoint rebuilds closed doors or forgets maze access | Round-trip through actual slot bytes, production restore and movement, pending |
| PX-03 | Maze return spawns inside its portal or at the unrelated old Deep arch | Actual maze E exit returns beyond the correct source entrance, pending |
| PX-04 | Unsolved puzzle can start the maze by swimming around its wall or above the exit | Negative unsolved exit fixture, pending |

Branches: unsolved/solved; live/cold restore; source puzzle/deep compatibility;
lab locked/cleared; malformed new save fields; active diver; transition pending.
World maze state and checkpoint scene enums remain their existing typed contracts.
New exit origin is a validated string, solved flag a bool. Do not mutate party
before rejecting malformed new fields. Timers/cutscene completion are bounded;
entrance saves cannot touch existing user slots.

Self-critique: inert-but-stable exit fails a real scene assertion. Geometry and
fixtures only drive the scenario, not success. Resource identity, actual maze
arrival, reopened physical doors and safe return are independent oracles.

## Skipped

Full pressure-plate solving/grapple usability, maze completion/resource earning,
browser save durability and subjective visuals remain separate required checks.

## Evaluation

PX-01 reproduced: real plate Areas solved/opened the doors; parsed exit movement
never loaded the maze on 213f9af. Corrected live entry and cold saved entry pass,
with identical resource identity, untouched lab states and real E return beyond
the same exit. Unsolved exit is rejected; invalid new saved fields are rejected
before party mutation. Native 1x exit/arrival views were inspected: the local
instruction and MAZE ENTRANCE label read clearly above the opened passage.

Excluded harness failures: dynamically named CollisionShape3D was looked up by a
fixed child name, then an untyped Array caused a parse error. Neither is accepted
as a game defect or green receipt. A first native capture looked sideways with
the chase camera inside a corridor wall; the final capture uses actual mouse
look toward the entrance. General wall-camera clipping remains a separate
existing visual risk, not claimed repaired by this handoff.

The older guidance regression used slot 3 without an ownership check; its
rerun now uses an unused guarded fixture slot and removes only its created file.
