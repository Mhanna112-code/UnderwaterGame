# A reusable, item-keyed version of Glassgoat's delivered Door FBX.
#
# This is intentionally NOT `Door` in door.gd.  Door is the existing
# lock-plate puzzle's procedural blocker and must remain that self-contained
# mechanic.  KeyDoor is a separate world object which uses the delivered
# shape-key asset, has a player-facing key requirement, and can be placed by
# the maze or a later main-scene route without either place knowing its art
# import or animation details.
class_name KeyDoor
extends StaticBody3D

signal door_opened(door_id: String)

const DOOR_SCENE := preload("res://game/Door.fbx")

# A stable identity is deliberately separate from the required item: several
# distinct doors may use the same key, while a save must remember each one.
@export var door_id := ""
@export var required_key_id := "current_pearl"
@export var prompt_override := ""
@export_range(0.1, 8.0, 0.05) var opening_duration := 1.2
@export var shape_key_name: StringName = &"Open"
@export_range(0.0, 1.0, 0.01) var open_value := 1.0
# The supplied FBX is in a very small Blender unit scale.  Its actual model
# bounds, not a guessed magic scale, determine the rest of this component's
# size.  A level can choose a different visual height per placement.
@export_range(0.5, 12.0, 0.1) var visual_height := 3.2
@export_range(0.6, 8.0, 0.1) var interaction_radius := 3.0
# Keep collision until the authored morphology is plainly moving out of the
# passage.  This threshold is part of the public gameplay contract and is
# covered by verify/key_door.gd.
@export_range(0.0, 1.0, 0.05) var collision_release_progress := 0.8

var _door_frame: MeshInstance3D
var _shape_index := -1
var _collision: CollisionShape3D
var _prompt: Label3D
var _world: World
var _opened := false
var _opening := false
var _open_progress := 0.0:
	set(value):
		_open_progress = clampf(value, 0.0, 1.0)
		_apply_open_progress()

func _ready() -> void:
	add_to_group("key_door")
	_world = _find_world()
	_build_art_and_collision()
	_build_prompt()
	if _world != null and not door_id.is_empty() and _world.is_key_door_open(door_id):
		restore_open_state()

func _process(_delta: float) -> void:
	if _prompt == null or _opened:
		return
	var active_diver := _active_world_diver()
	_prompt.visible = active_diver != null and is_in_range(active_diver)
	if _prompt.visible:
		_prompt.text = interaction_prompt(active_diver)

# Called by World before it dispatches E to the active diver's ability.
# Returns true only when the door actually owns this key press (missing-key
# feedback counts as owning it, so E cannot both complain and fire an ability).
func interact(actor: Diver) -> bool:
	if _opened or _opening or not is_in_range(actor):
		return false
	var keys: Array[String] = []
	if actor.world != null:
		keys = actor.world.key_items
	if not keys.has(required_key_id):
		_show_missing_key()
		return true
	_begin_open()
	return true

func is_in_range(actor: Diver) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	return actor.global_position.distance_to(global_position) <= interaction_radius

func is_open() -> bool:
	return _opened

func is_collision_blocking() -> bool:
	return _collision != null and not _collision.disabled

func open_progress() -> float:
	return _open_progress

func interaction_prompt(actor: Diver) -> String:
	if _opened:
		return ""
	return _nearby_prompt(actor)

# Save restoration is intentionally instantaneous: a saved route should not
# put a newly reloaded player in front of a visually closed but logically open
# checkpoint while an animation catches up.
func restore_open_state() -> void:
	_opened = true
	_opening = false
	_open_progress = 1.0
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _prompt != null:
		_prompt.visible = false

func _begin_open() -> void:
	if _opened or _opening:
		return
	_opened = true
	_opening = true
	if _world != null and not door_id.is_empty():
		_world.mark_key_door_open(door_id)
	if _prompt != null:
		_prompt.text = "Unlocking…"
		_prompt.visible = true
	var tw := create_tween()
	tw.tween_property(self, "_open_progress", 1.0, opening_duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_finish_open)
	door_opened.emit(door_id)

func _finish_open() -> void:
	_opening = false
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _prompt != null:
		_prompt.visible = false

func _apply_open_progress() -> void:
	if _door_frame != null and _shape_index >= 0:
		_door_frame.set_blend_shape_value(_shape_index, lerpf(0.0, open_value, _open_progress))
	if _collision != null and _open_progress >= collision_release_progress:
		_collision.set_deferred("disabled", true)

