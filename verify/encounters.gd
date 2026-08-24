# Does an encounter actually start, from anywhere a player can be standing?
#
# Written because of a bug this would have caught the day it landed. The two
# key item spots turn the next random encounter into a guardian fight, and
# the code that read them used the wrong dictionary key. GDScript does not
# stop at a bad key, it throws, and a throw inside a signal handler takes the
# rest of the handler with it. So a random encounter rolled anywhere within
# 10 m of either spot did nothing at all: no fight, no message, and the
# encounter counter had already been reset, so the only symptom was a dive
# that never got attacked in a particular corner of the map.
#
# It is the worst shape a bug can have. It is invisible, it is intermittent
# by construction, and the part of the map it breaks is the part built around
# the reward.
#
# Usage: godot --headless --path . --script verify/encounters.gd
extends SceneTree

var world: Node3D
var findings: Array = []
var frames := 0
var spots: Array = []
var at := -1
var expect_reward := ""

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	root.add_child(world)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames == 2:
		# Open water first, then dead centre of every key item spot.
		spots.append({"at": Vector3(0.0, 2.0, 0.0), "what": "open water", "reward": ""})
		for s in ItemGuardian.SPOTS:
			spots.append({"at": s.at as Vector3, "what": "the %s spot" % String(s.item), "reward": String(s.item)})
		return false

	if at >= 0:
		_check_result()
		if not findings.is_empty() and findings.size() > 6:
			return _report()
	at += 1
	if at >= spots.size():
		return _report()
	_trigger(spots[at] as Dictionary)
	return false

func _trigger(spot: Dictionary) -> void:
	# Leave no battle running from the previous case.
	if world.battle != null:
		world.battle.free()
		world.battle = null
	world.battling = false
	expect_reward = String(spot.reward)
	var d: Diver = world.divers[world.active]
	d.position = spot.at as Vector3
	d.encounter_triggered.emit()
	# Key-item spots now open the special-encounter chooser before creating
	# Battle. Drive that public signal exactly as the carousel does so this
	# gate still verifies the important contract: one fight, correct reward.
	if expect_reward != "" and world.special_encounter_prompt.visible:
		world.special_encounter_prompt.diver_chosen.emit(d.model_name)

func _check_result() -> void:
	var spot: Dictionary = spots[at] as Dictionary
	var battles := 0
	for c in world.get_children():
		if c is Battle:
			battles += 1
	var got := String(world._pending_reward_item)
	print("%-28s %d battle(s), reward %s" % [
		String(spot.what), battles, got if got != "" else "none"])
	if battles == 0:
		findings.append("NO FIGHT: an encounter at %s started nothing at all" % String(spot.what))
	elif battles > 1:
		findings.append("STACKED FIGHTS: an encounter at %s started %d battle screens" % [String(spot.what), battles])
	if got != expect_reward:
		findings.append("WRONG REWARD: an encounter at %s is worth '%s', expected '%s'" % [
			String(spot.what), got, expect_reward])

func _report() -> bool:
	for f in findings:
		print("FINDING  " + f)
	print("ENCOUNTERS: clean" if findings.is_empty() else "ENCOUNTERS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
