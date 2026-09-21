extends Control

# Autoload singleton (see project.godot's [autoload] section) - always
# present in the tree, reached globally as CharacterAbilityPopup.open(...)
# rather than instanced/added-as-a-child anywhere, so no class_name here
# (one would collide with the reserved autoload name and fail to compile).
#
# One popup, paged through a caller-supplied list of {slot, title, body}
# entries (see World._show_ability_popups()) - PopupClose doubles as both
# buttons the brief asked for: it reads "Next" and advances while there's
# another page left, then relabels itself to "Close" on the last one
# instead of the popup needing a second, separate button that would sit
# unused on every page but the last. Highlights whichever HUD Slot (see
# slot.gd) belongs to the diver the current page is about, the same
# "draw a border around the thing being explained" idea battle.gd's
# tutorial captions use on a stat row - so the popup and the HUD element
# it's describing are visually tied together while it's open.
signal closed

var _pages: Array[Dictionary] = []
var _index := 0
# Cached after the first render - see _wasd_cluster_texture(). Rendering the
# WASD cluster to a texture takes a couple of real frames (a SubViewport
# needs to actually draw before its texture is valid), so this is warmed in
# _ready() rather than the first time a page actually needs it.
var _wasd_texture: ImageTexture = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	(%PopupClose as Button).pressed.connect(_on_next_pressed)
	_style_panel()
	# PanelContainer defaults to visible, unlike a PopupPanel (which starts
	# hidden until .popup() is called) - hide it up front so it isn't just
	# sitting on screen from the moment the game boots, before open() is
	# ever called.
	(%AbilityExplanationPanel as PanelContainer).hide()
	# Fire-and-forget: by the time a player actually finishes the tutorial
	# and _show_ability_popups() first opens this, several real seconds have
	# passed, plenty for this one-time render to finish well ahead of need.
	_wasd_cluster_texture()

# Dark blue fill, white outline - a permanent look for the whole window,
# unlike Slot.set_highlighted()'s version of this same StyleBoxFlat
# technique, which toggles a border on/off per diver. A plain PanelContainer
# draws whatever's set on its own "panel" theme override as its background/
# border, same mechanism _row_stylebox() in battle.gd and set_highlighted()
# in slot.gd both already use. Not a PopupPanel (a Window subclass) - that
# was crashing this project's windowed/GPU-rendered launches outright the
# instant this autoload booted, before open() was ever even called, on at
# least one machine. Every other overlay in this project (TutorialBook,
# SpecialEncounterPrompt, InventoryMenu, TitleScreen) is a plain Control
# toggled by visibility for the same reason - this now matches them instead
# of being the only Window-based UI in the whole codebase.
func _style_panel() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.22)
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	(%AbilityExplanationPanel as PanelContainer).add_theme_stylebox_override("panel", style)
	# Default Label font color reads fine on the editor's own light gray
	# background but disappears against this dark blue fill - same reason
	# every other screen in the project (title_screen.gd, tutorial_book.gd,
	# inventory_menu.gd, ...) sets an explicit light font color rather than
	# relying on the theme default.
	(%Title as Label).add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	var media_style := StyleBoxFlat.new()
	media_style.bg_color = Color(0.03, 0.08, 0.11)
	media_style.border_color = Color(0.25, 0.42, 0.48)
	media_style.set_border_width_all(1)
	(%MediaFrame as PanelContainer).add_theme_stylebox_override("panel", media_style)

# `pages` entries: {"slot": Slot (or null), "title": String, "body": String}.
func open(pages: Array[Dictionary]) -> void:
	if pages.is_empty():
		return
	_pages = pages
	_index = 0
	get_tree().paused = true
	_refresh()
	(%AbilityExplanationPanel as PanelContainer).show()

func _refresh() -> void:
	var page := _pages[_index]
	(%Title as Label).text = String(page.get("title", ""))
	_build_paragraph(String(page.get("body", "")))
	for p in _pages:
		var slot: Slot = p.get("slot")
		if slot != null:
			slot.set_highlighted(slot == page.get("slot"))
	(%PopupClose as Button).text = "Close" if _index >= _pages.size() - 1 else "Next"
	var page_slot: Slot = page.get("slot")
	_refresh_media(String(page_slot.diver.ability_id) if page_slot != null else "")

