class_name Slot
extends PanelContainer

# A "[ E ]"-style keycap baked directly into the body text via BBCode
# ([bgcolor]+[outline_*]+[color], closed in reverse/LIFO order) rather than
# a separate widget - CharacterAbilityPopup's %Body is a bbcode_enabled
# RichTextLabel specifically so this renders right where the word actually
# falls in the sentence ("Press [E] to..."), not in a disconnected row
# underneath. Plain-text keys elsewhere (WASD's own diamond arrangement,
# which can't be inline since it's a 2D layout, not a run of text) still go
# through CharacterAbilityPopup's _key_badge()/_wasd_cluster() instead.
static func _badge(key: String) -> String:
	return "[bgcolor=#1a1a1e][outline_color=#000000][outline_size=8][color=#ffffff] %s [/color][/outline_size][/outline_color][/bgcolor]" % key

# Not BBCode-able like the single-key badges above - W/A/S/D need to be
# stacked (W above A/S/D, matching their real physical layout), which is a
# 2D arrangement no run of text can represent, inline or otherwise. Left in
# the body text as a plain marker instead; CharacterAbilityPopup splits the
# string on this token and drops its own small _wasd_cluster() widget in
# between the two halves, small enough to sit within the paragraph and
# left-aligned like the surrounding text, wrapping onto its own line only if
# it doesn't fit next to whatever text precedes it.
const WASD_MARKER := "{{WASD}}"

var worldExplanation := "In the world map, divers can freely swim around encountering enemies, finding items and progressing to new areas. Use %s and move the camera around with the mouse to swim and look around. Use %s to switch between active divers. Divers also have special abilities they can use to interact with the world." % [WASD_MARKER, _badge("Tab")]

var maxilaniAbilityTitle := "Maxilani — Swap/Sonar"
var maxilaniSwapBody := "Press %s while Maxilani is the active diver to swap positions with other divers, then use the left and right arrow keys to switch to the diver you want to swap with and press Enter to confirm and swap. You can first swap to the other divers with %s and favorably position them to strategically set up their positions to solve puzzles and other mechanics you encounter while swimming around, then swap back to Maxilani and activate her swap abiity." % [_badge("E"), _badge("Tab")]
var maxilaniSonarBody := "Maxilani has a built in sonar she can use to find hidden items in the world that appear as red circles in the minimap on the top-right of the screen. Toggle Sonar On/Off with %s to consume 3 oxygen after every 3 seconds which will reveal hidden items on the minimap as you swim around. Swim close enough to the red circles to trigger random encounters with enemies who hold the hidden items." % _badge("Q")

var musashiAbilityTitle := "Musashi — Grapple"
var musashiGrappleBody:= "Press %s while Musashi is the active diver to switch into a first person Grapple mode where you can aim at golden objects then left click to grapple them (flashing them green on successful grapples) to launch Musashi towards the grapple points." % _badge("E")

var buckyAbilityTitle := "Bucky — Shockwave"
var buckyShockwaveBody:= "Press %s while Bucky is the active diver to send out a shockwave that can break any brown colored objects (rocks, doors, etc.). In some cases, breaking these objects will reveal items or other objects underneath them." % _badge("E")


# One per diver, laid out in a row by World._build_diver_slots() - purely a
# HUD anchor for now (no icon art exists yet, so $TextureRect stays blank
# until set_diver() is given one). CharacterAbilityPopup calls
# set_highlighted() to spotlight whichever Slot belongs to the diver its
# current page is explaining, the same "draw a border around the thing
# being explained" idea battle.gd's tutorial captions use on a stat row.
var diver: Diver

func set_diver(d: Diver, icon: Texture2D = null) -> void:
	diver = d
	if icon != null:
		($TextureRect as TextureRect).texture = icon

func set_highlighted(on: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	if on:
		style.border_color = Color(1.0, 0.85, 0.2)
		style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)
