# Opening Angler: ordinary combat, weaker health

## Context

Battle owns the same move buttons, target confirmation, attack animation,
CombatRules/formula resolution and legacy damage roll used by ordinary fights.
The opening may shorten this Angler through HP only. Defeat interrupts normal
victory for Cordys, without XP or campaign rewards. It must not teach guaranteed
hits, inflated damage, missing utility moves or different turn/stat rules.

## Bugs and cheapest checks

| ID | Failure | Check |
| --- | --- | --- |
| ANGLE-001 | Opening overrides STR/DEF/AGI/ACC/EVA along with HP. | Both spawned Anglers obey the normal species' 5–25% independent stat-boost range; opening HP alone is greater than 1 and below normal. Two random encounters need not roll identical ACC. |
| ANGLE-002 | Opening hides utility or rewrites accuracy. | All three diver kits exactly equal ordinary kits, including optional learned moves; generated accuracy/evasion and defense witnesses. |
| ANGLE-003 | Nonlethal or missed action ends the encounter, or stalls it. | Real Attack/move/target buttons: Electric Touch leaves HP, utility deals zero, Haymaker misses; subsequent real action can finish. |
| ANGLE-004 | Actual kill grants rewards, emits normal victory or duplicates interruption. | Real button kill emits exactly one interruption, no finished result/XP; ordinary Angler remains unchanged. |

## Test design / independent witnesses

Use production enemy/party stats and real UI actions, not injected death or a
test replacement resolver. Maxilani Electric Touch: STR 1 against DEF 0 gives
1 damage; Flash Blast deals 0. Bucky Haymaker: ACC 1 - 3 <= EVA 1 must miss.
Musashi Precise Tap: ACC 2 + 9 > EVA 1 legitimately hits. Compare original
ordinary move data, not the modified opener's move as its own oracle.

## Scope / balance caveat

Ordinary Angler base HP is 5 (normal boost may round to 6); selected opening HP is 3. Other stats, full move kits,
costs, effects and turn order remain normal. This explicitly supersedes OPEN-009's
old every-choice-one-shot requirement. Legacy Bucky powers 6/10/15 already
produce excessive damage at the current 10-HP scale; this repair must not claim
the campaign is balanced or silently retune all encounter tables.

## Skipped

Campaign-wide balance acceptance, arbitrary infinite utility spam and new moves.
Native gates cannot establish browser readability or complete opening timing;
run the exact exported normal-entry journey too.

## Evaluation

Red on original `fcb41a2`: eight findings (HP, four species stats and all three
move kits). The first comparison fixture was corrected to select an actual
ordinary Angler rather than a random roster member; independent random ACC
rolls were also recognized, not incorrectly treated as identical-stat promises.
Repair removes the opener's stat overrides and move filtering/accuracy rewrite.
Button matrix covers all 11 base moves plus 12 ACC/DEF boundary shapes; separate
nonlethal, utility and miss follow-ups must return usable turns and finish.
Native ordinary rules, Quick Read, enemy clips, Cordys 15-case/survivor matrix
and full opening → recovery → actual later death → Restart/Load pass.
Exact export/browser proof is now green: full normal title/New Game, genuine
nonlethal Electric Touch, usable Musashi turn/actual kill, Cordys, recovery,
persisted completion/defaults and cold Load, 111.656 seconds, zero errors.
The browser harness's stale next-move Y coordinate was repaired by selecting
the rendered move label. Evidence and remaining campaign-balance caveat:
`docs/evidence/opening-angler-normal-rules/README.md`.
