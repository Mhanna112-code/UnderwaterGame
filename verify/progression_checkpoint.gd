# `progression route: capstone checkpoint round-trips full resources and the
# next unlocked objective through SaveManager — guards against a stale save,
# duplicated capstone, or partial recovery`.
extends SceneTree

const TEST_SLOT := 99
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := await _make_world()
	world._current_slot = TEST_SLOT
	world.route.start_after_tutorial()
	# Win the two shallow tutorials, then secure the pre-capstone checkpoint.
	for _i in range(2):
		world.route.begin_active_encounter()
		world.route.resolve_active_encounter("won")
	_expect(world.route.objective_id == "shallow_capstone",
		"CHECKPOINT SETUP: shallow capstone was not the next authored objective")
	var pre := world.route.begin_active_encounter()
	_expect(bool(pre.get("checkpoint_before", false)),
		"CHECKPOINT SETUP: shallow capstone did not request a pre-fight checkpoint")
	world._secure_route_checkpoint("test pre-capstone")
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		stats.hp = 1
		stats.oxygen = 0.0
	var restored_pre := await _make_world()
	restored_pre._current_slot = TEST_SLOT
	restored_pre._load_save()
	_expect(restored_pre.route.objective_id == "shallow_capstone" and restored_pre.route.checkpoint_id == "shallows_capstone",
		"CHECKPOINT RESTORE: pre-capstone save did not restore the exact capstone and checkpoint identity")
	_expect(_party_is_full(restored_pre),
		"CHECKPOINT RESTORE: pre-capstone save did not restore full HP and O2")
	_expect(not restored_pre.route.begin_active_encounter().is_empty(),
		"CHECKPOINT RESTORE: restored capstone was stuck in an in-progress encounter state")

	# A capstone victory advances first; its post-fight save must resume at the
	# deep Swordfish rather than replaying the cleared shallow pair.
	world.route.resolve_active_encounter("won")
	world._secure_route_checkpoint("test post-capstone")
	var restored_post := await _make_world()
	restored_post._current_slot = TEST_SLOT
	restored_post._load_save()
	_expect(restored_post.route.objective_id == "deep_swordfish" and restored_post.route.checkpoint_id == "shallows_capstone",
		"CHECKPOINT UNLOCK: post-capstone save replayed shallow combat instead of opening deep Swordfish")
	_expect(_party_is_full(restored_post),
		"CHECKPOINT UNLOCK: post-capstone save did not retain full party recovery")

	world.queue_free()
	restored_pre.queue_free()
	restored_post.queue_free()
	_remove_test_save()
	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("progression checkpoint  pre/post capstone recovery and unlock round-trip cleanly")
	quit(0 if findings.is_empty() else 1)

func _make_world() -> World:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	paused = false
	return world

func _party_is_full(world: World) -> bool:
	for diver_value in world.divers:
		var stats := (diver_value as Diver).stats
		if stats.hp != stats.hp_max or not is_equal_approx(stats.oxygen, stats.oxygen_max):
			return false
	return true

func _remove_test_save() -> void:
	var path := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(SaveManager.slot_path(TEST_SLOT)):
		DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
