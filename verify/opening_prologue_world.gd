# Quiet-spawn and protected-world integration.
#
# Bugs caught:
# - OPEN-007: normal New Game never arms the movement/idle trigger or creates
#   duplicate prologue Battles.
# - OPEN-008: the retired mandatory tutorial beam, random encounters, route
#   systems, or camera capture compete before recovery.
#
# Usage: godot --headless --path . --script verify/opening_prologue_world.gd
extends SceneTree

const TEST_SLOT := 918298
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	await world._on_title_new_game(TEST_SLOT)
	await process_frame

	_expect(world.has_method("_update_prologue_trigger"), "OPEN-007 World has no prologue trigger lifecycle")
	_expect(world.route_state.prologue_phase == "spawn_exploration", "OPEN-007 normal handoff did not enter quiet spawn")
	_expect(not world.route_state.prologue_complete, "OPEN-008 debug video fast-forward incorrectly completed the prologue")
	_expect(not world._intro_active, "OPEN-008 mandatory tutorial capture remains active at quiet spawn")
	_expect(not is_instance_valid(world.light_beam), "OPEN-008 mandatory tutorial beam remains at quiet spawn")
	_expect(not is_instance_valid(world._intro_arrow), "OPEN-008 mandatory tutorial arrow remains at quiet spawn")
	_expect(world._camera_look_override == null, "OPEN-008 quiet spawn still captures the camera")

	# A random-encounter signal before the authored trigger must be ignored.
	world._on_encounter_triggered(world.divers[world.active] as Diver)
	_expect(not world.battling, "OPEN-008 random encounter preempted incomplete prologue")

	if world.has_method("_update_prologue_trigger"):
		var diver := world.divers[world.active] as Diver
		diver.position += Vector3(3.1, 0.0, 0.0)
		world.call("_update_prologue_trigger", 0.4)
		world.call("_update_prologue_trigger", 4.1)
		await process_frame
		_expect(world.battling and world.battle != null, "OPEN-007 movement did not start prologue Angler")
		_expect(world.route_state.prologue_phase == "angler", "OPEN-007 Battle start did not publish Angler phase")
		_expect(world.route_state.encounter_source == "prologue_angler", "OPEN-007 Battle source is not prologue_angler")
		if world.battle != null:
			_expect(world.battle.prologue_angler_encounter, "OPEN-009 World started an ordinary Angler instead of prologue configuration")
		var original_battle := world.battle
		world.call("_update_prologue_trigger", 10.0)
		_expect(world.battle == original_battle, "OPEN-007 repeated frames replaced/duplicated the prologue Battle")

	world.queue_free()
	await process_frame
	paused = false
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	_remove_test_save()
	_finish()

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("OPENING PROLOGUE WORLD: clean" if findings.is_empty() else "OPENING PROLOGUE WORLD: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
