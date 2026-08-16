# The dive site: a seafloor, the three divers, and a camera you swim behind.
#
# Deliberately small. This exists so the team can get hands on the models and
# feel their scale and speed in motion, which no screenshot can settle, and
# so the next argument about the art is had in front of something playable.
extends Node3D

# Every diver now arrives rigged, textured and animated in a file of its own.
# content/cast.gd says which is which.
const GOBLIN := preload("res://GoblinGrunt.fbx")
const ActorScript := preload("res://game/actor.gd")
const SiteScript := preload("res://game/site.gd")
const BeaconScript := preload("res://game/beacon.gd")

# Where the fights are lives in content/sites.gd now: a graph of places
# joined by routes, so adding an area is a data entry and the map is checked
# by verify/sites.gd rather than by eye.
const TOUCH := 2.6

signal encountered(enemy_name: String, encounter: String)

# the squad starts at the anchor, under the descent line they came down
const SPAWN := [Vector3(0.0, 2.0, 3.0), Vector3(-3.4, 2.2, 0.4), Vector3(3.4, 2.4, 0.4)]

var divers: Array = []
var active := 0
var yaw := 0.0
var pitch := -0.16
var cam_dist := 6.5
var cam: Camera3D
var hud: Label
var parts: Control
var _hint_left := 15.0
var mouse_look := false
var _t := 0.0
var lantern: Node3D
var beaten: Dictionary = {}
var marks: Array = []          # live guards: {node, site}
var site_nodes: Dictionary = {}
var routes: Array = []         # {from, to, beacons: [Beacon]}
var _fired := false
# test seam: verify/swim.gd steers the player without a keyboard. Nothing in
# the game writes these, so the shipped build reads the real keys.
var scripted := false
var scripted_dir := Vector3.ZERO
var scripted_rise := 0.0

func _ready() -> void:
	cam = $Camera3D
	hud = $HUD/Controls
	parts = $HUD/Parts
	_build_site()
	for i in range(Cast.ALL.size()):
		var c: Dictionary = Cast.by_index(i)
		var d := Swimmer.new()
		d.source = load(String(c.file)) as PackedScene
		d.clip_family = String(c.family)
		d.carries = (c.carries as Array).duplicate()
		d.model_name = String(c.mesh)
		d.position = SPAWN[i % SPAWN.size()]
		add_child(d)
		divers.append(d)
	_place_enemies()
	_face_the_trail()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_hud()

# Start looking down the road. The lit beacons were behind the camera on
# spawn, which threw away the entire point of building them: the first thing
# a player sees should be the way on, not the empty water opposite it.
func _face_the_trail() -> void:
	var lead: Node3D = null
	var best := INF
	var me: Vector3 = SPAWN[0]
	for r in routes:
		for b in r.beacons:
			if (b as Beacon).state != Beacon.State.ONWARD:
				continue
			var d: float = me.distance_to((b as Node3D).global_position)
			if d < best:
				best = d
				lead = b
	if lead == null:
		return
	var v: Vector3 = lead.global_position - me
	v.y = 0.0
	if v.length() < 0.5:
		return
	v = v.normalized()
	yaw = atan2(v.x, v.z)

# The seabed everything stands on, and rock scattered across it for parallax.
# Without something to move relative to, swimming at this scale reads as
# standing still.
func _build_site() -> void:
	var floor_body := StaticBody3D.new()
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.23, 0.23)
	fm.roughness = 1.0
	floor_mesh.material_override = fm
	floor_body.add_child(floor_mesh)
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 0.4, 200)
	fs.shape = box
	fs.position.y = -0.2
	floor_body.add_child(fs)
	add_child(floor_body)

	# One MultiMesh, not a node per rock. Scenery keeps clear of every site
	# and of every route, so nothing can wall the player off from a place
	# they are being led to.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260815
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 0.7
	rock.radial_segments = 7
	rock.rings = 4
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.13, 0.19, 0.21)
	rm.roughness = 1.0
	rock.surface_set_material(0, rm)

	var lanes: Array = []
	for r in Sites.routes():
		for b in r.beacons:
			lanes.append(b as Vector3)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = rock
	mm.instance_count = 120
	for i in range(120):
		var sz := rng.randf_range(0.8, 3.8)
		var a := rng.randf() * TAU
		var dist := rng.randf_range(6.0, 78.0)
		var here := Vector3(cos(a) * dist, 0.0, sin(a) * dist)
		var blocked := false
		for d in Sites.ALL:
			var c: Vector3 = d.at
			if here.distance_to(Vector3(c.x, 0.0, c.z)) < float(d.radius) + 2.5:
				blocked = true
		for l in lanes:
			if here.distance_to(Vector3((l as Vector3).x, 0.0, (l as Vector3).z)) < 3.0:
				blocked = true
		if blocked:
			mm.set_instance_transform(i, Transform3D().scaled(Vector3.ONE * 0.001))
			continue
		var t := Transform3D()
		t = t.scaled(Vector3(sz, sz * rng.randf_range(0.5, 0.9), sz))
		t = t.rotated(Vector3.UP, rng.randf() * TAU)
		t.origin = Vector3(here.x, sz * 0.15, here.z)
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

