# Bug Catalog: legacy highway goal versus active core route

**Scope:** `game/world.gd` route guidance and the older three-plate highway
puzzle. This is a captured browser-playtest failure, not a theoretical case.

## Module read summary

- **Public interface:** `RouteProgression.public_state()` provides the active
  objective; `World.route_guidance_presentation()` is the companion visible
  guidance contract added for this regression.
- **Load-bearing comments:** the route is intentionally separate from older
  optional content, and a player should see exactly one active route beacon.
- **IO boundaries:** physics `Area3D` plate occupancy, scene-frame visibility,
  and the player-facing objective banner.
- **Branching points:** `_check_gap_puzzle()` chooses whether all plates are
  occupied; `_begin_core_route_after_tutorial()` creates the active route;
  route objective transitions rebuild guidance.
- **Magic-string contracts:** route objective IDs including `shallow_angler`
  are defined in `RouteProgression.BEATS`, not inferred from scene names.
- **Existing coverage:** route physical traversal already covers the genuine
  authored trigger. It does not cover an unrelated old goal becoming visible
  after the core route is active.

## Bug catalog

| # | Bug | Blast radius | Why plausible | Test type | Status |
| --- | --- | --- | --- | --- | --- |
| 1 | Completing the legacy three-plate puzzle displays a large visual-only goal while a different core-route objective is active, causing a player to wait in a circle that cannot progress the game. | High — the player concludes the game has stalled and misses the authored route encounter. | `_check_gap_puzzle()` unconditionally showed `Waypoint`, while the new route can be active at the same time. | Captured physics/UI integration | caught on first run; fixed |

## Test plan

### Bug #1 — stale legacy goal competes with the active route

- **Description:** `route guidance: a completed legacy highway puzzle cannot
  expose a second inert destination during an active authored route — guards
  against standing in a visual-only goal with no progression`.
- **What it catches:** the exact playtest state: all three production divers
  occupy the real plates, the puzzle completes, and its non-interactive ring
  remains visible beside the active shallow objective.
- **Self-critique:**
  - It cannot pass for wrong-but-stable output because it requires physical
    plate completion *and* one unambiguous visible route state.
  - It does not depend on mesh names or a private route helper; it observes
    the documented guidance presentation after production physics signals.
  - A refactor may replace the legacy goal asset entirely without breaking the
    test, provided it never competes with an active route objective.

## Skipped

- The legacy highway's rewards/cutscene are not redesigned here; the captured
  defect is navigation ambiguity, not the puzzle mechanics.
- Browser typography of the completion announcement is deferred to the normal
  UI review, since this test pins its gameplay meaning.

## Evaluation

- **Bugs caught:** #1 failed initially: the active core route left the old
  `Waypoint` visible after actual plate completion. The repair suppresses it
  whenever a core objective is active and announces the continuing objective.
- **Bugs characterized:** the actual first authored trigger still starts its
  Angler battle from ordinary production swimming, and the reef crossing
  remains physically open after the guidance repair.
