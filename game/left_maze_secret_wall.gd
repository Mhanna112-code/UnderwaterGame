extends Node3D
class_name FlowField

# Side-view level inside the maze's left secret wall, between ceiling slab CSGBox3D16 and floor slab CSGBox3D17.
# A cell grid holds a whirlpool flow field; hidden objects follow it and shoot through the core, shown on the minimap.
# The diver starts at the walled left end; reaching the right end, or Esc, returns to the maze.

const MAZE_SCENE := "res://game/maze_level.tscn"

# --- Grid --------------------------------------------------------------------
var cell_radius := 10.0
var cell_diameter := cell_radius * 2.0

var cells := []          # [{"cellPos": Vector3, "cell_index": int, "dist": float, "velocity": Vector3}]
var cols := 0            # cells along the slabs
var rows := 0            # cells from slab to slab

@onready var w16 := $CSGBox3D16 as CSGBox3D
@onready var w17 := $CSGBox3D17 as CSGBox3D
@onready var center := (w16.global_position + w17.global_position) * 0.5

# Level axes from the slabs: `along` (screen right), `across` (ceiling to floor), `normal` (away from camera).
var along := Vector3.ZERO
var across := Vector3.ZERO
var normal := Vector3.ZERO
var level_length := 0.0        # along the slabs
var level_gap := 0.0           # open space between the slabs
var slab_thickness := 0.0
var slot_width := 0.0          # the slabs' width out of the level's plane
var grid_origin := Vector3.ZERO   # cell (0, 0)'s outer corner: start end, against the ceiling

# --- Whirlpool ---------------------------------------------------------------
var vortex_strength := 5.0     # peak swirl speed, at the edge of the core
var drain_strength := 2.5      # pull toward the centre
var core_radius := 3.0
var spin_sign := 1.0

# --- Hidden objects ----------------------------------------------------------
enum SwirlState { SPIRAL, PASS }
const PASS_RADIUS := 1.8       # this close to the centre: shoot straight through
const PASS_SPEED := 7.0
const PASS_EXIT_RADIUS := 4.5  # back to following the flow once this far out again
var swirl_pos := PackedVector3Array()
var swirl_vel := PackedVector3Array()
var swirl_state := PackedByteArray()
var swirl_drag := PackedFloat32Array()   # per-object variation, so they don't move in lockstep

# --- Diver, camera, HUD --------------------------------------------------------
const CAMERA_DISTANCE := 18.0
var diver: Diver
var start_along := 0.0         # how far along the level the diver started
var _arrow: Node3D
var _arrow_label: Label3D
var _arrow_blink: Tween
var _minimap: Control
var _leaving := false
var campaign_session: CampaignSession

func _ready() -> void:
	campaign_session = SceneHandoff.take_campaign_session()
	_measure_level()
	init_maze_grid()
	for i in cells.size():
		calculate_whirlpool_center(i)
	_build_start_wall()
	spawn_swirlers()
	_spawn_diver()
	_build_move_right_arrow()
	_build_minimap()
	($HUD/Controls as Label).text = "A / D: swim left / right   W / S (or Space / Shift): up / down   Esc: back to the maze"

# --- Level shape ---------------------------------------------------------------

func _measure_level() -> void:
	along = w16.global_basis.x.normalized()
	across = (w17.global_position - w16.global_position).normalized()
	normal = along.cross(across).normalized()
	level_length = w16.size.x * w16.global_basis.x.length()
	slab_thickness = w16.size.z * w16.global_basis.z.length()
	slot_width = w16.size.y * w16.global_basis.y.length()
	level_gap = w16.global_position.distance_to(w17.global_position) - slab_thickness
	grid_origin = w16.global_position - along * level_length * 0.5 + across * slab_thickness * 0.5

func init_cell(world_pos: Vector3, grid_index: int) -> void:
	cells.append({"cellPos": world_pos, "cell_index": grid_index, "dist": 0.0, "velocity": Vector3.ZERO})

func init_maze_grid() -> void:
	cells.clear()
	cols = int(level_length / cell_diameter)
	rows = int(level_gap / cell_diameter)
	for j in rows:
		for i in cols:
			var world_pos := grid_origin + along * (i + 0.5) * cell_diameter + across * (j + 0.5) * cell_diameter
			init_cell(world_pos, j * cols + i)

# Level coords: x = distance along the slabs, y = distance down from the ceiling.
func plane_uv(world: Vector3) -> Vector2:
	var local := world - grid_origin
	return Vector2(local.dot(along), local.dot(across))

func uv_to_world(uv: Vector2) -> Vector3:
	return grid_origin + along * uv.x + across * uv.y

# --- Whirlpool field -------------------------------------------------------------