func _place_enemies() -> void:
	_build_sites()
	_build_routes()
	_light_route()

func _build_sites() -> void:
	for d in Sites.ALL:
		var site: Site = SiteScript.new()
		add_child(site)
		site.build(d)
		site_nodes[String(d.id)] = site
		if String(d.kind) != "combat":
			continue
		var done: bool = bool(beaten.get(String(d.guard), false))
		site.set_cleared(done)
		if done:
			continue
		# the guard, standing over the thing it guards
		var a: RiggedActor = ActorScript.new()
		add_child(a)
		a.setup(GOBLIN, "GoblinGrunt", "rig|", "Idle")
		a.position = (d.at as Vector3) + Vector3(1.4, 0.0, 0.6)
		a.position.y = 0.0
		marks.append({"node": a, "site": d})

		var part := SalvagePart.new()
		part.position = (d.at as Vector3) + Vector3(0.0, -0.6, 0.0)
		part.position.y = 1.0
		add_child(part)

func _build_routes() -> void:
	for r in Sites.routes():
		var made: Array = []
		var order := 0
		for at in r.beacons:
			var b: Beacon = BeaconScript.new()
			add_child(b)
			b.build(at as Vector3, order)
			made.append(b)
			order += 1
		routes.append({"from": String(r.from), "to": String(r.to), "beacons": made})

# The route to the next place with something still on it is the lit one.
# Everything already done goes green, everything past it stays dim, so at any
# moment exactly one line of lights is telling you where to go.
func _light_route() -> void:
	var target := ""
	for d in Sites.ALL:
		if String(d.kind) == "combat" and not bool(beaten.get(String(d.guard), false)):
			target = String(d.id)
			break
	for r in routes:
		var st: int = Beacon.State.IDLE
		if String(r.to) == target:
			st = Beacon.State.ONWARD
		elif _is_done(String(r.to)):
			st = Beacon.State.DONE
		for b in r.beacons:
			(b as Beacon).set_state(st)

func _is_done(site_id: String) -> bool:
	var d: Dictionary = Sites.by_id(site_id)
	if d.is_empty() or String(d.kind) != "combat":
		return true
	return bool(beaten.get(String(d.guard), false))

# The staff used to be placed here as scenery because the old delivery had it
# as a loose mesh. It is skinned to the diver's rig now and she carries it, so
# there is nothing to put on the seabed.

func _unhandled_input(e: InputEvent) -> void:
	# DRAG to look, rather than swallowing the cursor on the first click.
	# Taking the mouse and keeping it meant the only way to get it back was
	# to guess at ESC, which is exactly the wrong thing to make somebody
	# guess at before they have worked out any of the other controls.
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
			mouse_look = mb.pressed
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
	_check_contact()
	if _hint_left > 0.0:
		_hint_left -= dt
		hud.modulate.a = clampf(_hint_left / 4.0, 0.0, 1.0)

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
			var site: Dictionary = m.site
			encountered.emit(String(site.guard), String(site.encounter))
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
	var centre: Vector3 = SPAWN[i % SPAWN.size()]
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

func _update_hud() -> void:
	var d: Swimmer = divers[active]
	var left := 0
	for m in marks:
		if is_instance_valid(m.node as Node):
			left += 1
	var sites := 0
	for sd in Sites.ALL:
		if String(sd.kind) == "combat":
			sites += 1
	if parts != null:
		parts.guarded = left
		parts.total = sites
		parts.queue_redraw()
	# The controls hint is the last text in the game and it fades: a player
	# needs it for the first few seconds and never again, and leaving it up
	# is how a screen full of words starts.
	hud.text = "WASD swim · SPACE up · SHIFT down · hold mouse or use arrows to look · TAB switch diver"

func _find(n: Node, nm: String) -> MeshInstance3D:
	if n is MeshInstance3D and String(n.name) == nm:
		return n
	for c in n.get_children():
		var r := _find(c, nm)
		if r != null:
			return r
	return null
