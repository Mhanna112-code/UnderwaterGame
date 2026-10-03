# Deep-zone Spatial Route Bug Catalog

## Scope

The existing ability corridor ends near x=47, but the original 120×120 world
has an invisible east boundary near x=62. This gate establishes a shared,
expanded layout before actors or lab content are placed. It deliberately tests
real World collision rather than treating coordinates in a document as proof
of reachability.

## Bug catalog

| ID | Observable failure | Cheapest catching test | Status |
| --- | --- | --- | --- |
| DZ-ROUTE-001 | Deep entry, either blocker, lab, or maze transition lies outside supported floor or behind the old invisible x=62 boundary. | Downward floor rays plus diver-sized collision samples along both production route branches. | Covered by `verify/deep_zone_route.gd`. |
| DZ-ROUTE-002 | New content is compressed into the shallows instead of occupying a distinct expanded region. | Shared layout requires ordered lab beats, minimum travel spacing, and a maze branch spatially separate from the lab. | Covered by `verify/deep_zone_route.gd`. |
| DZ-ROUTE-003 | The new region is numerically called Deep but looks identical to the shallows. | Compare the production deep-floor material luminance against the original shallow floor. | Automated treatment covered by `verify/deep_zone_route.gd`; browser aesthetic review remains mandatory. |
| DZ-ROUTE-004 | Tests force RouteState to Deep, but normal physical travel never changes the public zone/objective. | Move the active production Diver across the shared boundary and observe `RouteState`. | Covered by `verify/deep_zone_route.gd`. |
| DZ-ROUTE-005 | A random encounter can fire inside an authored blocker, lab, or maze-transition safety volume. | Shared encounter-policy decision table at open-water and protected points plus production dispatch behavior. | Covered by `verify/deep_zone_route.gd`: protected beats/corridors suppress random dispatch while open deep water still starts an ordinary fight. |
| DZ-ROUTE-006 | The expanded deep zone is an empty dark plane with no readable threshold, laboratory silhouette, or distinct maze branch. | Require three production-world landmark groups with renderable approach-scale bounds, then inspect repeatable 1280×720 route captures. | Covered after `DZ-VIS-001`: entry/lab/maze production captures retained under `docs/evidence/deep-zone-route/`. |
| DZ-ROUTE-007 | Crossing into Deep changes internal state but never tells the player what to do next. | Physically cross the production boundary and require one visible objective owner whose text names Bomb Bot. | Covered by `verify/deep_zone_route.gd` and the retained entry capture. |

## Self-critique

- Collision sampling proves a diver-sized volume is not blocked at the sampled
  route, but not that a human can read or enjoy the route. Both normal and
  narrow browser journeys remain required.
- Material luminance catches a missing treatment, not artistic quality.
- This first gate excludes the blocker actors themselves. Their one-time
  trigger volumes and loss/retry behavior receive a later decision-table gate.
