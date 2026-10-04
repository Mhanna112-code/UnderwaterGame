# Maze and campaign execution ledger

## Current authoritative status

October 4, 2026: campaign/opening merged into current main at 493b1d8, retaining the current two-turn Headbutt rule. PR97's runtime conflicts are now reconciled locally, including its map controls, live-demo adapters and revival support. Source PR heads were refreshed again and still match the saved plan. Existing opening worktree changes remain untouched. No combined export or deployment exists yet; campaign state transfer and finale work are not implemented.

| Phase | State | Required next evidence |
| --- | --- | --- |
| Foundation | Recorded | Initial plan/contracts committed at 2e701c9; later decisions remain subject to reconciliation |
| Integrated baseline | In progress | Local textual reconciliation imports and five existing focused gates pass; semantic review and new state-transfer regression remain required |
| State/recovery | Planned | Real handoffs, coherent saves, old/new/interruption/denied-write tests |
| Maze route | Planned | Normal entry, puzzles, keys, local encounter policy and return |
| Puppet encounter | Planned | Both real waves, conserved resources, correct reward and recovery |
| Cordys finale | Planned | Reachable no-lab normal-action win/loss and persisted closure |
| Audio and feedback delivery | Planned | Exact export/served bytes and critical deployed checks |
| Windows/Linux | Planned | Exported, launch-tested and playtested recorded separately |
| Full regression/polish | Planned | Complete clean audit round on identified artifact |
| Human approval | Pending | Collaborator review; no public promotion before approval |

## Next action

Finish end-to-end reads of the maze, secret excursion, World/save/title dispatch and relevant party contracts. Extend the bug catalog with module summaries, then reproduce INT-01 through an actual distinctive-party handoff and repair it before adding further regression tests. The existing transition test checks only scene/HUD existence and cannot accept resource preservation.

## Local baseline evidence and limitations

- Godot 4.7.1 import completed with no script/parse errors. Missing-UID warnings reflect generated metadata temporarily stashed before reconciliation; Godot regenerated those files. They are not runtime acceptance evidence.
- Existing `maze_minimap`, `enemy_moves`, `opening_prologue_state`, `deep_zone_maze_transition` and `ability_popup_video` checks exited 0 without script errors. Receipts are under docs/evidence/maze-campaign-integration/. These checks ran the uncommitted PR97 merge on top of 493b1d8.
- `maze_minimap` checks live wall/current overlays and Marc's L/E/R behavior. Its private-method fixtures do not prove human navigation or full maze traversal.
- `deep_zone_maze_transition` establishes that the separate world path can construct MazeLevel without lab victory, but skips onboarding and places the diver directly at the trigger. It does not prove normal travel, carried state, save/recovery or visual entrance clarity.
- `ability_popup_video` exercises the real world page list and embedded decoder sizing; it does not cover new live-demo lifecycle or human readability/audio.
- Production sphere-room developer spawn was disabled, and Door.fbx resource case corrected. Actual production entry placement still needs its accepting regression and visual inspection.
- All test processes are terminal. No export, deployment or native packaging is running.
