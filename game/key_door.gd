# A reusable, item-keyed version of Glassgoat's delivered Door FBX.
#
# This is intentionally NOT `Door` in door.gd.  Door is the existing
# lock-plate puzzle's procedural blocker and must remain that self-contained
# mechanic.  KeyDoor is a separate world object which uses the delivered
# shape-key asset, has a player-facing key requirement, and can be placed by
# the maze or a later main-scene route without either place knowing its art
# import or animation details.
#
# Ported from UnderwaterGame PR #93 into the maze project. Maze changes only:
# the model is game/KeyDoor.fbx (PR #93's corrected Door.fbx - the maze's
# older game/Door.fbx stays for its own Door class); with no World above it,
# the save/key bookkeeping is skipped, an empty `required_key_id` means no key
# is needed, `active_diver_source` says which diver is being played, and
# `announce` shows the missing-key text.
class_name KeyDoor
extends StaticBody3D

signal door_opened(door_id: String)

const DOOR_SCENE := preload("res://game/KeyDoor.fbx")

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
# Optional secondary visuals that should disappear once the passage clears.
# Glassgoat's corrected Door keeps its upright wheel visible, so this is empty
# by default; placements can still opt in for a different asset.
@export var hide_when_open_node_names: Array[StringName] = []
# Maze hooks (see the header): who's being played, where to show text, and
# (with no World) the party's key items.
var active_diver_source: Callable
var announce: Callable
var key_source: Callable
# Maze: keys are a plain count and any key opens any door - with these set,
# a door takes one key instead of looking for its own key id.
var key_count_source: Callable
var spend_key: Callable

var _door_frame: MeshInstance3D
var _shape_index := -1
var _hide_when_open_meshes: Array[MeshInstance3D] = []
var _door_inner_panel: MeshInstance3D
var _inner_panel_rest_transform := Transform3D.IDENTITY
var _inner_panel_lift := 0.0
var _collision: CollisionShape3D
var _prompt: Label3D
var _world: Node   # World, when there is one (not in the maze)
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
	if _world != null and not door_id.is_empty() and _world.has_method("is_key_door_open") and _world.is_key_door_open(door_id):
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
	if required_key_id.is_empty():
		_begin_open()
		return true
	if key_count_source.is_valid():
		if int(key_count_source.call()) <= 0:
			_show_missing_key()
			return true
		if spend_key.is_valid():
			spend_key.call()
		_begin_open()
		return true
	var keys: Array = []
	if actor.world != null:
		keys = actor.world.key_items
	elif key_source.is_valid():
		keys = key_source.call()
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
	if _world != null and not door_id.is_empty() and _world.has_method("mark_key_door_open"):
		_world.mark_key_door_open(door_id)
	if _prompt != null:
		_prompt.text = "Opening…" if required_key_id.is_empty() else "Unlocking…"
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
	var doorway_is_clear := _open_progress >= collision_release_progress
	if _door_inner_panel != null and is_instance_valid(_door_inner_panel):
		var lift_progress := clampf(_open_progress / collision_release_progress, 0.0, 1.0)
		var lifted_transform := _inner_panel_rest_transform
		lifted_transform.origin += _inner_panel_rest_transform.basis.y.normalized() * _inner_panel_lift * lift_progress * lift_progress
		_door_inner_panel.transform = lifted_transform
		_door_inner_panel.visible = not doorway_is_clear
	for visual in _hide_when_open_meshes:
		if is_instance_valid(visual):
			visual.visible = not doorway_is_clear
	if _collision != null and doorway_is_clear:
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
	_hide_when_open_meshes = _find_named_meshes(art, hide_when_open_node_names)
	_rebuild_opening_frame(_door_frame)
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
	if required_key_id.is_empty():
		return "E: Open door"
	if key_count_source.is_valid():
		return "E: Unlock door" if int(key_count_source.call()) > 0 else "Press E to interact"
	if actor.world != null and actor.world.key_items.has(required_key_id):
		return "E: Unlock door"
	if actor.world == null and key_source.is_valid() and (key_source.call() as Array).has(required_key_id):
		return "E: Unlock door"
	# Maze: don't give away which key it takes.
	return "Press E to interact"

func _show_missing_key() -> void:
	var text := prompt_override if not prompt_override.is_empty() else "You need something to unlock this door."
	if _prompt != null:
		_prompt.text = text
		_prompt.visible = true
	if _world != null:
		_world._announce(text)
	elif announce.is_valid():
		announce.call(text)

func _key_display_name() -> String:
	return String(Items.ITEMS.get(required_key_id, {}).get("display", required_key_id))

func _active_world_diver() -> Diver:
	if _world == null:
		return active_diver_source.call() as Diver if active_diver_source.is_valid() else null
	if _world.active < 0 or _world.active >= _world.divers.size():
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

func _find_named_meshes(node: Node, wanted_names: Array[StringName]) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	_collect_named_meshes(node, wanted_names, found)
	return found

