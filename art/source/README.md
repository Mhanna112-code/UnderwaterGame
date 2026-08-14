# Source art, deliberately outside Godot's import path

The `.gdignore` beside this file tells Godot to skip this folder entirely.

The raw FBX lives here because FBX is the newest and most version-sensitive
importer in Godot: whether it opens at all depends on which engine build you
run. Leaving it in the project meant every editor that opened the repo had to
import it, and any editor that could not simply failed.

The game loads `art/characters/divers.glb` instead, converted from this file
by `tools/fbx_to_glb.gd`. glTF imports the same way across every Godot 4.x.

To regenerate the glb after a new delivery:

    godot --headless --path . --script tools/fbx_to_glb.gd

That script reads a path constant at the top; point it at the new file first.
