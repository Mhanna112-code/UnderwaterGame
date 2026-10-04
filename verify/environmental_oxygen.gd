# Issue #48: the actual progression route must remain recoverable when every
# diver has zero oxygen. The test preserves an existing test slot before it
# creates a new run, so it cannot discard a real player's saved data.
extends SceneTree

const TEST_SLOT := 918276
const NEAR_SIDE_X := 22.0
const FAR_SIDE_MIN_X := 30.0

var findings: Array[String] = []
var _had_existing_save := false
var _saved_bytes := PackedByteArray()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_backup_test_slot()
	var world := await _fresh_world()
	var mermaid := world.divers[0] as Diver
	var diver_boy := world.divers[1] as Diver
	var marine_man := world.divers[2] as Diver
	for diver in world.divers:
		(diver as Diver).stats.oxygen = 0.0
		(diver as Diver).encounter_chance = 0.0

	_test_zero_readiness([mermaid, diver_boy, marine_man])
	_test_sonar_boundary(mermaid)
	await _break_entrance_at_zero(world, marine_man)
	await _cross_party_at_zero(mermaid, diver_boy, marine_man)
	await _complete_plates(world, [mermaid, diver_boy, marine_man])

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("environmental oxygen  zero-O2 abilities and real puzzle completion clean")
	world.queue_free()
	_restore_test_slot()
	quit(0 if findings.is_empty() else 1)

func _fresh_world() -> World:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(TEST_SLOT)
	await process_frame
	return world

func _test_zero_readiness(divers: Array) -> void:
	for diver in divers:
		var d := diver as Diver
		if not d.can_use_ability():
			findings.append("ZERO READINESS: %s/%s is disabled at zero oxygen" % [d.model_name, d.ability_id])

func _test_sonar_boundary(mermaid: Diver) -> void:
	if mermaid.toggle_sonar():
		findings.append("SONAR BOUNDARY: sonar activated at zero oxygen")

func _break_entrance_at_zero(world: World, marine_man: Diver) -> void:
	marine_man.global_position = Vector3(16.0, 3.0, 10.0)
	marine_man.use_ability()
	await process_frame
	await process_frame
	if world._cracked_walls.has("entrance_blockade"):
		findings.append("SHOCKWAVE EFFECT: entrance blockade survived zero-oxygen Shockwave")
	_expect_zero(marine_man, "SHOCKWAVE COST")

func _cross_party_at_zero(mermaid: Diver, diver_boy: Diver, marine_man: Diver) -> void:
	mermaid.global_position = Vector3(NEAR_SIDE_X, 2.0, 9.0)
	diver_boy.global_position = Vector3(NEAR_SIDE_X, 2.0, 10.0)
	marine_man.global_position = Vector3(NEAR_SIDE_X, 2.0, 11.0)

	await _grapple_across(diver_boy, "first crossing")
	await _swap(mermaid, diver_boy, "Mermaid takes first far position")
	await _grapple_across(diver_boy, "second crossing")
	await _swap(mermaid, marine_man, "Marine Man takes far position")
	await _swap(mermaid, diver_boy, "Mermaid returns far and Diver Boy stages")
	await _grapple_across(diver_boy, "final crossing")

	for diver in [mermaid, diver_boy, marine_man]:
		var d := diver as Diver
		if d.global_position.x < FAR_SIDE_MIN_X:
			findings.append("CROSSING: %s remained on near side at x=%.2f" % [d.model_name, d.global_position.x])
		_expect_zero(d, "CROSSING COST")

func _grapple_across(diver_boy: Diver, step: String) -> void:
	await create_timer(Diver.GRAPPLE_COOLDOWN + 0.05).timeout
	if not diver_boy.can_use_ability():
		findings.append("GRAPPLE READY (%s): unavailable at zero oxygen" % step)
		return
	var eye := diver_boy.global_position + Vector3(0.0, diver_boy.height * 0.4, 0.0)
	var crossing_anchor := Vector3(32.0, 2.0, 10.0)
	diver_boy.use_ability((crossing_anchor - eye).normalized())
	await create_timer(Diver.GRAPPLE_PULL_DURATION + 0.15).timeout
	if diver_boy.global_position.x < FAR_SIDE_MIN_X:
		findings.append("GRAPPLE EFFECT (%s): stopped at x=%.2f" % [step, diver_boy.global_position.x])

func _swap(mermaid: Diver, target: Diver, step: String) -> void:
	await create_timer(Diver.SWAP_COOLDOWN + 0.05).timeout
	if not mermaid.can_use_ability():
		findings.append("SWAP READY (%s): unavailable at zero oxygen" % step)
		return
	var before_mermaid := mermaid.global_position
	var before_target := target.global_position
	mermaid.use_ability(Vector3.ZERO, target)
	await process_frame
	var mermaid_took_target_side := (mermaid.global_position.x >= FAR_SIDE_MIN_X) == (before_target.x >= FAR_SIDE_MIN_X)
	var target_took_mermaid_side := (target.global_position.x >= FAR_SIDE_MIN_X) == (before_mermaid.x >= FAR_SIDE_MIN_X)
	if not mermaid_took_target_side or not target_took_mermaid_side:
		findings.append("SWAP EFFECT (%s): sides did not exchange; got %s/%s" % [step, mermaid.global_position, target.global_position])

func _complete_plates(world: World, party: Array) -> void:
	for i in range(3):
		(party[i] as Diver).global_position = Vector3(39.0, 2.0, 7.5 + i * 2.5)
	for _frame in range(8):
		await physics_frame
	if world._puzzle_goal == null or not world._puzzle_goal.visible:
		findings.append("PUZZLE GOAL: all three zero-oxygen divers did not reveal the goal")

func _expect_zero(diver: Diver, prefix: String) -> void:
	if not is_zero_approx(diver.stats.oxygen):
		findings.append("%s: %s oxygen changed from zero to %.2f" % [prefix, diver.model_name, diver.stats.oxygen])

func is_zero_approx(value: float) -> bool:
	return is_equal_approx(value, 0.0)

func _slot_path() -> String:
	return ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))

func _backup_test_slot() -> void:
	var path := _slot_path()
	_had_existing_save = FileAccess.file_exists(path)
	if _had_existing_save:
		var source := FileAccess.open(path, FileAccess.READ)
		_saved_bytes = source.get_buffer(source.get_length())

func _restore_test_slot() -> void:
	var path := _slot_path()
	if _had_existing_save:
		var destination := FileAccess.open(path, FileAccess.WRITE)
		destination.store_buffer(_saved_bytes)
	elif FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
