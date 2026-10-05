# Maze map discovery and first-open contract

2026-10-05. Frozen authored source: #97 4ec6598, including f698bee.

## Module understanding

MazeMiniMap (read end to end) discovers walls, rooms, currents and points of
interest from the live diver, draws radar and overview, handles L/E/Ctrl/arrows,
and round-trips discovered identities through plain campaign data. MazeLevel
provides physical POIs, map ownership and regional access. CharacterAbilityPopup
(read end to end with its scene) owns the paused lesson and retains battle-safe
WeakRef callers. CampaignCheckpoint validates the JSON boundary; old saves may
lack newly optional presentation state.

Public boundaries: real key input, real chest E/reward, visible legend words and
icons, wall projection, public discovery restore/campaign snapshot, viewport
resize, pause and scene lifetime. No network or randomness in map rendering;
generated discovery subsets and sizes exercise conditional output. Branches:
unearned/out-of-area L rejects; battle/modal/aim blocks; first versus repeated
open; revealed versus unknown POIs; current present versus moved away; wide side
legend versus narrow stacked legend; present/missing/invalid saved intro state.

## Ranked catalog and self-critique

| ID | Failure and blast radius | Test/oracle | Status |
|---|---|---|---|
| DISC-1 | First L pauses before projection/layout, or never teaches navigation. A player sees bunched geometry or unexplained keys. | Actual chest E then L, inspect pause/lesson and projected wall bounds immediately before any gameplay process tick. No helper invocation; earned traversal is a separate route gate. | Characterized synchronous first-dispatch projection; authored introduction implemented. |
| DISC-2 | Legend discloses unvisited bosses/rooms or omits discovered chest/boss symbols. | Generated public restored discovery subsets; inspect actual visible legend labels, independently derive expected kinds from fixture identities; native icon inspection. | Missing legend/boss POI caught and repaired; 64 subsets pass. |
| DISC-3 | New legend/help runs off short/narrow viewports or blocks the diagram. | Real viewport resizing including paused first-open, widget/text bounds, native 360x640 and 720x480 frames. | Narrow lesson clipping caught and repaired; 12 paused shapes pass. |
| DISC-4 | Restore retains old rendered rooms/lines after discovery is replaced. | Open full discovery then public restore empty discovery; rendered lines/legend must lose unknown content. | Replacement now clears drawings; full-to-empty plus 64 generated replacements pass. |
| DISC-5 | First-open lesson replays after load or new optional field invalidates old saves. | JSON round-trip through checkpoint validator and public restore, real L after load; legacy missing field accepted, malformed field rejected. | New/legacy JSON round trips and five invalid types pass. |
| DISC-6 | Browser smoke falsely requires a pre-granted map, or accepts ambient frames as map success. | Served hash plus actual keyboard swimming/E acquisition then L/OCR; no grant or internal state injection. The existing 703fa50 rejection is an obsolete observer, not a product red. | confirmed obsolete observer |
| DISC-7 | A narrow text-only map lesson leaves its panel offsets behind when a later authored video lesson opens. | Public popup pages: narrow text lesson, then a real Grapple clip at desktop size; inspect the visible panel's centering and media bounds. No private refresh call. | Characterized; viewport resize refreshes text offsets before media opens, so suspected desktop regression retracted. |
| DISC-8 | An unread orange notice remains drawn through first L because the lesson pauses before the next physics visibility update. | Actual chest E/R/L, assert active notice before L and hidden banner immediately after the first dispatched L; keep the paused lesson and verify the same notice reappears after closing the overview. Physics is disabled in this existing projection fixture, so no later frame can repair the failure. | caught; synchronous Maze-owned visibility fixed; headless/native checks pass |

Each test asserts output semantics, not a private call count or exact prose.
Wrong-but-stable hidden content, invalid projection, missing lesson or resource
grant fails; implementation refactors preserving these public behaviors pass.

## Skipped / bounded claims

- No New Game or whole-campaign claim from a near-chest layout fixture.
- New radius-site persistence and full map route remain their own admission.
- Exact punctuation/colors aren't correctness oracles; screenshots supplement
  semantic checks for visual legibility and icon presence.
- The old artifact/browser failure does not prove current L input is broken:
  unearned map rejection is intentional and must stay.

## Evaluation

- October 5 Sonar composition follow-up: actual first L with an unread notice
  reproduces DISC-8 while physics is disabled and the lesson pauses the tree.
  Maze listens to map visibility and relinquishes/restores captions in the
  same dispatch. New paused red/green and 12 native viewport receipts are in
  `docs/evidence/sonar-vision-oct5`; prior map/browser claims below stay bounded
  to their original source, not this newly changed export.
- Caught: missing discovery-only legend and visited-boss POI; the text-only
  first-open lesson clipped 360x640. Captured reds and accepted native receipt
  are in `docs/evidence/maze-map-discovery-oct5`.
- Characterized: synchronous first-dispatch projection, generated discovered
  kinds, replacement drawings, optional JSON lesson history, media transition.
- Separate earned routes pass through actual E/L acquisition in standalone,
  shared-World ramp and actual `--maze-playtest` contexts. Real cold title Load
  keeps the World owner, selected disposable slot and earned map.
- Invalid observers excluded: asserting before buffered input dispatch;
  restoring discovery and then allowing genuine local reveal to alter mask 0;
  using Godot's reserved `--embedded` flag (display-server abort, not a game
  crash); expecting old standalone topology after embedded cold Load.
- Browser baseline: the old `703fa50` pack rejects unearned L and earns its map
  with real swimming/E/L. Initial fixed-time steering did not reach the chest;
  adding unnecessary ascent at a review spawn already at Y=2 hit clearance.
  A native reproduction locates the correct route and the browser driver now
  stops on the real E prompt. Neither failed driver attempt is a product red.
  This baseline does not admit the new legend/intro; fresh export acceptance
  remains a separate requirement.
- Fresh `2054d11` local exported pack passes actual browser acquisition,
  first/repeat L, paused lesson and overview at 1280x720, 720x480 and 360x640.
  Rendered captures inspected. Initial narrow OCR rejection split intact prose
  across two lines; whitespace-aware assertion fixes that observer, not UI.
  Receipt and identified PCK hash: `docs/evidence/maze-map-discovery-oct5/browser`.
- No tests removed. No whole campaign, human discoverability, hosted-current
  build or target-platform launch claim follows from this bounded batch.
