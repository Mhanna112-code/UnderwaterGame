# Shown by World when a diver enters a visible artifact guardian
# (see world.gd's _on_item_guardian_triggered()/_offer_special_encounter())
# - two screens, only one visible at a time:
#   confirm: explains the stakes (special ability needed, a timed
#     challenge, real treasure, no permadeath) with Enter/Not Now.
#   select: a rotating carousel of the three divers - 3D model preview,
#     name, ability - Left/Right to cycle, Enter to commit to that diver,
#     Back returns to confirm.
# Same paused-but-interactive shape as TitleScreen/GameOverScreen -
# process_mode ALWAYS so input still works while get_tree().paused
# freezes the world underneath.
class_name SpecialEncounterPrompt
extends Control

signal diver_chosen(model_name: String)
signal cancelled

# Flavor-only, not read anywhere else - a short tutorial for the carousel,
# read right before committing to a diver. MODIFIED: was a one-line
# reminder of what the ability does out in the WORLD ("Swap places with a
# teammate") - not actually useful here, since this screen is about which
# diver survives the SPECIAL ENCOUNTER's own minigame, a completely
# different mechanic per diver (see rock_dodge_minigame.gd/
# diver_swap_minigame.gd). Rewritten to explain that minigame specifically,
# so a player picking blind knows what they're about to be asked to do.
const ABILITY_BLURBS := {
	"swap": "In the encounter: portraits fly in from the enemy. Watch which one matches the reference sitting in each slot, then Left/Right and E to swap into a mismatched slot before it lands.",
	"grapple": "In the encounter: click to capture the mouse, aim at the glowing yellow weak spot, and left-click to grapple it. Each incoming rock needs two weak-spot hits before impact.",
	"shockwave": "In the encounter: three lanes come in at once - one rock, two solid walls. Hold Left/Right to lean into that lane (let go to snap back to middle) and line up with the rock, then E to shockwave it before it lands. Standing in a wall's lane gets you hit.",
}

const ROSTER := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]

var _mode := "confirm"
var _carousel_index := 0

var _confirm_panel: Control
var _select_panel: Control
var _preview_vp: SubViewport
var _preview_diver: Diver
var _name_label: Label
var _ability_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# set_anchors_preset() alone leaves offsets at their default zero, which
	# for a runtime-built Control parented directly under a CanvasLayer (no
	# parent Control to inherit a size from) collapses the whole rect to
	# (0, 0) - everything nested inside then renders pinned to the top-left
	# corner instead of filling the screen. Same bug title_screen.gd hit;
	# set_anchors_and_offsets_preset() is the fix there too.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_confirm_panel = _build_confirm_panel()
	add_child(_confirm_panel)

	_select_panel = _build_select_panel()
	_select_panel.visible = false
	add_child(_select_panel)

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mode = "confirm"
	_confirm_panel.visible = true
	_select_panel.visible = false

func close() -> void:
	visible = false

func _build_confirm_panel() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# MODIFIED (added): CenterContainer centers based on its child's own
	# minimum size, but a child without an explicit shrink size flag can
	# still end up laid out against the top-left corner instead of centered
	# - this popup was doing exactly that in practice. Forcing shrink-center
	# on both axes here is the standard fix.
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(420, 0)
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(col)

	var title := Label.new()
	title.text = "Something Guards This Place"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(title)

	var body := Label.new()
	body.text = "Breaking through will take one diver's special ability to survive a timed challenge - and the reward is real.\n\nIf that diver falls here, they won't be lost - they'll wash back out with the health they went in with."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color(0.75, 0.85, 0.9))
	col.add_child(body)

	var enter_btn := Button.new()
	enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = Vector2(420, 44)
	enter_btn.pressed.connect(_on_enter_pressed)
	col.add_child(enter_btn)

	var not_now_btn := Button.new()
	not_now_btn.text = "Not Now"
	not_now_btn.custom_minimum_size = Vector2(420, 40)
	not_now_btn.pressed.connect(func() -> void: cancelled.emit())
	col.add_child(not_now_btn)

	return center

func _on_enter_pressed() -> void:
	_mode = "select"
	_confirm_panel.visible = false
	_select_panel.visible = true
	_carousel_index = 0
	_refresh_carousel()

