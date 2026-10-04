# OPEN-012 / OPEN-AUDIT-008: valid imported bounds can still make the boss
# unreadably small in the real short battle stage. Run at 720x480 and wide.
extends SceneTree

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await world._on_title_new_game(918306)
	world._update_prologue_trigger(0.4)
	world._update_prologue_trigger(7.2)
	await process_frame
	var fight := world.battle
	await fight.reveal_prologue_octopus()
	await create_timer(0.1).timeout
	var actor := fight.enemies[0].actor as PrologueOctopus
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for vertex in actor.current_pose_points():
		var point := fight._stage_cam.unproject_position(vertex)
		low = low.min(point)
		high = high.max(point)
	var size := Vector2(fight._stage_vp.size)
	var fraction := (high.y - low.y) / size.y
	print("Cordys projected stage-height fraction: %.3f" % fraction)
	if fraction < 0.45:
		findings.append("OPEN-012 narrow-stage boss reads miniature (below 45% stage height)")
	if low.x < 0.0 or high.x > size.x or low.y < 0.0 or high.y > size.y:
		findings.append("OPEN-012 boss framing clips the idle silhouette")
	world.queue_free()
	await process_frame
	paused = false
	root.get_node("GameAudio").release_streams_for_shutdown()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(918306)))
	for finding in findings:
		print("FINDING  " + finding)
	quit(0 if findings.is_empty() else 1)
