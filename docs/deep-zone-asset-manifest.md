# Deep-zone Runtime Asset Manifest

The table and exclusions below record the original PR96 asset admission, not
the current PR100 encounter ownership. In PR100, the visible V2 Octopus is
Cordys in the opening and the independent, defeatable maze finale. Bomb Bot
and Sword Slayer also have separate maze-puppet instances; those do not clear
their laboratory blockers. The partial character-animation admission below is
new integration work. Raw
dimensions are measurements from Godot's imported mesh bounds; production
scale, facing, floor alignment, and composition are owned by later actor/room
wrappers and must be proved separately.

| Asset | Canonical source | SHA-256 | Runtime path | Raw Godot proof | Player-facing owner | Provenance / permission |
| --- | --- | --- | --- | --- | --- | --- |
| Bomb Bot | `/Users/tomriddle1/Dropbox/Bomb_Bot.fbx` | `c06f40ad40b627e410c6ea886ce61da7ec4122c337eaf12123b74106c8a297e0` | `res://art/deep_zone/Bomb_Bot.fbx` | 1 mesh, 1 material, bounds 11.47 × 3.92 × 3.44; 9 clips including source-typo `LightingBlast`, `SlingPunch`, `Sonic_Bump` | First one-time laboratory blocker | Delivered through the team Dropbox/Glassgoat asset set; formal license/credit wording is still unconfirmed. |
| Sword Slayer | `/Users/tomriddle1/Dropbox/Sword_Slayer.fbx` | `ae7e28161a8d444246d51f154352bd6ce35189592479bc581404e903e54deb58` | `res://art/deep_zone/Sword_Slayer.fbx` | 1 mesh, 1 material, bounds 2.04 × 2.40 × 5.85; 10 clips including `GreatSlash`, `Stabbing`, `Spinning_Drill` | Second one-time laboratory blocker | Delivered through the team Dropbox/Glassgoat asset set; formal license/credit wording is still unconfirmed. |
| Broken Office | `/Users/tomriddle1/Dropbox/Broken_Office.fbx` | `2ab8fda5d82a7308795253da75a0b0b7fb111ec6ced297de40365d5fcdb9c355` | `res://art/deep_zone/Broken_Office.fbx` | 15 meshes, 16 active materials, bounds 32.60 × 26.46 × 19.00 | Hidden compact Mermaid/Tethys interior staging room; never rendered as the exterior shell | Delivered through the team Dropbox/Glassgoat environment set; formal license/credit wording is still unconfirmed. |
| Deep Rocks | `/Users/tomriddle1/Dropbox/Rocks.fbx` | `ddad2eb643fb0867210b528d3111d4a64017ee9a8794ac507987b379eda28ea9` | `res://art/deep_zone/Rocks.fbx` | 6 meshes, 6 active materials, bounds 4.65 × 2.44 × 4.75 | Deep threshold, route reef, laboratory frame, and maze-transition silhouette; production placements deliberately vary scale and rotation | Glassgoat explicitly approved use and varied rock sizes; formal credit wording is still unconfirmed. |
| Beach palms | `/Users/tomriddle1/Dropbox/Beach_assets1.fbx` | `a97a80d3465514e55b9c616034fd5504de780d45d0d42b36a4b2d5d8e8838d05` | `res://art/deep_zone/Beach_assets1.fbx` | 3 source meshes/materials; production deliberately exposes only textured `Palm_Tree_1` | Two restrained silhouette pairs at the deep threshold and maze branch, outside the travel corridors | Glassgoat explicitly approved tree use. Bundled `Sand1` and `Water_1` test planes are excluded from production. |
| Corrected Lab Door | `/Users/tomriddle1/Dropbox/Corrected_Door.fbx` | `e3fa86956ecb42373eb07d3ec592034391d2e260bb8d01897dcfdba0796d6260` | `res://art/deep_zone/Corrected_Door.fbx` | 2 meshes, 1 material/embedded texture; production bounds 3.09 × 7.61 × 4.30 | Single visible lab entrance embedded in the physical rock shell | Glassgoat explicitly identified this separated door for concealing the laboratory exterior. |
| Octopus Boss V2 | `/Users/tomriddle1/Dropbox/Octopus_Boss_V2.fbx` | `e51ac165292525291714505341661067dc56022b20dc52d7aa29ccdf2d491792` | `res://art/deep_zone/Octopus_Boss.fbx` | 7 meshes, 6 materials, 34,585 vertices, 41,928 faces, 203 bone bindings, and all 15 delivered clips | Prepared later-route boss asset beyond the maze; no gameplay owner in this slice | Delivered by Glassgoat. The composite/corpse presentation and formal license/credit wording still require confirmation. |

