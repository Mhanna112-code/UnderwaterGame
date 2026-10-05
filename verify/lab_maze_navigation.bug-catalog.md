# Post-laboratory maze navigation

Generated with design-tests, 2026-10-05.

## Responsibility and public boundary

World owns the exploration camera, actual diver swimming and HUD. DeepZoneEnvironment deliberately conceals Broken Office inside a rock shell. After the Tethys result, RouteState persists `lab_state=cleared` and `tethys_state=defeated`; maze ownership is independent of lab victory. The ramp begins at the eastern World boundary, not at the earlier maze landmark. Navigation must survive those sight-line obstructions without changing either progression rule.

Load-bearing contracts: opening the lab disables only its door backing; the side shell remains physical. World stops moving actors while a battle/menu/maze owns input. A cold checkpoint reconstructs geometry and HUD, not a transient victory callback.

IO: camera-relative input, physics/collision, viewport resizing, rendered frames, checkpoint decoding. The focused fixture supplies a completed lab milestone, not evidence of earned victory. Existing `lab_payoff.gd` separately wins the actual fight.

Branches: incomplete prologue; lab not cleared; post-victory Deep exploration; Shallows; menu/aim/battle; maze ownership; completed campaign; cold Load. The state strings are enumerated in `game/route_state.gd`.

## Bug catalog

| ID | Failure | Impact and plausibility | Test | Status |
|---|---|---|---|---|
| NAV-1 | The rock shell/fog hides the maze destination after Tethys. | High: the next route is undiscoverable; existing world-space MAZE sign is behind opaque rocks. | Captured visual/World contract: unobstructed screen-space directional guidance from the lab exit. | Fixed |
| NAV-2 | A visible indicator points into collision rather than a usable entrance. | High: an apparent fix still strands the player. | Actual camera-relative W swimming from the lab return position across the real ramp, without teleport or injected entry. | Characterized: real route traversable |
| NAV-3 | Guide leaks into battle/maze/menus or is lost on Load. | Medium: multiple navigation/input owners; victory-only activation would fail cold Load. | World state transitions and checkpoint round-trip, observe rendered HUD visibility. | Characterized |
| NAV-4 | Arrow direction/layout breaks with camera rotation or narrow screens. | Medium: pointing east in screen space regardless of camera would send players backwards. | Seeded camera-angle/viewport invariant: displayed pointer agrees with physical destination; card remains in view and below controls/objective. | Fixed party-bar overlap; direction characterized |
| NAV-5 | The collision-clear exit still runs through opaque rock meshes, blacking out the camera. | High: a compass-only fix is navigable but visually broken; native swim capture exposed it. | Inspect actual exit swim render, and retain pre-victory concealment; cleared-state Load rebuilds the open sight line. | Fixed after rendered defect |

## Self-critique

- NAV-1 asserts a visible player-facing guide, not a private callback or exact prose. Rendering is inspected separately: a node existing alone cannot prove readability.
- NAV-2 does not use supplied `won`/entry signals or move actors during the route. A stable-but-blocked path fails.
- NAV-3 observes visibility while real owners change and after normal checkpoint restore, not a newly invented persistent flag.
- NAV-4 uses independently calculated camera-forward/right bearings across more than five poses. Exact styling is not locked; only arrow direction and usable bounds are contractual.

## Skipped

- Combat rebalancing, maze redesign, lab prerequisites and lab exterior art replacement: outside this navigation fix.
- Earned whole-campaign balance: supplied milestone fixture isolates the exit. Existing actual fight gate remains required.
- Audio: a persistent visual guide needs no additional alert or music change.

## Evaluation

Initial original-code missing-guide result used a fixture whose HUD was also hidden. That fixture was rejected and corrected; it is not acceptance evidence. The corrected missing-guide wiring mutation fails with HUD=true, camera=true, paused=false. Restoring the production wiring passes. The compass-only run reached the maze through real W swimming but exposed NAV-5 in the native screenshot. Clearing the two exit-cover clusters after victory removes that blackout; pre-fight shell/door/interior regression still passes.

Native rendered review additionally found NAV-4: party HP/O2 overlapped navigation at narrow widths despite the initial bounds test passing. The objective now reserves the party column where they share horizontal space, and the compass sits beneath it. The strengthened intersection invariant and inspected 1280/720/360-by-720 screenshots pass.

Adversarial checks: 18 seeded camera/width combinations agree with the physical ramp bearing; ordinary W swimming reaches the same embedded maze without teleporting; actual legal-kit Tethys victory and cold Title Load retain guidance; inventory, actual battle and maze ownership remove it. No fake won result is used in the separate Tethys regression.

Scope: the route fixture supplies lab completion. It does not prove earned campaign balance or subjective whole-game polish. Browser/export acceptance is recorded separately in the evidence receipt.
