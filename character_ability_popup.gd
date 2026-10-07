extends Control

# Autoload singleton (no class_name: it would collide with the autoload name).
# Pages through {slot, title, body} entries; PopupClose reads "Next" until the last
# page, then "Close". Highlights the HUD Slot of the diver each page describes.
signal closed

# Video clips rely on the player being constrained to MediaFrame (see _refresh_media()).
const ENABLE_VIDEO_CLIPS := true

var _pages: Array[Dictionary] = []
var _index := 0
var _pending_batches: Array[Dictionary] = []
var _page_owner: WeakRef
var _mouse_mode_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false
var _owns_pause := false
# Cached WASD texture; warmed in _ready() since the SubViewport render takes a few frames.
var _wasd_texture: ImageTexture = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Root ignores input so its rect can't swallow world input while the panel is hidden.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above every HUD CanvasLayer.
	($UI as CanvasLayer).layer = 100
	(%PopupClose as Button).pressed.connect(_on_next_pressed)
	_style_panel()
	_build_close_button()
	get_viewport().size_changed.connect(_layout_text_page)
	# PanelContainer starts visible; hide until open().
	(%AbilityExplanationPanel as PanelContainer).hide()
	# Warm the WASD texture ahead of first use.
	_wasd_cluster_texture()

# Escape closes the popup (the tree is paused, so World can't handle it).
func _unhandled_input(event: InputEvent) -> void:
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

# Corner X closes from any page. Wrapped in a non-Container Control so the
# PanelContainer doesn't force it to the full rect.
func _build_close_button() -> void:
	var panel := %AbilityExplanationPanel as PanelContainer
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(overlay)
	var btn := Button.new()
	btn.text = "×"
	var btn_size := Vector2(28, 28)
	btn.custom_minimum_size = btn_size
	btn.add_theme_font_size_override("font_size", 16)
	btn.pressed.connect(_close)
	# Explicit anchors from a fixed size: PRESET_MODE_MINSIZE mismeasures before add_child().
	var inset := 12.0
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 0.0
	btn.anchor_bottom = 0.0
	btn.offset_right = -inset
	btn.offset_left = -inset - btn_size.x
	btn.offset_top = inset
	btn.offset_bottom = inset + btn_size.y
	overlay.add_child(btn)

# Pulses PopupClose so the next button to press is always obvious.
func _process(_delta: float) -> void:
	# Show deferred batches once no battle is running and the tree isn't paused.
	if not _pending_batches.is_empty() and not _battle_running() and not get_tree().paused \
			and not (%AbilityExplanationPanel as PanelContainer).visible:
		var batch: Dictionary = _pending_batches.pop_front()
		var owner_ref: WeakRef = batch.get("owner")
		if owner_ref == null or is_instance_valid(owner_ref.get_ref()):
			_display_pages(batch["pages"], owner_ref)
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		return
	var flash := 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
	(%PopupClose as Button).modulate.a = flash

# Dark blue fill, white outline. Plain Control rather than PopupPanel (Window
# subclass), which crashed some machines on boot.
func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.22)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	(%AbilityExplanationPanel as PanelContainer).add_theme_stylebox_override("panel", style)
	# Explicit light font color; the default is unreadable on the dark fill.
	(%Title as Label).add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	var media_style := StyleBoxFlat.new()
	media_style.bg_color = Color(0.03, 0.08, 0.11)
	media_style.border_color = Color(0.25, 0.42, 0.48)
	media_style.set_border_width_all(1)
	(%MediaFrame as PanelContainer).add_theme_stylebox_override("panel", media_style)

func _battle_running() -> bool:
	return is_inside_tree() and get_tree().get_first_node_in_group("battle") != null

func suspend_for_battle() -> void:
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		return
	_pending_batches.push_front({"pages": _pages.slice(_index), "owner": _page_owner})
	_clear_highlights()
	_clear_media()
	(%AbilityExplanationPanel as PanelContainer).hide()
	_pages = []
	# Battle now owns pause/cursor; don't restore exploration capture over it.
	if _owns_pause:
		get_tree().paused = false
	_owns_pause = false

# `owner` keeps pages from outliving their World/Maze scene; optional.
func open(pages: Array[Dictionary], owner: Node = null) -> void:
	if pages.is_empty():
		return
	var owner_ref: WeakRef = weakref(owner) if is_instance_valid(owner) else null
	if _battle_running():
		_pending_batches.append({"pages": pages, "owner": owner_ref})
		return
	_display_pages(pages, owner_ref)

