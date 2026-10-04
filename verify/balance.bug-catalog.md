# Campaign balance bug catalog

Scope: whether a new party can leave the save point, traverse the linked map
from `anchor` through `shallows` to the farthest `trench` artifact, survive the
random encounters and both guardians produced by the game, and exhibit a real
casual-to-skilled strategy curve.

## Catalog

| ID | Bug hypothesis | User impact | Likelihood | Cheapest faithful test | Status |
|---|---|---:|---:|---|---|
| BAL-1 | The aggregate single-fight headline hides an unwinnable allowed pack size. | Critical: a legal encounter can be a run-ending wall. | Observed | Report wins separately for every production enemy count and require a nonzero casual floor. Current result: casual 0/38 against three grunts. | Fixed: level 1 rolls 1-2; three unlocks after level 2. |
| BAL-2 | The simulator recreates a full party for every fight, hiding HP, barrier, oxygen, and death attrition. | Critical: it cannot support the claim that the map is traversable. | Certain | Reuse the same `CombatantStats` resources for an entire seeded route. | Fixed and exercised over 240 routes/policy. |
| BAL-3 | The simulator omits the production 8-16 m/50% encounter process and the two guaranteed guardian battles. | Critical: it tests a different workload than reaching the artifact. | Certain | Walk the actual `Sites` graph distances, roll checks at production spacing/chance, and fight at every guarded site. | Fixed; guardians are now one visible actor/one battle pack. |
| BAL-4 | XP awards and level-up full restoration are absent, making any campaign model pessimistic and unlike production. | High: can produce false failures or motivate overtuning. | Certain | Award production XP after each win through `CombatantStats.gain_xp()` on the persistent party. | Fixed; campaign also applies the production 40% victory recovery. |
| BAL-5 | Both policies are assigned automatic QTE failure, so “skilled” measures move greed only. | High: it does not model the skill expression the player actually has. | Certain | Give named policies fixed, declared heavy-dodge success rates while keeping all other seeded inputs comparable. | Fixed: casual 30%, skilled 80%, declared in code/report. |
| BAL-6 | A successful route can still depend on an implausible lucky encounter count. | High: headline success conceals why runs pass. | Medium | Report route successes, random fights, guardian fights, enemies defeated, end level, and remaining HP by policy. | Fixed; successful casual/skilled routes average 4.3/4.9 battles and finish with 36.1/37.7 total party HP after growth. |
| BAL-7 | Test enemy scaling can drift from production's living-party reference. | High: dead members in the average make later enemies unlike the shipped game. | Medium | Build each pack from the average of living party members and production Goblin edge/floor constants. | Fixed. |
| BAL-8 | The casual policy treats formula-backed Scuba moves as non-damaging because they have no legacy `power` field. | High: the simulator silently skips the authored accuracy specialist's turns and reports the wrong strategy curve. | Observed after normalizing the roster. | Select damaging moves through the production formula evaluator when a formula is present. | Fixed; RED exposed skipped Scuba turns, GREEN exercises her formula moves. |
| BAL-9 | The legacy ordinary enemy's nine flat power was balanced against 26/42-HP teammates and routinely one-shots the authored 10/10/10 roster. | Critical: a casual player cannot survive the required chain of encounters even though every player stat is correct. | Observed: unchanged tuning produced 9.2%/30.0% route completion. | Run the fixed-seed isolated and persistent-route gates against the exact authored roster before accepting enemy tuning. | Historical fix: legacy fallback power became 3 and its HP floor was 15. The later authored Angler/Swordfish/Frilled roster replaces that shared floor with its own authored floors plus party scaling; BAL-10–15 revalidate the new system rather than claiming the old floor still ships. |
| BAL-10 | A historical route-green result is assumed to cover the later mixed Angler/Swordfish/Frilled-Shark roster, even though new authored moves alter campaign attrition. | Critical: a broad average can hide one new opponent or guardian that makes the far artifact implausible. | Observed: the current mixed-roster route was 28.8% casual / 61.2% skilled despite the earlier 52.5% / 92.1% green. | Report the exact stage and enemy identity at each terminal route loss before changing any production tuning. | fixed — diagnostics remain in the gate. |
| BAL-11 | The party reaches level 2 after only a couple of route fights, immediately enabling the three-enemy formation before the two-site introductory route has established the core loop. | High: terminal-route diagnostics showed level-2 three-enemy random packs were a substantial part of both casual and skilled losses. | Observed: the old level gate was `<= 1`, while successful runs average only level 1.9/2.0. | Keep the first two guarded sites to one/two-enemy packs, then run the existing fixed-seed route and isolated duration gates. | fixed — three-enemy packs begin at level 3. |
| BAL-12 | A random encounter can preempt the visible guardian as the player reaches an unclaimed artifact site. | High: it makes the source of combat ambiguous and adds an unplanned battle before the deliberate guardian challenge. | User playtest feedback: it is hard to tell whether a fight belongs to an artifact or random encounters. | Put a red test at the real guardian coordinate: an ordinary encounter signal must be ignored there, then the physical guardian must still open its chooser. | fixed — `verify/guardian_encounter_exclusion.gd`. |
| BAL-13 | The former 30% post-victory regroup was calibrated before the authored 10-HP roster and mixed enemy move set; winning a fight can still leave the next mandatory fight mathematically decided. | High: a player who wins does not receive enough recovery to keep trying the intended route. | Current route failures still cluster after multiple legal encounters even after zone exclusion. | Increase only the existing, visible post-victory recovery and require the fixed-seed campaign to retain HP pressure while meeting both route success floors. | fixed — visible recovery is now 40%. |
| BAL-14 | The average-duration gate treats a single Glassgoat-authored 5–8 HP fish and a multi-enemy formation as identical evidence of combat depth. | Medium: it pressures the team to inflate authored low-HP enemy stats just to satisfy an aggregate. | Observed: skilled average is 2.3 rounds, but the aggregate includes intentionally quick solo enemies. | Report wins and rounds by formation; require the two-enemy formation—not every fish—to meet the tactical-duration floor. | fixed — skilled two-enemy wins average 2.8 rounds. |
| BAL-15 | Early random formations give solo and two-enemy packs equal probability even though the first two artifact sites are the onboarding route for a new mixed roster. | High: casual players repeatedly meet the high-attrition formation before they can learn the enemy identities, while a single-enemy fight has no automatic-loss tail. | Observed: the prior casual route failed 52.1% of seeds after the three-pack and guardian-zone repairs. | Bias level 1–2 ordinary rolls toward solo enemies while retaining a material two-enemy chance; keep the multi-enemy duration and route-success gates. | fixed — 65% solo / 35% two-enemy. |

