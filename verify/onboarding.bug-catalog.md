# Opening-route bug catalog

The stacked tutorial must exercise the existing PR #50 gate rather than build a
second, disconnected level.  The tests below protect player-path contracts.

| ID | Fault / player-visible symptom | Cheapest meaningful test | Status |
|---|---|---|---|
| OB-01 | New Game leaves the world paused behind a modal tutorial, so a player cannot begin swimming. | Instantiate `World`, select New Game, assert HUD is visible and the tree is unpaused. | covered by `verify/onboarding.gd` |
| OB-02 | A random fight fires while the player is being directed to the locked route, interrupting ability learning before the maze. | Invoke the active diver's encounter handler while onboarding is active; assert no `Battle` is created. | covered by `verify/onboarding.gd` |
| OB-03 | The first objective is absent or points to an item/guardian rather than the entrance blockade. | Start onboarding; assert a visible route marker exists at the entrance blockade and no item guardian visibility changes. | covered by `verify/onboarding.gd` |
| OB-04 | Breaking the entrance rubble does not advance the objective, leaving the player without the Grapple instruction. | Emit the entrance wall's `broken` signal; assert step becomes `grapple` and marker moves to the far anchor. | covered by `verify/onboarding.gd` |
| OB-05 | A completed grapple crossing does not advance the route to the coordinated door puzzle. | Complete the registered far-anchor callback; assert step becomes `swap` and marker moves to the three-plate gate. | covered by `verify/onboarding.gd` |
| OB-06 | Opening the three-plate gate still leaves random fights suppressed, so the maze never reaches the core combat loop. | Occupy all plates, run puzzle check, assert doors open, onboarding completes, and one active-diver encounter creates a battle. | covered by `verify/onboarding.gd` |
| OB-07 | Load Game replays the first-run route and traps an existing save behind the tutorial gate. | Load a valid slot; assert onboarding is not activated. | covered by `verify/onboarding.gd` |

## Invariants

- The route uses only the existing entrance rubble, whirlpool/grapple anchors,
  plates, and doors produced by `World._build_highway()`.
- Route markers teach traversal only; artifact sites remain sonar-discovered,
  matching the accepted no-item-beacon feedback.
- `#50` is not changed. This branch is the integration/repair layer.