func _display_pages(pages: Array[Dictionary], owner_ref: WeakRef) -> void:
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		_mouse_mode_before = Input.mouse_mode
		_paused_before = get_tree().paused
	_clear_highlights()
	_pages = pages
	_page_owner = owner_ref
	_index = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_owns_pause = true
	get_tree().paused = true
	_refresh()
	(%AbilityExplanationPanel as PanelContainer).show()

func _refresh() -> void:
	var page := _pages[_index]
	(%Title as Label).text = String(page.get("title", ""))
	_build_paragraph(String(page.get("body", "")))
	for p in _pages:
		var slot: Variant = p.get("slot")
		if is_instance_valid(slot):
			slot.set_highlighted(slot == page.get("slot"))
	(%PopupClose as Button).text = "Close" if _index >= _pages.size() - 1 else "Next"
	var page_slot: Variant = page.get("slot")
	# "media" overrides the clip for divers with multiple pages; otherwise derived from ability_id.
	# "media_control": a Callable returning a Control to show instead of a clip.
	if page.get("media_control") is Callable:
		_show_media_control((page["media_control"] as Callable).call())
		return
	var media_key: String = String(page.get("media", page_slot.diver.ability_id if is_instance_valid(page_slot) and is_instance_valid(page_slot.diver) else ""))
	_refresh_media(media_key)
	_layout_text_page()

