# `open water: a diver can swim beside the visible entrance rocks — guards
# against an invisible corridor-wide collision wing blocking traversal`.
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

	if diver.global_position.x < 22.0:
		findings.append(
			"INVISIBLE OPEN-WATER BLOCKADE: diver stopped at x=%.2f beside the visible entrance rocks" % diver.global_position.x
		)

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("OPEN WATER: diver crossed the unblocked water beside the visible entrance rocks")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
