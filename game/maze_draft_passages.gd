extends Node3D
# Authored 4ec6598 passage pair, adapted to shared World ownership. This
# component owns only transient prompt/motion; the maze snapshot owns walls.
const WIDTH := 2.6
const REACH := 1.6
var maze: MazeLevel
var end_cap: CSGBox3D
var outgoing_z := 0.0
var break_side := 0.0
var return_x := 0.0
var return_z := 0.0
var return_side := 0.0
var prompt: ConfirmPromptModal
var busy := false
var latched := false
var return_latched := false
var actor: Diver
var motion: Tween
var departure := Vector3.ZERO
var return_visuals: Array[Node3D] = []
var floor_shape: CollisionShape3D
var floor_pieces: Array[StaticBody3D] = []
var outgoing_slot: MeshInstance3D

func setup(owner_maze: MazeLevel) -> void:
	maze = owner_maze
	floor_shape = maze.get_node("MazeFloorCollision").get_child(0) as CollisionShape3D
	end_cap = maze.get_node("Wall11EndCap") as CSGBox3D
	var corridor := maze.get_node("WindCorridorBreakRock") as Area3D
	break_side = signf(maze._corridor_shape(corridor).global_position.x - end_cap.global_position.x)
	var geometry: Dictionary = maze._wall_geometry(end_cap)
	var z0 := minf(geometry.negative_end.z, geometry.positive_end.z)
	var z1 := maxf(geometry.negative_end.z, geometry.positive_end.z)
	outgoing_z = clampf(maze._potion_rock_spot.z + 0.7 + WIDTH * 0.5, z0 + WIDTH * 0.5, z1 - WIDTH * 0.5)
	outgoing_slot = _slot_visual(Vector3(end_cap.global_position.x, maze._floor_top_y, outgoing_z),
		Vector3(end_cap.size.z + REACH * 2.0, 2.0, WIDTH))
	_streaks(Vector3(end_cap.global_position.x + break_side * (end_cap.size.z * 0.5 + 1.2), maze._floor_top_y + 0.5, outgoing_z),
		Vector3(-break_side, -0.35, 0).normalized())
	var box7 := maze.get_node("CSGBox3D7") as CSGBox3D
	var closer := maze.get_node("Wall10Closer") as CSGBox3D
	var west := box7.global_position.x + box7.size.z * 0.5
	var east := end_cap.global_position.x + end_cap.size.z * 0.5
	if east > west:
		maze._spawn_barrier("DraftNorthBarrier", Vector3((west + east) * 0.5, 0, closer.global_position.z), Vector3(east - west, 0, end_cap.size.z))
	var targets := maze._walls_10_11_targets()
	var wall11 := maze.get_node("CSGBox3D11") as CSGBox3D
	var wall10_target: Vector3 = targets[1][1]
	var wall11_target: Vector3 = targets[0][1]
	return_x = wall11_target.x - wall11.size.x * 0.5 + 6.0
	return_z = wall11_target.z
	return_side = -signf(wall10_target.z - wall11_target.z)
	return_visuals.append(_slot_visual(Vector3(return_x, maze._floor_top_y, return_z), Vector3(WIDTH, 2.0, wall11.size.z + REACH * 2.0)))
	return_visuals.append(_streaks(Vector3(return_x, maze._floor_top_y + 0.5, return_z + return_side * (wall11.size.z * 0.5 + 1.2)),
		Vector3(0, -0.35, -return_side).normalized()))
	_show_return(false)

func _slot_visual(at: Vector3, size: Vector3) -> MeshInstance3D:
	var pit := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	pit.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.06, 0.11)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	pit.material_override = mat
	add_child(pit)
	pit.global_position = at - Vector3.UP
	return pit

func _streaks(at: Vector3, direction: Vector3) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 70
	particles.lifetime = 2.0
	particles.preprocess = 2.0
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(0.9, 0.4, WIDTH * 0.45) if absf(direction.x) > 0.1 else Vector3(WIDTH * 0.45, 0.4, 0.9)
	process.direction = direction
	process.spread = 4.0
	process.initial_velocity_min = 2.0
	process.initial_velocity_max = 3.0
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	var fade := Gradient.new()
	fade.set_color(0, Color(0.75, 0.95, 1.0, 0.0))
	fade.set_color(1, Color(0.75, 0.95, 1.0, 0.0))
	fade.add_point(0.15, Color(0.75, 0.95, 1.0, 0.8))
	fade.add_point(0.8, Color(0.6, 0.85, 1.0, 0.55))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	var streak := BoxMesh.new()
	streak.size = Vector3(0.03, 0.5, 0.03)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	streak.material = mat
	particles.draw_pass_1 = streak
	particles.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 4, 16))
	add_child(particles)
	particles.global_position = at
	return particles

func modal_open() -> bool:
	return busy or is_instance_valid(prompt)

