# `progression guidance: show the physical beacon OR the off-screen HUD arrow,
# never both — guards against a visible post contradicted by Beacon LEFT/RIGHT`.
#
# MUST run windowed:
#   godot --path . --resolution 1280x720 --script verify/route_guidance_visibility.gd
#   godot --path . --resolution 1920x1080 --script verify/route_guidance_visibility.gd
extends SceneTree

const SETTLE_FRAMES := 8
const BROWSER_SIZE := Vector2i(1280, 720)

var world: World
var render_view: SubViewport
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	# A SubViewport gives this camera/UI contract an actual 1280×720 browser
	# surface even on headless CI, whose host Window is deliberately 64×64.
	# It exercises World’s production projection code rather than substituting
	# a fake rectangle into the assertion.
	render_view = SubViewport.new()
	render_view.size = BROWSER_SIZE
	render_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(render_view)
	var viewport := Rect2(Vector2.ZERO, Vector2(BROWSER_SIZE))
	world = (load("res://game/world.tscn") as PackedScene).instantiate()
	world.skip_intro_for_test = true
	render_view.add_child(world)
	for _i in SETTLE_FRAMES:
		await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame
	world._intro_active = false
	world._begin_core_route_after_tutorial()
	if world.route_transition_card != null:
		world.route_transition_card.dismiss()
	for _i in 3:
		await process_frame

	_check_visible_beacon_suppresses_hud(viewport)
	_check_partial_beacon_suppresses_hud(viewport)
	_check_offscreen_beacon_uses_hud(viewport)
	_expect(not is_instance_valid(world._intro_arrow) or not world._intro_arrow.visible,
		"ROUTE GUIDANCE left the tutorial's hovering arrow active beside the route beacon")
	world.queue_free()
	render_view.queue_free()
	await process_frame
	_report()

func _place_camera(look_target: Vector3) -> void:
	var target := world.route.active_position()
	world.cam.global_position = target + Vector3(0.0, 7.0, 16.0)
	world.cam.look_at(look_target, Vector3.UP)

func _safe_view(viewport: Rect2) -> Rect2:
	return Rect2(Vector2(56.0, 72.0), viewport.size - Vector2(112.0, 146.0))

func _check_visible_beacon_suppresses_hud(viewport: Rect2) -> void:
	var target := world.route.active_position()
	_place_camera(target + Vector3(0.0, 1.1, 0.0))
	world._update_route_direction_indicator()
	var bounds := world.route_beacon_screen_bounds()
	_expect(bounds.has_area() and _safe_view(viewport).intersects(bounds),
		"ROUTE GUIDANCE could not project the visible beacon bounds: %s" % bounds)
	_expect(not world.route_direction_label.visible,
		"ROUTE GUIDANCE showed '%s' while the physical beacon was visible" % world.route_direction_label.text)

func _check_partial_beacon_suppresses_hud(viewport: Rect2) -> void:
	var target := world.route.active_position()
	var safe := _safe_view(viewport)
	var found_edge_case := false
	# Aim progressively above the post.  At one camera angle the beacon's base
	# point is outside the safe HUD region while its visible post/lamp still
	# intersects it: this is the exact case the old point-only check missed.
	for step in range(-48, 65):
		var aim_height := float(step) * 0.25
		_place_camera(target + Vector3(0.0, aim_height, 0.0))
		var point := world.cam.unproject_position(target)
		var bounds := world.route_beacon_screen_bounds()
		if safe.has_point(point) or not safe.intersects(bounds):
			continue
		world._update_route_direction_indicator()
		found_edge_case = true
		_expect(not world.route_direction_label.visible,
			"ROUTE GUIDANCE showed '%s' while visible beacon bounds %s crossed the safe view" % [world.route_direction_label.text, bounds])
		break
	_expect(found_edge_case,
		"ROUTE GUIDANCE test could not construct a partial-beacon camera case at %s" % viewport.size)

func _check_offscreen_beacon_uses_hud(viewport: Rect2) -> void:
	var target := world.route.active_position()
	_place_camera(world.cam.global_position + (world.cam.global_position - target).normalized() * 10.0)
	world._update_route_direction_indicator()
	_expect(world.route_direction_label.visible,
		"ROUTE GUIDANCE did not expose an off-screen Beacon direction label")
	_expect("Beacon • " in world.route_direction_label.text,
		"ROUTE GUIDANCE off-screen fallback lost readable text: '%s'" % world.route_direction_label.text)
	if world.route_direction_label.visible:
		_expect(viewport.encloses(world.route_direction_label.get_global_rect()),
			"ROUTE GUIDANCE off-screen label is clipped: %s in %s" % [world.route_direction_label.get_global_rect(), viewport])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _report() -> void:
	for finding in findings:
		push_error(finding)
	print("ROUTE GUIDANCE VISIBILITY: clean" if findings.is_empty() else "ROUTE GUIDANCE VISIBILITY: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
