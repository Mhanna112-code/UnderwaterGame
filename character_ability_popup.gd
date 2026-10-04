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

# Embedded clips are enabled only after the player is constrained to its
# MediaFrame. See _refresh_media(): a non-expanded VideoStreamPlayer reports
# its native 1920x1080 source size as a minimum and can grow this small popup
# into a full-screen overlay.
const ENABLE_VIDEO_CLIPS := true

var _pages: Array[Dictionary] = []
var _index := 0
# Cached after the first render - see _wasd_cluster_texture(). Rendering the
# WASD cluster to a texture takes a couple of real frames (a SubViewport
# needs to actually draw before its texture is valid), so this is warmed in
# _ready() rather than the first time a page actually needs it.
var _wasd_texture: ImageTexture = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# This autoload Control stays visible for the lifetime of the game; only
	# its inner panel is hidden between uses. Ignore input on the root so its
	# centered 600x350 rect cannot swallow world mouse-look or IntroCrawl's
	# click-to-skip events while the panel is hidden. The panel and its child
	# buttons still receive input when the modal is open.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The modal's own CanvasLayer defaults to layer 1 - the same as a scene's
	# HUD layer - and the HUD is added after this autoload, so HUD captions
	# (e.g. the maze's orange warnings) drew on top of the open modal. Put
	# the modal above every HUD layer.
	($UI as CanvasLayer).layer = 100
	(%PopupClose as Button).pressed.connect(_on_next_pressed)
	_style_panel()
	_build_close_button()
	# PanelContainer defaults to visible, unlike a PopupPanel (which starts
	# hidden until .popup() is called) - hide it up front so it isn't just
	# sitting on screen from the moment the game boots, before open() is
	# ever called.
	(%AbilityExplanationPanel as PanelContainer).hide()
	# Fire-and-forget: by the time a player actually finishes the tutorial
	# and _show_ability_popups() first opens this, several real seconds have
	# passed, plenty for this one-time render to finish well ahead of need.
	_wasd_cluster_texture()

# Every other paged/modal overlay in this project (TutorialBook, IntroCrawl)
# closes on Escape - this one didn't, so Escape here did nothing at all: the
# popup has no listener for it, and get_tree().paused (set by open()) freezes
# World's own Escape handling underneath it too. _close() never ran, "closed"
# never fired, and anything depending on that signal never happened either.
func _unhandled_input(event: InputEvent) -> void:
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

# An always-reachable exit independent of which page you're on - PopupClose
# (below) only reads "Close" on the last page; everywhere else it reads
# "Next" and a corner X is the only way to leave outright, same "get me out
# of this modal" job TutorialBook's own corner X does (tutorial_book.gd).
# A PanelContainer stacks every direct child to the same content rect (the
# same trick MarginContainer uses for an overlay), so an extra child here
# sits on top of %Margin's own layout instead of pushing it aside; wrapped
# in a plain, non-Container Control first since a Container would otherwise
# force this new child to that same full rect too, fighting the anchor/
# offset that actually places the button in the corner.
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
	# Explicit anchors/offsets computed from a fixed size, not
	# set_anchors_and_offsets_preset()'s PRESET_MODE_MINSIZE - that reads
	# get_combined_minimum_size() at the moment it's called, and calling it
	# before add_child() (this button wasn't in the tree yet) measured a
	# stale, smaller size than the 28x28 + font-16 actually settled on,
	# undershooting the inset and leaving it hanging half outside the
	# panel's own rounded top-right corner instead of sitting inside it.
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

# Pulses PopupClose - Next on every page but the last, Close once it
# relabels itself there (see _refresh()) - so there's always exactly one
# flashing button pointing at "what to press next", same sine-pulse shape
# as [pulse] BBCode text elsewhere (pulse_text_effect.gd) and TutorialBook's
# own Next/Close pulse (tutorial_book.gd) rather than a third effect system.
func _process(_delta: float) -> void:
	if not (%AbilityExplanationPanel as PanelContainer).visible:
		return
	var flash := 0.35 + 0.65 * (0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.0))
	(%PopupClose as Button).modulate.a = flash

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
	# "media" lets a page pick its own clip explicitly - needed the moment a
	# diver gets more than one page (Maxilani's Swap and Sonar are two
	# separate pages now, see world.gd's _show_ability_popups()), since
	# page_slot.diver.ability_id alone is one fixed value per diver and
	# can't tell those two pages apart on its own. Falls back to that same
	# ability_id-derived lookup for a diver with only one page (Musashi,
	# Bucky), so they don't need to pass it explicitly.
	# "media_control": a Callable returning a Control to show in the media
	# frame instead of a clip file (e.g. a live-drawn demo animation).
	if page.get("media_control") is Callable:
		_show_media_control((page["media_control"] as Callable).call())
		return
	var media_key: String = String(page.get("media", page_slot.diver.ability_id if page_slot != null else ""))
	_refresh_media(media_key)

