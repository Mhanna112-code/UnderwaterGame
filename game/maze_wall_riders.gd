extends RefCounted
# Transient passenger ownership only. Party/resources and durable wall state
# remain with World/Maze. A passenger may cross intervening geometry while the
# authored wall swings, but is released only at a capsule-clear landing.
const MARGIN := 0.08
var maze: Node3D
var passengers: Dictionary = {}
var cached_boxes: Array[Dictionary] = []

func _init(owner_maze: Node3D) -> void:
	maze = owner_maze

func busy() -> bool:
	return not passengers.is_empty()

func owns(actor: Diver) -> bool:
	return passengers.has(actor)

func detach_in_place(actor: Diver, wall: CSGBox3D) -> void:
	if owns(actor) and passengers[actor].wall == wall:
		_release(actor) # C5 exemption applies even to an arriving passenger.

func capture(actor: Diver, wall: CSGBox3D, offset: Vector3, destination: Transform3D) -> bool:
	if owns(actor) or actor.is_grappling() or actor.is_suction_locked():
		return false # Never steal a grapple/whirlpool's motion ownership.
	var record := {"wall": wall, "offset": offset, "y": actor.global_position.y,
		"mask": actor.collision_mask, "locked": actor.is_suction_locked(),
		"destination": destination, "pending": false, "wait": 0,
		"entry": maze.entrance_point(), "retry": 0, "warned": false}
	# Cache a verified destination while the physics owner still exists. Its
	# target wall volume is tested explicitly, not at its old physical pose.
	var landing: Variant = _landing(actor, record)
	if landing == null:
		return false
	passengers[actor] = record
	actor.collision_mask = 0
	actor.set_suction_locked(true)
	actor.velocity = Vector3.ZERO
	return true

func carry(actor: Diver, wall: CSGBox3D) -> void:
	if not owns(actor) or passengers[actor].wall != wall or passengers[actor].pending:
		return
	var record: Dictionary = passengers[actor]
	var at: Vector3 = wall.global_transform * (record.offset as Vector3)
	at.y = float(record.y)
	actor.global_position = at
	actor.velocity = Vector3.ZERO

func finish(wall: CSGBox3D) -> void:
	for actor in passengers:
		if passengers[actor].wall == wall:
			passengers[actor].pending = true
			passengers[actor].wait = 2 # Let CSG/attached collider transforms settle.

func update() -> void:
	if busy():
		_geometry() # Include concurrently requested walls before owner teardown.
	for actor in passengers.keys():
		if not is_instance_valid(actor):
			passengers.erase(actor)
			continue
		var record: Dictionary = passengers[actor]
		if not record.pending:
			continue
		if int(record.wait) > 0:
			record.wait = int(record.wait) - 1
			continue
		if int(record.retry) > 0:
			record.retry = int(record.retry) - 1
			continue
		var landing: Variant = _landing(actor, record)
		if landing != null:
			actor.global_position = landing
			_release(actor)
		else:
			# A newly introduced obstruction cannot turn a blocked point into
			# a "successful" release. Retry at a bounded rate, retain save lock.
			record.retry = 15
			if not record.warned:
				record.warned = true
				maze._announce("The wall landing is blocked. Waiting for a clear space.")

func cancel(preserve_positions := false) -> void:
	for actor in passengers.keys():
		if is_instance_valid(actor):
			# World applies loaded party poses before Maze restoration. Never
			# relocate those poses while relinquishing the old motion owner.
			if not preserve_positions and actor.is_inside_tree():
				var record: Dictionary = passengers[actor]
				var landing: Variant = _landing(actor, record)
				if landing == null:
					# Cancellation may need a clear recovery approach if a new
					# obstacle filled the final face. Never reuse a stale point.
					var recovery := record.duplicate()
					recovery.wall = null
					recovery.destination = Transform3D(Basis.IDENTITY, record.entry)
					recovery.offset = Vector3.ZERO
					landing = _landing(actor, recovery)
				if landing == null:
					push_error("Moving-wall cancellation has no clear landing or recovery approach")
					continue # Do not call a buried/ghosted actor a safe release.
				actor.global_position = landing
			_release(actor)
		else:
			passengers.erase(actor)

