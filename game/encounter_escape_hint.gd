extends PanelContainer
## Transient information only: World owns the R setting and all gameplay.
const DURATION := 3.0
var setting_label: Label
var help_label: Label
var _elapsed := 0.0
var _enabled := true
var _style: StyleBoxFlat

func _ready() -> void:
	name = "EscapeEncounterHint"
	# Expire even if the player immediately opens a paused menu. No pending
	# timer/tween can resurrect a retired cue or extend its deadline.
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.025, 0.12, 0.17, 0.96)
	_style.border_color = Color(0.42, 0.85, 0.88)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	_style.content_margin_left = 12
	_style.content_margin_right = 12
	_style.content_margin_top = 10
	_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", _style)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 5)
	add_child(rows)
	setting_label = Label.new()
	setting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setting_label.add_theme_font_size_override("font_size", 22)
	setting_label.add_theme_color_override("font_color", Color(0.84, 1.0, 1.0))
	setting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(setting_label)
	help_label = Label.new()
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.add_theme_font_size_override("font_size", 16)
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(help_label)
	get_viewport().size_changed.connect(_layout)
	_layout()
	dismiss()

func show_after_escape(encounters_enabled: bool) -> void:
	_elapsed = 0.0
	visible = true
	set_encounters_enabled(encounters_enabled)

func set_encounters_enabled(encounters_enabled: bool) -> void:
	_enabled = encounters_enabled
	setting_label.text = "R: Encounters (%s)" % ("On" if _enabled else "Off")
	help_label.text = "Turn encounters off while heading to a save point." if _enabled else "Random encounters off. Head to a save point."
	# Updating the setting never resets the three-second lifetime.
	_update_contrast()

func dismiss() -> void:
	visible = false
	modulate = Color.WHITE

func _process(dt: float) -> void:
	if not visible:
		return
	_elapsed += dt
	if _elapsed >= DURATION:
		dismiss()
		return
	_update_contrast()

func _update_contrast() -> void:
	var pulse := (0.5 + 0.5 * sin(_elapsed * TAU)) if _enabled else 0.0
	_style.bg_color = Color(0.025, 0.12, 0.17, 0.96).lerp(Color(0.06, 0.25, 0.29, 0.96), pulse)
	_style.border_color = Color(0.42, 0.85, 0.88).lerp(Color(0.78, 1.0, 1.0), pulse)

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var width := minf(500.0, maxf(240.0, viewport_size.x - 32.0))
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = (viewport_size.x - width) * 0.5
	offset_right = offset_left + width
	# Below the objective (118px) AND minimap (166px), not over either.
	offset_top = 174.0
	offset_bottom = 256.0