func _show_media_control(media: Control) -> void:
	var frame := %MediaFrame as PanelContainer
	frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in frame.get_children():
		child.queue_free()
	frame.show()
	media.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_child(media)

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
		# Native size, not squashed to fit a single text line - add_image()
		# used to force this into 54x18 against the texture's actual 90x63,
		# flattening the two-row W/A/S/D layout into an illegible sliver.
		# RichTextLabel grows that line's own height to fit the tallest
		# inline content automatically, so drawing it at the size it was
		# actually rendered at is enough on its own to give it room - no
		# manual newline needed, which would otherwise break "Use [WASD] and
		# move..." across a line for no reason.
		label.add_image(tex, int(WASD_CLUSTER_SIZE.x), int(WASD_CLUSTER_SIZE.y))
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

# Key badge/gap sizing, shared between _key_badge()/_wasd_cluster() (the
# layout) and _wasd_cluster_texture()/_build_paragraph() (the rendered
# result, which needs the same numbers to size the SubViewport and the
# inline image it becomes without either squashing or clipping it).
const _KEY_SIZE := Vector2(26, 26)
const _KEY_GAP := 3
const _CLUSTER_PAD := Vector2(3, 4)   # transparent breathing room baked into the texture itself
const WASD_CLUSTER_CONTENT_SIZE := Vector2(_KEY_SIZE.x * 3 + _KEY_GAP * 2, _KEY_SIZE.y * 2 + _KEY_GAP)
const WASD_CLUSTER_SIZE := WASD_CLUSTER_CONTENT_SIZE + _CLUSTER_PAD * 2

# Renders _wasd_cluster() once into an off-screen SubViewport and keeps the
# resulting texture for every page that needs it after - a SubViewport
# needs a couple of real frames to actually draw before its texture is
# valid, so doing this per-page-open would flash in a frame or two late
# every single time instead of just the first. Padded on all sides
# (_CLUSTER_PAD) rather than rendered tight to the grid's own edges, so the
# inline image _build_paragraph() drops into the paragraph text already
# carries its own breathing room instead of butting straight up against
# neighboring glyphs.
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

# A "keycap" - a black-bordered square with one letter, big enough to read
# clearly inline with the surrounding body text without looking like a
# smudge (the 18x18/font-11 version this replaced did, once forced through
# add_image()'s old 54x18 squash - see _build_paragraph()).
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

# W centered above A/S/D, same physical layout as the real keys - a 3-column
# grid with an empty same-sized spacer standing in for the two gaps flanking
# W on the top row. size_flags_horizontal = SIZE_SHRINK_BEGIN keeps the
# whole cluster hugging the left edge (matching the text it sits between)
# instead of stretching to fill %Paragraph's full width.
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
	frame.custom_minimum_size = TutorialContent.VIDEO_FRAME_SIZE
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for child in frame.get_children():
		child.queue_free()
	# Pages such as Inventory have no clip by design. Hide the entire media
	# frame instead of showing the generic "Clip coming soon" placeholder,
	# which is reserved for abilities that are expected to have media.
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
			if ability_id == "grapple":
				# The Grapple recording has pillarbox bars encoded into the video
				# itself. VideoStreamPlayer.expand scales the full source frame,
				# including those black margins, so crop the unused sides before
				# drawing it into MediaFrame.
				var crop_shader := Shader.new()
				crop_shader.code = """
				shader_type canvas_item;
				uniform float side_crop = 0.18;
				void fragment() {
					vec2 source_uv = UV;
					source_uv.x = mix(side_crop, 1.0 - side_crop, UV.x);
					COLOR = texture(TEXTURE, source_uv) * COLOR;
				}
				"""
				var crop_material := ShaderMaterial.new()
				crop_material.shader = crop_shader
				player.material = crop_material
			# expand=true scales the video to fill whatever rect it's given,
			# with no aspect-ratio awareness at all (unlike TextureRect, which
			# has STRETCH_KEEP_ASPECT_CENTERED below) - filling %MediaFrame's
			# own ~160x140 rect directly stretched a 1920x1080 (16:9) source
			# into a near-square frame, visibly squashed. AspectRatioContainer
			# is what actually keeps it undistorted: it sizes/centers its one
			# child to the given ratio and lets expand=true fill THAT correctly
			# proportioned rect instead of the mismatched frame directly.
			var aspect := AspectRatioContainer.new()
			aspect.ratio = 16.0 / 9.0
			aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			aspect.add_child(player)
			player.expand = true
			player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			player.finished.connect(player.play)
			# Parented to frame (%MediaFrame), not self - a plain add_child()
			# here put it on the popup's own root instead, which (a) never
			# gets cleared by this function's own frame.get_children() cleanup
			# above, leaking a new VideoStreamPlayer every time this page is
			# shown again, and (b) left it outside the frame cleanup path instead
			# of keeping the clip inside this small MediaFrame.
			frame.add_child(aspect)
			# Not autoplay=true - that starts Theora decode synchronously the
			# same frame this popup pauses the tree and _wasd_cluster_texture()
			# may still be mid-render (its own SubViewport awaits two
			# RenderingServer.frame_post_draw signals). Deferring play() one
			# frame lets that settle first, in case decode contending with an
			# in-flight SubViewport render is what was stalling the whole
			# screen to black rather than just this player's own small frame.
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
