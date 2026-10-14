class_name MazeRouteGuide
extends PanelContainer
## Screen-space compass: remains legible when the lab shell hides the ramp.
## Up means swim forward in the current exploration camera, not world north.
var pointer: Polygon2D
var distance_label: Label

func _ready() -> void:
	name = "MazeRouteGuide"
	add_to_group("maze_route_guide")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.055, 0.09, 0.96)
	style.border_color = Color("65b9df")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 44)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)
	pointer = Polygon2D.new()
	pointer.name = "Direction"
	pointer.position = Vector2(34, 32)
	pointer.color = Color("90e9ff")
	pointer.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(12, 0), Vector2(5, -2),
		Vector2(5, 16), Vector2(-5, 16), Vector2(-5, -2), Vector2(-12, 0),
	])
	add_child(pointer)
	var labels := VBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	labels.add_theme_constant_override("separation", 2)
	row.add_child(labels)
	var title := Label.new()
	title.text = "Maze ramp"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("e5faff"))
	labels.add_child(title)
	distance_label = Label.new()
	distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	distance_label.add_theme_font_size_override("font_size", 14)
	distance_label.add_theme_color_override("font_color", Color("90bccc"))
	labels.add_child(distance_label)

func update_bearing(camera: Camera3D, diver_position: Vector3, destination: Vector3, below_hud: float) -> void:
	var toward := destination - diver_position
	toward.y = 0
	var forward := -camera.global_basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0
	right = right.normalized()
	pointer.rotation = atan2(toward.dot(right), toward.dot(forward))
	distance_label.text = "%d m" % ceili(toward.length())
	var viewport_size := get_viewport_rect().size
	size = Vector2(200, 64)
	position = Vector2((viewport_size.x - size.x) * 0.5,
		minf(maxf(below_hud + 12, viewport_size.y * 0.27), viewport_size.y - size.y - 16))
