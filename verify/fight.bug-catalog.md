# Fight interaction bug catalog

This gate drives the real battle menus and watches the animated 3D stage.
Its aim assertion is intentionally tied to the exact target selected by the
combat flow, not a guess based on whichever enemy happens to be closest.

| ID | Bug to catch | Cheapest regression check |
| --- | --- | --- |
| FA-1 | A party attacker begins an attack clip while too far from, or facing away from, the actual selected enemy. This makes a visible swing land in open water. | `Battle.player_swing_staged` is emitted after `_step_toward()` and `play_clip()`. `verify/fight.gd` checks that exact attacker/target pair is within 3.6m and within 35 degrees. |
| FA-2 | In a multi-enemy pack, a valid swing is falsely reported as mis-aimed because another living enemy is nearer than the selected target. This turns the gate red even though the player-facing action is correct. | The same direct-pair signal replaces nearest-enemy inference; the gate's seeded two-enemy fight exercises the case. |
| FA-3 | A delayed return-home tween reads a combat actor after the battle has freed it, producing Godot `SCRIPT ERROR` spam after a fight. | `_send_home()` holds the delayed dictionary value as `Variant`, validates it before converting to `Node3D`, and `verify/gates.sh` fails on any Godot `SCRIPT ERROR`. |

## Post-write verification

Run `godot --headless --path . --script verify/fight.gd`. It must finish a
real menu-driven fight, return to the overworld, observe at least one exact
target aim sample, and report `FIGHT: clean`.