func _release(actor: Diver) -> void:
	var record: Dictionary = passengers[actor]
	actor.collision_mask = int(record.mask)
	actor.set_suction_locked(bool(record.locked))
	actor.velocity = Vector3.ZERO
	passengers.erase(actor)

func _landing(actor: Diver, record: Dictionary) -> Variant:
	var collision: CollisionShape3D
	for child in actor.get_children():
		if child is CollisionShape3D:
			collision = child
			break
	if collision == null or not collision.shape is CapsuleShape3D:
		return null
	var capsule := collision.shape as CapsuleShape3D
	var xf: Transform3D = record.destination
	var preferred: Vector3 = xf * (record.offset as Vector3)
	preferred.y = maxf(float(record.y), float(maze._floor_top_y) + capsule.height * 0.5 + MARGIN)
	var side := signf((record.offset as Vector3).z)
	var wall := record.wall as CSGBox3D
	# Shared actors still have a physics world after Maze's children exit.
	# Cache target solid volumes while live; do not query off-tree globals.
	var space := actor.get_world_3d().direct_space_state
	var boxes := _geometry()
	for ring in range(41):
		for angle in range(1 if ring == 0 else 24):
			var at := preferred + Vector3.FORWARD.rotated(Vector3.UP, TAU * angle / 24.0) * ring * 0.25
			if is_instance_valid(wall) and (xf.affine_inverse() * at).z * side < wall.size.z * 0.5 + capsule.radius + 0.05:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform = Transform3D(actor.global_basis, at) * collision.transform
			query.collision_mask = int(record.mask)
			query.exclude = [actor.get_rid()]
			if _solid_volume(query.transform.origin, capsule, boxes):
				continue
			var blocked := false
			for hit in space.intersect_shape(query, 32):
				# Moving geometry is validated at its destination below. Ignore
				# stale physics surfaces (and their attached skirts/rocks) only.
				var collider := hit.collider as Node
				var moving := false
				for owner_wall in maze._wall_motion_targets:
					if is_instance_valid(owner_wall) and (collider == owner_wall or owner_wall.is_ancestor_of(collider)):
						moving = true
						break
				if not moving:
					blocked = true
					break
			if not blocked:
				return at
	return null

func _geometry() -> Array[Dictionary]:
	# Child exit precedes Maze._exit_tree; retain previously verified global
	# target geometry rather than reading a removed child's global_transform.
	if maze.wall_boxes.any(func(w: Variant) -> bool: return is_instance_valid(w) and not w.is_inside_tree()):
		return cached_boxes
	var boxes: Array[Dictionary] = []
	for wall in maze.wall_boxes:
		if not is_instance_valid(wall) or not wall.visible or not wall.use_collision:
			continue
		var xf: Transform3D = wall.global_transform
		if maze._wall_motion_targets.has(wall):
			xf = wall.get_parent().global_transform * (maze._wall_motion_targets[wall] as Transform3D)
		boxes.append({"inverse": xf.affine_inverse(), "half": wall.size * 0.5})
		# Skirts and the split rock also move with their wall. Their old
		# physics poses were intentionally ignored; forecast their solid boxes.
		if maze._wall_motion_targets.has(wall):
			for child in wall.find_children("*", "CollisionShape3D", true, false):
				var collision := child as CollisionShape3D
				if collision.disabled or not collision.shape is BoxShape3D:
					continue
				var child_xf: Transform3D = xf * wall.global_transform.affine_inverse() * collision.global_transform
				boxes.append({"inverse": child_xf.affine_inverse(), "half": (collision.shape as BoxShape3D).size * 0.5})
	cached_boxes = boxes
	return boxes

func _solid_volume(center: Vector3, capsule: CapsuleShape3D, boxes: Array[Dictionary]) -> bool:
	# Triangle-only CSG shape queries miss capsules entirely buried in a wall.
	var segment := capsule.height * 0.5 - capsule.radius
	for box in boxes:
		var local: Vector3 = (box.inverse as Transform3D) * center
		var half: Vector3 = box.half
		var gap := Vector3(maxf(absf(local.x) - half.x, 0), maxf(absf(local.y) - half.y - segment, 0), maxf(absf(local.z) - half.z, 0))
		if gap.length_squared() < capsule.radius * capsule.radius:
			return true
	return false
