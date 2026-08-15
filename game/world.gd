# The dive site: a seafloor, the three divers, and a camera you swim behind.
#
# Deliberately small. This exists so the team can get hands on the models and
# feel their scale and speed in motion, which no screenshot can settle, and
# so the next argument about the art is had in front of something playable.
extends Node3D

const SRC := preload("res://art/characters/divers.glb")
const GOBLIN := preload("res://GoblinGrunt.fbx")
const ActorScript := preload("res://game/actor.gd")

# Where the fights are. Visible, fixed, and sitting on something: you can
# always swim past one, and swimming past means surfacing without whatever
# it was standing over. Nothing here is random, which is the whole point.
const ENEMIES := [
	{"name": "grunt_shallows", "encounter": "goblin", "at": Vector3(6.5, 1.7, -6.5)},
]
const TOUCH := 2.6

signal encountered(enemy_name: String, encounter: String)

const CAST := [
	{"model": "Staff_Diver", "at": Vector3(0, 2.0, 0)},
	{"model": "Prototype_1(1910)", "at": Vector3(-3.6, 2.2, -3.0)},
	{"model": "Prototype_V(1922)", "at": Vector3(3.6, 2.4, -3.0)},
]

var divers: Array = []
var active := 0
var yaw := 0.0
var pitch := -0.16
var cam_dist := 6.5
var cam: Camera3D
var hud: Label
var mouse_look := false
var _t := 0.0
var lantern: Node3D
var beaten: Dictionary = {}
var marks: Array = []
var _fired := false
# test seam: verify/swim.gd steers the player without a keyboard. Nothing in
# the game writes these, so the shipped build reads the real keys.
var scripted := false
var scripted_dir := Vector3.ZERO
var scripted_rise := 0.0

func _ready() -> void:
	cam = $Camera3D
	hud = $HUD/Controls
	_build_site()
	for c in CAST:
		var d := Swimmer.new()
		d.model_name = String(c.model)
		d.position = c.at as Vector3
		add_child(d)
		divers.append(d)
	_carry_lantern()
	_place_enemies()
	_update_hud()

func _place_enemies() -> void:
	for e in ENEMIES:
		if beaten.get(String(e.name), false):
			continue
		var a: RiggedActor = ActorScript.new()
		add_child(a)
		a.setup(GOBLIN, "GoblinGrunt", "rig|", "Idle")
		a.position = e.at as Vector3
		marks.append({"node": a, "data": e})

		# something to be standing over, so the fight is about the thing
		# rather than about the enemy being in the way
		var loot := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.8, 0.5, 0.6)
		loot.mesh = box
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.75, 0.62, 0.3)
		lm.emission_enabled = true
		lm.emission = Color(0.5, 0.4, 0.15)
		lm.emission_energy_multiplier = 0.6
		loot.material_override = lm
		loot.position = (e.at as Vector3) + Vector3(0.0, -1.4, 0.0)
		add_child(loot)

