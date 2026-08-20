# Owns exactly one job: who can be targeted right now, who's currently
# picked, and cycling between them - kept separate from the ability
# itself (which only cares about the eventual confirmed/cancelled result)
# and from the camera (which just gets told where to look, via
# world.focus_camera_on()/return_camera_to_player()). That separation is
# what lets a second targeted ability later reuse this whole
# select/cycle/confirm/cancel flow instead of duplicating it.
#
# Adapted from a from-scratch Game/CameraController/TargetSelector
# proposal to this project's actual shape: characters are Diver instances
# built with .new() (no .tscn scenes anywhere in this project), and there's
# one camera already owned by world.gd rather than a separate controller
# node - see world.gd's focus_camera_on()/return_camera_to_player() for
# where "tell the camera where to go" actually lives.
class_name TargetSelector
extends Node

signal confirmed(target: Node3D)
signal cancelled

var world: World

# The full roster - every character that could ever be a target for some
# ability, not just "current candidates for the ability in progress."
# register_character()/unregister_character() maintain this; a given
# selection's actual candidate list is computed fresh in
# _refresh_targets() each time selection starts, since who's *valid*
# depends on who's asking (a requester can't target themselves) and could
# later depend on the ability itself (allies-only, enemies-only, etc.).
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

# Not called anywhere yet - nothing in this game removes a diver - but
# kept available for when something does (a diver knocked out, a
# character leaving the roster), same as the original proposal flagged.
func unregister_character(character: Node3D) -> void:
	selectable_characters.erase(character)

# requester is excluded from its own candidate list - an ability that
# targets "another character" shouldn't be able to pick the caster.
# Returns false (and does nothing else) if there's nobody valid to pick.
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

# Moves the cursor and points the camera at whichever candidate is now
# selected - both happen from this one place so cycling always keeps
# them in sync.
func _apply_selection() -> void:
	var target := current_target()
	if target == null:
		return
	if world != null:
		world.focus_camera_on(target)

# Cursor position is refreshed every frame the selected target is valid,
# not just when the selection changes - if the target ever moves again
# (this game currently holds non-active divers still, but nothing here
# should assume that stays true forever), the cursor keeps following.
func _process(_dt: float) -> void:
	if not selecting or cursor == null:
		return
	var target := current_target()
	if target == null or not is_instance_valid(target):
		return
	var lift := 2.5
	if target is Diver:
		lift = (target as Diver).height + 0.6
	cursor.visible = true
	cursor.global_position = target.global_position + Vector3.UP * lift

func _show_cursor() -> void:
	if cursor != null:
		cursor.visible = true
		return
	# A downward-pointing cone, built the same way as this project's other
	# throwaway ability VFX (see diver.gd's _shockwave_vfx()) rather than
	# a separate TargetCursor.tscn - nothing in this project uses .tscn
	# files for dynamically-created objects, so a cursor scene would be
	# the only exception rather than following the established pattern.
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
