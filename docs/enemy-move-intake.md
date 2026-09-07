# Ordinary enemy attack intake

Glassgoat can make as many Angler attacks as is useful. The game now treats an
attack's animation and combat role as data rather than adding a new `Battle`
branch per clip.

## What to deliver

- Put every action in the same rigged FBX as the enemy.
- Name action takes consistently: `Angler_T(Attack)<ActionName>`.
- Keep Idle, Swimming Start/Mid/End, Damaged, and Death alongside attacks.
- Include textures in the FBX or as clearly named files in the same ZIP.

The current Angler file already contains `Bite`, `headbutt`, and `Shine`. Bite
and Ramming Bite are enabled. Headbutt and Lure Flash are recorded but disabled
until the team decides their damage/effect and target behavior; they cannot
accidentally change the live balance.

## Enabling an attack

One data record in `content/enemy_moves.gd` controls a move:

```gdscript
{
    "id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
    "enabled": true, "target": "single", "roll_order": 2,
    "weight": 20.0, "finisher_weight": 20.0, "verb": "headbutts",
    "combat": {"power": 9, "acc_mod": 1, "quick_time_bool": false},
}
```

`clip` is a case-insensitive fragment of the FBX take name. `weight` controls
normal selection and `finisher_weight` controls selection when a configured
finisher is possible. New moves currently target one diver; party-wide enemy
moves need a specific combat-design decision before they are enabled.

Run `godot --headless --path . --script verify/enemy_moves.gd` after changing
the catalogue. It fails if a configured clip is absent, disabled art leaks into
selection, a move cannot start, or a turn mutates the source catalogue.