func _layout_text_page() -> void:
	# Fit text-only pages to the viewport; media pages keep their authored layout.
	if (%MediaFrame as Control).visible:
		return
	var viewport := get_viewport_rect().size
	var width := minf(720, viewport.x - 32)
	var height := minf(340, viewport.y - 32)
	var panel := %AbilityExplanationPanel as Control
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -height * 0.5
	panel.offset_bottom = height * 0.5
	(%Title as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _show_media_control(media: Control) -> void:
	var frame := %MediaFrame as PanelContainer
	frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in frame.get_children():
		child.queue_free()
	frame.show()
	media.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(media)

# Rebuilds the paragraph label. WASD_MARKER is replaced by an inline image of the
# key cluster so RichTextLabel handles wrapping.
func _build_paragraph(body: String) -> void:
	var paragraph := %Paragraph as Control
	for child in paragraph.get_children():
		child.queue_free()
	var label := _rich_label()
	paragraph.add_child(label)
	var parts := body.split(Slot.WASD_MARKER)
	_append_with_markers(label, parts[0])
	if parts.size() > 1:
		var tex := await _wasd_cluster_texture()
		# The page may be replaced while awaiting the texture; don't write into a freed label.
		if not is_instance_valid(label) or label.is_queued_for_deletion():
			return
		# Native size; RichTextLabel grows the line height to fit.
		label.add_image(tex, int(WASD_CLUSTER_SIZE.x), int(WASD_CLUSTER_SIZE.y))
		_append_with_markers(label, parts[1])

# Swaps Slot.SMALL_MARKER/SPECIAL_MARKER for inline minimap marker swatches.
func _append_with_markers(label: RichTextLabel, text: String) -> void:
	var rest := text
	while true:
		var small_at := rest.find(Slot.SMALL_MARKER)
		var special_at := rest.find(Slot.SPECIAL_MARKER)
		if small_at < 0 and special_at < 0:
			break
		var special := small_at < 0 or (special_at >= 0 and special_at < small_at)
		var at := special_at if special else small_at
		var marker := Slot.SPECIAL_MARKER if special else Slot.SMALL_MARKER
		label.append_text(rest.substr(0, at))
		var tex := _marker_swatch(special)
		label.add_image(tex, tex.get_width(), tex.get_height(), Color.WHITE, INLINE_ALIGNMENT_CENTER)
		rest = rest.substr(at + marker.length())
	label.append_text(rest)

# Minimap red circles at popup scale, keeping their size ratio. Built from an Image.
const _MARKER_RED := Color(1.0, 0.18, 0.18)
const _MARKER_OUTLINE := Color(1.0, 0.75, 0.75)
var _marker_swatches := {}

func _marker_swatch(special: bool) -> ImageTexture:
	if _marker_swatches.has(special):
		return _marker_swatches[special]
	var radius := 9.0 if special else 5.7
	var size := 22
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := (size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var fill := clampf(radius + 0.5 - d, 0.0, 1.0)
			if fill <= 0.0:
				continue
			var col := _MARKER_RED
			if special and d > radius - 1.6:
				col = _MARKER_OUTLINE
			col.a = fill
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_marker_swatches[special] = tex
	return tex

func _rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# RichTextLabel uses "default_color", not "font_color".
	label.add_theme_color_override("default_color", Color(0.8, 0.88, 0.9))
	return label

# Shared by the cluster layout and its rendered texture/inline image size.
const _KEY_SIZE := Vector2(26, 26)
const _KEY_GAP := 3
const _CLUSTER_PAD := Vector2(3, 4)   # transparent padding baked into the texture
const WASD_CLUSTER_CONTENT_SIZE := Vector2(_KEY_SIZE.x * 3 + _KEY_GAP * 2, _KEY_SIZE.y * 2 + _KEY_GAP)
const WASD_CLUSTER_SIZE := WASD_CLUSTER_CONTENT_SIZE + _CLUSTER_PAD * 2

# Renders _wasd_cluster() once into an off-screen SubViewport and caches it.
func _wasd_cluster_texture() -> ImageTexture:
	if _wasd_texture != null:
		return _wasd_texture
	var vp := SubViewport.new()
	vp.size = Vector2i(WASD_CLUSTER_SIZE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", int(_CLUSTER_PAD.x))
	margin.add_theme_constant_override("margin_right", int(_CLUSTER_PAD.x))
	margin.add_theme_constant_override("margin_top", int(_CLUSTER_PAD.y))
	margin.add_theme_constant_override("margin_bottom", int(_CLUSTER_PAD.y))
	vp.add_child(margin)
	margin.add_child(_wasd_cluster())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_wasd_texture = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return _wasd_texture

# Keycap: bordered square with one letter.
func _key_badge(letter: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.border_color = Color.BLACK
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", style)
	badge.custom_minimum_size = _KEY_SIZE
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(label)
	return badge

# W centered above A/S/D via a 3-column grid with spacers.
func _wasd_cluster() -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", _KEY_GAP)
	grid.add_theme_constant_override("v_separation", _KEY_GAP)
	var spacer_a := Control.new()
	spacer_a.custom_minimum_size = _KEY_SIZE
	var spacer_b := Control.new()
	spacer_b.custom_minimum_size = _KEY_SIZE
	grid.add_child(spacer_a)
	grid.add_child(_key_badge("W"))
	grid.add_child(spacer_b)
	grid.add_child(_key_badge("A"))
	grid.add_child(_key_badge("S"))
	grid.add_child(_key_badge("D"))
	return grid

# Shows the demo clip/image for `ability_id` from TutorialContent.ABILITY_MEDIA, or a placeholder.
func _refresh_media(ability_id: String) -> void:
	var frame := %MediaFrame as PanelContainer
	frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in frame.get_children():
		child.queue_free()
	# No ability id (e.g. Inventory): hide the frame instead of showing a placeholder.
	if ability_id.is_empty():
		frame.hide()
		return
	frame.show()
	var path := String(TutorialContent.ABILITY_MEDIA.get(ability_id, ""))
	if path != "" and ResourceLoader.exists(path):
		if path.get_extension() == "ogv" and ENABLE_VIDEO_CLIPS:
			var player := VideoStreamPlayer.new()
			var video_stream := VideoStreamTheora.new()
			video_stream.file = path
			player.stream = video_stream
			# AspectRatioContainer keeps the 16:9 clip undistorted; expand=true ignores aspect.
			var aspect := AspectRatioContainer.new()
			aspect.ratio = 16.0 / 9.0
			aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			aspect.add_child(player)
			player.expand = true
			player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player.finished.connect(player.play)
			# Parent to the frame so the cleanup above frees it.
			frame.add_child(aspect)
			# Deferred rather than autoplay so decode doesn't start in the same frame the tree pauses.
			player.call_deferred("play")
			return
		var tex := load(path) as Texture2D
		if tex != null:
			var rect := TextureRect.new()
			rect.texture = tex
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			frame.add_child(rect)
			return
	var placeholder := Label.new()
	placeholder.text = "Clip\ncoming soon"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.add_theme_color_override("font_color", Color(0.35, 0.5, 0.55))
	frame.add_child(placeholder)

func _on_next_pressed() -> void:
	if _pages.is_empty():
		return
	if _index >= _pages.size() - 1:
		_close()
		return
	_index += 1
	_refresh()

func _clear_highlights() -> void:
	for p in _pages:
		var slot: Variant = p.get("slot")
		if is_instance_valid(slot):
			slot.set_highlighted(false)

func _clear_media() -> void:
	var frame := %MediaFrame as PanelContainer
	for player in frame.find_children("*", "VideoStreamPlayer", true, false):
		player.stop()
		player.stream = null
	for child in frame.get_children():
		frame.remove_child(child)
		child.queue_free()

func _close() -> void:
	_clear_highlights()
	_clear_media()
	(%AbilityExplanationPanel as PanelContainer).hide()
	_pages = []
	_page_owner = null
	if _owns_pause:
		get_tree().paused = _paused_before
		# Restore before `closed`: a listener may open another modal immediately.
		Input.mouse_mode = _mouse_mode_before
	_owns_pause = false
	closed.emit()
