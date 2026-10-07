# Model lineup scene: every FBX model spread along X, floor-aligned and turning, with measured size labels.
extends Node3D

const SRC := preload("res://art/characters/divers.glb")

var turners: Array = []

func _ready() -> void:
	var src: Node3D = SRC.instantiate()
	var models: Array = []
	_collect(src, models)

	var gap := 3.0
	var x := -gap * (models.size() - 1) * 0.5
	for m in models:
		var pivot := Node3D.new()
		pivot.name = String(m.name) + "_pivot"
		add_child(pivot)
		var mi: MeshInstance3D = m
		mi.get_parent().remove_child(mi)
		pivot.add_child(mi)
		# Models arrive centred on their origin; drop them onto y=0.
		var box: AABB = _world_aabb(mi)
		pivot.position = Vector3(x, -box.position.y, 0.0)
		turners.append(pivot)
		# Label the full box size, not just height (the lantern lies flat).
		_label(String(m.name), box.size, x, box.size.y)
		x += gap
	src.queue_free()
	_frame_camera(models.size(), gap)

# Frame the whole cast automatically.
func _frame_camera(n: int, gap: float) -> void:
	var cam: Camera3D = $Camera3D
	var span: float = maxf(gap * float(n - 1) + 2.0, 4.0)
	# fov is vertical; size the horizontal lineup accordingly.
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var aspect: float = vp.x / maxf(1.0, vp.y)
	var htan: float = tan(deg_to_rad(cam.fov * 0.5)) * aspect
	var dist: float = span * 0.5 / htan * 1.1
	cam.position = Vector3(0.0, 1.4, dist)
	cam.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)

func _process(dt: float) -> void:
	for t in turners:
		(t as Node3D).rotate_y(dt * 0.5)

func _collect(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
		return
	for c in n.get_children():
		_collect(c, out)

func _world_aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.global_transform
	var out := AABB(t * a.get_endpoint(0), Vector3.ZERO)
	for i in range(8):
		out = out.expand(t * a.get_endpoint(i))
	return out

func _label(nm: String, size: Vector3, x: float, top: float) -> void:
	var l := Label3D.new()
	l.text = "%s\n%.2f x %.2f x %.2f m" % [nm, size.x, size.y, size.z]
	l.font_size = 48
	l.pixel_size = 0.004
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(x, top + 0.5, 0.0)
	add_child(l)
