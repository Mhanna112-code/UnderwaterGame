# Exercise every diver's state changes, not merely confirm that the named
# clips exist. The movement gate drives Mermaid through a real swim; this
# isolates all three delivered rigs and proves each one can enter/hold/leave
# swimming and play both damage reactions. It also checks the carried staff is
# visible on Mermaid's intact rig, which is the structural half of issue #26.
#
# Usage: godot --headless --path . --script verify/animations.gd
extends SceneTree

const TIMEOUT_SECONDS := 30.0

var models: Array = []
var at := 0
var diver: Diver
var phase := "spawn"
var started_ms := 0
var findings: Array = []

func _initialize() -> void:
	models = Cast.model_names()
	started_ms = Time.get_ticks_msec()

func _process(_dt: float) -> bool:
	if _elapsed() > TIMEOUT_SECONDS:
		findings.append("TIMEOUT: animation sequence stalled in %s for %s" % [phase, diver.model_name if diver != null else "no diver"])
		return _report()
	if at >= models.size():
		return _report()

	match phase:
		"spawn":
			diver = Diver.new()
			diver.model_name = String(models[at])
			root.add_child(diver)
			phase = "idle"
		"idle":
			if diver.anim == null:
				return false
			_expect("idle", Cast.motion(diver.model_name, "idle"))
			if diver.model_name == "Staff_Diver":
				_check_staff()
			diver._update_motion(true)
			phase = "swim_start"
		"swim_start":
			if _playing(Cast.motion(diver.model_name, "swim_start")):
				phase = "swim_loop"
		"swim_loop":
			if _playing(Cast.motion(diver.model_name, "swim")):
				diver._update_motion(false)
				phase = "swim_end"
		"swim_end":
			if _playing(Cast.motion(diver.model_name, "swim_end")):
				phase = "idle_again"
		"idle_again":
			if _playing(Cast.motion(diver.model_name, "idle")):
				diver.play_hit_reaction(false)
				phase = "hurt"
		"hurt":
			if _playing(Cast.motion(diver.model_name, "hurt")):
				# A second one-shot deliberately replaces the first. Combat never
				# does this, but it lets this isolated gate prove both mappings
				# without waiting several seconds per character.
				diver.play_hit_reaction(true)
				phase = "hurt_bad"
		"hurt_bad":
			if _playing(Cast.motion(diver.model_name, "hurt_bad")):
				print("%-20s idle -> start -> loop -> end -> idle; light + heavy reactions" % diver.model_name)
				diver.queue_free()
				diver = null
				at += 1
				phase = "spawn"
	return false

func _playing(stem: String) -> bool:
	if diver == null or diver.anim == null:
		return false
	var current := String(diver.anim.current_animation)
	var wanted := diver.resolve(stem)
	return wanted != "" and current == wanted

func _expect(label: String, stem: String) -> void:
	if not _playing(stem):
		findings.append("%s: %s is playing '%s', expected '%s'" % [diver.model_name, label, diver.anim.current_animation, diver.resolve(stem)])

func _check_staff() -> void:
	var staff := _find_mesh(diver, "Staff_Lantern")
	if staff == null:
		findings.append("STAFF MISSING: Mermaid's rig has no Staff_Lantern mesh")
		return
	if not staff.visible:
		findings.append("STAFF HIDDEN: Staff_Lantern exists but is not visible")
	if staff.skeleton.is_empty():
		findings.append("STAFF UNSKINNED: Staff_Lantern has no skeleton path and cannot track the hand")

func _find_mesh(node: Node, wanted: String) -> MeshInstance3D:
	if node is MeshInstance3D and String(node.name) == wanted:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child, wanted)
		if found != null:
			return found
	return null

func _elapsed() -> float:
	return float(Time.get_ticks_msec() - started_ms) / 1000.0

func _report() -> bool:
	for finding in findings:
		print("FINDING  " + finding)
	print("ANIMATIONS: clean" if findings.is_empty() else "ANIMATIONS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
