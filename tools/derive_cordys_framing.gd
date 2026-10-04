# Mechanical derivative of the canonical skin/selected clips. Regenerate when
# the source FBX, normalization, or semantic clip selection changes. Runtime
# must not scan dozens of full meshes at the first visible boss reveal.
extends SceneTree

const OUTPUT := "res://art/deep_zone/octopus_prologue_frame.tres"
const SAMPLES := 19

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var actor := PrologueOctopus.new()
	var started := Time.get_ticks_msec()
	root.add_child(actor)
	print("Cordys actor ready: %d ms" % (Time.get_ticks_msec() - started))
	var hull := PackedVector3Array()
	var clips := {}
	for key in ["idle", "reveal", "hurt", "finish"]:
		clips[key] = actor.clip_name(key)
		var duration := actor.play(key)
		for sample in range(SAMPLES):
			actor.anim.seek(duration * float(sample) / float(SAMPLES - 1), true)
			var points := actor.current_pose_points()
			for x in [-1.0, 0.0, 1.0]:
				for y in [-1.0, 0.0, 1.0]:
					for z in [-1.0, 0.0, 1.0]:
						var direction := Vector3(x, y, z)
						if direction.is_zero_approx():
							continue
						var extreme := points[0]
						var largest := -INF
						for point in points:
							var projected := point.dot(direction)
							if projected > largest:
								largest = projected
								extreme = point
						hull.append(actor.to_local(extreme))
	if hull.size() != 4 * SAMPLES * 26:
		push_error("Unexpected framing derivative point count")
		quit(1)
		return
	var derivative := Resource.new()
	derivative.set_meta("source_sha256", FileAccess.get_sha256("res://art/deep_zone/Octopus_Boss.fbx"))
	derivative.set_meta("target_height", actor.TARGET_HEIGHT)
	derivative.set_meta("clips", clips)
	derivative.set_meta("samples", SAMPLES)
	derivative.set_meta("points", hull)
	var error := ResourceSaver.save(derivative, OUTPUT)
	print("Cordys frame derivative: %d surface points, save result %d" % [hull.size(), error])
	actor.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
