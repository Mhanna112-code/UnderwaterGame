# Combat/content source map

This is the source-level decision record for Slice 5, not a second move
catalogue.  It compares raw PR #72 (`87b1842`) with the later authored content
that the integrated build must preserve.  A raw change is never silently
discarded: it is either implemented, superseded by an equivalent, or resolved
here as an explicit conflict with the more specific author specification.

## Sources used

- **Raw PR #72**, `combat-ui-and-tutorial-updates`, commit `87b1842` — the
  requested feature set being extracted.
- **Glassgoat, `Group_StatsV2-2.pdf`**, player move and status table.  The
  Scuba pages specify Strength damage, `1 + Strength` Bleed, Blindness 2 for
  Accuracy turns, Multiple Knee Combo's temporary -1 Accuracy/-1 Evasion, and
  Axe Kick's temporary -3 Evasion.
- **Glassgoat’s enemy tables in the team channel** — Angler’s final three
  attacks (Headbutt, Bite, Shine/Flash Blast), Frilled Shark’s Bite/Tail Spin,
  and Swordfish’s Arc Slash/Triple Combo/Spinning Slayer.  These are the
  detailed, later source for enemy mechanics; the PR’s older disabled-move
  catalogue is not a substitute for them.
- **The release target contract** (`goal-objective.md`) — artifact sites retain
  physical Angler/Swordfish guardians and random encounters do not preempt
  them.  This resolves the otherwise incompatible raw #72 guardian rewrite.

## Decision table

| Area | Raw #72 proposed behavior | Governing source / decision | Integrated behavior and proof |
| --- | --- | --- | --- |
| Scuba Stabbing | Changed persistent Bleed to a three-turn status. | `Group_StatsV2-2.pdf` defines `Bleed 1 + Strength` and describes its ongoing stacking/end-turn behavior without a duration. The author table is more specific. | **Explicit design decision:** persistent, stacking `1 + Strength` Bleed remains. `verify/glassgoat_combat.gd` proves reapplication stacks and remains active; Quick Read renders no invented duration. |
| Scuba Flash Blast | Added a temporary -1 Accuracy/-1 Evasion self cost. | The PDF specifies only all-foe Blindness 2 for Accuracy turns. Its temporary self-cost belongs to Multiple Knee Combo, not Flash Blast. | **Explicit design decision:** no Flash self-cost. `verify/glassgoat_combat.gd` proves Blindness level/duration; `verify/combat_quick_read.gd` checks its visible outcome. |
| Temporary self effects | Applied self cost before hit/formula resolution. | The PDF says Multiple Knee Combo and Axe Kick penalties are temporary until the actor’s next turn; they cannot retroactively change the action that paid them. | **Ported equivalent:** `CombatRules.resolve()` calculates the action first, then applies the cost on hit, miss, or successful QTE dodge. `verify/combat_content_reconciliation.gd` protects the timing and all three outcomes. |
| Downed divers/Tidal Revival | Retained a faded party actor and restored it when revived. | Raw #72 feature, compatible with current spell tree and party targeting. | **Integrated:** `Diver.play_death_fade()` retains a party actor; `Battle` calls `play_revive()` after Tidal Revival. The focused lifecycle regression catches freed references and verifies visible return. |
| Angler | Removed legacy Ramming Bite and left Headbutt/Shine disabled. | Glassgoat later named exactly three attacks: Bite (Strength + Bleed 1+Strength), Headbutt (Strength + stun by Strength), and Shine/Flash Blast (all foes, evasion loss/duration by Accuracy). The original Headbutt duration is preserved here as source evidence, but current party scaling turns it into a three-whole-turn lockout. | **Integrated, deliberate balance exception:** the three authored attacks are enabled; legacy Ramming Bite is absent. Headbutt keeps Strength damage but stuns for exactly two turns. On exact main, 1,200 isolated fights and 2,400 full routes per policy showed flat two turns raises route completion from 55.1% to 56.6% casual and 92.5% to 93.8% skilled; isolating the fields showed capped Bleed made no measurable difference. `verify/enemy_moves.gd` protects the two-turn rule and `verify/balance.gd` exercises campaign consequences. |
| Swordfish / Frilled Shark | Removed the later authored formula move sets in favor of old power moves. | Glassgoat’s later enemy tables govern: Swordfish Arc Slash/Triple Combo/Spinning Slayer; Frilled Bite/Tail Spin. | **Ported equivalent:** current #73 moves remain intact. `verify/swordfish_moves.gd`, `verify/ordinary_roster.gd`, and the campaign simulation exercise them. |
| Tethys Poison Breath | Replaced flat Poison 2 with 15% of struck target maximum HP for three turns. | Raw #72; compatible with the boss’s party-wide Poison Breath and no contrary authored numeric rule was supplied. | **Integrated:** `poison_fraction: 0.15` is converted at impact, separately for every target, with a minimum of one. `verify/tethys_boss.gd` proves 20 HP receives 3 poison and a live 500-HP party receives 75 for three turns. |
| Special encounter prompt | Converted physical artifact guardians into a random encounter inside a revealed-item radius. | The release target expressly preserves visible guardians, deliberate one-enemy site battles and no random preemption. These player outcomes are mutually exclusive. | **Explicit design decision, Slice 6:** retain the physical guardian flow. `verify/guardian_encounter_exclusion.gd`, `verify/artifact_guardians.gd`, and `verify/special_encounters.gd` are the regression contracts; Slice 6 will record the completed coexistence audit and browser routes. |

## Scope boundary

This map does not make every unfinalized enemy number a permanent balance
decision.  It distinguishes **authored formula/target/effect semantics** from
the existing AI selection weights and boss tuning.  Any future weight or stat
change must rerun `verify/balance.gd`; it must not change a named authored move
or status rule without updating this record and its focused contract.
