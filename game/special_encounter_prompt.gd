# Special encounter prompt: confirm screen (stakes) then a diver carousel (Left/Right, Enter, Back).
# process_mode ALWAYS so it works while the tree is paused.
class_name SpecialEncounterPrompt
extends Control

signal diver_chosen(model_name: String)
signal cancelled

# Blurbs come from tutorial_content.gd; media from its SPECIAL_ENCOUNTER_MEDIA table.
const ROSTER := ["Staff_Diver", "Prototype_1(1910)", "Prototype_V(1922)"]

var _mode := "confirm"
var _carousel_index := 0

var _confirm_panel: Control
var _select_panel: Control
var _preview_vp: SubViewport
var _preview_diver: Diver
var _name_label: Label
var _ability_label: RichTextLabel
var _media_frame: PanelContainer
var _confirm_column: VBoxContainer
var _select_column: VBoxContainer
var _showcase: GridContainer
var _preview_container: SubViewportContainer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	# Offsets too, or a Control under a CanvasLayer collapses to (0, 0).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.08, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_confirm_panel = _build_confirm_panel()
	add_child(_confirm_panel)

	_select_panel = _build_select_panel()
	_select_panel.visible = false
	add_child(_select_panel)
	get_viewport().size_changed.connect(_layout)
	_layout()

func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_mode = "confirm"
	_confirm_panel.visible = true
	_select_panel.visible = false

func close() -> void:
	visible = false
	_stop_media()

func _layout() -> void:
	var available := get_viewport_rect().size - Vector2(32, 32)
	_confirm_column.custom_minimum_size.x = clampf(available.x, 240, 420)
	available.x = minf(available.x, 760)
	_select_column.custom_minimum_size.x = maxf(240, available.x)
	_showcase.columns = 1 if available.x < 620 else 2
	var portrait := available.x < 620
	var preview_height := 150.0 if portrait else clampf(available.y - 230.0, 150.0, 260.0)
	_preview_container.custom_minimum_size = Vector2(minf(280, available.x), preview_height)
	var video_width := minf(320, available.x)
	if not portrait:
		video_width = minf(video_width, (available.x - 20) * 0.5)
	_media_frame.custom_minimum_size = Vector2(video_width, video_width * 9.0 / 16.0)

func _stop_media() -> void:
	if _media_frame != null:
		for player in _media_frame.find_children("*", "VideoStreamPlayer", true, false):
			(player as VideoStreamPlayer).stop()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			if _mode == "select":
				_on_back_pressed()
			else:
				cancelled.emit()
		KEY_ENTER:
			if _mode == "confirm":
				_on_enter_pressed()
			else:
				diver_chosen.emit(String(ROSTER[_carousel_index]))
		KEY_LEFT:
			if _mode == "select":
				_cycle(-1)
		KEY_RIGHT:
			if _mode == "select":
				_cycle(1)
		_:
			return
	get_viewport().set_input_as_handled()

