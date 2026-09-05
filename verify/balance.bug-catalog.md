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
| BAL-4 | XP awards and level-up full restoration are absent, making any campaign model pessimistic and unlike production. | High: can produce false failures or motivate overtuning. | Certain | Award production XP after each win through `CombatantStats.gain_xp()` on the persistent party. | Fixed; campaign also applies production 30% victory recovery. |
| BAL-5 | Both policies are assigned automatic QTE failure, so “skilled” measures move greed only. | High: it does not model the skill expression the player actually has. | Certain | Give named policies fixed, declared heavy-dodge success rates while keeping all other seeded inputs comparable. | Fixed: casual 30%, skilled 80%, declared in code/report. |
| BAL-6 | A successful route can still depend on an implausible lucky encounter count. | High: headline success conceals why runs pass. | Medium | Report route successes, random fights, guardian fights, grunts defeated, end level, and remaining HP by policy. | Fixed; final successful runs average 4.1/4.6 battles and 5.3/6.5 grunts. |
| BAL-7 | Test enemy scaling can drift from production's living-party reference. | High: dead members in the average make later enemies unlike the shipped game. | Medium | Build each pack from the average of living party members and production Goblin edge/floor constants. | Fixed. |
| BAL-8 | The casual policy treats formula-backed Scuba moves as non-damaging because they have no legacy `power` field. | High: the simulator silently skips the authored accuracy specialist's turns and reports the wrong strategy curve. | Observed after normalizing the roster. | Select damaging moves through the production formula evaluator when a formula is present. | Fixed; RED exposed skipped Scuba turns, GREEN exercises her formula moves. |
| BAL-9 | The ordinary enemy's nine flat power was balanced against legacy 26/42-HP teammates and routinely one-shots the authored 10/10/10 roster. | Critical: a casual player cannot survive the required chain of encounters even though every player stat is correct. | Observed: unchanged tuning produced 9.2%/30.0% route completion. | Run the fixed-seed isolated and persistent-route gates against the exact authored roster before accepting enemy tuning. | Fixed on the same small-number scale: ordinary power 3 and HP floor 15. |

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
the same small-number scale produced final GREEN: 85.0%/98.3% isolated wins,
53.3%/93.3% route completion, and a 40-point skill gap. Successful casual and
skilled routes average 5.0 and 6.6 defeated grunts respectively, so success does
not depend on avoiding combat.
