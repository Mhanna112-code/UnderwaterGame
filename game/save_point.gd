# Rest spot that makes SavePointMenu reachable. Tracks a list of occupants since divers can overlap.
class_name SavePoint
extends Area3D

var occupants: Array[Diver] = []
var _mat: StandardMaterial3D
var _crystal: MeshInstance3D
var _crystal_material: StandardMaterial3D
var disabled = false
@export var footprint_offset_y := 0.05

func _ready() -> void:
	if not disabled:
		# Divers are on layer 2.
		collision_mask = 2
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

		var crystal := PrismMesh.new()
		crystal.size = Vector3(0.9, 2.0, 0.9)
		var mesh := MeshInstance3D.new()
		mesh.mesh = crystal
		mesh.position.y = 1.0
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(0.3, 0.75, 0.95)
		_mat.emission_enabled = true
		_mat.emission = Color(0.3, 0.75, 0.95)
		_mat.emission_energy_multiplier = 1.4
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		# Fade the decorative crystal near the camera so it can't hide the diver.
		_crystal = mesh
		_crystal_material = _mat.duplicate() as StandardMaterial3D
		_crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = _crystal_material
		add_child(mesh)

		var ring := TorusMesh.new()
		ring.inner_radius = 1.1
		ring.outer_radius = 1.4
		var ring_mesh := MeshInstance3D.new()
		ring_mesh.mesh = ring
		# Lay the torus flat so its edge doesn't hide the diver.
		ring_mesh.position.y = footprint_offset_y
		ring_mesh.material_override = _mat
		add_child(ring_mesh)

		var shape := CollisionShape3D.new()
		var col := CylinderShape3D.new()
		col.radius = 1.6
		col.height = 3.0
		shape.shape = col
		add_child(shape)

		var tw := create_tween().set_loops()
		tw.tween_property(mesh, "rotation:y", TAU, 6.0).from(0.0)

		# Floating sign above the crystal: a title and a smaller subtitle.
		add_child(_sign_label("SavePointTitle", "Save Point", 64, Color(0.75, 0.95, 1.0), 2.75))
		add_child(_sign_label("SavePointSubtitle", "Restore your party", 40, Color(0.6, 0.85, 0.95), 2.35))

func _sign_label(label_name: String, text: String, font_size: int, color: Color, height: float) -> Label3D:
	var label := Label3D.new()
	label.name = label_name
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.008
	label.modulate = color
	label.outline_size = 10
	label.outline_modulate = Color(0.0, 0.05, 0.1, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = Vector3(0.0, height, 0.0)
	return label

func _process(_delta: float) -> void:
	if not is_instance_valid(_crystal):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Explicit opacity also works in the Compatibility/web renderer.
	var distance := camera.global_position.distance_to(_crystal.global_position)
	var opacity := clampf((distance - 5.0) / 3.0, 0.0, 1.0)
	_crystal.visible = opacity > 0.01
	var color := _crystal_material.albedo_color
	color.a = opacity
	_crystal_material.albedo_color = color

func _on_body_entered(body: Node3D) -> void:
	if body is Diver and not occupants.has(body):
		occupants.append(body)

func _on_body_exited(body: Node3D) -> void:
	occupants.erase(body)

func has_diver(d: Diver) -> bool:
	return occupants.has(d)
