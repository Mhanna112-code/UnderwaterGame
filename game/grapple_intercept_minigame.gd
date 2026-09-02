# Diver Boy's special-encounter defense: the enemy launches targets from
# random points in front of the diver, mouse-look aims a first-person camera,
# and left-click fires a grapple line. Unshot targets damage the diver when
# they arrive; the battle owns the actual damage calculation via object_hit.
class_name GrappleInterceptMinigame
extends Control

signal finished(hits: int, total: int)
signal object_hit
signal wrong_object_hit

const TARGET_COUNT := 8
const TITLE_HOLD := 0.8
const MIN_SPAWN_GAP := 0.60
const MAX_SPAWN_GAP := 1.0
const FLIGHT_TIME := 3.2
const HIT_ANGLE := deg_to_rad(7.0)
const LOOK_SENSITIVITY := 0.0035
const MAX_YAW := 0.75
const MAX_PITCH := 0.48

var stage_root: SubViewport
var stage_camera: Camera3D
var target_actor: Node3D
var source_position := Vector3.ZERO

var _targets: Array[MeshInstance3D] = []
var _target_tweens: Dictionary = {}
var _decoys: Array[MeshInstance3D] = []
var _decoy_tweens: Dictionary = {}
var _spawned := 0
var _resolved := 0
var _hits := 0
var _penalties := 0
var _yaw := 0.0
var _pitch := 0.0
var _base_forward := Vector3.FORWARD
var _old_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _target_was_visible := true
var _progress: Label
var _start_button: Button

func _ready() -> void:
	if get_parent() is Control:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.04, 0.18)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := Label.new()
	title.text = "GRAPPLE INTERCEPT"
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 35.0
	title.offset_left = -220.0
	title.offset_right = 220.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.3))
	add_child(title)

	var hint := Label.new()
	hint.text = "Grapple ORANGE threats • Avoid BLUE decoys (they damage you)"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 78.0
	hint.offset_left = -330.0
	hint.offset_right = 330.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)

	_progress = Label.new()
	_progress.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress.offset_top = 110.0
	_progress.offset_left = -100.0
	_progress.offset_right = 100.0
	_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_progress)
	_update_progress()

	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -16.0
	crosshair.offset_top = -25.0
	crosshair.offset_right = 16.0
	crosshair.offset_bottom = 25.0
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.add_theme_font_size_override("font_size", 34)
	crosshair.add_theme_color_override("font_color", Color(0.95, 0.9, 0.45))
	add_child(crosshair)

	_start_button = Button.new()
	_start_button.text = "CLICK TO START PLAYTEST"
	_start_button.set_anchors_preset(Control.PRESET_CENTER)
	_start_button.offset_left = -170.0
	_start_button.offset_top = 70.0
	_start_button.offset_right = 170.0
	_start_button.offset_bottom = 122.0
	_start_button.add_theme_font_size_override("font_size", 20)
	_start_button.visible = false
	add_child(_start_button)

func run() -> void:
	if stage_camera == null or target_actor == null or stage_root == null:
		push_error("GrappleInterceptMinigame requires stage_root, stage_camera, and target_actor")
		finished.emit(0, TARGET_COUNT)
		return
	_old_mouse_mode = Input.mouse_mode
	# Browsers reject pointer lock unless it is requested from a user gesture.
	# The dedicated web playtest therefore waits on a real click; desktop keeps
	# the immediate start used by automated/local playtests.
	if OS.has_feature("web"):
		_start_button.visible = true
		await _start_button.pressed
		_start_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_target_was_visible = target_actor.visible
	target_actor.visible = false
	var eye := target_actor.global_position + Vector3(0.0, (target_actor as Diver).height * 0.4, 0.0)
	_base_forward = (source_position - eye).normalized()
	stage_camera.global_position = eye
	stage_camera.look_at(eye + _base_forward * 10.0, Vector3.UP)
	await get_tree().create_timer(TITLE_HOLD).timeout
	_spawn_loop()

func _exit_tree() -> void:
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_yaw = clampf(_yaw - motion.relative.x * LOOK_SENSITIVITY, -MAX_YAW, MAX_YAW)
		_pitch = clampf(_pitch - motion.relative.y * LOOK_SENSITIVITY, -MAX_PITCH, MAX_PITCH)
		_update_camera()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_shoot()

