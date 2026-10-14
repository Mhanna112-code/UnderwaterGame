# Battle hit/heal/status effects on the 3D stage, plus the small status icons
# drawn beside HP bars. Static helpers; battle.gd decides when to call them.
class_name BattleFx
extends RefCounted

const DAMAGE_RED := Color(1.0, 0.1, 0.1)
const STUN_YELLOW := Color(1.0, 0.9, 0.15)
const HEAL_GREEN := Color(0.35, 1.0, 0.45)
const BLOOD_RED := Color(0.75, 0.02, 0.06)
const POISON_GREEN := Color(0.45, 0.85, 0.2)

# Flickers a coloured overlay on every mesh of `actor` (the swirl-room hit look).
static func flash(actor: Node3D, color: Color, pulses := 3, pulse_time := 0.09) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var meshes: Array = actor.find_children("*", "MeshInstance3D", true, false)
	if actor is MeshInstance3D:
		meshes.append(actor)
	if meshes.is_empty():
		return
	var tint := StandardMaterial3D.new()
	tint.albedo_color = Color(color, 0.55)
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.emission_enabled = true
	tint.emission = color
	tint.emission_energy_multiplier = 1.5
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var set_tint := func(on: bool) -> void:
		for m in meshes:
			if not is_instance_valid(m):
				continue
			var mesh := m as MeshInstance3D
			if on:
				mesh.material_overlay = tint
			elif mesh.material_overlay == tint:
				# Only clear our own tint; a newer flash may have replaced it.
				mesh.material_overlay = null
	var tw := actor.create_tween()
	for i in pulses:
		tw.tween_callback(set_tint.bind(true))
		tw.tween_interval(pulse_time)
		tw.tween_callback(set_tint.bind(false))
		tw.tween_interval(pulse_time)

# Green bubbles rising from `at` (healing).
static func bubbles(parent: Node, at: Vector3) -> void:
	var p := _particles(parent, at, HEAL_GREEN, 16, 1.3, 0.35)
	p.direction = Vector3.UP
	p.spread = 18.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 0.5, 0)
	p.mesh = _sphere(0.055, 0.11)

# Blood drops falling from `at` (a Bleed tick).
static func blood_drops(parent: Node, at: Vector3) -> void:
	var p := _particles(parent, at, BLOOD_RED, 18, 0.9, 0.3)
	p.direction = Vector3.DOWN
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0, -6.0, 0)
	p.mesh = _sphere(0.07, 0.2)

# A green cloud puffing out around `at` (a Poison tick).
static func poison_cloud(parent: Node, at: Vector3) -> void:
	var p := _particles(parent, at, POISON_GREEN, 14, 1.4, 0.35)
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.45
	p.gravity = Vector3.ZERO
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.6))
	grow.add_point(Vector2(1.0, 1.8))
	p.scale_amount_curve = grow
	p.mesh = _sphere(0.14, 0.28)

# Three red arrows sliding down over `at` (a stat-lowering or status move landed).
static func down_arrows(parent: Node, at: Vector3) -> void:
	_arrows(parent, at, Color(1.0, 0.2, 0.2), false)

# Three green arrows rising over `at` (a stat boost landed).
static func up_arrows(parent: Node, at: Vector3) -> void:
	_arrows(parent, at, HEAL_GREEN, true)

static func _arrows(parent: Node, at: Vector3, color: Color, rising: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = true
	var mesh := _arrow_mesh(rising)
	for i in 3:
		var arrow := MeshInstance3D.new()
		arrow.mesh = mesh
		arrow.material_override = mat
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(arrow)
		arrow.position = at + Vector3((float(i) - 1.0) * 0.3, (-0.1 if rising else 0.35) + (0.12 if i == 1 else 0.0), 0.0)
		var tw := arrow.create_tween()
		tw.tween_interval(float(i) * 0.06)
		tw.tween_property(arrow, "position:y", arrow.position.y + (0.55 if rising else -0.55), 0.75).set_ease(Tween.EASE_IN)
		tw.tween_callback(arrow.queue_free)
	var fade := parent.create_tween()
	fade.tween_interval(0.4)
	fade.tween_property(mat, "albedo_color:a", 0.0, 0.45)

# Arrow in the XY plane (billboarded by its material): head below and shaft
# above when falling, flipped when rising.
static func _arrow_mesh(rising := false) -> Mesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var flip := -1.0 if rising else 1.0
	for v in [Vector3(-0.13, 0, 0), Vector3(0.13, 0, 0), Vector3(0, -0.17, 0),
			Vector3(-0.045, 0, 0), Vector3(0.045, 0, 0), Vector3(0.045, 0.18, 0),
			Vector3(-0.045, 0, 0), Vector3(0.045, 0.18, 0), Vector3(-0.045, 0.18, 0)]:
		st.add_vertex(Vector3(v.x, v.y * flip, v.z))
	return st.commit()

static func _sphere(radius: float, height: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = height
	s.radial_segments = 8
	s.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	s.material = mat
	return s

# One-shot CPU burst that frees itself; colour fades out over its lifetime.
static func _particles(parent: Node, at: Vector3, color: Color, amount: int, lifetime: float, radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.75
	p.amount = amount
	p.lifetime = lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	var fade := Gradient.new()
	fade.set_color(0, Color(color, 0.9))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade
	parent.add_child(p)
	p.position = at
	p.emitting = true
	# Cleanup on its own tween, so it dies with the node if the stage goes first.
	p.create_tween().tween_callback(p.queue_free).set_delay(lifetime + 0.3)
	return p


# Small icon beside an HP bar: a blood drop for Bleed, a cloud for Poison.
class StatusIcon:
	extends Control

	var kind := ""

	func _init(icon_kind: String) -> void:
		kind = icon_kind
		custom_minimum_size = Vector2(13, 13)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func _draw() -> void:
		var w := size.x
		var h := size.y
		if kind == "bleed":
			var r := h * 0.3
			var c := Vector2(w * 0.5, h * 0.64)
			draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5, h * 0.04),
				c + Vector2(-r * 0.95, -r * 0.3), c + Vector2(r * 0.95, -r * 0.3)]), BLOOD_RED.lightened(0.15))
			draw_circle(c, r, BLOOD_RED.lightened(0.15))
			draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.25, Color(1, 0.6, 0.6, 0.8))
		elif kind == "poison":
			var col := POISON_GREEN
			draw_circle(Vector2(w * 0.32, h * 0.6), h * 0.24, col)
			draw_circle(Vector2(w * 0.55, h * 0.42), h * 0.28, col)
			draw_circle(Vector2(w * 0.74, h * 0.62), h * 0.22, col)
			draw_rect(Rect2(w * 0.3, h * 0.6, w * 0.45, h * 0.22), col)
			draw_circle(Vector2(w * 0.5, h * 0.55), h * 0.08, Color(0.15, 0.3, 0.05))
