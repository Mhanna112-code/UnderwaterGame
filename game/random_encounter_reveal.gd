# Transient enemies in the real exploration World3D. No encounter stats,
# rewards, collision bodies or independent roster roll live here.
class_name RandomEncounterReveal
extends Node3D

signal finished
const DURATION := 1.5
var enemy_ids: Array[String] = []
var camera: Camera3D
var actors: Array[Goblin] = []
var _elapsed := 0.0
var _starts: Array[Vector3] = []
var _travel: Array[float] = []
var _original_camera_transform: Transform3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("random_encounter_reveal")
	_original_camera_transform = camera.global_transform
	_clear_camera_origin()
	for index in range(enemy_ids.size()):
		var actor := Battle.actor_for_enemy_id(enemy_ids[index])
		add_child(actor)
		actors.append(actor)
		# Three-quarter approach exposes the long rigs' body/bill as well as
		# their face; straight-on Shark reads as a small floating head.
		actor.rotation.y = atan2(camera.global_basis.z.x, camera.global_basis.z.z) - 0.6
		_place_actor(actor, index)
		actor.play("swim")
		_starts.append(actor.global_position)
		_travel.append(minf(0.15, actor.scale.x * 0.15))
	print("RANDOM_REVEAL|enemies=", ",".join(enemy_ids), "|duration=", DURATION)

func _process(dt: float) -> void:
	_elapsed += dt
	# A restrained approach makes the reveal read as an interception. Its
	# limited travel stays inside the clearance measured before animation.
	for index in range(actors.size()):
		actors[index].global_position = _starts[index] + camera.global_basis.z * minf(_elapsed / DURATION, 1.0) * _travel[index]
	if _elapsed >= DURATION:
		set_process(false)
		finished.emit()

func _place_actor(actor: Goblin, index: int) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	var count := enemy_ids.size()
	var cell := Rect2(Vector2(size.x * (0.11 + float(index) * 0.78 / count), size.y * 0.25), Vector2(size.x * 0.78 / count, size.y * 0.25))
	var pixel := cell.get_center()
	# Match the real mesh to its screen cell, not a guessed generic radius.
	# If nearby scenery blocks the lane, move toward the camera and reduce
	# world scale proportionally. This preserves screen readability without
	# putting a long Shark through the floor/wall or changing combat assets.
	for depth in [9.0, 7.0, 5.0, 3.0, 1.6, 0.85, 0.4, 0.2]:
		actor.scale = Vector3.ONE * minf(1.0, depth / 9.0)
		_center_actor(actor, camera.project_position(pixel, depth))
		for attempt in range(12):
			if _fits_cell(actor, cell):
				break
			actor.scale *= 0.84
			_center_actor(actor, camera.project_position(pixel, depth))
		if _clear_of_environment(actor):
			return
	# Even a camera almost touching terrain needs a foreground interception.
	# Keep shrinking rather than ignoring collision clearance or adding a ring.
	for attempt in range(12):
		actor.scale *= 0.75
		_center_actor(actor, camera.project_position(pixel, 0.2))
		if _clear_of_environment(actor):
			return

func _center_actor(actor: Goblin, target: Vector3) -> void:
	actor.global_position += target - actor.visual_bounds().get_center()

func _fits_cell(actor: Goblin, cell: Rect2) -> bool:
	var bounds := actor.visual_bounds()
	for corner in range(8):
		var point := bounds.get_endpoint(corner)
		if not camera.is_position_in_frustum(point) or not cell.has_point(camera.unproject_position(point)):
			return false
	return true

func _clear_of_environment(actor: Goblin) -> bool:
	var bounds := actor.visual_bounds().grow(minf(0.15, actor.scale.x * 0.15) + 0.03)
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, bounds.get_center())
	query.collision_mask = 1
	query.collide_with_areas = false
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	# Empty volume behind a wall is not a visible reveal. Test the entire
	# silhouette's sight lines as well as the space occupied by the rig.
	for corner in range(9):
		var point := bounds.get_center() if corner == 8 else bounds.get_endpoint(corner)
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position, point, 1)
		if not space.intersect_ray(ray).is_empty():
			return false
	return true

func restore_camera() -> void:
	if is_instance_valid(camera):
		camera.global_transform = _original_camera_transform

func _clear_camera_origin() -> void:
	# World's chase camera does not collide with scenery. A camera actually
	# inside a wall cannot see any world-space silhouette, however small.
	# Nudge only this short reveal to the nearest clear viewpoint, then restore
	# the original on handoff/cancellation; do not rewrite normal camera policy.
	var shape := SphereShape3D.new()
	shape.radius = 0.18
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var origin := camera.global_position
	var offsets := [Vector3.ZERO]
	for distance in [0.4, 0.8, 1.6, 3.2]:
		for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
			offsets.append(direction * distance)
	for offset in offsets:
		query.transform = Transform3D(Basis.IDENTITY, origin + offset)
		if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			camera.global_position = origin + offset
			return