func _update_camera() -> void:
	var forward := _base_forward.rotated(Vector3.UP, _yaw)
	var right := forward.cross(Vector3.UP).normalized()
	forward = forward.rotated(right, _pitch).normalized()
	stage_camera.look_at(stage_camera.global_position + forward * 10.0, Vector3.UP)

func _spawn_loop() -> void:
	while _spawned < TARGET_COUNT:
		await get_tree().create_timer(randf_range(MIN_SPAWN_GAP, MAX_SPAWN_GAP)).timeout
		if not is_instance_valid(self):
			return
		_spawn_target()
		if _spawned % 2 == 0:
			_spawn_decoy()
		_spawned += 1

func _spawn_target() -> void:
	var eye := stage_camera.global_position
	var forward := _base_forward
	var right := forward.cross(Vector3.UP).normalized()
	var spawn := eye + forward * randf_range(9.0, 12.0) + right * randf_range(-4.0, 4.0) + Vector3.UP * randf_range(-2.2, 2.8)

	var target := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.42
	mesh.height = 0.84
	target.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.28, 0.12)
	material.emission_enabled = true
	material.emission = Color(0.65, 0.08, 0.02)
	material.emission_energy_multiplier = 1.5
	target.material_override = material
	stage_root.add_child(target)
	target.global_position = spawn
	_targets.append(target)

	var tween := target.create_tween()
	_target_tweens[target] = tween
	tween.tween_property(target, "global_position", eye, FLIGHT_TIME)
	tween.finished.connect(func() -> void: _land(target))

func _spawn_decoy() -> void:
	var eye := stage_camera.global_position
	var forward := _base_forward
	var right := forward.cross(Vector3.UP).normalized()
	var side := -1.0 if randf() < 0.5 else 1.0
	var start := eye + forward * randf_range(6.5, 9.5) + right * side * 4.5 + Vector3.UP * randf_range(-1.8, 2.2)
	var finish := start - right * side * randf_range(5.0, 7.0)

	var decoy := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.75, 0.75, 0.75)
	decoy.mesh = mesh
	decoy.rotation = Vector3(randf(), randf(), randf())
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.55, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.04, 0.25, 0.9)
	material.emission_energy_multiplier = 1.4
	decoy.material_override = material
	stage_root.add_child(decoy)
	decoy.global_position = start
	_decoys.append(decoy)
	var tween := decoy.create_tween()
	_decoy_tweens[decoy] = tween
	tween.tween_property(decoy, "global_position", finish, 3.2)
	tween.parallel().tween_property(decoy, "rotation", decoy.rotation + Vector3(2.0, 3.0, 2.5), 3.2)
	tween.finished.connect(func() -> void: _clear_decoy(decoy))

func _shoot() -> void:
	if _targets.is_empty() and _decoys.is_empty():
		return
	var aim := -stage_camera.global_transform.basis.z.normalized()
	var best: MeshInstance3D = null
	var best_angle := HIT_ANGLE
	for candidate in _targets + _decoys:
		var to_target: Vector3 = (candidate.global_position - stage_camera.global_position).normalized()
		var angle := aim.angle_to(to_target)
		if angle <= best_angle:
			best = candidate
			best_angle = angle
	if best != null:
		if _decoys.has(best):
			_hit_decoy(best)
		else:
			_destroy_target(best)

func _hit_decoy(decoy: MeshInstance3D) -> void:
	_decoys.erase(decoy)
	var flight: Tween = _decoy_tweens.get(decoy, null)
	if flight != null and flight.is_valid():
		flight.kill()
	_decoy_tweens.erase(decoy)
	_penalties += 1
	_grapple_beam(stage_camera.global_position, decoy.global_position)
	wrong_object_hit.emit()
	_show_wrong_hit()
	var flash := decoy.create_tween()
	flash.tween_property(decoy, "scale", Vector3.ONE * 1.6, 0.08)
	flash.tween_property(decoy, "scale", Vector3.ZERO, 0.12)
	flash.tween_callback(decoy.queue_free)
	_update_progress()