func _collect_named_meshes(node: Node, wanted_names: Array[StringName], found: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and wanted_names.has(node.name):
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_named_meshes(child, wanted_names, found)

# Glassgoat's corrected asset places the wheel outside the aperture, but the
# authored Open morph still leaves a disconnected central leaf behind. Split
# that leaf from the source mesh at runtime: the outer frame keeps its real
# imported shape-key animation while the leaf rises clear before collision is
# released. This preserves the delivered closed pose and an actual doorway.
func _rebuild_opening_frame(source: MeshInstance3D) -> void:
	if source.mesh == null or source.mesh.get_surface_count() != 1:
		push_error("KeyDoor: expected one-surface Door_Frame mesh")
		return
	var split := _split_door_frame_mesh(source.mesh)
	if split.is_empty():
		push_error("KeyDoor: could not isolate the Door_Frame inner panel")
		return
	var parent_node := source.get_parent()
	if parent_node == null:
		push_error("KeyDoor: Door_Frame has no parent")
		return
	var outer := _make_door_piece(source, split["outer"] as Mesh)
	var inner := _make_door_piece(source, split["inner"] as Mesh)
	parent_node.add_child(outer)
	parent_node.add_child(inner)
	source.visible = false
	_door_frame = outer
	_shape_index = _blend_shape_index(outer.mesh, shape_key_name)
	_door_inner_panel = inner
	_inner_panel_rest_transform = inner.transform
	_inner_panel_lift = source.mesh.get_aabb().size.y * 1.35

func _make_door_piece(source: MeshInstance3D, mesh: Mesh) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.transform = source.transform
	piece.cast_shadow = source.cast_shadow
	piece.gi_mode = source.gi_mode
	return piece

func _split_door_frame_mesh(source_mesh: Mesh) -> Dictionary:
	var base_arrays := source_mesh.surface_get_arrays(0)
	var blend_arrays := source_mesh.surface_get_blend_shape_arrays(0)
	if blend_arrays.is_empty():
		return {}
	var vertices := base_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := base_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var center_panel := _find_center_panel_vertices(vertices, indices)
	if center_panel.is_empty():
		return {}
	var outer_indices := PackedInt32Array()
	var inner_indices := PackedInt32Array()
	for triangle_start in range(0, indices.size(), 3):
		var triangle := PackedInt32Array([indices[triangle_start], indices[triangle_start + 1], indices[triangle_start + 2]])
		if center_panel.has(triangle[0]) and center_panel.has(triangle[1]) and center_panel.has(triangle[2]):
			inner_indices.append_array(triangle)
		else:
			outer_indices.append_array(triangle)
	if inner_indices.is_empty() or outer_indices.is_empty():
		return {}
	var inner_arrays := base_arrays.duplicate(true)
	inner_arrays[Mesh.ARRAY_INDEX] = inner_indices
	var outer_arrays := base_arrays.duplicate(true)
	outer_arrays[Mesh.ARRAY_INDEX] = outer_indices
	var outer_blend_arrays: Array = []
	for blend in blend_arrays:
		var filtered_blend := (blend as Array).duplicate(true)
		# Godot's blend-shape channels carry only vertex/normal/tangent data;
		# they inherit the filtered base surface's index buffer.
		filtered_blend[Mesh.ARRAY_INDEX] = null
		outer_blend_arrays.append(filtered_blend)
	var inner := ArrayMesh.new()
	inner.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, inner_arrays)
	inner.surface_set_material(0, source_mesh.surface_get_material(0))
	var outer := ArrayMesh.new()
	outer.blend_shape_mode = source_mesh.blend_shape_mode
	for index in range(source_mesh.get_blend_shape_count()):
		outer.add_blend_shape(source_mesh.get_blend_shape_name(index))
	outer.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, outer_arrays, outer_blend_arrays)
	outer.surface_set_material(0, source_mesh.surface_get_material(0))
	return {"outer": outer, "inner": inner}

func _find_center_panel_vertices(vertices: PackedVector3Array, indices: PackedInt32Array) -> Dictionary:
	var parent: Array[int] = []
	for vertex in range(vertices.size()):
		parent.append(vertex)
	for triangle_start in range(0, indices.size(), 3):
		_union_vertices(parent, indices[triangle_start], indices[triangle_start + 1])
		_union_vertices(parent, indices[triangle_start], indices[triangle_start + 2])
	var groups: Dictionary = {}
	for vertex in range(vertices.size()):
		var root_index := _find_vertex_root(parent, vertex)
		if not groups.has(root_index):
			groups[root_index] = {}
		(groups[root_index] as Dictionary)[vertex] = true
	var all_bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex in vertices:
		all_bounds = all_bounds.expand(vertex)
	var best: Dictionary = {}
	for group in groups.values():
		var component := group as Dictionary
		var first_vertex := int(component.keys()[0])
		var bounds := AABB(vertices[first_vertex], Vector3.ZERO)
		for vertex_value in component.keys():
			bounds = bounds.expand(vertices[int(vertex_value)])
		var centered := absf(bounds.get_center().x - all_bounds.get_center().x) <= all_bounds.size.x * 0.1
		var tall := bounds.size.y >= all_bounds.size.y * 0.8
		var narrower_than_frame := bounds.size.x <= all_bounds.size.x * 0.75
		if centered and tall and narrower_than_frame and component.size() > best.size():
			best = component
	return best

func _find_vertex_root(parent: Array[int], index: int) -> int:
	if parent[index] != index:
		parent[index] = _find_vertex_root(parent, parent[index])
	return parent[index]

func _union_vertices(parent: Array[int], left: int, right: int) -> void:
	var root_left := _find_vertex_root(parent, left)
	var root_right := _find_vertex_root(parent, right)
	if root_left != root_right:
		parent[root_right] = root_left

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
