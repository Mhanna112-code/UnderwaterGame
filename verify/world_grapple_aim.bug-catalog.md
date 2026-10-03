# Bug Catalog: `verify/world_grapple_aim.gd`

**Scope:** the ordinary-world Grapple aim lifecycle in `game/world.gd`.

| Bug | Player impact | Test contract |
| --- | --- | --- |
| The active diver mesh remains visible after the camera moves to the diver's eye line. | Musashi's head and torso cover the crosshair and far anchor, making the second required gap shot visually unreadable even when the underlying raycast is correct. | Entering Grapple aim hides only the active diver's model; cancel and fire both restore it. |
| Cancel or fire hides the diver permanently. | The player returns to third-person movement with an invisible active character. | Both exit paths restore model visibility and leave aim mode. |

This gate deliberately asserts player-visible lifecycle state rather than a
camera implementation detail. Browser screenshots remain the proof that the
anchor is actually readable once the mesh is hidden.
