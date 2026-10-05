# Whirlpool wall-occlusion safety — October 5

Only the LOS portion of the required Whirlpool integration is admitted here.
Production base7ced43e; final source fingerprints are in `source.sha256`.
Godot4.7.1, AppleM1/macOS; native repeat uses Metal Forward+1280×720.
Accepted commands exit0 without script/engine errors. No player saves written.

`original-red.log` catches actual World suction through a real solid wall:
Maxilani locks, loses2HP (7→5) and resets228.8→226 despite the barrier.
The production port checks open water at the diver's own height in **both**
drag and suction entry paths; a ray starting inside a solid is blocked as well.
The existing floor-aligned translucent ring is unchanged, preserving aim view.

| Receipt | Behavior proved |
|---|---|
| `captured-green.log` | Same real wall/Area3D overlap refuses lock/motion/damage; removing that wall permits actual suction,2HP loss, authored reset, visible model and unlocked movement at0 Oxygen. |
| `matrix.log` |24 obstructed/open pairs:3 capsules ×2 solid wall types (StaticBody/CSG) ×2 suction shapes (sphere/cylinder) ×2 orientations. Independent queries require approach/reset clearance and a real blocker, then unobstructed sightline. An always-disabled hazard fails the positive leg. |
| `native.log` | Captured negative/positive pair on native Metal with matching behavior. No screenshot or final visual acceptance is claimed. |
| `current-route.log` | Actual normal movement/L/E/Ctrl+E current channel remains traversable. |
| `grapple-aim.log` | Public F/fire/cancel, layer5 item reel, anchor travel, real modal/restore and surviving shared-model teardown remain correct. |

## Rejected observers and remaining work

`rejected-reset-fixture.log` placed a rotated reset inside a real ramp side
rail. `rejected-open-water-fixture.log` relocated the hypothetical positive
case across an actual World boundary wall. Neither was a broken LOS repair;
the final generator validates clear approach/reset/sightline and stays in the
known playable approach. No damage/position/positive-catch assertion was relaxed.

The bug catalog leaves WHIRL-2/3/4/5 open: inactive/battle/menu and root-caption
ownership; interrupted Tween/restore/teardown; downedHP safety; authored gentle
hall layout/deep-shaft/floor/visual integration. Those still require production
changes and direct verification. This is not a completed whirlpool port,
campaign/balance/browser proof, full-suite result or merge readiness.

The hosted PR100 preview remains bffe1b5; canonical main is untouched.

```sh
godot --headless --path . --script res://verify/whirlpool_safety.gd
godot --headless --path . --script res://verify/whirlpool_safety.gd -- --matrix
godot --path . --resolution 1280x720 --script res://verify/whirlpool_safety.gd
godot --headless --path . --script res://verify/maze_current_route.gd
godot --headless --path . --script res://verify/maze_grapple_aim.gd
```

Both new safety commands are registered in `verify/gates.sh`.
