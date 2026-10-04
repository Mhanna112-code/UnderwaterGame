# REVEAL-04: bounded properties using the actual world, camera, imported
# actors and environment physics, not guessed radii or placeholder meshes.
extends SceneTree
var findings: Array[String] = []
var output := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
		DirAccess.make_dir_recursive_absolute(output)
	call_deferred("_run")

func _run() -> void:
	var world := load("res://game/world.tscn").instantiate() as World
	world.skip_intro_for_test = true
	world.route_state.prologue_complete = true
	world.route_state.opening_video_seen = true
	root.add_child(world)
	await process_frame
	await physics_frame
	world.title_screen.close()
	world.get_node("HUD").visible = true
	var properties := 0
	var positions := [Vector3(0, 4, 0), Vector3(0, 1, 0), Vector3(17, 3, 10)]
	for viewport in [Vector2i(1280, 720), Vector2i(720, 480)]:
		root.size = viewport
		await process_frame
		for pitch in [-1.0, -0.16, 0.7]:
			for yaw in [0.0, PI / 2.0, PI]:
				for roster in [["angler"], ["swordfish_duelist"], ["frilled_shark"], ["angler", "frilled_shark"], ["frilled_shark", "swordfish_duelist", "angler"]]:
					world.cam.global_position = positions[int(properties / 5) % positions.size()]
					world.cam.global_rotation = Vector3(pitch, yaw, 0)
					var reveal := RandomEncounterReveal.new()
					reveal.enemy_ids.assign(roster)
					reveal.camera = world.cam
					world.add_child(reveal)
					# No artificial placement helper: inspect real generated actors.
					reveal.set_process(false)
					for moment in [0.0, 0.75, 1.4]:
						for actor in reveal.actors:
							if actor.anim != null:
								actor.anim.seek(moment, true)
							var bounds := actor.visual_bounds()
							for corner in range(8):
								var point := bounds.get_endpoint(corner)
								var pixel := world.cam.unproject_position(point)
								if world.cam.is_position_behind(point) or not Rect2(Vector2(viewport) * 0.05, Vector2(viewport) * 0.9).has_point(pixel):
									findings.append("REVEAL-04 clipped %s at %s / %s / %s / %s: %s" % [actor.enemy_id(), viewport, pitch, yaw, moment, pixel])
							var shape := BoxShape3D.new()
							shape.size = bounds.size
							var query := PhysicsShapeQueryParameters3D.new()
							query.shape = shape
							query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
							query.collision_mask = 1
							if not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
								findings.append("REVEAL-04 %s intersects environment at %s / %s / %s" % [actor.enemy_id(), viewport, pitch, yaw])
							var ray := PhysicsRayQueryParameters3D.create(world.cam.global_position, bounds.get_center(), 1)
							if not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
								findings.append("REVEAL-04 %s hidden behind terrain at %s / %s / %s" % [actor.enemy_id(), world.cam.global_position, pitch, yaw])
					properties += 1
					if not output.is_empty() and is_equal_approx(pitch, -0.16) and is_zero_approx(yaw):
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("formation-%s-%d.png" % [viewport.x, properties]))
					reveal.free()
	for finding in findings:
		push_error(finding)
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	await process_frame
	print("RANDOM REVEAL FRAMING: ", properties, " formations / three live animation samples: ", "PASS" if findings.is_empty() else "FAIL")
	quit(0 if findings.is_empty() else 1)