func outgoing_in_reach() -> bool:
	if maze == null or not maze.maze_active or maze._diver == null:
		return false
	var p := maze._diver.global_position
	var off := p.x - end_cap.global_position.x
	return signf(off) == break_side and absf(off) <= end_cap.size.z * 0.5 + REACH + 1.2 \
		and absf(p.z - outgoing_z) <= WIDTH * 0.5 + 1.0 \
		and p.y >= maze._floor_top_y and p.y <= maze._floor_top_y + 4.0

func update() -> void:
	var open := maze._walls_10_11_swung and not maze._wall_set_moving("CSGBox3D10/11")
	_show_return(open)
	# The dark marker suggests a slot, but must not visually bury the actor
	# while the bounded floor tunnel is open. Keep the authored water streaks.
	outgoing_slot.visible = not busy
	(return_visuals[0] as MeshInstance3D).visible = open and not busy
	if not outgoing_in_reach():
		latched = false
	var map := maze.get_node("HUD/MazeMiniMap") as MazeMiniMap
	if busy or maze._battling or maze.any_modal_open() or maze._chest_reward_pending \
		or maze._gate_cutscene or not maze._moving_wall_sets.is_empty() \
		or (map.main_map != null and map.main_map.visible) \
		or (maze.target_selector != null and maze.target_selector.selecting):
		return
	if outgoing_in_reach() and not latched:
		open_outgoing_prompt()
		return
	var p := maze._diver.global_position
	var wall := maze.get_node("CSGBox3D11") as CSGBox3D
	var off := p.z - return_z
	var incoming := open and signf(off) == return_side and absf(off) <= wall.size.z * 0.5 + REACH \
		and absf(p.x - return_x) <= WIDTH * 0.5 and p.y >= maze._floor_top_y and p.y <= maze._floor_top_y + 4.0
	if not incoming:
		return_latched = false
	if incoming and not return_latched:
		# A blocked exit must not run hundreds of shape queries and repeat
		# its warning every frame. Leaving/reapproaching permits a new try.
		return_latched = true
		var exit_axis := Vector3(0, 0, -return_side)
		var near := Vector3(return_x, maze._floor_top_y - 0.4, return_z + return_side * (wall.size.z * 0.5 + 0.6))
		var far := Vector3(return_x, near.y, return_z - return_side * (wall.size.z * 0.5 + 0.6))
		_start_passage(near, far, Vector3(return_x, p.y, return_z - return_side * (wall.size.z * 0.5 + REACH + 0.8)), wall, exit_axis)

func _show_return(on: bool) -> void:
	for node in return_visuals:
		node.visible = on
		if node is GPUParticles3D:
			(node as GPUParticles3D).emitting = on

func open_outgoing_prompt() -> void:
	if not outgoing_in_reach() or modal_open() or maze.any_modal_open():
		return
	latched = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	maze._mouse_look = false
	maze._diver.velocity = Vector3.ZERO
	prompt = ConfirmPromptModal.new("A draft leads under the wall. Explore the other side?")
	prompt.answered.connect(func(yes: bool) -> void:
		prompt = null
		if yes and outgoing_in_reach():
			var p := maze._diver.global_position
			var x := end_cap.global_position.x
			var t := end_cap.size.z
			var low := maze._floor_top_y - 0.4
			_start_passage(Vector3(x + break_side * (t * 0.5 + 0.6), low, outgoing_z),
				Vector3(x - break_side * (t * 0.5 + 0.6), low, outgoing_z),
				Vector3(x - break_side * (t * 0.5 + REACH + 0.8), p.y, outgoing_z), end_cap, Vector3(-break_side, 0, 0)))
	add_child(prompt)

func _clear_exit(d: Diver, preferred: Vector3, wall: CSGBox3D, axis: Vector3) -> Variant:
	var shape: CollisionShape3D
	for child in d.get_children():
		if child is CollisionShape3D:
			shape = child
			break
	if shape == null:
		return null
	preferred.y = maxf(preferred.y, maze._floor_top_y + (shape.shape as CapsuleShape3D).height * 0.5 + 0.08)
	var space := get_world_3d().direct_space_state
	for ring in range(21):
		for k in range(24):
			var at := preferred + Vector3.FORWARD.rotated(Vector3.UP, TAU * k / 24.0) * ring * 0.25
			if (at - wall.global_position).dot(axis) < wall.size.z * 0.5 + d.radius + 0.05:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape.shape
			query.transform = Transform3D(Basis.IDENTITY, at) * shape.transform
			query.collision_mask = d.collision_mask
			query.exclude = [d.get_rid()]
			var capsule := shape.shape as CapsuleShape3D
			if not _inside_solid_wall(query.transform.origin, capsule) and space.intersect_shape(query, 1).is_empty():
				return at
	return null

