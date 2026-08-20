# Does every clip the game asks for actually exist in the file it comes from?
#
# content/cast.gd names about thirty clips by hand. A renamed export, a
# re-rig, or a typo turns any one of them into a diver standing perfectly
# still in the middle of a fight, which is exactly the kind of bug that
# survives a playthrough because nobody can tell "no animation" from "an
# animation I did not notice."
#
# This asks each delivered file what it contains and fails on the first name
# the file does not have. It is the gate behind #25.
#
# Usage: godot --headless --path . --script verify/clips.gd
extends SceneTree

const MOTIONS := ["idle", "swim", "swim_start", "hurt", "hurt_bad", "down", "down_start", "win"]

var findings: Array = []

func _init() -> void:
	for model_name in Cast.model_names():
		_check(String(model_name))
	# Every move the fight can offer has to animate too, including the ones
	# that fall through to the family's default swing.
	for model_name in Cast.model_names():
		var moves: Array = Battle.BASE_MOVES.get(model_name, []) as Array
		if moves.is_empty():
			findings.append("NO MOVES: %s has no entry in battle.gd BASE_MOVES" % model_name)
	for f in findings:
		print("FINDING  " + f)
	print("CLIPS: clean" if findings.is_empty() else "CLIPS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _check(model_name: String) -> void:
	var path := Cast.file(model_name)
	if not ResourceLoader.exists(path):
		findings.append("MISSING FILE: %s for %s" % [path, model_name])
		return
	var inst: Node = (load(path) as PackedScene).instantiate()
	var ap := _player(inst)
	if ap == null:
		findings.append("NO AnimationPlayer: %s" % path)
		inst.queue_free()
		return

	# The suffix after the bar is the clip; the part before it is whichever
	# armature name this particular delivery happened to use.
	var have: Dictionary = {}
	for a in ap.get_animation_list():
		var s := String(a)
		var bar := s.rfind("|")
		have[s.substr(bar + 1) if bar >= 0 else s] = ap.get_animation(a).length

	var mesh_names: Array = []
	_meshes(inst, mesh_names)
	if not mesh_names.has(model_name):
		findings.append("NO MESH: '%s' is not in %s (has %s)" % [model_name, path, ", ".join(mesh_names)])
	for c in Cast.carries(model_name):
		if not mesh_names.has(String(c)):
			findings.append("NO CARRIED MESH: '%s' is not in %s" % [c, path])

	print("%-20s %-40s %d clips" % [model_name, path.get_file(), have.size()])
	for m in MOTIONS:
		_want(model_name, have, Cast.motion(model_name, m), "motion " + m)
	var moves: Array = Battle.BASE_MOVES.get(model_name, []) as Array
	for mv in moves:
		_want(model_name, have, Cast.ability(model_name, String(mv.name)), "move " + String(mv.name))
	inst.queue_free()

func _want(model_name: String, have: Dictionary, clip: String, what: String) -> void:
	if clip == "":
		findings.append("UNMAPPED: %s has no clip for %s" % [model_name, what])
		return
	if not have.has(clip):
		findings.append("NO CLIP: %s wants '%s' for %s, the file does not have it" % [model_name, clip, what])
		return
	# A zero length clip resolves and plays and does nothing, which looks
	# identical to a missing one from the player's side of the screen.
	if float(have[clip]) < 0.05:
		findings.append("EMPTY CLIP: %s's '%s' (%s) is %.2fs long" % [model_name, clip, what, have[clip]])
		return
	print("   %-14s %-34s %.2fs" % [what, clip, have[clip]])

func _player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _player(c)
		if r != null:
			return r
	return null

func _meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(String(n.name))
	for c in n.get_children():
		_meshes(c, out)
