# Deep-zone Asset Intake Bug Catalog

## Scope

The three assets selected for this vertical slice before gameplay ownership:
Bomb Bot, Sword Slayer, and Broken Office. This gate proves the delivered
files import as visible Godot scenes with usable geometry and the required
authored attack clips. Production battle framing and lab composition remain
separate later gates.

## Bug catalog

| ID | Observable failure | Cheapest catching test | Status |
| --- | --- | --- | --- |
| DZ-ASSET-001 | A selected FBX is absent or cannot be instantiated by Godot. | Load each canonical runtime path as a `PackedScene`. | Covered by `verify/deep_zone_assets.gd`. |
| DZ-ASSET-002 | An FBX imports animation/skeleton data but no visible mesh, as the current Octopus delivery does. | Recursively require non-empty rendered mesh bounds. | Covered by `verify/deep_zone_assets.gd`. |
| DZ-ASSET-003 | Bomb Bot or Sword Slayer imports but one of its production attack clips is missing. | Normalize the real `AnimationPlayer` clip inventory and require all authored clip fragments. | Covered by `verify/deep_zone_assets.gd`; Bomb Bot's delivered `LightingBlast` typo is recorded and will be mapped by its actor. |
| DZ-ASSET-004 | Broken Office imports as unshaded/unassigned geometry rather than the supplied authored materials. | Require at least one active or embedded surface material in the raw import. | Covered by `verify/deep_zone_assets.gd`. |
| DZ-ASSET-005 | A valid raw model is tiny, floating, backward, or obscured after production normalization. | Actor/gallery bounds plus real-resolution screenshot. | Planned after raw intake is green. |

## Self-critique

- Raw import proof does not establish an attractive gameplay composition.
- Clip names alone do not prove visible deformation; production actor tests
  must sample the actual attack path after actor wrappers exist.
- A material count does not judge artistic quality. Browser screenshots remain
  required before the lab or either blocker is accepted.
