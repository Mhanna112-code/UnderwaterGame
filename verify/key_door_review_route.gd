# Native contract for the public `?keydoor=1` / --key-door-playtest reviewer
# route. The browser URL itself is separately exercised during export review.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://game/world.tscn") as PackedScene
	var world := packed.instantiate() as World
	root.add_child(world)
	current_scene = world
	for _i in range(4):
		await process_frame
	_expect(not paused, "REVIEW ROUTE: World remained paused behind the title screen")
	_expect(world._first_encounter_done, "REVIEW ROUTE: tutorial/encounter gate still blocks the isolated review")
	var door := world.get_node_or_null("KeyDoorReview") as KeyDoor
	_expect(door != null, "REVIEW ROUTE: no real KeyDoor was placed")
	if door != null:
		_expect(door.required_key_id == "current_pearl", "REVIEW ROUTE: demo door does not require the visible Current Pearl")
		_expect(door.is_collision_blocking(), "REVIEW ROUTE: demo door starts physically open")
	var key := world.get_node_or_null("KeyDoorReviewCurrentPearl") as Area3D
	_expect(key != null, "REVIEW ROUTE: no physical Current Pearl pickup was placed")
	if key != null and door != null:
		# Exercise the actual Area3D pickup rather than merely asserting that a
		# decorative test orb exists.  A reviewer must be able to acquire the
		# key through normal world collision before returning to the Door FBX.
		var actor := world.divers[world.active] as Diver
		actor.global_position = key.global_position + Vector3(0.0, 0.1, 0.0)
		# Broad-phase overlap updates are deferred by the real physics server;
		# wait a handful of ticks rather than assuming a teleport emits the
		# Area3D signal in the same frame.
		for _tick in range(8):
			await physics_frame
		_expect(world.key_items.has("current_pearl"), "REVIEW ROUTE: walking into the Current Pearl did not award the required key")
		actor.global_position = door.global_position
		await physics_frame
		var press := InputEventKey.new()
		press.pressed = true
		press.keycode = KEY_E
		world._unhandled_input(press)
		await process_frame
		_expect(door.is_open(), "REVIEW ROUTE: collected physical key did not unlock the placed Door FBX")
	_expect(world._current_slot < 0, "REVIEW ROUTE: review path can write a campaign save")
	_finish()

func _expect(condition: bool, finding: String) -> void:
	if not condition:
		findings.append(finding)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("KEY DOOR REVIEW ROUTE: clean" if findings.is_empty() else "KEY DOOR REVIEW ROUTE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
