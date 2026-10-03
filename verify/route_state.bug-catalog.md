# Route State Verification Bug Catalog

## Scope

Public authored-progression state for the deep-zone route, including save/load
round trips and objective-change observation. World geometry, combat dispatch,
and presentation are covered by later vertical slices.

## Bug catalog

| ID | Observable failure | Cheapest catching test | Status |
| --- | --- | --- | --- |
| ROUTE-STATE-001 | After saving and loading, the current zone/objective, either lab blocker, lab/Tethys progress, maze-door availability, Octopus availability, or the encounter source resets or changes. | Pure RouteState serialization round trip covering every public field. | Covered by `verify/route_state.gd`. |
| ROUTE-STATE-002 | The HUD or another route consumer cannot react when the active objective changes. | Connect to `objective_changed`, change the objective through the public API, and assert one signal carrying the new id. | Covered by `verify/route_state.gd`. |
| ROUTE-STATE-003 | A malformed save silently installs an impossible lifecycle value. | Load invalid lifecycle strings and verify documented safe defaults. | Planned after the public happy-path contract is green. |
| ROUTE-STATE-004 | A World checkpoint omits RouteState even though RouteState itself can serialize. | Real World + SaveManager restart round trip. | Planned next. |

## Test-design self-critique

- The first test intentionally stays below `World`; it proves the public state
  object before integration and will not catch an omitted call from
  `World._serialize_state()` or `_load_save()`.
- It asserts behavior through the public API and save dictionary, not internal
  helper calls or implementation structure.
- It does not claim route geometry, encounters, or UI work exists.

