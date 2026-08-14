# Convert the delivered FBX into a .glb the repo can carry.
#
# FBX support is the newest and most version-sensitive part of Godot's import
# path: which engine build you are on decides whether the file opens at all.
# glTF is the opposite, supported the same way across every Godot 4.x. Baking
# the models to .glb once, here, means nobody else's editor has to have an
# opinion about FBX.
#
# Usage: godot --headless --path ~/underwatergame --script tools/fbx_to_glb.gd
extends SceneTree

const SRC := "res://art/characters/Main_Team_Rigging_2.fbx"
const OUT := "res://art/characters/divers.glb"

var frames := 0
var subject: Node3D

func _initialize() -> void:
	subject = (load(SRC) as PackedScene).instantiate()
	root.add_child(subject)

func _process(_dt: float) -> bool:
	frames += 1
	if frames < 3:
		return false      # let transforms settle before they are baked
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_scene(subject, state)
	if err != OK:
		print("APPEND FAILED: %d" % err)
		quit(1)
		return true
	err = doc.write_to_filesystem(state, ProjectSettings.globalize_path(OUT))
	if err != OK:
		print("WRITE FAILED: %d" % err)
		quit(1)
		return true
	print("wrote      %s" % OUT)
	quit(0)
	return true
