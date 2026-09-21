# Ordinary enemy attack intake

Glassgoat can make as many Angler attacks as is useful. The game now treats an
attack's animation and combat role as data rather than adding a new `Battle`
branch per clip.

## What to deliver

- Put every action in the same rigged FBX as the enemy.
- Name action takes consistently: `Angler_T(Attack)<ActionName>`.
- Keep Idle, Swimming Start/Mid/End, Damaged, and Death alongside attacks.
- Include textures in the FBX or as clearly named files in the same ZIP.

The current Angler file already contains `Bite`, `headbutt`, and `Shine`. All
three are enabled: Glassgoat's Discord follow-up supplied Headbutt's and Flash
Blast's (the renamed `Shine`/"Lure Flash") damage/effect and target behavior.

## Enabling an attack

One data record in `content/enemy_moves.gd` controls a move. A move that only
deals plain power+strength damage can stay on the older shape:

```gdscript
{
    "id": "headbutt", "name": "Headbutt", "clip": "attack)headbutt",
    "enabled": true, "target": "single", "roll_order": 2,
    "weight": 20.0, "finisher_weight": 20.0, "verb": "headbutts",
    "combat": {"power": 9, "acc_mod": 1, "quick_time_bool": false},
}
```

A move whose damage or effect scales off a wielder stat instead uses the same
`formula`/`effects` shape as `content/combat_moves.gd`'s player kit - Bite,
Headbutt and Flash Blast all use this one, since `Battle._resolve_attack()`
dispatches any move carrying a `formula` key straight to `CombatRules.resolve()`
(see `content/enemy_moves.gd`'s own header comment for the delivered numbers):

```gdscript
"combat": {
    "formula": {"strength": 1}, "acc_mod": 1,
    "effects": [
        {"kind": "status", "status": "stun", "level": {"flat": 1}, "duration": {"strength": 1}},
    ],
},
```

`clip` is a case-insensitive fragment of the FBX take name. `weight` controls
normal selection and `finisher_weight` controls selection when a configured
finisher is possible. `target: "all"` (Flash Blast) hits every living diver
through `Battle._do_enemy_all_foes_turn()` instead of the single picked target
- that was the party-wide combat-design decision the previous revision of this
doc was waiting on.

`CombatantStats` supports two effects with no prior ordinary-enemy user: `stun`
(skips the afflicted combatant's next N turns entirely - see
`CombatantStats.is_stunned()`/`Battle._advance_turn()`) and `evasion_down` (a
timed Evasion reduction, the same shape as the existing Blindness status but
scoped to one stat - see `CombatantStats.effective_evasion()`).

Run `godot --headless --path . --script verify/enemy_moves.gd` after changing
the catalogue. It fails if a configured clip is absent, disabled art leaks into
selection, a move cannot start, a turn mutates the source catalogue, or Bite/
Headbutt/Flash Blast's agreed formula or effect regresses. Also run
`godot --headless --path . --script verify/glassgoat_combat.gd` (the Stun and
Evasion-down status contracts live there) and
`godot --headless --path . --script verify/balance.gd` (an enemy move must
still resolve through the same `formula` dispatch the balance simulator uses
for the player's own V2 moves).