func _build_select_panel() -> Control:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Choose who goes"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	col.add_child(heading)

	# Left arrow / 3D preview / right arrow, side by side - the preview
	# itself is a small SubViewport with its own camera and one live Diver
	# instance, same recipe battle.gd's own stage uses (SubViewportContainer
	# + SubViewport + Camera3D + Diver.new()), just facing the camera
	# instead of facing away (battle's party puppets show their backs to
	# the camera on purpose - a showcase screen wants the opposite).
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)

	var left_btn := Button.new()
	left_btn.text = "<"
	left_btn.custom_minimum_size = Vector2(50, 220)
	left_btn.pressed.connect(_cycle.bind(-1))
	row.add_child(left_btn)

	var preview_container := SubViewportContainer.new()
	preview_container.custom_minimum_size = Vector2(280, 260)
	preview_container.stretch = true
	row.add_child(preview_container)

	_preview_vp = SubViewport.new()
	_preview_vp.size = Vector2i(280, 260)
	_preview_vp.transparent_bg = true
	_preview_vp.disable_3d = false
	# Keep the carousel's review model isolated from the live overworld. A
	# SubViewport shares its parent's World3D by default, which made nearby
	# divers, guardians and scenery appear stacked inside this preview.
	_preview_vp.own_world_3d = true
	preview_container.add_child(_preview_vp)

	var cam := Camera3D.new()
	cam.fov = 55.0
	# look_at_from_position(), not position + look_at() - this whole panel
	# is still an orphan subtree at this point (returned by this function,
	# only added to the live tree by _ready()'s caller afterward), and
	# look_at() needs global_transform, which doesn't resolve until a node
	# is actually inside the tree. look_at_from_position() sets both
	# position and orientation in one call without that requirement.
	cam.look_at_from_position(Vector3(0.0, 1.2, 3.2), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_preview_vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	_preview_vp.add_child(light)

	var right_btn := Button.new()
	right_btn.text = ">"
	right_btn.custom_minimum_size = Vector2(50, 220)
	right_btn.pressed.connect(_cycle.bind(1))
	row.add_child(right_btn)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	col.add_child(_name_label)

	_ability_label = Label.new()
	_ability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_label.add_theme_color_override("font_color", Color(0.6, 0.85, 0.7))
	# MODIFIED (added): ABILITY_BLURBS grew from a short one-liner into an
	# actual tutorial sentence - without autowrap this would just run off
	# the edges of the screen instead of wrapping under the diver preview.
	_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ability_label.custom_minimum_size = Vector2(360, 0)
	col.add_child(_ability_label)

	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 12)
	col.add_child(button_row)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(150, 40)
	back_btn.pressed.connect(_on_back_pressed)
	button_row.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Send Them In"
	confirm_btn.custom_minimum_size = Vector2(180, 40)
	confirm_btn.pressed.connect(func() -> void: diver_chosen.emit(String(ROSTER[_carousel_index])))
	button_row.add_child(confirm_btn)

	return col

func _cycle(dir: int) -> void:
	_carousel_index = (_carousel_index + dir + ROSTER.size()) % ROSTER.size()
	_refresh_carousel()

func _on_back_pressed() -> void:
	_mode = "confirm"
	_select_panel.visible = false
	_confirm_panel.visible = true

# Rebuilds the preview Diver from scratch on every cycle rather than
# swapping model_name on a persistent one - Diver._build_stats()/model
# setup all run from _ready(), so a fresh instance is the reliable way to
# get a clean model swap instead of fighting whatever a live Diver
# assumes only happens once.
func _refresh_carousel() -> void:
	if _preview_diver != null and is_instance_valid(_preview_diver):
		_preview_diver.queue_free()
	var model_name := String(ROSTER[_carousel_index])
	_preview_diver = Diver.new()
	_preview_diver.model_name = model_name
	_preview_diver.can_be_selected = false
	_preview_vp.add_child(_preview_diver)
	_preview_diver.rotation.y = PI   # faces the camera - the opposite of battle's party puppets on purpose

	# MODIFIED: was its own local {model_name: display_name} dict, duplicating
	# (and drifting from - it still said "Mermaid"/"Diver Boy"/"Marine Man"
	# after Cast.DISPLAY_NAMES moved to Maxilani/Musashi/Mech Pilot) the one
	# real source of truth. Cast.display_name() is what battle.gd's own
	# _display() already defers to - one name, one meaning, everywhere.
	_name_label.text = Cast.display_name(model_name)
	var ability_id := String(Diver.BASE_STATS.get(model_name, {}).get("ability", ""))
	_ability_label.text = String(ABILITY_BLURBS.get(ability_id, ""))
