# Latest authored maze drafts: focused October 5 admission

Source batch based on PR #100 `2f89a61`, with the code/tests in the commit
containing this directory. No new PR, main merge or deployment. Existing review
alias still serves `bffe1b5`; it does not prove these repairs.

## What is carried

Marc #97 `4ec6598` one-way outgoing Break Room draft below Wall11EndCap,
separate automatic incoming draft below settled swung wall 11, latest 10/11
west-end alignment, Wall11Closer, home-state line barrier and northern barrier.
All movement retains the World-owned party and resources. No separate scene,
portal save, reward or recovery grant is introduced.

## Failures reproduced and repaired

- `missing-passage-red.log`: actual approach offered no outgoing question.
- `floor-red.log` / `skirt-red.log`: endpoint-only green hid collisions during
  the under-wall motion. A bounded temporary floor cut retains solidity outside
  the tunnel, and the capsule travels below the actual skirt before resurfacing.
- `teardown-red.log`: removing the transient owner resealed the floor around
  the shared actor. Abort restores its safe departure before sealing/unlocking.
- `blocked-exit-red.log`: concave CSG surface queries accepted a capsule wholly
  inside a solid box. Solid-volume validation now safely aborts the passage.
- `legacy-alignment-red.log` / `legacy-volume-red.log`: old saves restored the
  superseded wall target or buried a previously clear player inside its new
  location. Only the recognized old transform is migrated; overlapping party
  members move clear without changing HP/Oxygen/inventory/puzzle progress.
- Native inspection: the dark slot marker hid the diver during descent; it now
  hides while the physical tunnel is open. Settled wall copy now says OPEN or
  CLOSED rather than permanently saying "swinging". The question fits 360px.

## Accepting checks

Commands use `/opt/homebrew/bin/godot` 4.7.1 on macOS. Inspect full logs for
findings/script errors as well as process status. These are also registered in
`verify/gates.sh`.

| Receipt | Observable contract |
| --- | --- |
| `passages.log` | Three outgoing actors, 12 return actor/state/direction cases; 476 independent whole-motion checks; one-way/No/rearm; moving-wall negative; actual held-key departure; floor elsewhere remains solid and reseals afterward |
| `blocked-exit.log` | Real Yes with a physically blocking CSG volume aborts safely rather than starting motion into it |
| `teardown-0.log`, `teardown-1.log`, `teardown-2.log` | Actual transient-owner removal mid-motion restores each shared actor to its departure, releases suction and reseals the floor |
| `restores.log` | Six current/legacy JSON restores, solid-interior saved-placement checks, actual returns and fresh Title Load from legacy standalone coordinates; shared resources/slot conserved |
| `coordinate-frame.log` | Existing 144 generated frame/state cases and malformed-frame negatives preserved |
| `embedded-checkpoint.log` | Existing 48 World/maze checkpoint cases and legacy cold Title Load preserved |
| `embedded-ramp.log` | Physical bidirectional ramp/floor seam and live ownership preserved |
| `current-route.log` | Actual earned-map first-channel swimming, currents and map controls preserved |
| `chest-ownership.log` | Six actual chest/actor input-lock cases preserved |
| `input-ownership.log` | Three actors retain exclusive map/save/Swap owners, real Ctrl+E/R/E and strong-room policy through the new embedded entrance |

Disposable slot **918365** is refused if already present, created solely for
the cold-load test, then removed. Player slots are not touched. The embedded
checkpoint regression separately owns disposable 918359 under its same guard.

## Inspected native frames

1280x720: `outgoing-question.png`, `outgoing-approach.png`,
`outgoing-in-motion.png`, `outgoing-exit.png`, `return-approach.png`.
360x640: `outgoing-question-narrow.png`.

Generated with `tools/shoot_maze_drafts.gd`, real production World/party,
passage inputs and camera, **fixture placement near the passage**, opening/
training skipped, random/strong-room encounters and Sonar off. Frames are not
an earned normal journey, browser test, resource-balance test or proof that
the rest of the campaign is complete. No character stats/level-five kit is
granted to claim a campaign win.

## Evidence rejected, not counted as product fixes

A verifier variable-shadowing parse error; an old separate-scene input fixture;
endpoint-only and concave-surface-only greens; an incorrectly positioned first
saved-overlap probe. Strengthened or corrected observers replace those results.

## Still required by the full plan

Remaining moving-wall rider/floor/whirlpool routes, discovery map/intro,
first-person aim, Sonar Vision, radius encounters and notification queue;
recovery/scaling and earned-route balance; Tethys opening/Cordys finale pivot;
durable completion/interrupted saves; full suite and actual browser journeys;
matching web/Windows/Linux export delivery and final PR/issue reconciliation.
No whole-geometry or merge-ready claim is made.
