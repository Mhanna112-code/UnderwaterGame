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
signal boss_playtest_chosen
signal special_playtest_chosen

var _mode := "main"
var _pending_action := "new"   # "new" | "load"

var _list: VBoxContainer
var _boss_playtest_available := false
var _special_playtest_available := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# PRESET_FULL_RECT anchors alone preserve this Control's initial zero-size
	# offsets. That leaves the CenterContainer with a (0, 0) parent rectangle,
	# collapsing the title and both actions into the upper-left corner. Reset
	# anchors and offsets together so this runtime-built overlay owns the full
	# viewport at every supported resolution.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

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

# Kept out of the ordinary title flow. World enables this only for the
# dedicated ?boss=1 review URL (or the matching command-line test flag), so
# PR #54's normal New/Load presentation remains exactly the one already
# reviewed while Glassgoat gets a one-click route to his boss.
func enable_boss_playtest() -> void:
	_boss_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# Like the boss route above, this is opt-in review plumbing rather than part
# of the ordinary New/Load flow. It lets a reviewer reach the guardian chooser
# and all three ability minigames without first navigating the full map.
func enable_special_playtest() -> void:
	_special_playtest_available = true
	if visible and _mode == "main":
		_refresh()

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
	new_btn.custom_minimum_size = Vector2(360, 58)
	new_btn.add_theme_font_size_override("font_size", 21)
	new_btn.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	new_btn.pressed.connect(_on_new_game_pressed)
	_list.add_child(new_btn)
	new_btn.grab_focus()

	if _boss_playtest_available:
		var boss_btn := Button.new()
		boss_btn.text = "Play Tethys Boss Test"
		boss_btn.tooltip_text = "Glassgoat animation and combat validation"
		boss_btn.custom_minimum_size = Vector2(360, 46)
		boss_btn.add_theme_font_size_override("font_size", 17)
		boss_btn.add_theme_color_override("font_color", Color(1.0, 0.62, 0.62))
		boss_btn.pressed.connect(boss_playtest_chosen.emit)
		_list.add_child(boss_btn)

	if _special_playtest_available:
		var special_btn := Button.new()
		special_btn.text = "Play Special Encounter Test"
		special_btn.tooltip_text = "Choose a diver and test their ability minigame"
		special_btn.custom_minimum_size = Vector2(360, 46)
		special_btn.add_theme_font_size_override("font_size", 17)
		special_btn.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		special_btn.pressed.connect(special_playtest_chosen.emit)
		_list.add_child(special_btn)

	# A first-time player has exactly one meaningful action. Do not present a
	# dead Load Game path (followed by three disabled slots) until a save
	# actually exists.
	if not _has_any_save():
		return
	var load_btn := Button.new()
	load_btn.text = "Load Game"
	load_btn.custom_minimum_size = Vector2(360, 40)
	load_btn.add_theme_font_size_override("font_size", 16)
	load_btn.modulate = Color(0.78, 0.82, 0.85)
	load_btn.pressed.connect(_open_slots.bind("load"))
	_list.add_child(load_btn)

func _on_new_game_pressed() -> void:
	# With no prior run there is nothing useful to distinguish three empty
	# slots. One click starts in slot 0; once saves exist, the slot picker is
	# retained so players can choose an empty slot or intentionally overwrite.
	if not _has_any_save():
		new_game_chosen.emit(0)
		return
	_open_slots("new")

func _has_any_save() -> bool:
	for slot in range(SaveManager.SLOT_COUNT):
		# A corrupt/empty file is treated as an empty slot everywhere else in
		# this screen, so it must not resurrect a Load Game action with no
		# enabled destination.
		if not SaveManager.read_slot(slot).is_empty():
			return true
	return false

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
# Maxilani regardless of who's "active" in the save.
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
