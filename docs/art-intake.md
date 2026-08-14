# Art intake: Main_Team_Rigging_2.fbx

Source: Glass_Goat, via Dropbox, Aug 14 2026.
Exported from Blender 4.5.2 LTS (binary FBX 7400), from
`OTC_ARTS/Blender/1_Character_Sets/9_Struggles/Diving_Armors/Main_Team_Rigging_2.blend`.

## Does it load in Godot?

Yes. Godot 4.7.1 imports it natively through ufbx, so no FBX2glTF converter
and no manual conversion step is needed. Import runs clean, and the four
textures embedded in the FBX are extracted automatically into
`.godot/imported/`.

Reproduce:

	godot --headless --path . --editor --quit        # import
	godot --headless --path . --script tools/dump_fbx.gd
	godot --headless --path . --script tools/measure_fbx.gd
	godot --path . --script tools/shoot_scene.gd -- res://game/lineup.tscn out.png 10

Or just open the project: `game/lineup.tscn` is the main scene and stands the
whole cast on a floor, turning, labelled with their measured sizes.

## What is in the file

| node | world size (m) | verts | surfaces |
|---|---|---|---|
| Prototype_1(1910) | 1.44 x 2.22 x 0.62 | 2523 | 1 |
| Prototype_V(1922) | 2.44 x 2.74 x 1.07 | 2697 | 1 |
| Staff_Diver | 1.66 x 1.96 x 0.86 | 6392 | 6 |
| Staff_Lantern | 0.12 x 0.12 x 1.79 | 519 | 1 |

Nine materials: `Prototype_1(1910)`, `Prototype_V(1922)`, `Diver_Lady`,
`Face`, `Mouth`, `Eyes`, `DiverMask1`, `Diver_Tank1`, `Material`.

12131 verts total. This is a light load for any target we care about.

## What is NOT in the file

**There is no rig.** The name says `Main_Team_Rigging_2`, but the export
carries zero bones, zero skin deformers and zero blend shapes. Godot imports
zero `Skeleton3D` nodes, and a byte scan of the FBX finds no `LimbNode`,
`Deformer`, `Cluster`, `Skin`, `BlendShape` or `BindPose` records at all.

The single `AnimationPlayer` holds one clip, `Staff_Diver|CameraAction`, which
is 0.00 seconds long and has one track. It is an export artifact of a camera,
not character animation.

So today these are static T-pose props. They can be placed, lit and shown, and
they cannot be posed or animated until a rigged export arrives.

What most likely happened on the Blender side: the FBX exporter ran with the
armature left out, either through "Limit to: Selected Objects" with only the
meshes selected, or with Armature unticked under Object Types. Asking for a
re-export with Armature included, "Add Leaf Bones" off, and the meshes parented
to the armature should bring the skeleton across.

## Things to know when placing them

- Every mesh node carries a **-90 degree X rotation and a scale of 100**. That
  is the normal Blender Z-up correction and it is already correct on screen,
  but it means the mesh's local +Z is world +Y. Reparent the imported
  `MeshInstance3D` without its transform and it will lie down.
- All four models sit at the **same origin**, stacked. `game/lineup.gd` spreads
  them out and drops each one onto y=0.
- The models are **big**: the 1922 suit stands 2.74 m. If the divers are meant
  to read as human-scale next to level geometry, agree a target height before
  anyone builds a room around them.
