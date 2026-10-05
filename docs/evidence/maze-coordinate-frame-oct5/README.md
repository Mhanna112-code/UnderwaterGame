# Coordinate-safe maze checkpoint preparation, October 5

Baseline PR100 source: 3892ced. This batch adds the coordinate-frame boundary
and pending-reward replacement. Exact implementing commit is in Git history
and the linked PR100 progress comment; none of these results describes the
older hosted bffe1b5 artifact.

## Accepted behavior

- Snapshot capture records coordinate_origin; absent metadata remains the
  legacy standalone origin. Public restore rebases the party, walls, rotation
  homes, rocks, pending orbs/keys and broken-rock records as one unit.
- Direction/rotation/size, map discovery, flags, keys and live campaign
  resources are not translated; source checkpoints are not mutated.
- Malformed or untranslatable frames are rejected before live restoration.
- Reapplying pending rewards replaces them instead of duplicating them;
  an empty reward checkpoint removes unsaved collectible drops.

The new gate instantiates the actual production maze and invokes its public
restore. The recursive fixture oracle is independent of the production
per-container translation. It then exercises 144 JSON/frame cases (three
active divers, eight downed patterns, six origins), depleted HP/Oxygen,
statuses, earned kit and independent lab/tutorial progress. Ten invalid
origins, three invalid destinations and translated-range overflow are rejected.

## Captured regressions and accepted receipts

- red.log: six real scene-restore failures before coordinate migration.
- repeat-red.log: duplicate rewards and retained unsaved rewards.
- preflight-red.log: runtime validation accepted an untranslatable source.
- final-maze_coordinate_frame.log: all repaired focused cases pass.
- final-maze_checkpoint_io.log: 24 valid / 40 invalid saves plus actual corrupt
  title Load rejection, no checkpoint mutation.
- final-marc_earned_map_persistence.log: actual save/cold/legacy Load preserves
  acquired map, spent door keys and spell relics.
- maze_secret_continuity.log: actual secret E/Esc resource/puzzle continuity.
- maze_world_return.log: 12 existing World-return cases.
- marc_orb_reel.log: 59 real-physics orb/anchor checks.
- maze_checkpoint.log: actual save/cold Load, failed write and full-party
  loss/restart; battle reports lost with HP [0,0,0].
- marc_exploration_controls.log: 86 actual input/zero-Oxygen/ownership checks.

Godot 4.7.1 headless; captured logs contain no script errors or infinite-loop
diagnostics. Earlier repeat-green and non-final codec/map logs are retained as
intermediate receipts, not substitutes for the final focused run.

## Explicit limits

This is a prerequisite for embedding, NOT completed World/maze ownership.
No connected physical entrance, embedded camera/HUD, inactive-area economy,
new underpass or normal earned-resource campaign is proven here. Existing
separate-scene regression gates are preservation checks, not final embedding
acceptance. Structural live rollback of broken rocks/closed doors still needs
its embedding implementation and tests. No browser export, alias update,
native package, main push or merge accompanies this batch.
