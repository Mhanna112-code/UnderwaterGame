# Reusable target selection: candidates, current pick, cycling, confirm/cancel.
# Camera moves are delegated to the host's focus_camera_on()/return_camera_to_player().
class_name TargetSelector
extends Node

signal confirmed(target: Node3D)
signal cancelled

# World in the main game; MazeLevel in the maze. Anything with
# focus_camera_on(target) and return_camera_to_player().
var world: Node

# Full roster; candidates are recomputed per selection in _refresh_targets().
var selectable_characters: Array[Node3D] = []

var selecting := false

var cursor: MeshInstance3D
var _cursor_mat: StandardMaterial3D

var _targets: Array[Node3D] = []
var _selected_index := 0
var _requester: Node3D

func register_character(character: Node3D) -> void:
	if character.can_be_selected:
		selectable_characters.append(character)

# Unused for now; kept for when a character can leave the roster.
func unregister_character(character: Node3D) -> void:
	selectable_characters.erase(character)

# The requester can't target itself. Returns false if nobody is valid.
func start_selection(requester: Node3D = null) -> bool:
	_requester = requester
	_refresh_targets()
	if _targets.is_empty():
		return false
	selecting = true
	_selected_index = 0
	_show_cursor()
	_apply_selection()
	return true

func _refresh_targets() -> void:
	_targets = []
	for c in selectable_characters:
		if is_instance_valid(c) and c != _requester and c.can_be_selected:
			_targets.append(c)

func select_next() -> void:
	if not selecting or _targets.is_empty():
		return
	_selected_index = (_selected_index + 1) % _targets.size()
	_apply_selection()

func select_previous() -> void:
	if not selecting or _targets.is_empty():
		return
	_selected_index = (_selected_index - 1 + _targets.size()) % _targets.size()
	_apply_selection()

func current_target() -> Node3D:
	if not selecting or _targets.is_empty():
		return null
	return _targets[_selected_index]

func confirm_selection() -> void:
	if not selecting:
		return
	var target := current_target()
	_end_selection()
	if target != null:
		confirmed.emit(target)

func cancel_selection() -> void:
	if not selecting:
		return
	_end_selection()
	cancelled.emit()

func _end_selection() -> void:
	selecting = false
	_hide_cursor()
	if world != null:
		world.return_camera_to_player()

# Moves the cursor and camera together so they stay in sync.
func _apply_selection() -> void:
	var target := current_target()
	if target == null:
		return
	if world != null:
		world.focus_camera_on(target)

# Refreshed every frame so the cursor follows a moving target.
func _process(_dt: float) -> void:
	if not selecting or cursor == null:
		return
	var target := current_target()
	if target == null or not is_instance_valid(target):
		return
	var lift := 2.5
	if target is Diver:
		lift = (target as Diver).height * 0.5 + 0.5   # origin is mid-body
	cursor.visible = true
	cursor.global_position = target.global_position + Vector3.UP * lift

func _show_cursor() -> void:
	if cursor != null:
		cursor.visible = true
		return
	# Downward cone built in code, like the other ability VFX.
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.28
	cone.height = 0.5
	cursor = MeshInstance3D.new()
	cursor.mesh = cone
	_cursor_mat = StandardMaterial3D.new()
	_cursor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cursor_mat.emission_enabled = true
	_cursor_mat.albedo_color = Color(0.35, 0.95, 0.4)
	_cursor_mat.emission = Color(0.35, 0.95, 0.4)
	cursor.material_override = _cursor_mat
	cursor.rotation_degrees.x = 180.0   # cone points down at the target
	add_child(cursor)

func _hide_cursor() -> void:
	if cursor != null:
		cursor.visible = false
