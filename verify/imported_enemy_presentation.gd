# `imported enemy presentation: Frilled Shark has bounded real geometry and an
# idle that loops/restarts — guards against giant framing and frozen actors`.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var shark := FrilledShark.new()
	root.add_child(shark)
	await process_frame

	if not shark.has_method("visual_bounds"):
		findings.append("VISUAL BOUNDS CONTRACT: imported enemy exposes no real mesh bounds to Battle framing")
	else:
		var bounds := shark.call("visual_bounds") as AABB
		var horizontal_span := maxf(bounds.size.x, bounds.size.z)
		if horizontal_span > 3.45:
			findings.append("FRILLED SHARK SCALE: %.2f m horizontal span exceeds the 3.4 m presentation cap" % horizontal_span)

	if shark.anim == null or shark._idle_anim.is_empty():
		findings.append("IDLE FIXTURE: Frilled Shark has no resolved imported idle")
	else:
		var idle := shark.anim.get_animation(shark._idle_anim)
		if idle == null or idle.loop_mode == Animation.LOOP_NONE:
			findings.append("IMPORTED IDLE LOOP: Frilled Shark idle is not configured to loop")
		shark.anim.play(shark._idle_anim)
		if idle != null:
			shark.anim.seek(maxf(0.0, idle.length - 0.01), true)
			shark.anim.advance(0.1)
		shark.play("idle")
		if not shark.anim.is_playing():
			findings.append("STOPPED IDLE RESTART: requesting the same idle name did not restart a stopped actor")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("IMPORTED ENEMY PRESENTATION: bounded geometry and durable idle are clean")
	shark.queue_free()
	await process_frame
	quit(0 if findings.is_empty() else 1)
