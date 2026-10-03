# Deep-zone Runtime Asset Manifest

This manifest records only assets admitted to the current vertical slice. Raw
dimensions are measurements from Godot's imported mesh bounds; production
scale, facing, floor alignment, and composition are owned by later actor/room
wrappers and must be proved separately.

| Asset | Canonical source | SHA-256 | Runtime path | Raw Godot proof | Player-facing owner | Provenance / permission |
| --- | --- | --- | --- | --- | --- | --- |
| Bomb Bot | `/Users/tomriddle1/Dropbox/Bomb_Bot.fbx` | `c06f40ad40b627e410c6ea886ce61da7ec4122c337eaf12123b74106c8a297e0` | `res://art/deep_zone/Bomb_Bot.fbx` | 1 mesh, 1 material, bounds 11.47 × 3.92 × 3.44; 9 clips including source-typo `LightingBlast`, `SlingPunch`, `Sonic_Bump` | First one-time laboratory blocker | Delivered through the team Dropbox/Glassgoat asset set; formal license/credit wording is still unconfirmed. |
| Sword Slayer | `/Users/tomriddle1/Dropbox/Sword_Slayer.fbx` | `ae7e28161a8d444246d51f154352bd6ce35189592479bc581404e903e54deb58` | `res://art/deep_zone/Sword_Slayer.fbx` | 1 mesh, 1 material, bounds 2.04 × 2.40 × 5.85; 10 clips including `GreatSlash`, `Stabbing`, `Spinning_Drill` | Second one-time laboratory blocker | Delivered through the team Dropbox/Glassgoat asset set; formal license/credit wording is still unconfirmed. |
| Broken Office | `/Users/tomriddle1/Dropbox/Broken_Office.fbx` | `2ab8fda5d82a7308795253da75a0b0b7fb111ec6ced297de40365d5fcdb9c355` | `res://art/deep_zone/Broken_Office.fbx` | 15 meshes, 16 active materials, bounds 32.60 × 26.46 × 19.00 | Compact, non-explorable Mermaid/Tethys lab staging room | Delivered through the team Dropbox/Glassgoat environment set; formal license/credit wording is still unconfirmed. |
| Deep Rocks | `/Users/tomriddle1/Dropbox/Rocks.fbx` | `ddad2eb643fb0867210b528d3111d4a64017ee9a8794ac507987b379eda28ea9` | `res://art/deep_zone/Rocks.fbx` | 6 meshes, 6 active materials, bounds 4.65 × 2.44 × 4.75 | Deep threshold, route reef, laboratory frame, and maze-transition silhouette | Delivered through the team Dropbox/Glassgoat environment set; formal license/credit wording is still unconfirmed. |
| Octopus Boss V2 | `/Users/tomriddle1/Dropbox/Octopus_Boss_V2.fbx` | `e51ac165292525291714505341661067dc56022b20dc52d7aa29ccdf2d491792` | `res://art/deep_zone/Octopus_Boss.fbx` | 7 meshes, 6 materials, 34,585 vertices, 41,928 faces, 203 bone bindings, and all 15 delivered clips | Prepared later-route boss asset beyond the maze; no gameplay owner in this slice | Delivered by Glassgoat. The composite/corpse presentation and formal license/credit wording still require confirmation. |

## Explicit exclusions for this slice

- The original `Octopus_Boss.fbx` delivery remains animation-only and is not
  used. Glassgoat's V2 replacement is now a verified visible runtime asset,
  but Octopus gameplay remains outside this slice and is not wired into the
  route, combat roster, or maze transition.
- `Tallceiling.fbx` is an untextured single broken-wall mesh and is not needed
  to establish the compact Broken Office lab.
- `Corrected_Door.fbx` belongs to Marc's separate maze/door work and is not a
  laboratory asset.
- `Angler_Terror.fbx` is empty and unusable.
- Beach/palm content is not part of the agreed deep-zone route; the palm is
  explicitly excluded by its author.
