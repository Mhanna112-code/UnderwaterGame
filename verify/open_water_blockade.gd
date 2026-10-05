# `open water: a diver can swim beside the visible entrance rocks and rise
# through unbounded water — guards against invisible world-spanning collision
# wings or ceilings blocking traversal`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_physics_process(false)
	world.random_encounters_enabled = false

	var diver := world.divers[0] as Diver
	diver.global_position = Vector3(8.0, 2.0, 0.0)
	diver.velocity = Vector3.ZERO
	diver.current_axis = Vector3.ZERO
	for _frame in range(240):
		diver.swim(Vector3.RIGHT, 0.0, 1.0 / 60.0)
		await physics_frame

	# The invisible wall in line with the blockade entrance was restored on
	# request: swimming past beside the rocks must now be stopped at the gate.
	if diver.global_position.x > 16.0:
		findings.append(
			"BLOCKADE BYPASS: diver swam past the entrance line to x=%.2f beside the rocks" % diver.global_position.x
		)

	# A later PR #96 change reintroduced the same player-facing failure class
	# vertically: one collision-only roof covered the original dive site and the
	# entire Deep extension. Probe the production CharacterBody3D at stable open-
	# water samples on both sides of the route. `test_only` keeps each sample
	# independent while still querying the real world physics and Diver shape.
	var vertical_samples := [
		Vector3(-40.0, 2.0, 0.0),
		Vector3(0.0, 2.0, 0.0),
		Vector3(40.0, 2.0, 0.0),
		Vector3(100.0, 2.0, 0.0),
		Vector3(220.0, 2.0, 0.0),
	]
	for sample in vertical_samples:
		diver.global_position = sample
		diver.velocity = Vector3.ZERO
		await physics_frame
		# Free water all the way up past the airborne reward rocks (18 m)...
		var collision := diver.move_and_collide(Vector3.UP * 17.0, true)
		if collision != null:
			findings.append(
				"INVISIBLE OPEN-WATER CEILING: upward path from %s hit collision at y=%.2f" % [
					sample,
					collision.get_position().y,
				]
			)
		# ...then the restored world ceiling at four blockade heights (24 m).
		var roof := diver.move_and_collide(Vector3.UP * 40.0, true)
		if roof == null or absf(roof.get_position().y - World.WORLD_CEILING_Y) > 0.5:
			findings.append("WORLD CEILING MISSING: upward path from %s did not stop at y=%.1f" % [sample, World.WORLD_CEILING_Y])

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("OPEN WATER: blockade line blocks the bypass; vertical is free up to the world ceiling")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
