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

RED on prior production tuning: casual route 1.7%, skilled route 20.0%, and
casual 0/38 against three grunts. After the level-1 pack/guardian correction,
the route was still RED at 19.2%/56.2%, isolating cumulative attrition. GREEN
after adding partial victory recovery. A later fidelity correction carried
partial segment distance and applied real growth fields. Final GREEN is casual
50.4%, skilled 84.6%, a 34.2-point gap; full `verify/gates.sh` and both local
and deployed browser gates are clean.
