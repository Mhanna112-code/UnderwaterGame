# `tutorial forward entry: default forward swimming reaches the visible
# light-beam tutorial - guards against a lateral first objective`.
#
# This is the behavior-only portion of PR #88 commit 8990875. It deliberately
# does not import that PR's route, storyboard, or tutorial curriculum.
extends SceneTree

const TIMEOUT_SECONDS := 8.0
const SLOT := 918305
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	# Preserve physical forward entry from the actual recovered-save milestone.
	world.route_state.opening_video_seen = true
	world.route_state.prologue_complete = true
	world.route_state.tutorial_complete = false
	world.route_state.set_objective("")
	SaveManager.write_slot(SLOT, world._serialize_state())
	await world._on_title_load_game(SLOT)
	# Random fights are legitimately available before optional training. This
	# physical-entry test isolates that one destination, like the player's R.
	world.random_encounters_enabled = false
	await physics_frame

	# A default-yaw W press maps to positive Z in World. Drive that same
	# production movement direction without teleporting or emitting the trigger.
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
		print("tutorial forward entry  production forward swim reached the visible tutorial beam")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(SLOT)))
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
