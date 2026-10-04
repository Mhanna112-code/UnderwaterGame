# Maze and campaign execution ledger

## Current authoritative status

October 4, 2026: campaign/opening merged into current main at 493b1d8, retaining the current two-turn Headbutt rule. PR97's runtime conflicts are reconciled locally. INT-01 live World-to-maze state loss is reproduced and repaired: six normal-proximity entrance cases conserve party resources, downed state, earned kit, inventory, relics, active diver and campaign progress. Existing opening worktree changes remain untouched. No combined export or deployment exists yet; maze persistence, secret return and finale remain incomplete.

| Phase | State | Required next evidence |
| --- | --- | --- |
| Foundation | Recorded | Initial plan/contracts committed at 2e701c9; later decisions remain subject to reconciliation |
| Integrated baseline | In progress | Local reconciliation and INT-01 live entrance gate pass; remaining semantic integration still required |
| State/recovery | In progress | Live entrance fixed; secret excursion, coherent maze saves, old/new/interruption/denied-write tests remain |
| Maze route | Planned | Normal entry, puzzles, keys, local encounter policy and return |
| Puppet encounter | Planned | Both real waves, conserved resources, correct reward and recovery |
| Cordys finale | Planned | Reachable no-lab normal-action win/loss and persisted closure |
| Audio and feedback delivery | Planned | Exact export/served bytes and critical deployed checks |
| Windows/Linux | Planned | Exported, launch-tested and playtested recorded separately |
| Full regression/polish | Planned | Complete clean audit round on identified artifact |
| Human approval | Pending | Collaborator review; no public promotion before approval |

## Next action

Local merge checkpoint: 7a762ee135f198b6af38ca8191e96e8ed77cb94e. The map gate was rerun on this committed source and passed. No public branch, main merge or deployment was performed.

Complete targeted source reads are recorded in the INT-01 module contract. The new handoff test failed with 166 state-loss findings, then passed all six cases after retaining the actual stats resources and inventory through a single-use campaign-session handoff. Existing normal-entry, maze-map and opening-state gates also pass with no script errors. Next: reproduce and repair INT-02 secret-room return without resetting maze puzzles or resources, then establish durable scene/checkpoint restore under INT-04. Do not treat a successful live entrance as cold-load acceptance.

## Local baseline evidence and limitations

- Godot 4.7.1 import completed with no script/parse errors. Missing-UID warnings reflect generated metadata temporarily stashed before reconciliation; Godot regenerated those files. They are not runtime acceptance evidence.
- Existing `maze_minimap`, `enemy_moves`, `opening_prologue_state`, `deep_zone_maze_transition` and `ability_popup_video` checks exited 0 without script errors. Receipts are under docs/evidence/maze-campaign-integration/. These checks ran the uncommitted PR97 merge on top of 493b1d8.
- `maze_minimap` checks live wall/current overlays and Marc's L/E/R behavior. Its private-method fixtures do not prove human navigation or full maze traversal.
- `deep_zone_maze_transition` establishes that the separate world path can construct MazeLevel without lab victory, but skips onboarding and places the diver directly at the trigger. It does not prove normal travel, carried state, save/recovery or visual entrance clarity.
- `ability_popup_video` exercises the real world page list and embedded decoder sizing; it does not cover new live-demo lifecycle or human readability/audio.
- Production sphere-room developer spawn was disabled, and Door.fbx resource case corrected. Actual production entry placement still needs its accepting regression and visual inspection.
- All test processes are terminal. No export, deployment or native packaging is running.