## Explicit exclusions for this slice

- The original `Octopus_Boss.fbx` delivery remains animation-only and is not
  used. Glassgoat's V2 replacement is now a verified visible runtime asset,
  but Octopus gameplay remains outside this slice and is not wired into the
  route, combat roster, or maze transition.
- `Tallceiling.fbx` is an untextured single broken-wall mesh and is not needed
  to establish the compact Broken Office lab.
- The obsolete `Door.fbx` is not used. Glassgoat's separated
  `Corrected_Door.fbx` is the canonical laboratory exterior entrance; it does
  not change ownership of Marc's separate maze-door implementation.
- `Angler_Terror.fbx` is empty and unusable.
- The Beach delivery's sand and water planes remain excluded. Only the
  approved textured palm mesh is visible in production, with scale,
  floor-alignment, transform variety, route clearance, and visual evidence
  verified separately.

## Partial character-animation delivery admitted to PR100

October 3 Dropbox deliveries contain nine authored spell clips missing from
the previous runtime mapping. They omit existing clips, so the complete
working character FBXs remain the model/skin owners. Do not replace them with
the partial updates. These are the files already downloaded; the stale Discord
export cannot establish whether Marc's latest pins contain additional files.

| Character / source | Source SHA256 | Moves now mapped to delivered clips | Animation-only runtime derivative / SHA256 |
| --- | --- | --- | --- |
| Maxilani, `/Users/tomriddle1/Dropbox/Max.fbx` | cee7fc9b79ad35531e9a78b0d2372b2dba9c53d0e09fe2e83f6839a974a5a977 | Swift Strike (delivered Swift Slash), Riptide Slash | `art/characters/spell_animations/maxilani.res`, ace0b57510484b5bca8c69d51e2ea996a84a883556cb57fc84bd365ebf612fce |
| Musashi, `/Users/tomriddle1/Dropbox/Musashi.fbx` | f78fb38418032c421b4a826f874f9573e8d05c1d4f010f21bed695f21de887b7 | Blinding Silt, Exploit Opening, Precise Jab | `art/characters/spell_animations/musashi.res`, 0df0fb4002499635edec7530bfcdd3f70699fce8c5d439a0565bba2d9eaec35a |
| Bucky, `/Users/tomriddle1/Dropbox/Buxky.fbx` | deadfbc96217f1fd5ae03cde371f9a39145d28cbb5fbda7ae84fb53623ce1afb | Guard Break, Heavy Slam, Mending Current, Tidal Revival | `art/characters/spell_animations/bucky.res`, 2806fec46d867101b2d4cc2d585192ca25213d0f7d460206faf6836fe05317fa |

Derivation: import these three sources plus `Scuba_Rigged.fbx`,
`Prototype1_Rigged.fbx`, `PrototypeV_Rigged.fbx` in an isolated Godot 4.7.1
project. Run `tools/derive_spell_animations.gd` against that project with
`-- --output-dir=/absolute/checkout/art/characters/spell_animations`.
The generator checks source hashes, node/bone paths and rest poses. The only
rest difference is explicitly keyed `c_pos`; it is not rotated a second time.
Maxilani's two new unbound controls (`Staff`, `c_hand_ik.r`) are omitted; her
existing skinned carried prop remains. Other source tracks resolve unchanged.
The resource metadata records each source/target hash and omitted track.

Cast camera derivative: `art/characters/spell_animations/frames.res`, SHA256
`33fa83968b3ad8adfe3ae591e78fae346fc71ff0561debf38277886afc66a3b7`.
Regenerate with `godot --headless --path . --script tools/derive_spell_frames.gd`
after changing a rig or supplementary library. It measures every admitted
clip's actual skinned surface at 41 poses, stores model/library hashes and
only affects framing during delivered casts. Runtime does not rescan meshes.
Live full-party projection checks independently catch stale or inadequate
bounds. Old exploration and base-attack framing remain unchanged.

Verification: all nine generic fallbacks failed the new delivery check before
repair. Runtime rigs now change sampled poses and retain old movement/base
attacks. Native gallery and real learned-move battles were inspected; healing
and revival use actual UI, HP/Oxygen and usable subsequent turns. Narrow-screen
cast occlusion and a lab-size regression were caught and repaired. These are
scoped checks, not a full earned route or a zero-defect whole-game round.

No bespoke clip was delivered here for Tidal Burst, Current Snare, Healing
Current or empowered Weaken/Slow. Their existing working fallbacks remain;
do not report every spell as having bespoke animation. Preview/native export
and platform status belong in the runtime manifest, not this source inventory.
