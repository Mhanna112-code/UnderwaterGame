# Dev-mode-only teleport (added by World._start_dev_mode, never in a normal
# game). G opens a window with a list of named places and a top-down map:
# click anywhere on the map to go there. T jumps the party to whatever the
# camera's centre is pointing at.
class_name DevTeleport
extends CanvasLayer

const AIM_RANGE := 250.0
const MENU_KEY := KEY_G

var world: World
var _panel: PanelContainer
var _list: VBoxContainer
var _map: TeleportMap
var _was_paused := false
var _old_mouse_mode := Input.MOUSE_MODE_VISIBLE

func _init(owner_world: World) -> void:
	world = owner_world
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(1000, 600)
	_panel.position = Vector2(-500, -300)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.07, 0.1, 0.96)
	style.border_color = Color(0.3, 0.75, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	title.text = "DEV TELEPORT  ·  click a place or anywhere on the map  ·  G / Esc to close  ·  T = jump to aim"
	title.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 540)
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_map = TeleportMap.new()
	_map.owner_tp = self
	_map.custom_minimum_size = Vector2(620, 540)
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_map)
	_panel.visible = false

func _input(e: InputEvent) -> void:
	var key := e as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == MENU_KEY:
		_close() if _panel.visible else _open()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and _panel.visible:
		_close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_T and not _panel.visible:
		_jump_to_aim()
		get_viewport().set_input_as_handled()

func _open() -> void:
	if world.battling:
		world._announce("Can't teleport during a battle.")
		return
	for c in _list.get_children():
		c.queue_free()
	var places := destinations()
	for entry in places:
		if entry.has("header"):
			var h := Label.new()
			h.text = String(entry.header)
			h.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
			_list.add_child(h)
			continue
		var b := Button.new()
		b.text = String(entry.name)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_go.bind(entry))
		_list.add_child(b)
	_map.prepare(places)
	_was_paused = get_tree().paused
	_old_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true

func _close() -> void:
	_panel.visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _old_mouse_mode

func _go(entry: Dictionary) -> void:
	_close()
	if String(entry.get("unlock", "")) == "tethys":
		world.dev_unlock_tethys()
	world.dev_teleport(entry.pos as Vector3, bool(entry.maze), String(entry.name), float(entry.get("yaw", NAN)))

# Map click: any (x, z). Lands just above the floor found there; the maze
# owns the spot if it's inside the maze's area.
func go_to_xz(xz: Vector2) -> void:
	var in_maze := world.embedded_maze != null and world.embedded_maze.contains_point(Vector3(xz.x, 0, xz.y))
	var floor_y := _floor_height_at(xz, in_maze)
	_close()
	world.dev_teleport(Vector3(xz.x, floor_y + 1.2, xz.y), in_maze, "map point (%d, %d)" % [roundi(xz.x), roundi(xz.y)])

func _floor_height_at(xz: Vector2, in_maze: bool) -> float:
	var space := world.get_world_3d().direct_space_state
	var top := 40.0
	if in_maze:
		top = world.embedded_maze._floor_top_y + 6.0   # under the maze ceiling
	var exclude: Array[RID] = []
	for d in world.divers:
		exclude.append((d as CollisionObject3D).get_rid())
	# Walk down through every surface under the click and keep the lowest:
	# the seafloor / maze floor, not the top of a rock or overhang above it.
	var lowest := INF
	var from := Vector3(xz.x, top, xz.y)
	for i in 8:
		var query := PhysicsRayQueryParameters3D.create(from, Vector3(xz.x, top - 80.0, xz.y))
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		lowest = (hit.position as Vector3).y
		exclude.append(hit.rid)
		from = (hit.position as Vector3) + Vector3.DOWN * 0.01
	if lowest == INF:
		return world.embedded_maze._floor_top_y if in_maze else 0.8
	return lowest

# Teleport to the point under the screen centre, staying in the current area.
func _jump_to_aim() -> void:
	if world.battling:
		return
	var in_maze := world.embedded_maze != null and world.embedded_maze.maze_active
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var centre := get_viewport().get_visible_rect().size * 0.5
	var from := cam.project_ray_origin(centre)
	var to := from + cam.project_ray_normal(centre) * AIM_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var exclude: Array[RID] = []
	for d in world.divers:
		exclude.append((d as CollisionObject3D).get_rid())
	query.exclude = exclude
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		world._announce("Nothing to teleport to there.")
		return
	# Step back off the surface along its normal so the party isn't in a wall.
	var spot: Vector3 = hit.position + (hit.normal as Vector3) * 1.2
	world.dev_teleport(spot, in_maze, "aim point")