# A floor and some rock so there is parallax to swim past: without something
# to move relative to, motion at this scale reads as standing still.
func _build_site() -> void:
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(120, 120)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.24, 0.24)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	floor_body.add_child(floor_mesh)
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 0.4, 120)
	fs.shape = box
	fs.position.y = -0.2
	floor_body.add_child(fs)
	add_child(floor_body)

	# One MultiMesh, not 46 nodes with 46 collision bodies. The browser build
	# was taking most of a minute to show its first frame and every node set up
	# at startup was part of that bill. Rocks are scenery: they do not need to
	# be solid, and they do not need to be separate objects.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260814          # same site every run: a level you can talk about
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	rock.radial_segments = 7
	rock.rings = 4
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.13, 0.19, 0.21)
	rock_mat.roughness = 1.0
	rock.surface_set_material(0, rock_mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = 46
	for i in range(46):
		var sz := rng.randf_range(0.8, 3.6)
		var a := rng.randf() * TAU
		var dist := rng.randf_range(7.0, 48.0)
		var t := Transform3D()
		t = t.scaled(Vector3(sz, sz * rng.randf_range(0.5, 0.9), sz))
		t = t.rotated(Vector3.UP, rng.randf() * TAU)
		t.origin = Vector3(cos(a) * dist, sz * 0.15, sin(a) * dist)
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

# The fourth model is a staff. Nothing in this FBX is rigged, so no diver has
# a hand to put it in: carried, it read as a stick floating beside somebody.
# Planted in the seabed as a site beacon it reads as a decision.
func _carry_lantern() -> void:
	var src: Node3D = SRC.instantiate()
	var m: MeshInstance3D = _find(src, "Staff_Lantern")
	if m == null:
		return
	var keep: Transform3D = m.transform
	m.owner = null
	m.get_parent().remove_child(m)
	lantern = Node3D.new()
	lantern.add_child(m)
	m.transform = keep
	lantern.position = Vector3(1.8, 0.0, 2.6)
	lantern.rotation.x = -PI * 0.5      # the staff arrives lying along Z; stand it up
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.86, 0.6)
	glow.light_energy = 3.0
	glow.omni_range = 12.0
	glow.position.y = 1.5
	lantern.add_child(glow)
	add_child(lantern)
	src.queue_free()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		# the web build starts with a free cursor; the first click takes it
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_look = true
	elif e is InputEventKey and (e as InputEventKey).pressed and (e as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_look = false
	elif e is InputEventMouseMotion and mouse_look:
		var mm := e as InputEventMouseMotion
		yaw -= mm.relative.x * 0.004
		pitch = clampf(pitch - mm.relative.y * 0.003, -1.1, 0.7)
	elif e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo:
		var k := (e as InputEventKey).keycode
		if k == KEY_TAB:
			active = (active + 1) % divers.size()
			_update_hud()

func _physics_process(dt: float) -> void:
	_t += dt
	# keyboard turning too: mouse capture is the first thing to go wrong in a
	# browser, and a build nobody can steer is a build nobody plays
	if Input.is_key_pressed(KEY_LEFT):
		yaw += dt * 2.0
	if Input.is_key_pressed(KEY_RIGHT):
		yaw -= dt * 2.0
	if Input.is_key_pressed(KEY_UP):
		pitch = clampf(pitch + dt * 1.2, -1.1, 0.7)
	if Input.is_key_pressed(KEY_DOWN):
		pitch = clampf(pitch - dt * 1.2, -1.1, 0.7)

	for i in range(divers.size()):
		var d: Swimmer = divers[i]
		if i == active:
			d.swim(_player_dir(), _player_rise(), dt)
		else:
			_drift(d, i, dt)
	_move_camera(dt)
	_move_lantern(dt)
	_check_contact()

# Contact starts the fight. Visible enemy, fixed place, no invisible trigger:
# a player who wants no part of this can see it from a distance and go round.
func _check_contact() -> void:
	if _fired:
		return
	var p: Vector3 = (divers[active] as Swimmer).global_position
	for m in marks:
		var n: Node3D = m.node
		if not is_instance_valid(n):
			continue
		if p.distance_to(n.global_position) <= TOUCH:
			_fired = true
			encountered.emit(String((m.data as Dictionary).name), String((m.data as Dictionary).encounter))
			return

func _player_dir() -> Vector3:
	if scripted:
		return scripted_dir
	var f := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		f.y -= 1.0
	if Input.is_key_pressed(KEY_S):
		f.y += 1.0
	if Input.is_key_pressed(KEY_A):
		f.x -= 1.0
	if Input.is_key_pressed(KEY_D):
		f.x += 1.0
	if f == Vector2.ZERO:
		return Vector3.ZERO
	f = f.normalized()
	# swim where the camera is looking, not where the world's axes point.
	# fwd matches the camera's actual look direction (see _move_camera's
	# `dir`); right is fwd rotated -90 around Y so it points to screen-right
	# regardless of which way the diver model currently happens to be
	# facing. W/A/S/D always map to camera-forward/left/back/right.
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(-cos(yaw), 0, sin(yaw))
	return (right * f.x - fwd * f.y).normalized()

func _player_rise() -> float:
	if scripted:
		return scripted_rise
	var r := 0.0
	if Input.is_key_pressed(KEY_SPACE):
		r += 1.0
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		r -= 1.0
	return r

# the divers you are not steering keep swimming a slow circuit, so the site
# never looks like a museum of three statues
func _drift(d: Swimmer, i: int, dt: float) -> void:
	var phase := _t * 0.25 + float(i) * 2.1
	var centre: Vector3 = (CAST[i].at as Vector3)
	var target := centre + Vector3(cos(phase) * 6.0, sin(phase * 0.7) * 1.2, sin(phase) * 6.0)
	var to := target - d.global_position
	to.y = 0.0
	var rise: float = clampf((target.y - d.global_position.y) * 0.6, -1.0, 1.0)
	d.swim(to.normalized() if to.length() > 0.4 else Vector3.ZERO, rise, dt)

func _move_camera(dt: float) -> void:
	var d: Swimmer = divers[active]
	var focus: Vector3 = d.global_position + Vector3(0, d.height * 0.35, 0)
	var dir := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch))
	var want: Vector3 = focus - dir * cam_dist
	want.y = maxf(want.y, 0.6)      # never bury the camera in the seabed
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 8.0, 0.0, 1.0))
	cam.look_at(focus, Vector3.UP)

func _move_lantern(_dt: float) -> void:
	if lantern == null:
		return
	lantern.rotation.z = sin(_t * 0.8) * 0.05      # a slow sway in the current

func _update_hud() -> void:
	var d: Swimmer = divers[active]
	var left := 0
	for m in marks:
		if is_instance_valid(m.node as Node):
			left += 1
	hud.text = "%s  (%.2f m)    %s\nWASD swim · SPACE up · SHIFT down · mouse or arrows look · TAB switch diver" % [
		String(d.model_name), d.height,
		"salvage guarded: %d" % left if left > 0 else "the site is clear"]

func _find(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null
