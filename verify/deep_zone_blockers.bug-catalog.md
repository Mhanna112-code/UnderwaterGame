# Deep-zone blocker bug catalog

## Public interface

The public progression contract is `World.route_state` plus the physical world
the active `Diver` can traverse. Bomb Bot and Sword Slayer are ordered,
one-time `lab_blocker` encounters. The lab interaction point must not be
physically reachable until both blocker states are `defeated`.

## Load-bearing invariants

- A blocker is not a waypoint. It must physically prevent access to the lab.
- Bomb Bot victory opens only the first stage; Sword Slayer still blocks the
  lab.
- Sword Slayer victory opens the lab route.
- The barrier must work throughout the swimmable water column. A persistent,
  visible cave roof may bound the valid low-water route; it must not disappear
  with either gate.
- Save/load and loss/retry may change lifecycle state, but they must never
  silently open a stage whose blocker is still available or in progress.

## IO boundaries and branching points

- `RouteState` save/load converts JSON-safe lifecycle strings back into live
  progression state.
- `World._update_deep_zone_blockers()` branches by blocker order and proximity.
- `World._resolve_deep_zone_blocker()` branches on result and blocker id.
- World collision is the final product boundary: a correct state label is not
  sufficient if a diver can swim around the encounter volume.

## Existing coverage

`verify/deep_zone_blockers.gd` already covers actor identity, stats, move clips,
battle dispatch, win/loss/flee, persistence, and visible actor lifecycle. It did
not previously ask whether the two encounters actually block the route.

## Ranked bugs

### DZ-BLOCK-010 — proximity-only encounters can be bypassed

- **Failure mode:** the player swims around the small trigger radii and reaches
  the lab while Bomb Bot and Sword Slayer are still available.
- **Blast radius:** critical; the authored route order and both required fights
  are optional in normal play.
- **Why plausible:** the deep zone is open 3D water, while the implementation
  uses two four-metre horizontal distance checks with no enclosing geometry.
  The exact-head audit reproduced the failure at the lab objective.
- **Cheapest strong test:** a physical reachability invariant on the production
  `World`, sampled at low and high swim elevations. The lab must be unreachable
  initially and after only Bomb Bot is defeated; after both are defeated, the
  valid low cave route must open while the high over-roof bypass stays closed.
- **Self-critique:** this asserts the player-visible outcome rather than node
  names, collision-shape counts, or implementation calls. It would fail for a
  stable but bypassable arrangement and survive a refactor to different visible
  gate geometry.

### DZ-BLOCK-011 — full-width field has a dead encounter edge

- **Failure mode:** a player approaches either side of the visible pressure
  field outside the old radial trigger, collides with it, and receives no fight
  or actionable response.
- **Blast radius:** high; the correct route appears broken even though the
  anti-bypass geometry works.
- **Why plausible:** the physical field is twenty metres wide while the old
  trigger was a four-metre circle around its centre.
- **Cheapest strong test:** production-world decision table across the left,
  centre, and right passable lanes. Each approach must dispatch exactly the
  authored Bomb Bot encounter, then loss/flee must remain latched until the
  player exits the entire field approach.
- **Self-critique:** this observes the battle identity and lifecycle outcome,
  not the trigger shape or helper method. A different interaction volume can
  replace the current geometry without changing the test.

## Skipped

- Exact visual style of the route gates: semantic tests cannot judge whether a
  barrier looks intentional. The mandatory 1280x720 and narrow-browser visual
  audit owns this.
- Exact blocker actor offset and scale: already covered semantically by the
  visible-bounds and production-stage checks, then judged visually.
- Lab cutscene, Tethys handoff, and maze transition: separate missing product
  boundaries with their own catalog entries and tests; they should not be
  hidden inside the blocker test.

## Evaluation

- **Caught:** DZ-BLOCK-010 reproduced the exact-head laboratory bypass at low
  and high swim elevations. DZ-BLOCK-011 reproduced the dead encounter edges
  created when the physical field became wider than the original radial
  trigger.
- **Characterized:** actor, battle, lifecycle, and persistence contracts from
  the pre-existing focused gate, plus left/centre/right dispatch, full-field
  loss/flee latching, low/high route reachability, and interrupted-save
  reconstruction.
- **Discovered while writing:** the first repair rendered the field as a giant
  opaque rectangle; the blocker actors were initially below the floor; the
  fixed-width HUD overlapped the minimap at 720x480; and Sword Slayer's long
  silhouette overlapped Bucky in battle. Those visual defects are recorded in
  `VISUAL_POLISH_AUDIT_LOG.md` and rejected before the local candidate was
  accepted.
- **Current result:** both catalogued route defects pass on the local candidate
  at the semantic boundary and in 1280x720/720x480 production captures. They
  remain unproven in a fresh hosted browser build until that candidate is
  committed, exported, deployed, and traversed from the ordinary title flow.
