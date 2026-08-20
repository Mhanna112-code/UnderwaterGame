# Shown once at game start (World._ready(), see _show_title_screen()) and
# again any time the player backs all the way out of a run (GameOverScreen's
# "Return to Title", which reloads the whole scene - see world.gd). The
# world underneath is already fully built by the time this shows (divers,
# terrain, HUD all exist) - this just sits on top and keeps the SceneTree
# paused until a slot's been chosen, same "everything's real, just frozen"
# approach as InventoryMenu/SavePointMenu use during their own screens,
# except this one needs process_mode ALWAYS since the whole point is
# staying interactive while paused.
#
# Two root screens: "main" (New Game / Load Game) and "slots" (three slot
# buttons + Back) - "slots" serves both actions, just with different
# button behavior/labels depending on _pending_action, so there's one
# picker instead of two near-identical ones.
class_name TitleScreen
extends Control

signal new_game_chosen(slot: int)
signal load_game_chosen(slot: int)

var _mode := "main"
var _pending_action := "new"   # "new" | "load"

var _list: VBoxContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "Underwater"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	col.add_child(_list)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mode = "main"
	_refresh()

func close() -> void:
	visible = false

func _refresh() -> void:
	for child in _list.get_children():
		child.queue_free()
	if _mode == "main":
		_refresh_main()
	else:
		_refresh_slots()

func _refresh_main() -> void:
	var new_btn := Button.new()
	new_btn.text = "New Game"
	new_btn.custom_minimum_size = Vector2(360, 44)
	new_btn.pressed.connect(_open_slots.bind("new"))
	_list.add_child(new_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(360, 44)
	load_btn.pressed.connect(_open_slots.bind("load"))
	_list.add_child(load_btn)

func _open_slots(action: String) -> void:
	_pending_action = action
	_mode = "slots"
	_refresh()

# New Game: every slot is pickable - an occupied one just gets an
# "(overwrite)" warning in its label rather than being blocked, since
# there's no reason to force a player to hunt for an empty slot if they
# want to restart in the one they've already been using.
# Load Game: only occupied slots are enabled - nothing to load from an
# empty one.
func _refresh_slots() -> void:
	var heading := Label.new()
	heading.text = "New Game - choose a slot" if _pending_action == "new" else "Load Game"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	_list.add_child(heading)

	for slot in range(SaveManager.SLOT_COUNT):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(360, 44)
		var data: Dictionary = SaveManager.read_slot(slot)
		if data.is_empty():
			btn.text = "Slot %d - Empty" % (slot + 1)
			btn.disabled = _pending_action == "load"
		else:
			btn.text = "Slot %d - %s%s" % [
				slot + 1, _summarize(data),
				" (overwrite)" if _pending_action == "new" else "",
			]
		btn.pressed.connect(_on_slot_pressed.bind(slot))
		_list.add_child(btn)

	var back := Button.new()
	back.text = "< Back"
	back.custom_minimum_size = Vector2(360, 36)
	back.pressed.connect(_back_to_main)
	_list.add_child(back)

# A one-line readout of a save's party, just enough to tell slots apart at
# a glance - the diver order matches World.CAST, so index 0 is always
# Mermaid regardless of who's "active" in the save.
func _summarize(data: Dictionary) -> String:
	var divers_data: Array = data.get("divers", [])
	if divers_data.is_empty():
		return "?"
	var d0: Dictionary = divers_data[0]
	var stats: Dictionary = d0.get("stats", {})
	return "Lv %d party" % int(stats.get("level", 1))

func _back_to_main() -> void:
	_mode = "main"
	_refresh()

func _on_slot_pressed(slot: int) -> void:
	if _pending_action == "new":
		new_game_chosen.emit(slot)
	else:
		load_game_chosen.emit(slot)
