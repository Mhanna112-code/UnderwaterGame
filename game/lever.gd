# Switch a diver pulls by swimming up and pressing E.
# Only reports the pull (`pulled`, `is_up`); the owning scene decides what it does.
class_name Lever
extends Area3D

signal pulled(is_up: bool)

@export var is_up := true
# false: the owning scene calls pull() itself; E is ignored.
@export var handles_input := true
# false: the handle stays green (state is shown elsewhere).
@export var color_by_state := true

var _handle: MeshInstance3D
var _handle_mat: StandardMaterial3D
var _diver_in_range: Diver = null

func _ready() -> void:
	# Divers are on collision layer 2.
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.32
	base_mesh.bottom_radius = 0.42
	base_mesh.height = 0.5
	base.mesh = base_mesh
	base.position.y = 0.25
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.2, 0.22, 0.24)
	base_mat.roughness = 0.85
	base.material_override = base_mat
	add_child(base)

	# Pivot at the base's top so the handle swings on a hinge.
	var pivot := Node3D.new()
	pivot.position.y = 0.5
	base.add_child(pivot)

	_handle = MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.045
	handle_mesh.bottom_radius = 0.065
	handle_mesh.height = 0.8
	_handle.mesh = handle_mesh
	_handle.position.y = 0.4   # extends up from the pivot
	_handle_mat = StandardMaterial3D.new()
	_handle_mat.emission_enabled = true
	_handle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_handle.material_override = _handle_mat
	pivot.add_child(_handle)
	pivot.rotation_degrees.z = -35.0 if is_up else 35.0
	_refresh_color()

	var shape := CollisionShape3D.new()
	var col := CylinderShape3D.new()
	col.radius = 1.1
	col.height = 2.2
	shape.shape = col
	add_child(shape)

func _on_body_entered(body: Node3D) -> void:
	if body is Diver:
		_diver_in_range = body as Diver

func _on_body_exited(body: Node3D) -> void:
	if body == _diver_in_range:
		_diver_in_range = null

func _unhandled_input(event: InputEvent) -> void:
	if not handles_input or _diver_in_range == null or not is_instance_valid(_diver_in_range):
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_E:
		# Consume E so it doesn't also fire the diver's ability.
		get_viewport().set_input_as_handled()
		pull()

func pull() -> void:
	is_up = not is_up
	var pivot := _handle.get_parent() as Node3D
	var target_z := -35.0 if is_up else 35.0
	var tw := create_tween()
	tw.tween_property(pivot, "rotation_degrees:z", target_z, 0.3)
	_refresh_color()
	pulled.emit(is_up)

func _refresh_color() -> void:
	var c: Color = Color(0.35, 0.95, 0.5) if is_up or not color_by_state else Color(0.9, 0.35, 0.3)
	_handle_mat.albedo_color = c
	_handle_mat.emission = c
	_handle_mat.emission_energy_multiplier = 1.3