# Rebuilds %Paragraph's one RichTextLabel from scratch every call. The
# inline [E]/[Q]/[Tab] badges are BBCode baked straight into the body string
# by slot.gd's _badge(), so a plain .text = body handles those. The WASD
# cluster can't be BBCode text (it's a 2D arrangement, not a run of
# characters), so a body containing Slot.WASD_MARKER is instead built with
# append_text()/add_image() - a rendered snapshot of the same cluster
# (_wasd_cluster_texture()) inserted as one inline "character" via
# RichTextLabel's own image support. That's what actually gets "same line
# as Use, wrapping to the next line only if it doesn't fit" for free -
# nothing here decides the line break, RichTextLabel's normal text layout
# does, the same as it would for an oversized letter.
func _build_paragraph(body: String) -> void:
	var paragraph := %Paragraph as Control
	for child in paragraph.get_children():
		child.queue_free()
	var label := _rich_label()
	paragraph.add_child(label)
	var parts := body.split(Slot.WASD_MARKER)
	label.append_text(parts[0])
	if parts.size() > 1:
		var tex := await _wasd_cluster_texture()
		label.add_image(tex, 54, 18)
		label.append_text(parts[1])

func _rich_label() -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# RichTextLabel's own base-text theme property is "default_color", not
	# Label's "font_color" - a [color=...] BBCode tag overrides this per-run,
	# but everything outside one (the ordinary prose) still needs this set or
	# it falls back to a barely-visible default against the dark blue fill.
	label.add_theme_color_override("default_color", Color(0.8, 0.88, 0.9))
	return label

# Renders _wasd_cluster() once into an off-screen SubViewport and keeps the
# resulting texture for every page that needs it after - a SubViewport
# needs a couple of real frames to actually draw before its texture is
# valid, so doing this per-page-open would flash in a frame or two late
# every single time instead of just the first.
func _wasd_cluster_texture() -> ImageTexture:
	if _wasd_texture != null:
		return _wasd_texture
	var vp := SubViewport.new()
	vp.size = Vector2i(60, 40)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(_wasd_cluster())
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	_wasd_texture = ImageTexture.create_from_image(vp.get_texture().get_image())
	vp.queue_free()
	return _wasd_texture

# A small "keycap" - a black-bordered square with one letter. Sized to sit
# within a line of body text (see _wasd_cluster()) rather than dominate it,
# unlike the bigger standalone badges this replaced.
func _key_badge(letter: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12)
	style.border_color = Color.BLACK
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	badge.add_theme_stylebox_override("panel", style)
	badge.custom_minimum_size = Vector2(18, 18)
	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(label)
	return badge

# W centered above A/S/D, same physical layout as the real keys - a 3-column
# grid with an empty same-sized spacer standing in for the two gaps flanking
# W on the top row. size_flags_horizontal = SIZE_SHRINK_BEGIN keeps the
# whole cluster hugging the left edge (matching the text it sits between)
# instead of stretching to fill %Paragraph's full width.
func _wasd_cluster() -> GridContainer:
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	var spacer_a := Control.new()
	spacer_a.custom_minimum_size = Vector2(18, 18)
	var spacer_b := Control.new()
	spacer_b.custom_minimum_size = Vector2(18, 18)
	grid.add_child(spacer_a)
	grid.add_child(_key_badge("W"))
	grid.add_child(spacer_b)
	grid.add_child(_key_badge("A"))
	grid.add_child(_key_badge("S"))
	grid.add_child(_key_badge("D"))
	return grid

# Swaps in whatever demo clip/image exists for `ability_id`, in the frame
# to the right of the body text - same loading logic as
# special_encounter_prompt.gd's own _refresh_media() (a still image loads
# into a TextureRect, a .ogv loops via a VideoStreamPlayer replaying itself
# on `finished`), reusing content/tutorial_content.gd's ABILITY_MEDIA table
# rather than a second copy of it. Neither file exists yet for any ability,
# so this always falls through to the placeholder today - same "reserve the
# spot, no code changes needed once a clip exists" reasoning as that other
# copy. "" (the World Map page, which isn't about any one ability) also
# falls through to the placeholder rather than a blank frame.
func _refresh_media(ability_id: String) -> void:
	var frame := %MediaFrame as PanelContainer
	for child in frame.get_children():
		child.queue_free()
	var path := String(TutorialContent.ABILITY_MEDIA.get(ability_id, ""))
	if path != "" and ResourceLoader.exists(path):
		if path.get_extension() == "ogv":
			var player := VideoStreamPlayer.new()
			player.stream = load(path)
			player.autoplay = true
			player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player.finished.connect(player.play)
			frame.add_child(player)
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
	if _index >= _pages.size() - 1:
		_close()
		return
	_index += 1
	_refresh()

func _close() -> void:
	for p in _pages:
		var slot: Slot = p.get("slot")
		if slot != null:
			slot.set_highlighted(false)
	(%AbilityExplanationPanel as PanelContainer).hide()
	get_tree().paused = false
	closed.emit()
