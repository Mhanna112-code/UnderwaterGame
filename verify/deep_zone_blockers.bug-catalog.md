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

### DZ-BAL-001 through DZ-BAL-004 — provisional blocker stats lack measured bounds

- **Failure mode:** the two one-time fights are individually or sequentially
  unwinnable for a casual full party, strategy makes no meaningful difference,
  or the sequence creates no pressure at all.
- **Blast radius:** high; both fights are mandatory gates immediately before
  the lab.
- **Why plausible:** their models arrived without an authored stat sheet and
  the first-pass values were explicitly provisional.
- **Cheapest strong test:** a seeded production-rules policy simulation using
  the exact actor stat blocks, move catalogues, target scopes, multi-hit rules,
  base party kits, 30% post-victory recovery, and deterministic seeds. Require
  each fight and the two-fight sequence to remain winnable while preserving a
  strategy advantage in retained HP and measurable encounter pressure. A
  mandatory blocker does not need to create arbitrary casual losses merely to
  make a win-rate graph diverge.
- **Self-critique:** this can reject mathematically broken tuning but cannot
  judge whether the encounter *feels* fair or whether its animation timing
  communicates danger. The final browser playtest remains the accepting human
  boundary.

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

### DZ-BLOCK-012 — construction tests miss a browser-only Bomb Bot crash

- **Failure mode:** Bomb Bot imports and its battle can be constructed, but the
  hosted web game crashes during a real enemy turn or victory handoff.
- **Blast radius:** critical; the first mandatory laboratory blocker prevents
  all later route progress.
- **Cheapest strong test:** finish the production encounter through real battle
  menu actions, require an authored attack animation, return to the World, and
  then repeat attack turns in an exact HTML5 export while collecting browser
  console errors. Covered by `verify/bomb_bot_battle.gd` and
  `verify/bomb_bot_webcheck.mjs`.
- **Self-critique:** the local exact export closes the engine/web boundary, but
  the stable hosted PR URL must still be rebuilt from and replayed at the final
  SHA before the original report is closed.

### DZ-BLOCK-013 — a victory awards no usable progression

- **Failure mode:** the level and spell helpers pass independently, but an
  authored route victory never grants XP, a Spell Point, an auto-learned move,
  or a usable move in the next fight.
- **Blast radius:** high; combat progression exists in code but is invisible in
  the playable campaign.
- **Cheapest strong test:** place the real party one XP below level two, win the
  production Bomb Bot battle, then require every diver to level, learn/equip a
  move, and see that move returned by the next Sword Slayer battle's real move
  menu source. Covered by `verify/deep_zone_progression.gd`.

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
- **Balance result:** the exact provisional actors and production move rules
  produce 98.2% casual / 100% skilled two-blocker completion. Casual wins lose
  15.0 party HP on average; skilled wins lose 9.1, a 5.9-HP strategy benefit.
  The starting stat blocks therefore remain unchanged pending the required
  human browser playtest.