# Rankine-vortex swirl plus drain toward `center`, flattened into the level plane.
func calculate_whirlpool_center(i: int) -> void:
	var pos: Vector3 = cells[i]["cellPos"]
	var to_center := center - pos
	to_center -= normal * to_center.dot(normal)
	var r := to_center.length()
	var inward := to_center / r if r > 0.001 else Vector3.ZERO
	var tangent := normal.cross(inward) * spin_sign
	var swirl := vortex_strength * (r / core_radius if r < core_radius else core_radius / r)
	# Drain grows toward the middle so objects get dragged through the core.
	var drain := drain_strength * core_radius / maxf(r, 0.75)
	cells[i]["dist"] = r
	cells[i]["velocity"] = tangent * swirl

# Bilinear blend of the four nearest cells' velocities.
func velocity_at(world: Vector3) -> Vector3:
	var uv := plane_uv(world) / cell_diameter - Vector2(0.5, 0.5)
	var x0 := clampi(int(floor(uv.x)), 0, cols - 1)
	var y0 := clampi(int(floor(uv.y)), 0, rows - 1)
	var x1 := mini(x0 + 1, cols - 1)
	var y1 := mini(y0 + 1, rows - 1)
	var tx := clampf(uv.x - x0, 0.0, 1.0)
	var ty := clampf(uv.y - y0, 0.0, 1.0)
	var a: Vector3 = cells[y0 * cols + x0]["velocity"]
	var b: Vector3 = cells[y0 * cols + x1]["velocity"]
	var c: Vector3 = cells[y1 * cols + x0]["velocity"]
	var d: Vector3 = cells[y1 * cols + x1]["velocity"]
	return a.lerp(b, tx).lerp(c.lerp(d, tx), ty)

# --- Hidden objects ----------------------------------------------------------------

# Plain data, not nodes; the minimap draws them from these arrays.
func spawn_swirlers() -> void:
	swirl_pos.clear()
	swirl_vel.clear()
	swirl_state.clear()
	swirl_drag.clear()
	for cell in cells:
		swirl_pos.append(cell["cellPos"])
		swirl_vel.append(Vector3.ZERO)
		swirl_state.append(SwirlState.SPIRAL)
		swirl_drag.append(randf_range(3.0, 4.5))

func _update_swirlers(delta: float) -> void:
	for k in swirl_pos.size():
		var pos := swirl_pos[k]
		var vel := swirl_vel[k]
		var to_center := center - pos
		to_center -= normal * to_center.dot(normal)
		var r := to_center.length()
		if swirl_state[k] == SwirlState.SPIRAL:
			vel = vel.lerp(velocity_at(pos), clampf(swirl_drag[k] * delta, 0.0, 1.0))
			if r < PASS_RADIUS:
				# Shoot straight through the middle and out the other side.
				swirl_state[k] = SwirlState.PASS
				var heading := vel.normalized() if vel.length() > 0.01 else to_center.normalized()
				vel = heading * PASS_SPEED
		elif r > PASS_EXIT_RADIUS:
			swirl_state[k] = SwirlState.SPIRAL
		pos += vel * delta
		# Stay on the level's plane and inside the slabs (bouncing off them).
		pos -= normal * (pos - center).dot(normal)
		var uv := plane_uv(pos)
		if uv.x < 0.0 or uv.x > level_length:
			vel -= along * 2.0 * vel.dot(along)
			uv.x = clampf(uv.x, 0.0, level_length)
		if uv.y < 0.0 or uv.y > level_gap:
			vel -= across * 2.0 * vel.dot(across)
			uv.y = clampf(uv.y, 0.0, level_gap)
		swirl_pos[k] = uv_to_world(uv)
		swirl_vel[k] = vel

# Wall closing the start end, slab to slab.
func _build_start_wall() -> void:
	var wall := CSGBox3D.new()
	wall.name = "SecretWallStart"
	wall.use_collision = true
	add_child(wall)
	var up := -across
	wall.global_basis = Basis(along, up, along.cross(up)).orthonormalized()
	wall.size = Vector3(slab_thickness, level_gap + slab_thickness * 2.0, slot_width)
	wall.global_position = grid_origin + across * level_gap * 0.5 + along * slab_thickness * 0.5

func _spawn_diver() -> void:
	diver = Diver.new()
	diver.model_name = SceneHandoff.diver_model if SceneHandoff.diver_model != "" else "Staff_Diver"
	add_child(diver)
	if campaign_session != null:
		diver.restore_campaign_member(campaign_session.party[campaign_session.active])
	start_along = slab_thickness + 3.0
	diver.global_position = uv_to_world(Vector2(start_along, level_gap * 0.5))
	var cam := $Camera3D as Camera3D
	cam.global_position = diver.global_position - normal * CAMERA_DISTANCE
	cam.look_at(diver.global_position, -across)

