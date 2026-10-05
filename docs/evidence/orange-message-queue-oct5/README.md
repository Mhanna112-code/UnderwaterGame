# Orange message FIFO — October 5 focused admission

This folder accompanies the source batch that contains it. Native Godot 4.7.1
Compatibility rendering, Apple M1/macOS; no browser-export or hosted admission.
The existing PR100 review alias still serves the older bffe1b5 artifact.

Scene-owned transient notices now retain one current message and up to four
waiting notices. The authored newest-four overflow policy is retained; exact
duplicates and encounter toggles cannot accumulate an unbounded backlog.
Each notice receives its own full readable duration. World/Maze preserve notices
while reading menus or the map; save-point held text follows the drained queue.
Queued E feedback uses an interaction revision rather than relying on the
currently visible notice changing. No tutorial-popup or save schema rewrite.

## Accepted evidence

- `model-green.log`: 228 generated FIFO/duplicate/toggle traces plus duration,
  negative-time and clear checks through the queue's public API.
- `input-green.log`, `native-green.log`: actual R/Q input, twenty R toggles,
  Inventory/map/Save-menu preservation, physical W into the real save Area3D,
  whole-party HP/O2 contact restoration, held P prompt and real queued E at
  the split rock; repeated E cannot prolong the notice, next E works after drain.
- `slot-green.log`: real permission-denied atomic staging write preserves both
  checkpoints and the active slot; successful retry commits immediately but its
  success notice follows the retained error. Disposable slots 918306/918307 only.
- `controls-regression.log`, `popup-regression.log`, `map-regression.log`,
  `combat-regression.log`, `load-regression.log`: existing controls, live WeakRef
  tutorial FIFO, actual map acquisition/review return, Stun/Angler dispatch and
  checkpoint rejection remain clean. `chest-regression.log` covers both chests
  with all three divers; `recovery-regression.log` covers the actual denied
  opening save, Retry Save, later loss/Restart and title Load with disposable
  slot 918299. It preserves existing opening behavior, not the pending Tethys pivot.
- Seven native screenshots: World/Maze current R and following Q, World contact
  before and after drain, and multiline queued E. Inspected for readable notices
  and non-overlapping HUD/prompt presentation; not a screenshot-only oracle.

## Genuine failures and excluded observations

`input-overwrite-red.log` is the original Q replacing unread R defect.
`save-menu-red.log` is a further real timer bug: SavePointMenu does not pause
the tree, so notices expired behind it. The guarded readable clock repairs it.

`slot-obsolete-oracle.log` combined immediate slot advancement with immediate
banner replacement. Only the latter contradicted FIFO; no lost save is claimed.
`wiring-invalid.log` tried a Control method on CanvasLayer. `fixture-invalid.log`
forgot to make the World HUD readable. Neither is counted as a game defect.

## Scope limits

Tests use completed-opening/seen-lesson active-HUD fixtures. The map ownership
fixture pre-grants a map solely to open its modal; separate earned-map tests
cover acquisition. Save and rock cases start near those interactions and use
actual inputs/contact afterward; these are not normal New Game journey proofs.
No party kit, encounter victory or campaign completion is claimed by this batch.
Full fight/cross-area/reset acceptance, full gates, current web/platform exports
and ordinary earned-resource campaign proof remain on the full-scope ledger.

Detailed bug catalog: `verify/orange_messages.bug-catalog.md`.
