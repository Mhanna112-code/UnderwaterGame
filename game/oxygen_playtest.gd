# Dedicated manual issue-#48 playtest. It boots the real World and real gap
# puzzle, skips the save/title flow, puts all three divers at zero oxygen,
# and leaves the player to solve it with the shipped controls.
class_name OxygenPlaytest
extends Node

const PLAYTEST_SLOT := 918276

var world: World
var status_label: Label
var ready_for_playtest := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	add_child(world)
	await get_tree().process_frame
	world.title_screen.new_game_chosen.emit(PLAYTEST_SLOT)
	await get_tree().process_frame

	var starts := [
		Vector3(12.2, 2.0, 11.0),
		Vector3(12.2, 2.0, 9.0),
		Vector3(13.5, 2.0, 10.0),
	]
	for i in range(world.divers.size()):
		var diver := world.divers[i] as Diver
		diver.global_position = starts[i]
		diver.stats.oxygen = 0.0
		diver.encounter_chance = 0.0
	# The normal save crystal sits between this deliberately close starting
	# camera and the blockade. It is unrelated to the scenario and fills most
	# of the viewport at this distance, so hide it in this review harness.
	for save_point in world._save_points:
		(save_point as SavePoint).visible = false
	world.active = 2
	world.yaw = PI / 2.0
	world.pitch = -0.12
	world._update_hud()
	world._update_hp_bar()
	world._update_oxygen_bar()
	_build_overlay()
	ready_for_playtest = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		if (event as InputEventKey).keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()

func _process(_delta: float) -> void:
	if not ready_for_playtest:
		return
	if world._puzzle_solved:
		status_label.text = "PASS: all three divers crossed at 0 O2 and opened the goal • R resets"
		status_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.6))

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 210.0
	# Leave the real top-left controls and top-right minimap unobscured. The
	# playtest explanation sits below them rather than competing for the same
	# strip of screen.
	panel.offset_top = 112.0
	panel.offset_right = -210.0
	panel.offset_bottom = 202.0
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	var title := Label.new()
	title.text = "ZERO-O2 PROGRESSION PLAYTEST"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	column.add_child(title)
	var instructions := Label.new()
	instructions.text = "All divers start at O2 0/100 • TAB switches • E uses the shown 0-O2 ability • Grapple: aim + click • R resets"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(instructions)
	status_label = Label.new()
	status_label.text = "Goal: Shockwave rubble -> repeatedly Grapple/Swap across -> put one diver on each lit plate"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	column.add_child(status_label)
