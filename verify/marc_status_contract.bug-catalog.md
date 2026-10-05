# Bug catalog: PR99 persistent Bleed and readable status amounts

October 4, 2026. Read CombatantStats (220 lines), CombatRules (117), complete
CombatMoves and existing glassgoat_combat (243). Public resolve/begin_turn/
end_turn/status_summary/fill are the consumer rule surfaces. Status entries carry
separate level and turns; zero turns means battle-persistent, not expired.

Branches/boundaries: ACC/EVA miss, QTE dodge, no-damage absorb, damaging hit with
existing Bleed, new timed/persistent status, stacking cap, end-turn decrement,
temporary self-cost, turn refill and end-of-fight cleanup. No file/network IO in
these rules. Existing glassgoat_combat inconsistently tests authored Scuba Bleed
as three turns and manually added Bleed as persistent; Marc de5f079 resolves the
authored move/help contract to persistent Bleed. Other timed statuses must remain
timed. This is collaborator rule integration, not a global balance redesign.

| ID | Failure | Blast radius / plausibility | Test/status |
| --- | --- | --- | --- |
| M99-S1 | Authored Stabbing stops bleeding after three turns while help promises rest-of-fight. | High: table's duration3 survives unless content and tests are ported together. | Real CombatRules authored move, fourth tick and fill cleanup; red expected. |
| M99-S2 | Bleed exceeds 10 on initial high-STR application, or misses/dodges add progress. | Medium: add_status only caps existing stacks; resolve early returns matter. | Bounded generated STR/ACC/EVA/hit/dodge cases, capped level and unchanged failure state; pending. |
| M99-S3 | Summary conflates amount with duration and is unreadable as `Poison 2·3`. | Medium: same line rendered on real cards. | Bounded level/duration sweep requires duration units and amount independently; native card verification deferred to Battle presentation increment. |
| M99-S4 | Longer readable summaries expand cards across the viewport or overlap other combatants. | High: current status Labels are unwrapped and feed card minimum width. | Real three-diver/three-enemy card geometry plus native multi-status capture. Pending. |
| M99-S5 | Move-applied feedback still conflates amount/duration or disagrees with the card. | Medium: latest 1b43949/7c34be2 fixes separate resolver and boss message paths. | Generated timed-effect consumer results compared with readable status amounts/turn units; red before port. |

Tests use actual authored moves and resolver, not a reconstructed table. Fourth
tick is an independent expiry oracle; poison/Blindness three-turn controls and
fill cleanup prevent turning everything persistent. Generated STR0..12 × hit/
miss/dodge covers the initial stack edge, not >5 hand-picked snapshots. Exact
punctuation/spacing is not pinned. Equivalent rule refactors must pass.

Skipped: changing enemy/boss base stats or prologue pacing (not this admission),
exact status label typography (real layout checks next), numerical balance of all
possible kits (existing attainable boss/puppet gates are rerun, not exhaustive).

Evaluation: real authored move failed the fourth-tick baseline (S1). Porting its
duration exposed initial high-STR Bleed exceeding 10 (S2), plus unreadable units
(S3); the cap repair is ours, not attributed to Marc's duration commit. All 39
strength/outcome combinations and 240 status level/duration combinations now
pass. Existing shared combat arithmetic passes; actual puppet conservation/waves
and campaign Cordys victory pass with normal party stats and legal kits.

S4 failed with overflowing enemy cards. Wrapping fixed wide and portrait views,
but a native live resize exposed short-screen overflow that headless had missed:
wide HP bars retained their construction widths. Adaptive bar sizing plus short
ordinary-fight turn units (`t`) at 10px fixes the three-party row and three-enemy
column. Full wording remains wide/tutorial and in the label tooltip. Native
720x480 multi-status view was inspected; all six card bounds fit and duration
amounts remain present. The paused render fixture is not proof of an active cast
with all conditions or earned route; broader presentation audit remains open.

First 240-second full Tethys balance run timed out after 32 recorded victories;
not counted as a complete gate. A fresh bounded 480-second run completed all
48 actual fights (levels 2/3, three legal consumer policies, eight seeds each),
with normal 10-HP divers, no QTE success injection and usable menu actions.
Every case reached the real winning result. This is bounded combat evidence,
not proof of an earned complete campaign route or general balance acceptance.

Latest shared refresh added S5 before port. All 36 generated timed-effect
resolver cases failed because the feedback said only `N turns`, not turns left.
The port uses singular/plural remaining-turn wording in the shared resolver and
the actual Poison Breath result path. Native narrow Heavy Slam and Mending/Revival
regressions passed; inspected captures show usable stage/card separation. Full
all-nine browser replay remains outside this bounded shared admission.
