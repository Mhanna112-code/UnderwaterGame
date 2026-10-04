# Cordys opening combat contract

Scope: Battle's prologue reveal, public Attack/move/target buttons, shared
CombatRules/CombatantStats, animated result and finished signal. No campaign
boss tuning, tutorial redesign, or reward changes.

The normal formula resolver already resolves Maxilani's 1 STR Electric Touch
as 1 damage and Axe Kick (STR + ACC) as 4. There is no fixed-one-damage branch.
The real shortcuts are the prologue move-accuracy rewrite and a finisher that
assigns every party member's HP to zero, independent of stats.

Load-bearing contract: overwhelming because of Cordys's HP/STR/ACC, not
rewritten player moves or unconditional death. Formula and legacy-power moves
must retain ACC/EVA, DEF, status, self-cost and Oxygen semantics. A non-damaging
choice must not be silently discarded at Cordys. One-action Angler guarantees
remain isolated to that encounter. IO: animation timers and legacy variance;
formula moves are deterministic. Branches: formula/power, one/all targets,
hit/EVA miss, status/self-cost, living/dead after response.

| Bug | Failure | Test and independent oracle |
| --- | --- | --- |
| OPEN-036 | Cordys kills a survivor by resetting HP, while player accuracy/choices are silently rewritten. | Public-button encounter: inflated-HP fixture must survive with damage derived from STR minus DEF; ordinary fresh party must lose. Original move data must remain intact. |
| OPEN-037 | Player choices become cosmetic: all attacks deal 1, ignore stats, lose status/costs, or preview disagrees with impact. | Differential STR/ACC/DEF/EVA matrix, actual buttons, HP/status/O2 and log observations. Manual witnesses: Electric 1, Axe 4, Stabbing Bleed 2 at base stats. |

Self-critique: a fixed HP reset fails the survivor fixture; a fixed damage
result fails stat variation. Inputs use actual move/target buttons, not a test
replacement for resolution. Shared rules are a differential oracle, backed by
independently hand-computed baseline witnesses. Model animation/import success
alone is not acceptance; exact exported normal-entry visual proof is required.

Skipped: arbitrary invincible/debug characters winning the campaign boss;
campaign Cordys balancing and teaching new moves; broader opening polish.

Evaluation: OPEN-036 was caught red: the 200-HP diagnostic character was
declared defeated and reduced to zero instead of retaining stat-derived HP.
The survivor check is green after replacing direct HP assignment. OPEN-037's
nine hand-computed button witnesses are green: baseline damage is 1/4/1 and
Bleed is 2; higher STR gives Axe 9 vs Electric 5, and ACC/EVA ties miss. Six
seeded generated shapes compare actual button resolution with ordinary shared
rules. The prior claim of a fixed-one-damage clamp was retracted after reading
the resolver and live stats; the actual defaults explain repeated 1s.

Survivor fixture is diagnostic, not a claim that the starting party survives
or that campaign balance is approved. Final exported proof is recorded in the
opening visual audit, not inferred from these native gates.
