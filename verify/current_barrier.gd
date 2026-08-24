extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var area := Area3D.new()
	area.collision_mask = 2
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 8.0)
	collision.shape = box
	area.add_child(collision)
	root.add_child(area)

	var current := WaterCurrent.new()
	root.add_child(current)
	current.setup(area, Vector3(0.0, 0.0, -1.0), 7.0, false)

	var diver := Diver.new()
	diver.model_name = "Prototype_V(1922)"
	diver.position = Vector3(0.0, 0.0, -2.5)
	root.add_child(diver)
	await physics_frame
	await physics_frame

	var max_z := diver.position.z
	for frame in range(240):
		diver.swim(Vector3(0.0, 0.0, 1.0), 0.0, 1.0 / 60.0)
		await physics_frame
		max_z = maxf(max_z, diver.position.z)

	var blocked := max_z < 3.5 and diver.position.z < -3.5
	print("CURRENT BARRIER: max upstream z %.3f, final z %.3f" % [max_z, diver.position.z])
	if not blocked:
		push_error("CURRENT BARRIER: diver crossed or was not swept back")
		quit(1)
		return
	print("CURRENT BARRIER: clean")
	quit()
