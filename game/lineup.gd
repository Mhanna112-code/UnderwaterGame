# The cast, laid out. Open the project and this is the main scene: every
# model from the FBX spread along X, floor-aligned, slowly turning, with the
# measured height printed under each one.
#
# The FBX arrives with all four models stacked at the origin, so "load the
# models" and "look at the models" are not the same job.
extends Node3D

const SRC := preload("res://art/characters/Main_Team_Rigging_2.fbx")

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
		# drop each model onto the floor: they arrive centred on their own
		# origin, which is not the same as standing on y=0
		var box: AABB = _world_aabb(mi)
		pivot.position = Vector3(x, -box.position.y, 0.0)
		turners.append(pivot)
		# label the whole box, not the height: the lantern is a 1.79m staff
		# lying flat, and "0.12 m" was a true number about the wrong axis
		_label(String(m.name), box.size, x, box.size.y)
		x += gap
	src.queue_free()
	_frame_camera(models.size(), gap)

# put the whole cast in shot instead of trusting a hand-placed camera: add a
# model and the framing follows
func _frame_camera(n: int, gap: float) -> void:
	var cam: Camera3D = $Camera3D
	var span: float = max(gap * (n - 1) + 2.0, 4.0)
	# fov is VERTICAL. Sizing a horizontal lineup against it pushed the
	# camera nearly twice as far back as it needed to be.
	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	var aspect: float = vp.x / max(1.0, vp.y)
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