func _show_wrong_hit() -> void:
	var warning := Label.new()
	warning.text = "WRONG OBJECT — DAMAGE!"
	warning.set_anchors_preset(Control.PRESET_CENTER)
	warning.offset_left = -220.0
	warning.offset_top = 55.0
	warning.offset_right = 220.0
	warning.offset_bottom = 105.0
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.add_theme_font_size_override("font_size", 28)
	warning.add_theme_color_override("font_color", Color(1.0, 0.22, 0.18))
	add_child(warning)
	var fade := warning.create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(warning, "modulate:a", 0.0, 0.45)
	fade.tween_callback(warning.queue_free)

func _clear_decoy(decoy: MeshInstance3D) -> void:
	_decoys.erase(decoy)
	_decoy_tweens.erase(decoy)
	if is_instance_valid(decoy):
		decoy.queue_free()

func _destroy_target(target: MeshInstance3D) -> void:
	_targets.erase(target)
	var flight: Tween = _target_tweens.get(target, null)
	if flight != null and flight.is_valid():
		flight.kill()
	_target_tweens.erase(target)
	_hits += 1
	_resolved += 1
	_grapple_beam(stage_camera.global_position, target.global_position)
	var flash := target.create_tween()
	flash.tween_property(target, "scale", Vector3.ONE * 1.8, 0.10)
	flash.tween_property(target, "scale", Vector3.ZERO, 0.10)
	flash.tween_callback(target.queue_free)
	_update_progress()
	_maybe_finish()

func _land(target: MeshInstance3D) -> void:
	if not _targets.has(target):
		return
	_targets.erase(target)
	_target_tweens.erase(target)
	_resolved += 1
	object_hit.emit()
	target.queue_free()
	_update_progress()
	_maybe_finish()

func _grapple_beam(from: Vector3, to: Vector3) -> void:
	var distance := from.distance_to(to)
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = distance
	mesh.top_radius = 0.035
	mesh.bottom_radius = 0.035
	beam.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.9, 0.25)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam.material_override = material
	stage_root.add_child(beam)
	beam.global_position = (from + to) * 0.5
	beam.look_at(to, Vector3.UP)
	beam.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	var fade := beam.create_tween()
	fade.tween_property(beam, "scale", Vector3(1.0, 1.0, 0.0), 0.16)
	fade.tween_callback(beam.queue_free)

func _update_progress() -> void:
	if _progress != null:
		_progress.text = "%d / %d intercepted   Wrong objects: %d" % [_hits, TARGET_COUNT, _penalties]

func _maybe_finish() -> void:
	if _resolved < TARGET_COUNT:
		return
	Input.mouse_mode = _old_mouse_mode
	if target_actor != null and is_instance_valid(target_actor):
		target_actor.visible = _target_was_visible
	for decoy in _decoys:
		if is_instance_valid(decoy):
			decoy.queue_free()
	_decoys.clear()
	finished.emit(_hits, TARGET_COUNT)

# Verification hook: aim directly at the closest target and fire through
# the exact same hit-selection path used by mouse input.
func auto_intercept_closest() -> bool:
	if _targets.is_empty() or stage_camera == null:
		return false
	var closest := _targets[0]
	for target in _targets:
		if stage_camera.global_position.distance_to(target.global_position) < stage_camera.global_position.distance_to(closest.global_position):
			closest = target
	stage_camera.look_at(closest.global_position, Vector3.UP)
	_shoot()
	return true

func auto_hit_decoy() -> bool:
	if _decoys.is_empty() or stage_camera == null:
		return false
	stage_camera.look_at(_decoys[0].global_position, Vector3.UP)
	_shoot()
	return true

# Battle-lifecycle verification uses direct resolution so its assertions
# isolate HP/camera/visibility wiring from the separate aim-selection test.
func verification_resolve_closest() -> bool:
	if _targets.is_empty():
		return false
	var closest := _targets[0]
	for target in _targets:
		if stage_camera.global_position.distance_to(target.global_position) < stage_camera.global_position.distance_to(closest.global_position):
			closest = target
	_destroy_target(closest)
	return true
