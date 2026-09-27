# `tutorial forward entry: default forward swimming reaches the visible
# light-beam tutorial — guards against a lateral/hidden first objective`.
#
# Captured product bug: a normal browser run could leave a new player beside
# the visible beam after a lateral key guess. This drives World’s production
# swim/update path from a clean title start; it does not emit the trigger,
# teleport the diver, or mutate tutorial state.
extends SceneTree

const TIMEOUT_SECONDS := 8.0
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(97)
	await physics_frame

	# World._player_dir maps a default-yaw W press to positive Z. Godot calls
	# that Vector3.BACK (its FORWARD convention is negative Z); the script seam
	# drives that exact resulting production direction so this
	# remains a deterministic physics integration test in headless Godot.
	world.scripted = true
	world.scripted_dir = Vector3.BACK
	var deadline := Time.get_ticks_msec() + int(TIMEOUT_SECONDS * 1000.0)
	while world.battle == null and Time.get_ticks_msec() < deadline:
		await physics_frame
	world.scripted = false
	world.scripted_dir = Vector3.ZERO

	_expect(world.battle != null,
		"TUTORIAL FORWARD ENTRY: eight seconds of default forward swimming did not reach the visible first tutorial target")
	if world.battle != null:
		_expect(world.battle.tutorial_encounter,
			"TUTORIAL FORWARD ENTRY: forward arrival opened a non-tutorial battle")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("tutorial forward entry: production forward swim reached the visible light-beam tutorial")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
