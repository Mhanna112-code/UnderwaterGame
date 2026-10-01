# End-to-end contract for the reusable, key-gated Door FBX component.
#
# Usage: godot --headless --path . --script verify/key_door.gd
extends SceneTree

const TEST_SLOT := 918274
const DOOR_ID := "verify_sea_gate"

var findings: Array[String] = []
var opened_signal_count := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_save()
	var world := await _fresh_world()
	var actor := world.divers[world.active] as Diver
	var door := await _add_door(world, actor)
	if door == null:
		_finish()
		return
	var bounds := (door._collision.shape as BoxShape3D).size if door._collision != null and door._collision.shape is BoxShape3D else Vector3.ZERO
	print("key door                 collision bounds %s centered at %s, visual height %.2f" % [bounds, door._collision.position if door._collision != null else Vector3.ZERO, door.visual_height])
	_expect(is_equal_approx(bounds.y, door.visual_height), "DOOR BOUNDS: collision height %s does not match configured visual height %.2f" % [bounds.y, door.visual_height])
	_expect(is_zero_approx(door._collision.position.y - bounds.y * 0.5), "DOOR GROUNDING: collision bottom %.3f is not aligned to the placement floor" % (door._collision.position.y - bounds.y * 0.5))

	# key door: missing key retains collision and reports requirement — guards
	# against locked-route bypass.
	_press_e(world)
	await process_frame
	_expect(not door.is_open(), "MISSING KEY: E opened the door without %s" % door.required_key_id)
	_expect(door.is_collision_blocking(), "MISSING KEY: collision released without the key")
	_expect(door.interaction_prompt(actor).contains("Requires Current Pearl"), "MISSING KEY: no readable Current Pearl requirement prompt")

	# key door: collision releases only after authored Open progress threshold —
	# guards against invisible early passage.
	world.key_items.append(door.required_key_id)
	_press_e(world)
	await process_frame
	_expect(door.is_open(), "KEYED INTERACTION: correct key did not begin opening")
	_expect(door.is_collision_blocking(), "EARLY COLLISION: opening released passage before authored progress")
	await create_timer(0.15).timeout
	_expect(door.open_progress() < door.collision_release_progress, "TIMELINE SETUP: sampled after collision threshold")
	_expect(door.is_collision_blocking(), "THRESHOLD COLLISION: passage released before threshold")
	await create_timer(1.2).timeout
	_expect(not door.is_collision_blocking(), "OPEN COLLISION: passage still blocks after authored open completed")

	# key door: repeated keyed interaction opens once — guards against duplicate
	# tween/persistence side effects.
	_press_e(world)
	_press_e(world)
	await process_frame
	_expect(opened_signal_count == 1, "IDEMPOTENCE: expected one door_opened signal, got %d" % opened_signal_count)
	_expect(world.opened_key_doors.count(DOOR_ID) == 1, "IDEMPOTENCE: save list contains duplicate door id")

	# key door: completed unlock survives World save/load — guards against
	# reopened progression gate.
	world._write_save()
	world._on_game_over_restart()
	for _i in range(6):
		await process_frame
	var restored := current_scene as World
	if restored == null:
		findings.append("PERSISTENCE SETUP: World did not restart from saved slot")
	else:
		var restored_actor := restored.divers[restored.active] as Diver
		var restored_door := await _add_door(restored, restored_actor, false)
		_expect(restored.is_key_door_open(DOOR_ID), "SAVE CONTENT: saved door id did not reload")
		_expect(restored_door.is_open(), "RESTORE: saved-open KeyDoor rebuilt locked")
		_expect(not restored_door.is_collision_blocking(), "RESTORE COLLISION: saved-open KeyDoor still blocks passage")
		await _verify_actual_legacy_lock_plate_puzzle(restored)
	_finish()

func _verify_actual_legacy_lock_plate_puzzle(world: World) -> void:
	# The integration must leave the original World wiring intact: three
	# distinct procedural Doors begin shut and only all three real LockPlates
	# together call Door.open(). A standalone Door.new() would not prove that.
	_expect(world._lock_plates.size() == 3, "LEGACY PUZZLE: expected three lock plates, got %d" % world._lock_plates.size())
	_expect(world._doors.size() == 3, "LEGACY PUZZLE: expected three procedural doors, got %d" % world._doors.size())
	for legacy_door_value in world._doors:
		_expect(not (legacy_door_value as Door)._opened, "LEGACY PUZZLE: a lock-plate Door began open")
	for i in range(mini(world.divers.size(), world._lock_plates.size())):
		(world.divers[i] as Diver).global_position = (world._lock_plates[i] as LockPlate).global_position
	for _tick in range(8):
		await physics_frame
	_expect(world._puzzle_solved, "LEGACY PUZZLE: three occupied lock plates did not solve the original gate")
	for legacy_door_value in world._doors:
		_expect((legacy_door_value as Door)._opened, "LEGACY PUZZLE: a Door did not open after the original three-plate condition")

func _fresh_world() -> World:
	var packed := load("res://game/world.tscn") as PackedScene
	var world := packed.instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	current_scene = world
	await process_frame
	world._on_title_new_game(TEST_SLOT)
	await process_frame
	return world

func _add_door(world: World, actor: Diver, expect_closed := true) -> KeyDoor:
	var door := KeyDoor.new()
	door.door_id = DOOR_ID
	door.required_key_id = "current_pearl"
	door.opening_duration = 1.0
	door.visual_height = 2.4
	door.interaction_radius = 4.0
	# KeyDoor's placement is floor-anchored, while a Diver's position is at its
	# collision-body center. Keeping the test on the floor catches a component
	# that would otherwise look correct only when spawned mid-water.
	door.position = Vector3(actor.position.x, 0.0, actor.position.z)
	door.door_opened.connect(func(_id: String) -> void: opened_signal_count += 1)
	world.add_child(door)
	await process_frame
	await physics_frame
	if expect_closed and not door.is_collision_blocking():
		findings.append("DOOR SETUP: new KeyDoor did not construct closed collision")
	return door

func _press_e(world: World) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_E
	world._unhandled_input(event)

func _expect(condition: bool, finding: String) -> void:
	if not condition:
		findings.append(finding)

func _remove_test_save() -> void:
	var absolute := ProjectSettings.globalize_path(SaveManager.slot_path(TEST_SLOT))
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)

func _finish() -> void:
	_remove_test_save()
	for finding in findings:
		print("FINDING  " + finding)
	print("KEY DOOR: clean" if findings.is_empty() else "KEY DOOR: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
