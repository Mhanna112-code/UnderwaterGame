# Bug catalog: Control Room route replacement

Generated using design-tests, October 5. Scope: the scene-local draft component,
Maze route initialization/input and durable checkpoint restore (not autosaves).

## Responsibility and public interface

The component offers a once-per-approach Yes/No draft from the 12/13 hallway
to the water outside Box12. Yes moves the selected live capsule below wall and
skirt, then releases it into clear water. The Control Room remains reachable
without a navigation map. Maze campaign JSON restore is the migration boundary.
Public surfaces: real swimming, Y/N, E chest, L map, scene teardown and JSON
checkpoint restore. Geometry/party fixture placement isolates these contracts;
it is not proof of the full campaign journey.

Load-bearing rules: one-way passage; actual clear exit before opening a bounded
floor tunnel; shared actors can outlive this owner; retired paths must not return
on Load; acquiring the map never requires the map itself. Branches: inactive,
paused, modal/battle/moving-wall, outside approach, decline/reapproach, blocked
exit, three capsules, interrupted owner, legacy/new layout, optional map owned.
IO: physics capsule/surface queries; Tween time; checkpoint JSON/coordinate
rebasing; optional generated fixture/captures. No real player slots are used.
Magic-string contracts: wall names are authored scene identifiers; `maze_nav_map`
is MAP_ITEM; `_path_opened` is a legacy CAMPAIGN_FLAGS field, not a new gate.
Existing tests: maze_draft_passages (Break Room/return), marc_earned_map (pre-map
chest), coordinate/checkpoint tests. Preserve these rather than duplicate them.

## Bugs and cheapest useful tests

| ID | Failure mode | Blast radius / plausibility | Test | Status |
|---|---|---|---|---|
| BOX12-1 | Hallway approach never offers the new one-way route, or No immediately repeats | High: replacement missing in current source | Actual approach/Y/N, three capsules, wrong side/height and reapproach | fixed (missing-route red) |
| BOX12-2 | Yes clips floor/skirt, leaves input locked, or exits into solid geometry | High: upstream visual subtraction does not cut our global collision floor | Every-physics-frame independent capsule and solid-volume queries, input and teardown negatives | characterized with reused safe tunnel |
| BOX12-3 | Old opened-path saves restore retired walls or bury a previously clear diver | High: old restore recreates PathWalls and swung12/13 | Capture actual old E-route JSON before deletion; generated actor/frame/map states and cold restore, then real swimming | fixed; migration also avoids active pull zones |
| BOX12-4 | New fencing prevents unearned-map chest acquisition/return | High: route touches dome access | Real swimming/E/L on new outside path; rerun existing earned-map route | characterized; no dome geometry fix needed |
| BOX12-5 | Paused/inactive/modal approaches steal input or pause ownership | High: a shared lesson can pause during the same physics tick | Public lesson/input composition plus inactive/wrong-side decision table | characterized; explicit paused/inactive guard |
| BOX12-6 | Ordinary chase camera collapses into the diver while its target goes below the floor | Medium: native Bucky motion capture showed a screen-filling model | Real-motion camera height invariant plus inspected native motion capture | fixed after native inspection |

Self-critique: node absence is only a secondary retired-route oracle. Primary
oracles are clear physical movement, unchanged resources/progress, actual chest
reward and durable migration. Expected route sides use authored wall/dome
geometry, not component cached coordinates. Migration uses captured pre-change
JSON, not fabricated copies of the new algorithm. Wrong-but-stable geometry
fails collision and movement checks. Generated cases cross selected actor,
coordinate origin and owned/unowned map; cosmetic refactors do not change these.

## Skipped / deferred

- C5 riders/collision, posterior barrier and hall whirlpools: next geometry batch.
- Autosave filesystem/browser durability: separate later intake batch.
- Full New Game journey/human discoverability and hosted browser: final campaign
  acceptance, not established by fixture-local physical traversal.
- Exact particle colours/wording: visual inspection, not format-lock assertions.

## Post-write evaluation

Missing-route red reproduced on baseline 0d147b9. Initial migration port found
a capsule immediately sucked through home Box12 by C4's nearby whirlpool:
safe-side migration now rejects active suction/pull radii and uses clear nearby
water. Native inspection found chase-camera collapse; passage motion uses the
existing overhead camera and restores normal follow afterward. Final three
capsule traversals, 240 sampled motion frames, six wrong side/height cases,
actual No/swim/reapproach/Yes, paused reading lessons, all input locks and
zero-Oxygen resource conservation pass. Three blocked exits and three real
owner removals pass. 36 old/current-frame × selected-diver × map × placement
JSON cases plus raw historical cold Title Load and real swimming pass.

Rejected observers: a nonexistent map process method made the first legacy
capture invalid (script errors despite a clean label); rerun generated the
accepted fixture before production edits. Reapproach originally steered into
the separate C4 hazard and waited for a waypoint after an automatic prompt;
use the capsule-clear wall-side approach and stop on the real prompt. Bucky
cannot pass the raised porch at Max's nominal height or above its ceiling:
real SPACE/Shift taps settle her capsule within the actual doorway. Neither
current/whirlpool nor dome collision was disabled or retuned for that test.
The initial narrow capture was still 1280px: resize the live window and assert
the requested rendered dimensions. These are fixture repairs, not product fixes.

Suspect/omission probes: capsule-only intersection can accept solid CSG
interiors (independent volume rejection retained); migration must not place an
actor into a live hazard (caught and repaired); modal/reading ownership must
compose with an automatic draft (actual paused lesson/input probe passes).
Native wide and true 360×640 captures inspected; logs/source hashes retained.
Full campaign, hosted browser and C5/whirlpool integration remain outside this
accepted batch and stay required by the comprehensive completion ledger.
