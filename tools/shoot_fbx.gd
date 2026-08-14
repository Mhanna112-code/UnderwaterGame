# Render the imported rig and LOOK at it. A tree dump proves the file parsed;
# it does not prove the models are usable. This frames each mesh on its own
# turntable plus one group shot, and writes PNGs.
#
# Usage: godot --path ~/underwatergame --script tools/shoot_fbx.gd -- <outdir>
extends SceneTree

const PATH := "res://art/characters/divers.glb"

var outdir := "/tmp"
var shots: Array = []      # [name, node-or-null for whole scene]
var idx := -1
var frames := 0
var holder: Node3D
var cam: Camera3D
var subject: Node3D

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		outdir = String(args[0])
	var packed: PackedScene = load(PATH)
	var src: Node3D = packed.instantiate()

	# report the transform every node actually arrived with: a 2cm AABB is
	# either a tiny mesh or a mesh with a big node scale, and those are very
	# different problems
	_report(src, 0)

	holder = Node3D.new()
	root.add_child(holder)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.13, 0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.45, 0.6, 0.65)
	e.ambient_light_energy = 1.2
	env.environment = e
	holder.add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, 40.0, 0.0)
	key.light_energy = 2.0
	holder.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-10.0, -130.0, 0.0)
	fill.light_energy = 0.7
	holder.add_child(fill)

	cam = Camera3D.new()
	holder.add_child(cam)

	subject = src
	holder.add_child(subject)

	for c in _all_meshes(subject):
		shots.append(String(c.name))
	shots.append("__all__")

# meshes may sit at any depth; the first version assumed a wrapper node that
# this file does not have, found none, and shot the inside of a boot
func _all_meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(_all_meshes(c))
	return out

func _report(n: Node, d: int) -> void:
	var pad := ""
	for i in range(d):
		pad += "  "
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		print("%s- %-22s pos %s scale %s" % [pad, n.name, str(t.origin), str(t.basis.get_scale())])
		if n is MeshInstance3D:
			var ga: AABB = (n as MeshInstance3D).get_aabb()
			var world_size: Vector3 = ga.size * (n as Node3D).global_transform.basis.get_scale() if (n as Node3D).is_inside_tree() else ga.size * t.basis.get_scale()
			print("%s    local aabb %s -> with node scale %s" % [pad, str(ga.size), str(world_size)])
	for c in n.get_children():
		_report(c, d + 1)

# No await in here: _process must RETURN a bool, and an awaiting _process
# hands Godot a coroutine instead, which read as "quit" and shot nothing.
# Plain frame counting instead: arm the shot, let it render, capture.
func _process(_dt: float) -> bool:
	frames += 1
	if frames == 1:
		idx += 1
		if idx >= shots.size():
			return true
		_arm(String(shots[idx]))
		return false
	if frames < 5:
		return false          # let the frame actually draw
	var which := String(shots[idx])
	var img: Image = root.get_texture().get_image()
	var safe := which.replace("(", "_").replace(")", "").replace("|", "_")
	var f := "%s/fbx_%s.png" % [outdir, safe]
	img.save_png(f)
	print("shot       %s  (%dx%d)" % [f, img.get_width(), img.get_height()])
	frames = 0
	return false

func _arm(which: String) -> void:
	var meshes: Array = []
	for c in _all_meshes(subject):
		(c as MeshInstance3D).visible = (which == "__all__" or String(c.name) == which)
		if (c as MeshInstance3D).visible:
			meshes.append(c)
	if meshes.is_empty():
		push_error("NOTHING VISIBLE for shot '%s'" % which)
	_frame(meshes)

# frame the visible meshes: world-space AABB, camera pulled back to fit
func _frame(meshes: Array) -> void:
	if meshes.is_empty():
		return
	var box: AABB = _world_aabb(meshes[0])
	for m in meshes:
		box = box.merge(_world_aabb(m))
	var c: Vector3 = box.get_center()
	var r: float = max(0.001, box.size.length() * 0.5)
	var dist: float = r / tan(deg_to_rad(35.0)) * 1.25
	var dir := Vector3(0.8, 0.45, 1.0).normalized()
	cam.position = c + dir * dist
	cam.look_at(c, Vector3.UP)
	cam.near = max(0.001, dist * 0.001)
	cam.far = dist * 10.0

func _world_aabb(m: MeshInstance3D) -> AABB:
	var a: AABB = m.get_aabb()
	var t: Transform3D = m.global_transform
	var pts: Array = []
	for i in range(8):
		pts.append(t * a.get_endpoint(i))
	var out := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		out = out.expand(p)
	return out
