extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	world.set_physics_process(false)
	await process_frame
	await process_frame

	world.active = 1
	var musashi := world.divers[world.active] as Diver
	musashi.unlock_ability()
	_check(musashi.ability_id == "grapple", "world_grapple_aim: fixture selects the aimed Grapple diver")
	_check(musashi.model != null and musashi.model.visible, "world_grapple_aim: Musashi begins visible in third-person world play")

	world.call("_start_ability")
	_check(world.aiming, "world_grapple_aim: Grapple enters first-person aim mode")
	_check(not musashi.model.visible, "world_grapple_aim: entering aim hides the active diver mesh — guards against the body covering the crosshair and far anchor")

	world.call("_cancel_aim")
	_check(not world.aiming, "world_grapple_aim: cancel exits aim mode")
	_check(musashi.model.visible, "world_grapple_aim: cancel restores the active diver mesh — guards against an invisible player after backing out")

	world.call("_start_ability")
	world.call("_fire_aimed_ability")
	await physics_frame
	_check(not world.aiming, "world_grapple_aim: firing exits aim mode")
	_check(musashi.model.visible, "world_grapple_aim: firing restores the active diver mesh — guards against an invisible player after a grapple attempt")

	if failures.is_empty():
		print("WORLD GRAPPLE AIM: clean")
		quit()
	else:
		print("WORLD GRAPPLE AIM: failures %s" % str(failures))
		quit(1)

func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
	else:
		push_error("FAIL: %s" % description)
		failures.append(description)
