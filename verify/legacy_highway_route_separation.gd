# `route guidance: a completed legacy highway puzzle cannot expose a second
# inert destination during an active authored route — guards against standing
# in a visual-only goal with no progression`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world: World = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame

	# Begin the real authored route, then complete the old optional highway
	# using its real Area3D plate occupancy rather than calling its solver.
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	world.route_transition_card.dismiss()
	for i in range(world._lock_plates.size()):
		var plate := world._lock_plates[i] as LockPlate
		(world.divers[i] as Diver).global_position = plate.global_position
	for _frame in 6:
		await physics_frame

	var guidance := world.route_guidance_presentation()
	_expect(world._puzzle_solved,
		"LEGACY ROUTE SEPARATION: production plate occupancy did not complete the highway puzzle")
	_expect(String(guidance.get("objective_id", "")) == "shallow_angler",
		"LEGACY ROUTE SEPARATION: starting the core route did not retain its authored objective")
	_expect(not bool(guidance.get("legacy_goal_visible", true)),
		"LEGACY ROUTE SEPARATION: completed highway puzzle exposed a second inert goal during the active route")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("LEGACY ROUTE SEPARATION: completed puzzle leaves one active destination")
	world.queue_free()
	quit(0 if findings.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)