## Invariants fixed before tuning

- Route success means winning both guarded sites and therefore reaching the
  farthest artifact; running away is not counted as progress.
- The route starts from a full level-1 party, uses no consumables, and gives no
  between-fight heal except production level-up restoration. This is a
  conservative, reproducible baseline.
- Casual route success must be at least 50%; skilled route success at least
  80%; skilled must exceed casual by at least 10 percentage points.
- Every enemy count production can roll at level 1 must have a nonzero casual
  win rate in the isolated breakdown.
- Route and isolated reports use fixed seeds and production combat formulas.

## Skipped / intentionally not tested here

- Consumable discovery/use: excluding it prevents an item drop from disguising
  an impossible base route.
- Human reaction-time distributions: fixed QTE rates are transparent policy
  assumptions, not a claim to measured player physiology.
- Boss balance: `?boss=1` is a separate authored validation encounter and is
  not on the two-artifact grunt route.
- Geometry/pathfinding errors: `verify/sites.gd` owns physical reachability;
  this gate consumes its graph and distances.

## Post-write evaluation

PR #54's original RED was casual route 1.7%, skilled route 20.0%, and casual
0/38 against three grunts; its historical mixed-roster GREEN was 50.4%/84.6%.
Normalizing all three players to Glassgoat's authored 10 HP reopened the gate at
9.2%/30.0% and exposed that the casual policy skipped every formula-backed
Scuba attack. Fixing simulator fidelity alone raised isolated casual wins to
39.2% but left route completion at 11.2%/30.0%. Retuning ordinary enemies on
the same small-number scale produced final GREEN after the #66 sync:
76.7%/97.5% isolated wins and 52.5%/92.1% route completion, a 39.6-point route
skill gap. Successful casual and skilled routes average 4.3 and 4.9 battles
respectively, so success does not depend on avoiding combat.

The later mixed roster reopened the route at 28.8% casual / 61.2% skilled.
Terminal-stage reporting isolated early level-2 three-enemy packs, random
pre-emption inside an unclaimed guardian site, and attrition after legal wins.
The revised run is 54.6% casual / 93.3% skilled. It keeps Marc's open-water
8–16 m / 50% cadence, retains two-enemy formations during onboarding (35%),
and keeps three-enemy packs for level 3. A guardian-zone red/green test proves
the deliberate encounter remains reachable; the two-enemy skilled duration is
2.8 rounds, so quick solo fish do not disguise a collapsed tactical fight.
