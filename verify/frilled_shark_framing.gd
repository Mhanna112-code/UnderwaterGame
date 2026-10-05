# `Frilled Shark framing: real mesh bounds stay inside the production stage and
# clear of party silhouettes — guards against height-only camera framing`.
# MUST run windowed; headless projection uses a meaningless 64x64 viewport.
extends SceneTree

const SETTLE_FRAMES := 24
var world: World
var frames := 0
var findings: Array[String] = []

func _initialize() -> void:
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(3)
		return false
	if frames == 3:
		world._start_battle("", false, "frilled_shark", [], false, false, "", true)
		return false
	if frames < SETTLE_FRAMES or world.battle == null:
		return false
	_check(world.battle)
	_save_evidence_if_requested()
	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("FRILLED SHARK FRAMING: real bounds are visible and separated from the party")
	quit(0 if findings.is_empty() else 1)
	return true

func _save_evidence_if_requested() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--evidence="):
			continue
		var path := argument.trim_prefix("--evidence=")
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			findings.append("EVIDENCE CAPTURE: could not save %s (%s)" % [path, error_string(error)])
		else:
			print("Frilled Shark evidence saved to %s" % path)

func _project_bounds(battle: Battle, bounds: AABB) -> Rect2:
	var stage := battle._stage_container as Control
	var viewport_size := Vector2(battle._stage_vp.size)
	var scale_to_screen := Vector2(
		stage.size.x / maxf(1.0, viewport_size.x),
		stage.size.y / maxf(1.0, viewport_size.y)
	)
	var rect := Rect2()
	var first := true
	for i in range(8):
		var screen_point := battle._stage_cam.unproject_position(bounds.get_endpoint(i)) * scale_to_screen + stage.position
		if first:
			rect = Rect2(screen_point, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(screen_point)
	return rect

func _party_bounds(battle: Battle, actor: Node3D) -> Rect2:
	var radius := maxf(0.7, float(actor.get("radius") if actor.get("radius") != null else 0.7))
	var low := battle._bottom_of(actor)
	var high := battle._top_of(actor)
	var world_bounds := AABB(low - Vector3(radius, 0.0, radius), Vector3(radius * 2.0, high.y - low.y, radius * 2.0))
	return _project_bounds(battle, world_bounds)

func _check(battle: Battle) -> void:
	var stage := battle._stage_container as Control
	var stage_rect := Rect2(stage.position, stage.size)
	var shark_entry: Dictionary = {}
	for enemy in battle.enemies:
		if String((enemy as Dictionary).get("enemy_id", "")) == "frilled_shark" or String((enemy as Dictionary).get("display_name", "")) == "Frilled Shark":
			shark_entry = enemy as Dictionary
			break
	if shark_entry.is_empty() or not is_instance_valid(shark_entry.get("actor")):
		findings.append("FRILLED FIXTURE: production battle did not create the authored shark actor")
		return
	var shark := shark_entry.actor as Goblin
	var shark_rect := _project_bounds(battle, shark.visual_bounds())
	print("Frilled mesh rect %s; stage %s" % [str(shark_rect), str(stage_rect)])
	if not stage_rect.encloses(shark_rect):
		findings.append("FRILLED OUT OF FRAME: mesh rect %s exceeds stage %s" % [str(shark_rect), str(stage_rect)])
	for member in battle.party:
		if not (member as Dictionary).has("actor") or not is_instance_valid((member as Dictionary).actor):
			continue
		var party_rect := _party_bounds(battle, (member as Dictionary).actor as Node3D)
		var overlap := shark_rect.intersection(party_rect)
		var smaller_area := minf(shark_rect.get_area(), party_rect.get_area())
		print("  %s rect %s; overlap %.1f%%" % [String((member as Dictionary).display_name), str(party_rect), 100.0 * overlap.get_area() / maxf(1.0, smaller_area)])
		if smaller_area > 0.0 and overlap.get_area() / smaller_area > 0.20:
			findings.append("FRILLED PARTY OVERLAP: shark covers %s's body silhouette" % String((member as Dictionary).display_name))
