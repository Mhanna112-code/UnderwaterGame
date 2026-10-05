# Marc's ready-door map priority and physical reach

October 4, 2026. Sources #97 `6758afb`, plus door reach from `bbadaaf`.

Complete KeyDoor, MazeLevel and MazeMiniMap read. KeyDoor opens one morphing
delivered asset, releases collision late in its Tween, spends one maze key via
the maze callable, and remembers each door separately. Its campaign-key path
is not the maze count. Plain map E currently always rotates a selected wall;
Ctrl+E must keep moving currents. A nearby *ready* door must take plain E first.
Missing/out-of-range/open doors do not take map priority; normal exploration's
missing-key feedback still owns E. Interaction reach should use nearest physical
door surface, not its floor-level origin. Door transforms and animation frames
are IO-like boundaries; independent campaign relics and spend-once matter.

| ID | Bug / risk | Cheapest high-leverage test | Status |
| --- | --- | --- | --- |
| DOOR-1 | E rotates walls with a ready door and open map; key not spent | High: real route blocked while following valid controls | Actual L/arrow/E dispatch, real door and collision/Tween, all three divers and keyed/free doors; wall transforms unchanged | reproduced and repaired |
| DOOR-2 | At the top/side of visible door E cannot reach it | High: apparent dead interaction; large door floor origin used | Real actor near independently measured collision top, real E with map open and closed | reproduced and repaired |
| DOOR-3 | Priority steals Ctrl+E or consumes key/relic repeatedly | High: removes puzzle agency/progression | Actual Ctrl+E moves same current, door stays shut; opened/missing/far-door map E still rotates wall; count and campaign relic invariants | generated checks pass |
| DOOR-4 | A missing-key door earlier in iteration steals E from another ready door | Medium: ready check and actual selected door disagree | Two actual overlapping doors with different eligibility; real E opens only eligible door | intermediate upstream port reproduced; repaired ready-only dispatch |

Generated owner cases: three divers × nine door/input states. Placement and
full discovery are interaction fixtures, NOT evidence of earned chest/map or
physical route traversal. No save slots are written. Oracles are actual opened
door, late collision release, remaining key count, unchanged campaign relics,
wall transform/current identity, not can_unlock helper truth or announcement text.
Skip full maze route, browser interaction, look/animation polish and earned map.

## Evaluation

Valid baseline `/tmp/underwater-marc-map-door-red-final.log`: ready-door map E
rotated walls rather than opening, and closed-map E failed at the door top.
First port of ready check/reach fixed both but left six overlap failures in
`-priority-first.log`: ready check found the free door, ordinary iteration used
the earlier locked door. Ready-only dispatch repairs that actual eligible-owner
mismatch. Semantic readiness uses keys directly, not fragile prompt punctuation.
All 27 cases pass in `-green.log`, retaining normal missing-key behavior outside
the map. Actual input-owner/checkpoint regressions and lab asset gate also pass
in `-input.log`, `-checkpoint.log`, `-lab.log` (same prefix).

Native rerun `/tmp/underwater-marc-map-door-native-ownership.log` passes all 27
parsed-input cases without script errors. First native captures used an 8m
fixture camera inside the opposite wall, bypassing production camera collision;
those are rejected. A closer capture exposes the actual open doorway and was
inspected in `/Volumes/Totallynotaharddrive/underwater-marc-door.VmQ6HD`.
This staged close view is NOT normal chase-camera/presentation acceptance.
An earlier native run recorded extra wall rotation/unrequested encounter copy;
not accepted. Fresh verifier windows opt out of OS focus so unrelated desktop
typing cannot enter these deterministic input cases. The controlled rerun is
clean; the first run's cause is not conclusively established as a product bug.

Excluded fixture oracle: reading the *new* nearest wall selection after L closed
and comparing it with the old set's transforms falsely reported wall changes.
The accepting test retains the same actual wall node identities across input.
Downstream failures after a door never opened are not separate double-spend
reproductions. Browser keys, earned map, full physical maze route and chase
camera/visual polish remain explicitly unaccepted by this batch.