# [{name, pos, maze}] plus {header} rows. Overworld positions are open water
# beside each place (a guarded/combat ring is approached from its edge, on the
# side facing the start, so you arrive looking at it instead of inside it).
func destinations() -> Array:
	var out: Array = []
	var layout = world.deep_zone_layout
	out.append({"header": "Overworld"})
	out.append({"name": "Start (anchor)", "pos": Vector3(0, 2.0, 9.0), "maze": false})
	for s in Sites.ALL:
		if String(s.get("kind", "")) == "anchor":
			continue
		var at: Vector3 = s.at
		var away := Vector3(at.x, 0, at.z).normalized() if Vector2(at.x, at.z).length() > 0.1 else Vector3.BACK
		var edge := at - away * (float(s.get("radius", 6.0)) + 2.0)
		var label := String(s.id).capitalize()
		if String(s.get("item", "")) != "":
			label += "  (guards %s)" % String(Items.ITEMS.get(String(s.item), {}).get("display", s.item))
		out.append({"name": label, "pos": Vector3(edge.x, 2.0, edge.z), "maze": false})
	if layout != null:
		var rp: Dictionary = layout.route_points()
		out.append({"name": "Ability exit", "pos": rp.ability_exit, "maze": false})
		out.append({"name": "Deep entry", "pos": rp.deep_entry, "maze": false})
		out.append({"name": "Deep hub", "pos": DeepZoneLayout.DEEP_HUB, "maze": false})
		# Bosses: a few metres short of them on the hub side, so the fight
		# doesn't start the moment you land.
		for boss in [["Bomb Bot", rp.bomb_bot], ["Sword Slayer", rp.sword_slayer]]:
			var at: Vector3 = boss[1]
			var back := (DeepZoneLayout.DEEP_HUB - at)
			back.y = 0.0
			out.append({"name": "%s (just outside)" % boss[0], "pos": at + back.normalized() * 10.0, "maze": false})
		# Unlocks the lab (Bomb Bot + Sword Slayer marked beaten) and lands just
		# outside its door: swim in to start the Tethys cutscene and fight.
		var lab_back: Vector3 = DeepZoneLayout.DEEP_HUB - (rp.lab as Vector3)
		lab_back.y = 0.0
		out.append({"name": "Tethys (unlocks lab, swim in to fight)", "pos": (rp.lab as Vector3) + lab_back.normalized() * 7.0, "maze": false, "unlock": "tethys"})
		out.append({"name": "Maze door (outside)", "pos": Vector3(200.0, 2.0, -4.0), "maze": false})
	var maze := world.embedded_maze
	if maze == null:
		return out
	var fy: float = maze._floor_top_y + 1.2
	out.append({"header": "Maze"})
	out.append({"name": "Maze entrance (inside)", "pos": Vector3(263, 2, DeepZoneLayout.MAZE_TRANSITION.z), "maze": true})
	_add_room(out, "Secret item room", maze._secret_item_room_rect(), fy)
	_add_room(out, "Strong room", maze._strong_room_rect(), fy)
	if maze._map_chest != null and is_instance_valid(maze._map_chest):
		var chest: Vector3 = maze._map_chest.global_position
		out.append({"name": "Control room (map chest)", "pos": Vector3(chest.x, fy, chest.z + 2.5), "maze": true})
	_add_room(out, "Sphere room", maze._sphere_room_interior, fy)
	var hall: Rect2 = maze._hall_rect()
	if hall.size != Vector2.ZERO:
		out.append({"name": "Boss hall (entrance)", "pos": Vector3(hall.position.x + 1.8, fy, hall.position.y + 1.6), "maze": true})
	_add_room(out, "Secret boss room", maze._secret_boss_room_rect(true), fy)
	var b33 := maze.get_node_or_null("CSGBox3D33") as Node3D
	if b33 != null:
		out.append({"name": "Main boss room (facing Cordys)", "pos": Vector3(b33.global_position.x + 3.0, fy, maze._main_boss_door_z), "maze": true, "yaw": -PI * 0.5})
	return out

func _add_room(out: Array, label: String, rect: Rect2, y: float) -> void:
	var r := rect.abs()
	if r.size.x > 0.5 and r.size.y > 0.5:
		out.append({"name": label, "pos": Vector3(r.get_center().x, y, r.get_center().y), "maze": true})


