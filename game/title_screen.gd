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

const COVER_ART: Texture2D = preload("res://docs/underwater-cover.png")

signal new_game_chosen(slot: int)
signal load_game_chosen(slot: int)
signal boss_playtest_chosen
signal guardian_playtest_chosen
signal special_playtest_chosen
signal onboarding_playtest_chosen
signal spell_playtest_chosen

var _mode := "main"
var _pending_action := "new"   # "new" | "load"

var _list: VBoxContainer
var _boss_playtest_available := false
var _guardian_playtest_available := false
var _guardian_playtest_label := "Play Guardian Test"
var _special_playtest_available := false
var _onboarding_playtest_available := false
# This is review-only plumbing like the boss/guardian/special/onboarding
# entries above.  It never appears in a normal first-player title flow.
var _spell_playtest_available := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# PRESET_FULL_RECT anchors alone preserve this Control's initial zero-size
	# offsets. That leaves the CenterContainer with a (0, 0) parent rectangle,
	# collapsing the title and both actions into the upper-left corner. Reset
	# anchors and offsets together so this runtime-built overlay owns the full
	# viewport at every supported resolution.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Glass_Goat's finished cover is the title surface itself, not a loading
	# splash or a detached promotional image. KEEP_ASPECT_COVERED prevents
	# stretching at non-16:9 resolutions; the art may crop at the edges but its
	# proportions never change.
	var cover := TextureRect.new()
	cover.name = "CoverArt"
	cover.texture = COVER_ART
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)

	# Keep the illustration visible while giving the title and buttons a stable
	# contrast floor across its darkest and brightest areas.
	var shade := ColorRect.new()
	shade.name = "ReadabilityShade"
	shade.color = Color(0.01, 0.025, 0.055, 0.28)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.name = "MenuCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.name = "MenuPanel"
	panel.custom_minimum_size = Vector2(424, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.015, 0.045, 0.075, 0.84)
	panel_style.border_color = Color(0.35, 0.68, 0.8, 0.62)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.name = "GameTitle"
	title.text = "Underwater"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.14, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
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

# Like the boss route, this is query-only review infrastructure. It keeps the
# normal first-player title surface untouched while letting Glassgoat inspect
# the far artifact guardian without navigating through saves and encounters.
func enable_guardian_playtest(label: String) -> void:
	_guardian_playtest_available = true
	_guardian_playtest_label = label
	if visible and _mode == "main":
		_refresh()

# Like the boss route above, this is opt-in review plumbing rather than part
# of the ordinary New/Load flow. It lets a reviewer reach the guardian chooser
# and all three ability minigames without first navigating the full map.
func enable_special_playtest() -> void:
	_special_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# A reviewer needs to inspect the post-tutorial world-control surface without
# replaying the deliberately paced combat lesson. Like the existing query-only
# boss/guardian/special routes, World enables this only for its review URL;
# normal New/Load presentation never receives a dev button.
func enable_onboarding_playtest() -> void:
	_onboarding_playtest_available = true
	if visible and _mode == "main":
		_refresh()

# Opens the actual save-point spell UI with temporary review resources.  The
# World owns the no-save contract and resource setup; TitleScreen only makes
# the opt-in route visible for ?spells=1 / --spell-playtest reviewers.
func enable_spell_playtest() -> void:
	_spell_playtest_available = true
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

	if _guardian_playtest_available:
		var guardian_btn := Button.new()
		guardian_btn.text = _guardian_playtest_label
		guardian_btn.tooltip_text = "Swordfish Duelist model, animation, and guardian battle validation"
		guardian_btn.custom_minimum_size = Vector2(360, 46)
		guardian_btn.add_theme_font_size_override("font_size", 17)
		guardian_btn.add_theme_color_override("font_color", Color(0.68, 0.88, 1.0))
		guardian_btn.pressed.connect(guardian_playtest_chosen.emit)
		_list.add_child(guardian_btn)

	if _special_playtest_available:
		var special_btn := Button.new()
		special_btn.text = "Play Special Encounter Test"
		special_btn.tooltip_text = "Choose a diver and test their ability minigame"
		special_btn.custom_minimum_size = Vector2(360, 46)
		special_btn.add_theme_font_size_override("font_size", 17)
		special_btn.add_theme_color_override("font_color", Color(0.65, 0.9, 1.0))
		special_btn.pressed.connect(special_playtest_chosen.emit)
		_list.add_child(special_btn)

	if _onboarding_playtest_available:
		var onboarding_btn := Button.new()
		onboarding_btn.text = "Review World Controls"
		onboarding_btn.tooltip_text = "Inspect the post-tutorial controls walkthrough"
		onboarding_btn.custom_minimum_size = Vector2(360, 46)
		onboarding_btn.add_theme_font_size_override("font_size", 17)
		onboarding_btn.add_theme_color_override("font_color", Color(0.62, 0.92, 0.82))
		onboarding_btn.pressed.connect(onboarding_playtest_chosen.emit)
		_list.add_child(onboarding_btn)

	if _spell_playtest_available:
		var spell_btn := Button.new()
		spell_btn.text = "Play Spell Test"
		spell_btn.tooltip_text = "Open the real spell interface with temporary spell points and every key item. This never writes a save."
		spell_btn.custom_minimum_size = Vector2(360, 46)
		spell_btn.add_theme_font_size_override("font_size", 17)
		spell_btn.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		spell_btn.pressed.connect(spell_playtest_chosen.emit)
		_list.add_child(spell_btn)

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
