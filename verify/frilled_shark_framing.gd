# Playtest repair: Frilled Shark's visible mesh must fit the real battle stage
# without swallowing the party composition. This starts the actual Frilled
# Shark encounter at browser resolution and projects its imported mesh bounds
# through Battle's live stage camera. It catches the prior height-only FBX
# normalization, where the long rest pose filled the screen even though the
# logical combat radius had been capped.
#
# MUST run windowed, not headless:
#   godot --path . --resolution 1280x720 --script verify/frilled_shark_framing.gd
#   godot --path . --resolution 1920x1080 --script verify/frilled_shark_framing.gd
extends SceneTree

const SETTLE_FRAMES := 28
const SAFE_MARGIN_PX := 12.0
# This leaves enough negative space for party actors, their fixed status
# columns, and the target selector. It is a composition budget, not a hidden
# gameplay-radius cap.
const MAX_STAGE_WIDTH_FRACTION := 0.45

var world: Node3D
var frames := 0
var settle := 0
var started := false
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	# A standalone script briefly reports a 100×100 bootstrap viewport before
	# ProjectSettings/--resolution take effect. Yielding one frame prevents this
	# gate from treating a real 1280×720 window as headless.
	await process_frame
	var browser_size := root.get_visible_rect().size
	if browser_size.x < 1000.0 or browser_size.y < 600.0:
		push_error("Frilled Shark framing must run in a real browser-sized window; got %s" % browser_size)
		quit(2)
		return
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	root.add_child(world)

func _process(_delta: float) -> bool:
	if world == null:
		return false
	frames += 1
	if frames == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frames < 5:
		return false
	if not started:
		# Fixed authored roster, normal World -> Battle entry. This is not a
		# query-string shortcut or a synthetic combat signal.
		world._start_battle("", false, "angler", [], false, false, ["frilled_shark"])
		started = true
		return false
	if world.battle == null:
		findings.append("World did not create the Frilled Shark battle")
		return _report()
	var battle: Battle = world.battle
	if battle._stage_cam == null or battle._stage_container == null or battle._stage_vp == null:
		return false
	settle += 1
	if settle < SETTLE_FRAMES:
		return false
	_check(battle)
	return _report()

func _check(battle: Battle) -> void:
	var shark: Node3D
	for entry in battle.enemies:
		if entry.has("actor") and is_instance_valid(entry.actor):
			var candidate := entry.actor as Node3D
			if candidate.has_method("enemy_id") and String(candidate.call("enemy_id")) == "frilled_shark":
				shark = candidate
				break
	if shark == null:
		findings.append("Battle roster did not contain Frilled Shark")
		return

	var stage: Control = battle._stage_container
	var stage_rect := Rect2(stage.global_position, stage.size)
	var visible_rect := _project_mesh_bounds(battle, shark)
	if visible_rect.size == Vector2.ZERO:
		findings.append("Frilled Shark did not expose any projectable mesh bounds")
		return
	var safe_stage := stage_rect.grow(-SAFE_MARGIN_PX)
	print("Frilled Shark framing: mesh %s, stage %s" % [visible_rect, stage_rect])
	if not safe_stage.encloses(visible_rect):
		findings.append("FRILLED MESH OUT OF STAGE: mesh %s, safe stage %s" % [visible_rect, safe_stage])
	if visible_rect.size.x > stage_rect.size.x * MAX_STAGE_WIDTH_FRACTION:
		findings.append("FRILLED MESH CROWDING COMPOSITION: %.0fpx of %.0fpx stage width" % [visible_rect.size.x, stage_rect.size.x])

	# A mesh that covers a party member's actual body point is not merely
	# "large"; it hides a player-controlled fighter. Check the live camera's
	# composition rather than assuming party placement from a design constant.
	var inner_mesh := visible_rect.grow(-SAFE_MARGIN_PX)
	for entry in battle.party:
		if not entry.has("actor") or not is_instance_valid(entry.actor):
			continue
		var actor := entry.actor as Node3D
		var body_mid := battle._bottom_of(actor).lerp(battle._top_of(actor), 0.5)
		var body_screen := _project_point(battle, body_mid)
		if inner_mesh.has_point(body_screen):
			findings.append("FRILLED MESH COVERS PARTY BODY: %s at %s" % [String(entry.display_name), body_screen])

func _project_mesh_bounds(battle: Battle, actor: Node3D) -> Rect2:
	var first := true
	var rect := Rect2()
	for mesh in _meshes(actor):
		var aabb := mesh.get_aabb()
		for corner in range(8):
			var point: Vector3 = mesh.global_transform * aabb.get_endpoint(corner)
			if battle._stage_cam.is_position_behind(point):
				findings.append("FRILLED MESH IS BEHIND THE LIVE STAGE CAMERA")
				continue
			var screen := _project_point(battle, point)
			if first:
				rect = Rect2(screen, Vector2.ZERO)
				first = false
			else:
				rect = rect.expand(screen)
	return rect

func _project_point(battle: Battle, point: Vector3) -> Vector2:
	var stage: Control = battle._stage_container
	var vp_size := Vector2(battle._stage_vp.size)
	var scale := Vector2(stage.size.x / maxf(1.0, vp_size.x), stage.size.y / maxf(1.0, vp_size.y))
	return battle._stage_cam.unproject_position(point) * scale + stage.global_position

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		out.append_array(_meshes(child))
	return out

func _report() -> bool:
	for finding in findings:
		print("FINDING  " + finding)
	print("FRILLED SHARK FRAMING: clean" if findings.is_empty() else "FRILLED SHARK FRAMING: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
