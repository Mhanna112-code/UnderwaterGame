# Glassgoat combat V2 — implementation map

Source: Glassgoat's `Group_StatsV2.pdf`, delivered 24 August 2026.

This branch is the first playable vertical slice of that specification. It
implements one complete character kit and the reusable mechanics that kit
requires; it does not claim the full document is finished.

## Implemented in this slice

- Scuba rig base stats: 10 HP, 1 Strength, 0 Defense, 3 Agility, 3 Evasion,
  3 Accuracy.
- Deterministic Accuracy versus Evasion. Evasion wins a tie.
- Evasion as a spendable pool: a dodge subtracts the attacker's Accuracy and
  the pool refills at the defender's next turn.
- Skill formulas stored as data and evaluated against the wielder's stats.
- The V2 damage floor: a landed damaging attack deals at least 1 unless
  Defense exceeds raw damage by more than 5, in which case it is absorbed.
- Bleed stacks, gains a stack from later damaging attacks and deals its stack
  count at the bleeding character's turn end.
- Blindness lowers Agility, Accuracy and Defense by its level for a timed
  duration.
- Temporary move penalties clear at the user's next turn.
- All five Scuba moves and their authored animations:

| Move | Implemented rule |
| --- | --- |
| Electric Touch | Strength damage; lower target Evasion by wielder Accuracy |
| Scuba Stabbing | Strength damage; apply `1 + Strength` Bleed |
| Flash Blast | all foes; Blindness 2 for wielder Accuracy turns |
| Multiple Knee Combo | all foes; temporary -1 Accuracy and -1 Evasion |
| Axe Kick | `Strength + Accuracy` damage; temporary -3 Evasion |

- On-model damage, `DODGE`, `ABSORBED`, Bleed and applied-effect feedback.
- Party current/max Evasion and active statuses in the combat readout; enemy
  stats remain contextual rather than permanently displayed.
- Contextual HP, Defense, Evasion and Accuracy while choosing a target.

## Deliberate interpretation

The PDF's Evasion paragraph explicitly says Evasion wins a tie, while the next
paragraph contains both “same or more accuracy ... will hit” and “losing on a
tie.” The implementation treats the latter as Accuracy losing the tie. This
also matches the deterministic comparison already on `main`.

## Not implemented by this slice

- Agility granting multiple actions.
- Electrical, Stun, obstruction, poison, Sound or biology-based resistance.
- Sightless, Echolocation/Sonar, Autotomy or Regeneration traits.
- Cyclops Diver and Fives' V2 stat blocks and move kits.
- A final whole-roster balance pass. The existing seeded simulator remains in
  band with the V2 Scuba slice, but the other two characters still use their
  legacy kits.

Those are subsequent vertical slices, not hidden claims of this pull request.
