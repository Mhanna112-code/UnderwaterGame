extends CanvasLayer
## Brief, non-interactive victory and omen over the actual defeated battlefield.
signal beat_changed(beat: String)
signal completed

var battlefield_texture: Texture2D
var _shade: ColorRect
var _center: CenterContainer
var _copy: VBoxContainer
var _title: Label
var _body: Label

func _ready() -> void:
	layer = 35 # Above Battle; below the subsequent movie's layer 40.
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("prologue_victory_bridge")
	var backing := ColorRect.new()
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backing.color = Color(0.015, 0.035, 0.05)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)
	var battlefield := TextureRect.new()
	battlefield.name = "DefeatedBattlefield"
	battlefield.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	battlefield.texture = battlefield_texture
	battlefield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battlefield.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battlefield)
	_shade = ColorRect.new()
	_shade.name = "InputBlocker"
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.015, 0.035, 0.05, 0.22)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_shade)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.add_child(_center)
	_copy = VBoxContainer.new()
	_copy.add_theme_constant_override("separation", 12)
	_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center.add_child(_copy)
	_title = _label(44, Color("a8f4d9"))
	_body = _label(22, Color("e4f4f7"))
	_copy.add_child(_title)
	_copy.add_child(_body)
	get_viewport().size_changed.connect(_layout)
	_layout()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run_beats()

func _run_beats() -> void:
	_title.text = "Victory"
	_body.text = "The Angler is defeated."
	_center.modulate.a = 0.0
	beat_changed.emit("victory")
	var victory := _tween()
	victory.tween_property(_center, "modulate:a", 1.0, 0.25)
	victory.tween_interval(2.05)
	await victory.finished
	await _fade_copy_out()
	_title.text = "Your victory has not gone unnoticed."
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_color", Color("d4e8ef"))
	_body.visible = false
	beat_changed.emit("notice")
	var notice := _tween()
	notice.set_parallel(true)
	notice.tween_property(_shade, "color", Color(0.008, 0.018, 0.03, 0.82), 0.6)
	notice.tween_property(_center, "modulate:a", 1.0, 0.18)
	notice.chain().tween_interval(1.33)
	await notice.finished
	await _fade_copy_out()
	_title.text = "Something stirs in the deep."
	_title.add_theme_font_size_override("font_size", 30)
	beat_changed.emit("omen")
	var omen := _tween()
	omen.tween_property(_center, "modulate:a", 1.0, 0.18)
	omen.tween_interval(1.62)
	omen.tween_property(_shade, "color", Color.BLACK, 0.3)
	omen.parallel().tween_property(_center, "modulate:a", 0.0, 0.3)
	await omen.finished
	visible = false
	completed.emit()
	queue_free()

func _fade_copy_out() -> void:
	var fade := _tween()
	fade.tween_property(_center, "modulate:a", 0.0, 0.12)
	await fade.finished

func _tween() -> Tween:
	return create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _layout() -> void:
	_copy.custom_minimum_size.x = minf(620.0, maxf(240.0, get_viewport().get_visible_rect().size.x - 48.0))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		get_viewport().set_input_as_handled()
