# Marc's immediate Evasion Down admission

October 4, 2026. Source #97 `6f4cca8` / #99 `6ea109f`.

## Module understanding and contracts

Read complete `CombatantStats`, `CombatRules`, `EnemyMoves` and existing
`glassgoat_combat` verifier. Stats already subtract Evasion Down in this branch;
only the immediate remaining-pool cap is missing. Resolve reads remaining EVA,
spends it on a dodge, and applies target effects only after a hit. Begin turn
clears temporary modifiers and refills effective EVA; duration expires after
target turns. Reapplying statuses retains max level/duration, not additive stacks.
Persistent zero-duration effects clear through ordinary victory/fill. No IO,
frames, models or save writes are required to test this arithmetic boundary.

Public surfaces: add_status, actual authored Angler Flash Blast through resolve,
follow-up ordinary resolve, begin/end_turn, temporary modifier, victory recovery.
Branches: fresh/spent/zero pool, weak/strong/no-op/reapplied status, temporary
modifier, landed/missed effect, timed/persistent duration, expiry/refill/reset.

## Ranked catalog

| Bug | Risk and cheapest meaningful test | Status |
| --- | --- | --- |
| EVA-1 status lowers effective number but leaves an oversized live dodge pool until the next turn | High: next real attack dodges despite the displayed weakened EVA; generated base/spent/debuff/modifier cases plus authored Flash Blast and follow-up normal hit | reproduced and repaired; same sequence passes |
| EVA-2 repair refills spent EVA or subtracts the status twice | High: corrupts deterministic combat; independent expected pool=min(previous, max(0, base+temporary-max status)), weaker reapplication and expiry before/after begin turn | generated checks pass |
| EVA-3 missed/no-op status lowers EVA anyway or status never clears | Medium: effect/expiry drift; actual authored miss, zero-level call, timed turns and persistent victory cleanup | generated and authored checks pass |

Tests do not call effective_evasion to calculate expected values, mirror private
implementation helpers, or mock a hit. Fixture stats are arithmetic cases, not
a claim of attainable campaign victory. These checks cannot prove animated
feedback, live Battle HUD refresh, actual encounter balance or browser behavior.
Existing Quick Read and full combat/status gates are separate regression checks.

## Evaluation

Valid red `/tmp/underwater-marc-evasion-red.log`: actual authored Flash Blast
left remaining EVA at 4 instead of 2; the subsequent 3-ACC attack dodged instead
of landing. This is not a tooltip-only reproduction. Marc's immediate min-cap
repair passes the same sequence and 1,260 generated arithmetic cases in
`/tmp/underwater-marc-evasion-green.log`. Weaker reapplication, expiry, no-op,
ordinary miss and victory cleanup pass without script errors. Existing
Glassgoat combat passes in `-glassgoat.log`.

Quick Read regression initially fails two stale three-turn Bleed expectations.
The earlier persistent-Bleed port had changed actual content/help but missed
this separate verifier. Its old comment already described persistent Bite,
contradicting its assertion. Update only that superseded expiry expectation to
rest-of-fight and explicitly reject the obsolete expiry text; do not change
product Bleed to placate it. This is test-contract reconciliation, not a newly
fixed tooltip bug, and that initial failing run is not accepted as clean.
Fresh Quick Read/status/puppet regressions pass without script errors:
`/tmp/underwater-marc-evasion-quickread-final.log`, `-status.log`, `-puppets.log`.
The latter runs actual production wave combat, not a fabricated victory.
All named skipped presentation/browser/global-balance boundaries remain open.
