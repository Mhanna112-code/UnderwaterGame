# Sonar Vision and paused-map caption ownership — October 5

Bounded PR100 batch after `b4ca2df`, reconciling authored #97 `4ec6598`.
The later `bba8b80` delta remains separate pending intake, not silently ported.

## Player-visible change

Maxilani's Q reveals sphere-room hazards from the start. No late lens pickup
or G equipment toggle is required. Legacy checkpoint booleans remain valid
and round-trippable but cannot disable Q. Existing Oxygen billing, hidden
collision/damage, generic keys, rewards and other diver abilities are retained.
Switching away or deactivating the maze clears its reveal. Sonar/R notices
coalesce independently; unread rewards retain FIFO order. Opening the map
hides Maze-owned captions immediately, including when its first lesson pauses
the tree; closing restores the unread notice.

## Receipts and limits

- `fresh-q-red.log`: actual fresh Q failed under the old pickup/G requirement.
- `sonar-notice-red.log`: port initially left Sonar-on text after actual Q off;
  the output originally labelled this SV-4, now separately catalogued SV-5.
- `paused-map-caption-red.log`: actual first L leaves an unread banner visible
  while physics is disabled and the navigation lesson pauses the tree.
- `sonar-headless-green.log`, `sonar-native-green.log`: fresh Q plus all four
  legacy flag pairs × three selected actors; JSON encode/decode/public restore,
  actual Q/G/Tab/Escape, inactive/outside/depleted resource checks. No player
  save file is written by this test. Camera settled before captures.
- `queue-model-green.log`: 484 independently expected FIFO/renewal/overflow/
  toggle cases, including 256 mixed Sonar/R cases.
- `queue-input-green.log`, `queue-native-green.log`: actual World/Maze R/Q,
  Inventory/map/Save-menu input, physical W/contact restoration/held P prompt,
  queued split-rock E/cooldown/drain/reuse. Completed-opening/seen-save-lesson
  and near-save-point/interaction fixtures; map is pre-granted for modal-only
  checks. These do not prove a normal New Game journey.
- `map-paused-green.log`, `map-native-green.log`: actual chest E/R/L; unread
  banner hidden before pause and restored on close; discovered-only legend
  (64 subsets), new/legacy JSON lesson history and five invalid values. Native
  paused layout at 12 sizes. Near-chest presentation fixture with physics
  disabled, not an earned-swimming claim.
- `map-presentation-green.log`: 12 generated overview/help/legend layouts.
- `earned-map-route-green.log`: actual standalone entry-to-chest swimming,
  E/acquisition/first L/return, no map/key grant. Not the full campaign route.
- `swirl-route-green.log`: all three actors physically swim to the vortex;
  contact damage/hits and real E key acquisition retained. Near-room fixture,
  random encounters off; no vision flags granted.
- `embedded-owner-green.log`: shared party, bidirectional physical lab ramp,
  one input/camera owner and parked Sonar/O2/encounter protection.
- `controls-green.log`: 86 real exploration controls/zero-O2 checks.
- `checkpoint-green.log`: real checkpoint/denied write/byte conservation,
  cold Title Load, wounded-party loss and Restart. Disposable slot only; not
  earned-resource combat balance proof.
- `combat-preservation-green.log`, `popup-preservation-green.log`: live Stun
  skip/Angler targeting-history dispatch and battle-safe WeakRef lesson FIFO
  regressions rerun on the final batch source.

Accepted native receipts use Godot 4.7.1, Apple M1, OpenGL 4.1 compatibility
renderer. An additional Forward+ run passed, but the included native evidence
uses compatibility rendering. PNGs in `native/` were visually inspected; no
old screenshots or screenshot count stand in for the semantic checks.

## Observer corrections, not product defects

The old checkpoint observer required immediate orange warning replacement;
FIFO intentionally preserves earlier unread notices. Slot/file-byte checks
stay immediate, while readable failure is awaited (maximum 18 seconds).
`checkpoint-obsolete-oracle.log` records that rejected run. Some live label
checks sampled the old HUD immediately after the pre-update physics signal;
they now wait for a complete update. The paused first-L defect above was
independently confirmed without any available physics update and fixed in
production, not hidden by waiting. Rejected timing/diagnostic logs remain in
the task's `/private/tmp/pr100-sonar-queue-input-*` files.

## Reproduce

From the repository root, run `godot --headless --path . --script` with each
of `verify/marc_sonar_vision.gd`, `verify/orange_message_model.gd`,
`verify/orange_messages.gd`, `verify/marc_swirl_route.gd`,
`verify/embedded_maze.gd`, `verify/marc_exploration_controls.gd`,
`verify/maze_checkpoint.gd`, `verify/marc_earned_map.gd` and
`verify/marc_maze_map_presentation.gd`.

Map composition: `godot --headless --path . --script verify/maze_map_discovery.gd
-- --legend --persistence --media-transition`.

Native Q/map/live queue: omit `--headless`, add
`--rendering-method gl_compatibility --rendering-driver opengl3`, and pass an
existing directory via `-- --capture-dir=/absolute/path`. Map captures also
use `--layout --legend --persistence` after `--`.

## Not release acceptance

Full gates, ordinary lab-first/maze-first campaigns, casual/skilled balance,
browser durability, Chrome Bomb Bot, current hosted artifact, final exports
and six-area final visuals remain pending. The review alias still serves the
older build; no canonical-main promotion or merge is made by this batch.
