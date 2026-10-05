# Battle end and post-lab maze approach, 2026-10-05

## Read summary

Battle owns actual attack resolution and the Victory/XP/learned-spell sequence;
World and Maze consume its `finished` result and restore exploration. The audio
autoload owns one player, paired INTRO/LOOP handoffs and persistent volume.
Wave-one puppet clearance and prologue Angler victory deliberately bypass normal
final victory. They must retain their own audio direction. World puzzle plates
open doors; the old integration also teleports from that doorway. DeepZoneLayout
owns route coordinates and protected random-encounter corridors; its environment
owns rendered landmarks. Cutscene's public `play_scroll_text` animates a Label
inside a CenterContainer: setting that child's position fights the container.

Public contracts: actual combat menu actions, `finished`, public music state,
physical plates and swimming, scene handoff, save/load, visible label rectangles.
IO: animation/timers, RNG, viewport layout, isolated save slot, real physics.
Branches: intermediate/final puppet wave, prologue/normal victory, tutorial
captions, win/flee/loss cleanup, solved/unsolved puzzle, old/current maze returns.
Existing gates cover audio state only *after* an injected World win, and the now
superseded puzzle-to-maze route. Neither proves the requested new timing/location.

## Bugs and tests

| ID | Failure and blast radius | Plausibility | Test/oracle |
|---|---|---|---|
| END-1 | Battle music continues through Victory and victory music only starts in exploration | Confirmed World-only cue dispatch | Real ordinary Angler attacks; require victory cue while Battle is still visible, then exploration after `finished` |
| CENTER-1 | Welcome beat is at the top, clipped or moved by a conflicting animation | Child position Tween overrides container layout | Public Cutscene rendered geometry across generated viewport sizes; text centered and contained |
| ENTRY-1 | Solved shallow puzzle still jumps directly to maze, bypassing requested post-lab ramp | Explicit proximity fast path | Real plate occupancy; former exit stays World; swim post-lab ramp into maze without lab victory |
| ENTRY-2 | Ramp/sign moves but collider/trigger/return point stays at old coordinates | Multiple owners, legacy saved entry source | Real capsule approach and scene return; old entrance does not teleport, current ramp does; party retained and no bounce |

Tests reject stable wrong output using temporal cue and scene observations, not
implementation calls. Viewport input space uses a bounded seeded generator.
Rendered captures supplement semantic centering. Route fixture locations are
disclosed: this proves approach/transfer, not a whole human navigation playthrough.

## Skipped

- Global balance, Tethys opener pivot and other pending Marc ports: separate work.
- Listening preference and emotional response: state tests cannot prove them.
- Windows/Linux hardware launches and new web deployment: not part of local proof.

## Evaluation

Pending red/green results and rendered audit.