func _build_art_and_collision() -> void:
	var art := DOOR_SCENE.instantiate() as Node3D
	if art == null:
		push_error("KeyDoor: Door.fbx did not instantiate as Node3D")
		return
	add_child(art)
	_door_frame = _find_shape_mesh(art, shape_key_name)
	if _door_frame == null:
		push_error("KeyDoor: Door.fbx is missing required shape key '%s'" % shape_key_name)
		return
	_shape_index = _blend_shape_index(_door_frame.mesh, shape_key_name)
	var raw_bounds := _subtree_bounds(art)
	if raw_bounds.size.y <= 0.0001:
		push_error("KeyDoor: Door.fbx has no usable vertical visual bounds")
		return
	var scale_factor := visual_height / raw_bounds.size.y
	art.scale = Vector3.ONE * scale_factor
	# The imported FBX is centred vertically around its own origin.  A level
	# placement, however, is a world-floor placement: `KeyDoor.position.y`
	# must mean "this door rests here," not "bury half the door below here."
	# Apply the same derived grounding offset to art and physics so they never
	# disagree about where the visible doorway begins.
	var floor_offset := Vector3(0.0, -raw_bounds.position.y * scale_factor, 0.0)
	art.position = floor_offset

	_collision = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(0.2, raw_bounds.size.x * scale_factor),
		maxf(0.2, raw_bounds.size.y * scale_factor),
		maxf(0.2, raw_bounds.size.z * scale_factor))
	_collision.shape = box
	_collision.position = floor_offset + raw_bounds.get_center() * scale_factor
	add_child(_collision)

func _build_prompt() -> void:
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.pixel_size = 0.006
	_prompt.font_size = 48
	_prompt.outline_size = 8
	_prompt.modulate = Color(0.65, 0.95, 1.0)
	_prompt.visible = false
	_prompt.no_depth_test = true
	_prompt.position = Vector3(0.0, visual_height + 0.55, 0.0)
	add_child(_prompt)

func _nearby_prompt(actor: Diver) -> String:
	if actor.world != null and actor.world.key_items.has(required_key_id):
		return "E: Unlock door"
	return "Requires %s · E" % _key_display_name()

func _show_missing_key() -> void:
	var text := prompt_override if not prompt_override.is_empty() else "Requires %s." % _key_display_name()
	if _prompt != null:
		_prompt.text = text
		_prompt.visible = true
	if _world != null:
		_world._announce(text)

func _key_display_name() -> String:
	return String(Items.ITEMS.get(required_key_id, {}).get("display", required_key_id))

func _active_world_diver() -> Diver:
	if _world == null or _world.active < 0 or _world.active >= _world.divers.size():
		return null
	var candidate: Variant = _world.divers[_world.active]
	return candidate as Diver if candidate is Diver else null

func _find_world() -> World:
	var candidate: Node = get_parent()
	while candidate != null:
		if candidate is World:
			return candidate as World
		candidate = candidate.get_parent()
	return null

func _find_shape_mesh(node: Node, wanted: StringName) -> MeshInstance3D:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh != null and _blend_shape_index(mesh_node.mesh, wanted) >= 0:
			return mesh_node
	for child in node.get_children():
		var found := _find_shape_mesh(child, wanted)
		if found != null:
			return found
	return null

func _blend_shape_index(mesh: Mesh, wanted: StringName) -> int:
	for i in range(mesh.get_blend_shape_count()):
		if mesh.get_blend_shape_name(i) == wanted:
			return i
	return -1

func _subtree_bounds(root_node: Node3D) -> AABB:
	var pieces: Array[AABB] = []
	_all_mesh_bounds(root_node, Transform3D.IDENTITY, pieces)
	if pieces.is_empty():
		return AABB()
	var bounds := pieces[0]
	for i in range(1, pieces.size()):
		bounds = bounds.merge(pieces[i])
	return bounds

func _all_mesh_bounds(node: Node, inherited: Transform3D, result: Array[AABB]) -> void:
	var next := inherited
	if node is Node3D:
		next = inherited * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result.append(_transform_aabb((node as MeshInstance3D).mesh.get_aabb(), next))
	for child in node.get_children():
		_all_mesh_bounds(child, next, result)

func _transform_aabb(box: AABB, transform: Transform3D) -> AABB:
	var corners := [
		box.position,
		box.position + Vector3(box.size.x, 0.0, 0.0),
		box.position + Vector3(0.0, box.size.y, 0.0),
		box.position + Vector3(0.0, 0.0, box.size.z),
		box.position + Vector3(box.size.x, box.size.y, 0.0),
		box.position + Vector3(box.size.x, 0.0, box.size.z),
		box.position + Vector3(0.0, box.size.y, box.size.z),
		box.end,
	]
	var transformed := AABB(transform * corners[0], Vector3.ZERO)
	for i in range(1, corners.size()):
		transformed = transformed.expand(transform * corners[i])
	return transformed
