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
	_check_whirlpool_visual(world)
	_check_lock_plate_visuals(world)
	_check_near_surface_reticle(world)

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

func _check_whirlpool_visual(world: World) -> void:
	var whirlpool: Whirlpool = null
	for child in world.get_children():
		if child is Whirlpool:
			whirlpool = child as Whirlpool
			break
	_check(whirlpool != null, "world_grapple_aim: production route owns a Whirlpool hazard")
	if whirlpool == null:
		return
	var visual: MeshInstance3D = null
	for child in whirlpool.get_children():
		if child is MeshInstance3D:
			visual = child as MeshInstance3D
			break
	_check(visual != null, "world_grapple_aim: Whirlpool has a player-visible hazard surface")
	if visual == null:
		return
	var transformed_bounds: AABB = visual.transform * visual.get_aabb()
	_check(
		transformed_bounds.size.y < transformed_bounds.size.x * 0.35,
		"world_grapple_aim: Whirlpool visual stays floor-aligned instead of forming an opaque wall across the required target line"
	)

func _check_lock_plate_visuals(world: World) -> void:
	_check(world._lock_plates.size() == 3, "world_grapple_aim: production route owns three pressure plates")
	for i in range(world._lock_plates.size()):
		var plate := world._lock_plates[i] as LockPlate
		var visual: MeshInstance3D = null
		for child in plate.get_children():
			if child is MeshInstance3D:
				visual = child as MeshInstance3D
				break
		_check(visual != null, "world_grapple_aim: pressure plate %d has a visible surface" % (i + 1))
		if visual == null:
			continue
		var transformed_bounds: AABB = visual.transform * visual.get_aabb()
		_check(
			transformed_bounds.size.y < transformed_bounds.size.x * 0.35,
			"world_grapple_aim: pressure plate %d visual lies on its real floor trigger instead of standing upright on the wall" % (i + 1)
		)

func _check_near_surface_reticle(world: World) -> void:
	_check(
		world.has_method("_aim_marker_scale_for_distance"),
		"world_grapple_aim: aim reticle owns distance-aware sizing — guards against a close wall filling the whole first-person view"
	)
	if not world.has_method("_aim_marker_scale_for_distance"):
		return
	var near_scale := float(world.call("_aim_marker_scale_for_distance", 0.1))
	var route_scale := float(world.call("_aim_marker_scale_for_distance", 8.0))
	_check(
		near_scale <= 0.05,
		"world_grapple_aim: a 10 cm ray hit keeps the gray miss reticle below 5% world scale"
	)
	_check(
		is_equal_approx(route_scale, 1.0),
		"world_grapple_aim: a normal route target retains the authored full-size reticle"
	)