func _inside_solid_wall(center: Vector3, capsule: CapsuleShape3D) -> bool:
	# CSG collision consists of triangle surfaces, so intersect_shape alone
	# accepts a capsule fully buried in an opaque wall. All authored boxes
	# are upright (yaw rotations); test the vertical capsule against their
	# solid volume as well, with rounded corners rather than a padded AABB.
	var segment_half := capsule.height * 0.5 - capsule.radius
	for wall in maze.wall_boxes:
		if not is_instance_valid(wall) or not wall.visible or not wall.use_collision:
			continue
		var local: Vector3 = wall.global_transform.affine_inverse() * center
		var half: Vector3 = wall.size * 0.5
		var gap := Vector3(maxf(absf(local.x) - half.x, 0.0),
			maxf(absf(local.y) - half.y - segment_half, 0.0), maxf(absf(local.z) - half.z, 0.0))
		if gap.length_squared() < capsule.radius * capsule.radius:
			return true
	return false

func _start_passage(near: Vector3, far: Vector3, preferred: Vector3, wall: CSGBox3D, axis: Vector3) -> void:
	actor = maze._diver
	var destination: Variant = _clear_exit(actor, preferred, wall, axis)
	if destination == null:
		actor = null
		maze._announce("The passage exit is blocked. Move the walls, then try again.")
		return
	busy = true
	departure = actor.global_position
	# The upstream visual slot alone does not cut the global invisible floor.
	# Open only this actor's bounded tunnel while its motion owns all input;
	# retain solid floor everywhere else and seal it once the clear exit is
	# reached. A declined prompt never opens a manual-sinking escape hole.
	var capsule := (actor.get_children().filter(func(n: Node) -> bool: return n is CollisionShape3D)[0] as CollisionShape3D).shape as CapsuleShape3D
	# Wall skirts intentionally fill the normal wall-to-floor clearance.
	# The authored passage must travel below those too, not clip through them.
	var bottom := minf(maze._floor_top_y, wall.global_position.y - wall.size.y * 0.5)
	var skirt := wall.get_node_or_null("Skirt") as StaticBody3D
	if skirt != null:
		for child in skirt.get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				var skirt_shape := child as CollisionShape3D
				bottom = minf(bottom, skirt_shape.global_position.y - (skirt_shape.shape as BoxShape3D).size.y * 0.5)
	var low := minf(near.y, bottom - capsule.height * 0.5 - 0.12)
	near.y = low
	far.y = low
	_open_floor_tunnel([actor.global_position, near, far, destination as Vector3], capsule.radius + 0.12)
	actor.velocity = Vector3.ZERO
	actor.set_suction_locked(true)
	actor.tree_exiting.connect(cancel, CONNECT_ONE_SHOT)
	motion = create_tween()
	motion.tween_property(actor, "global_position", near, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	motion.tween_property(actor, "global_position", far, 0.5)
	motion.tween_property(actor, "global_position", destination, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motion.tween_callback(_release)

func _release() -> void:
	_seal_floor()
	if is_instance_valid(actor):
		if actor.tree_exiting.is_connected(cancel):
			actor.tree_exiting.disconnect(cancel)
		actor.set_suction_locked(false)
		actor.velocity = Vector3.ZERO
	actor = null
	busy = false

func cancel() -> void:
	if motion != null and motion.is_valid():
		motion.kill()
	# Embedded actors belong to World and may outlive this transient owner.
	# Restore the known clear approach before sealing the floor; unlocking
	# an actor midway through the tunnel would bury it in the restored slab.
	if busy and is_instance_valid(actor) and actor.is_inside_tree():
		actor.global_position = departure
	_release()
	if is_instance_valid(prompt):
		prompt.queue_free()
	prompt = null

func _exit_tree() -> void:
	cancel()

func _open_floor_tunnel(points: Array, padding: float) -> void:
	var low: Vector3 = points[0]
	var high := low
	for point: Vector3 in points:
		low = low.min(point)
		high = high.max(point)
	var hole := Rect2(Vector2(low.x - padding, low.z - padding),
		Vector2(high.x - low.x + padding * 2, high.z - low.z + padding * 2))
	var full := floor_shape.shape as BoxShape3D
	var center := floor_shape.global_position
	var base := Rect2(center.x - full.size.x * 0.5, center.z - full.size.z * 0.5, full.size.x, full.size.z)
	hole = hole.intersection(base)
	for region in [
		Rect2(base.position, Vector2(hole.position.x - base.position.x, base.size.y)),
		Rect2(Vector2(hole.end.x, base.position.y), Vector2(base.end.x - hole.end.x, base.size.y)),
		Rect2(Vector2(hole.position.x, base.position.y), Vector2(hole.size.x, hole.position.y - base.position.y)),
		Rect2(Vector2(hole.position.x, hole.end.y), Vector2(hole.size.x, base.end.y - hole.end.y)),
	]:
		if region.size.x <= 0.001 or region.size.y <= 0.001:
			continue
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(region.size.x, full.size.y, region.size.y)
		shape.shape = box
		body.add_child(shape)
		add_child(body)
		body.global_position = Vector3(region.get_center().x, center.y, region.get_center().y)
		floor_pieces.append(body)
	floor_shape.set_deferred("disabled", true)

func _seal_floor() -> void:
	if is_instance_valid(floor_shape):
		floor_shape.set_deferred("disabled", false)
	for body in floor_pieces:
		if is_instance_valid(body):
			body.queue_free()
	floor_pieces.clear()