func _build_confirm_panel() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Shrink-center so the popup actually centers.
	center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var col := VBoxContainer.new()
	_confirm_column = col
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
	enter_btn.custom_minimum_size = Vector2(0, 44)
	enter_btn.pressed.connect(_on_enter_pressed)
	col.add_child(enter_btn)

	var not_now_btn := Button.new()
	not_now_btn.text = "Not Now"
	not_now_btn.custom_minimum_size = Vector2(0, 40)
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
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 16
	center.offset_top = 16
	center.offset_right = -16
	center.offset_bottom = -16
	var col := VBoxContainer.new()
	_select_column = col
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(col)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Choose who goes"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color(0.6, 0.7, 0.75))
	col.add_child(heading)

	# Responsive preview/video grid; the preview is a SubViewport with a live Diver facing the camera.
	var row := GridContainer.new()
	_showcase = row
	row.columns = 2
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("h_separation", 20)
	row.add_theme_constant_override("v_separation", 12)
	col.add_child(row)

	var left_btn := Button.new()
	left_btn.text = "<"
	left_btn.custom_minimum_size = Vector2(44, 40)
	left_btn.pressed.connect(_cycle.bind(-1))

	var preview_container := SubViewportContainer.new()
	_preview_container = preview_container
	preview_container.custom_minimum_size = Vector2(280, 260)
	preview_container.stretch = true
	row.add_child(preview_container)

	_preview_vp = SubViewport.new()
	_preview_vp.size = Vector2i(280, 260)
	_preview_vp.transparent_bg = true
	_preview_vp.disable_3d = false
	# Own World3D so overworld nodes don't appear in the preview.
	_preview_vp.own_world_3d = true
	preview_container.add_child(_preview_vp)

	var cam := Camera3D.new()
	cam.fov = 55.0
	# look_at_from_position() works before the node is in the tree; look_at() doesn't.
	cam.look_at_from_position(Vector3(0.0, 1.2, 3.2), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	_preview_vp.add_child(cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -30, 0)
	_preview_vp.add_child(light)

	# Demo clip/image slot beside the preview, rebuilt per diver in _refresh_media().
	_media_frame = PanelContainer.new()
	_media_frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	var media_bg := StyleBoxFlat.new()
	media_bg.bg_color = Color(0.03, 0.08, 0.11)
	media_bg.set_border_width_all(1)
	media_bg.border_color = Color(0.25, 0.42, 0.48)
	_media_frame.add_theme_stylebox_override("panel", media_bg)
	row.add_child(_media_frame)

	var right_btn := Button.new()
	right_btn.text = ">"
	right_btn.custom_minimum_size = Vector2(44, 40)
	right_btn.pressed.connect(_cycle.bind(1))
	var carousel_controls := HBoxContainer.new()
	carousel_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(carousel_controls)
	carousel_controls.add_child(left_btn)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carousel_controls.add_child(_name_label)
	carousel_controls.add_child(right_btn)

	# RichTextLabel so the controls show as key tiles (Slot._badge()).
	_ability_label = RichTextLabel.new()
	_ability_label.bbcode_enabled = true
	_ability_label.fit_content = true
	_ability_label.scroll_active = false
	_ability_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ability_label.add_theme_color_override("default_color", Color(0.6, 0.85, 0.7))
	# Autowrap: blurbs are full sentences.
	_ability_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_ability_label.custom_minimum_size = Vector2.ZERO
	col.add_child(_ability_label)

	var button_row := HBoxContainer.new()
	button_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button_row.add_theme_constant_override("separation", 12)
	col.add_child(button_row)

	var back_btn := Button.new()
	back_btn.text = "< Back"
	back_btn.custom_minimum_size = Vector2(140, 40)
	back_btn.pressed.connect(_on_back_pressed)
	button_row.add_child(back_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "Send Them In"
	confirm_btn.custom_minimum_size = Vector2(160, 40)
	confirm_btn.pressed.connect(func() -> void: diver_chosen.emit(String(ROSTER[_carousel_index])))
	button_row.add_child(confirm_btn)

	return center

func _cycle(dir: int) -> void:
	_carousel_index = (_carousel_index + dir + ROSTER.size()) % ROSTER.size()
	_refresh_carousel()

func _on_back_pressed() -> void:
	_stop_media()
	_mode = "confirm"
	_select_panel.visible = false
	_confirm_panel.visible = true

# Rebuild the preview Diver each cycle; model setup only runs in _ready().
func _refresh_carousel() -> void:
	if _preview_diver != null and is_instance_valid(_preview_diver):
		_preview_diver.queue_free()
	var model_name := String(ROSTER[_carousel_index])
	_preview_diver = Diver.new()
	_preview_diver.model_name = model_name
	_preview_diver.can_be_selected = false
	_preview_vp.add_child(_preview_diver)
	_preview_diver.rotation.y = PI  # faces the camera

	_name_label.text = Cast.display_name(model_name)
	var ability_id := String(Diver.BASE_STATS.get(model_name, {}).get("ability", ""))
	_ability_label.text = "[center]%s[/center]" % String(TutorialContent.ABILITY_BLURBS.get(ability_id, ""))
	_refresh_media(ability_id)

# Loads the demo clip/image for `ability_id`. Videos get expand + AspectRatioContainer, a fresh
# VideoStreamTheora per call (no shared decoder state), and loop by replaying on `finished`.
func _refresh_media(ability_id: String) -> void:
	for child in _media_frame.get_children():
		child.queue_free()
	var path := String(TutorialContent.SPECIAL_ENCOUNTER_MEDIA.get(ability_id, ""))
	if path != "" and ResourceLoader.exists(path):
		if path.get_extension() == "ogv":
			var player := VideoStreamPlayer.new()
			var video_stream := VideoStreamTheora.new()
			video_stream.file = path
			player.stream = video_stream
			player.expand = true
			var aspect := AspectRatioContainer.new()
			aspect.ratio = 16.0 / 9.0
			aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			aspect.add_child(player)
			player.finished.connect(player.play)
			_media_frame.add_child(aspect)
			# Deferred start so Theora decode doesn't contend with the build/pause transition.
			player.call_deferred("play")
			return
		var tex := load(path) as Texture2D
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_media_frame.add_child(rect)
			return
	var placeholder := Label.new()
	placeholder.text = "Tutorial clip\ncoming soon"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.add_theme_color_override("font_color", Color(0.35, 0.5, 0.55))
	_media_frame.add_child(placeholder)