# A yellow arrow pointing right, blinking, with "Move right" above it.
func _build_move_right_arrow() -> void:
	_arrow = Node3D.new()
	add_child(_arrow)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.85, 0.2)
	mat.emission_energy_multiplier = 2.5
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.12
	shaft_mesh.bottom_radius = 0.12
	shaft_mesh.height = 1.6
	shaft.mesh = shaft_mesh
	shaft.material_override = mat
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.0
	head_mesh.bottom_radius = 0.38
	head_mesh.height = 0.7
	head.mesh = head_mesh
	head.material_override = mat
	head.position = Vector3(0, 1.15, 0)
	_arrow.add_child(head)
	_arrow_label = Label3D.new()
	_arrow_label.text = "Move right"
	_arrow_label.font_size = 64
	_arrow_label.pixel_size = 0.008
	_arrow_label.outline_size = 10
	_arrow_label.modulate = Color(1.0, 0.9, 0.4)
	_arrow_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_arrow_label)
	# The meshes point up their own Y; turn that to point along the level.
	_arrow.global_basis = Basis(-across, along, normal).orthonormalized()
	_arrow.global_position = diver.global_position + along * 2.2 - across * 2.2 - normal * 0.8
	_arrow_label.global_position = _arrow.global_position - across * 1.0
	_arrow_blink = create_tween().set_loops()
	_arrow_blink.tween_callback(func() -> void:
		_arrow.visible = not _arrow.visible
		_arrow_label.visible = _arrow.visible)
	_arrow_blink.tween_interval(0.4)

func _remove_arrow() -> void:
	if _arrow == null:
		return
	_arrow_blink.kill()
	_arrow_label.queue_free()
	_arrow.queue_free()
	_arrow = null

# --- Minimap -------------------------------------------------------------------------

func _build_minimap() -> void:
	var w := 340.0
	var h := maxf(w * level_gap / level_length, 60.0)
	_minimap = Control.new()
	_minimap.name = "SecretMinimap"
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -w - 12.0
	_minimap.offset_right = -12.0
	_minimap.offset_top = 12.0
	_minimap.offset_bottom = 12.0 + h
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	$HUD.add_child(_minimap)

func _draw_minimap() -> void:
	var map_size := _minimap.size
	_minimap.draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.02, 0.05, 0.08, 0.85))
	_minimap.draw_rect(Rect2(Vector2.ZERO, map_size), Color(0.45, 0.7, 0.85), false, 2.0)
	var to_map := Vector2(map_size.x / level_length, map_size.y / level_gap)
	_minimap.draw_arc(plane_uv(center) * to_map, 6.0, 0.0, TAU, 24, Color(1, 1, 1, 0.8), 1.5)
	for k in swirl_pos.size():
		_minimap.draw_circle(plane_uv(swirl_pos[k]) * to_map, 2.5, Color(1.0, 0.15, 0.15))
	if diver != null:
		_minimap.draw_circle(plane_uv(diver.global_position) * to_map, 4.0, Color(0.3, 1.0, 0.45))

# --- Per frame -----------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_swirlers(delta)
	if diver == null or _leaving:
		return
	# Side-on controls: A/D along the level, W/S or Space/Shift up and down.
	var side := 0.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		side += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		side -= 1.0
	var rise := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE):
		rise += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SHIFT):
		rise -= 1.0
	diver.swim(along * side, rise, delta)
	# Keep the diver on the level's plane.
	diver.global_position -= normal * (diver.global_position - center).dot(normal)
	diver.velocity -= normal * diver.velocity.dot(normal)
	var uv := plane_uv(diver.global_position)
	if uv.x > start_along + 5.0:
		_remove_arrow()
	if uv.x > level_length - 2.0:
		_leave()

func _process(delta: float) -> void:
	if diver != null:
		var cam := $Camera3D as Camera3D
		# Follow along the level but stay level with the centre.
		var want := diver.global_position - normal * CAMERA_DISTANCE
		want += across * (plane_uv(center).y - plane_uv(diver.global_position).y)
		cam.global_position = cam.global_position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
		cam.look_at(cam.global_position + normal, -across)
	if _minimap != null:
		_minimap.queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_leave()

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	if campaign_session != null:
		campaign_session.party[campaign_session.active] = diver.campaign_member_state()
		SceneHandoff.campaign_session = campaign_session
	SceneHandoff.returning_from_secret_wall = true
	get_tree().change_scene_to_file.call_deferred(MAZE_SCENE)