# Top-down map of the whole play area (world x/z; north = -Z is up).
# Draws maze walls, site rings, named places and the party; click to go.
class TeleportMap:
	extends Control

	var owner_tp: DevTeleport
	var _places: Array = []
	var _walls: Array = []          # [PackedVector2Array footprint]
	var _bounds := Rect2()          # world x/z rect shown
	var _hover := Vector2.INF       # world x/z under the mouse
	var _zoom := 1.0                # mouse wheel
	var _pan := Vector2.ZERO        # right-drag, in pixels

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func prepare(places: Array) -> void:
		_places = places.filter(func(e: Dictionary) -> bool: return not e.has("header"))
		_walls.clear()
		var pts: Array[Vector2] = []
		for e in _places:
			var p: Vector3 = e.pos
			pts.append(Vector2(p.x, p.z))
		for s in Sites.ALL:
			pts.append(Vector2((s.at as Vector3).x, (s.at as Vector3).z))
		var maze: Node = owner_tp.world.embedded_maze
		if maze != null:
			for c in maze.get_children():
				if c is CSGBox3D and (c as CSGBox3D).visible:
					var box := c as CSGBox3D
					# Walls only: skip floor/ceiling slabs (thin and wide).
					if box.size.y < 1.0 or minf(box.size.x, box.size.z) > 3.0:
						continue
					var poly := PackedVector2Array()
					for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]:
						var world_pt: Vector3 = box.global_transform * (corner * box.size)
						poly.append(Vector2(world_pt.x, world_pt.z))
						pts.append(Vector2(world_pt.x, world_pt.z))
					_walls.append(poly)
		var r := Rect2(pts[0], Vector2.ZERO)
		for p in pts:
			r = r.expand(p)
		_bounds = r.grow(15.0)
		_zoom = 1.0
		_pan = Vector2.ZERO
		queue_redraw()

	# World x/z <-> map pixels, keeping the aspect ratio.
	func _scale() -> float:
		return minf(size.x / maxf(_bounds.size.x, 1.0), size.y / maxf(_bounds.size.y, 1.0)) * _zoom

	func _offset() -> Vector2:
		var base := minf(size.x / maxf(_bounds.size.x, 1.0), size.y / maxf(_bounds.size.y, 1.0))
		return (size - _bounds.size * base) * 0.5 + _pan

	func _to_px(xz: Vector2) -> Vector2:
		return _offset() + (xz - _bounds.position) * _scale()

	func _to_world(px: Vector2) -> Vector2:
		return _bounds.position + (px - _offset()) / _scale()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseMotion:
			var motion := e as InputEventMouseMotion
			if motion.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_pan += motion.relative
			_hover = _to_world(motion.position)
			queue_redraw()
			accept_event()
		elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			var mb := e as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				owner_tp.go_to_xz(_to_world(mb.position))
			elif mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				# Zoom around the cursor: keep the world point under it fixed.
				var anchor := _to_world(mb.position)
				_zoom = clampf(_zoom * (1.25 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8), 1.0, 25.0)
				_pan += mb.position - _to_px(anchor)
				queue_redraw()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.1, 0.14))
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.45, 0.55), false, 1.0)
		var font := get_theme_default_font()
		var s := _scale()
		for poly in _walls:
			var px := PackedVector2Array()
			for p in poly:
				px.append(_to_px(p))
			draw_colored_polygon(px, Color(0.45, 0.5, 0.55))
		for site in Sites.ALL:
			var at: Vector3 = site.at
			draw_arc(_to_px(Vector2(at.x, at.z)), maxf(2.0, float(site.get("radius", 4.0)) * s), 0, TAU, 24, Color(0.9, 0.35, 0.3, 0.7), 1.5)
		# Dots for every named place; only the one nearest the mouse is labelled.
		var hover_px := _to_px(_hover) if _hover != Vector2.INF else Vector2(-9999, -9999)
		var nearest := -1
		var nearest_d := 14.0
		for i in _places.size():
			var p: Vector3 = _places[i].pos
			var c := _to_px(Vector2(p.x, p.z))
			draw_circle(c, 4.0, Color(1.0, 0.85, 0.4) if bool(_places[i].maze) else Color(0.5, 0.9, 1.0))
			if c.distance_to(hover_px) < nearest_d:
				nearest_d = c.distance_to(hover_px)
				nearest = i
		if nearest >= 0:
			var np: Vector3 = _places[nearest].pos
			var nc := _to_px(Vector2(np.x, np.z))
			draw_string(font, nc + Vector2(7, -6), String(_places[nearest].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
		var diver := owner_tp.world.divers[owner_tp.world.active] as Node3D
		var d := _to_px(Vector2(diver.global_position.x, diver.global_position.z))
		draw_circle(d, 6.0, Color(0.3, 1.0, 0.45))
		draw_string(font, d + Vector2(8, -6), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 1.0, 0.45))
		if _hover != Vector2.INF and Rect2(Vector2.ZERO, size).has_point(_to_px(_hover)):
			draw_string(font, Vector2(8, size.y - 10), "click to go to (%d, %d)   ·   wheel: zoom   ·   right-drag: pan" % [roundi(_hover.x), roundi(_hover.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))
