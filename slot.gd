class_name Slot
extends PanelContainer

# Inline "[ F ]" keycap in BBCode so it renders within the sentence of a RichTextLabel.
static func _badge(key: String) -> String:
	return "[bgcolor=#1a1a1e][outline_color=#000000][outline_size=8][color=#ffffff] %s [/color][/outline_size][/outline_color][/bgcolor]" % key

# Plain marker: CharacterAbilityPopup splits on it and inserts its _wasd_cluster() widget.
const WASD_MARKER := "{{WASD}}"
# Inline minimap-marker swatches for the Sonar page, drawn by
# character_ability_popup.gd to match mini_map.gd/maze_mini_map.gd exactly.
const SMALL_MARKER := "{{SMALL_RED}}"
const SPECIAL_MARKER := "{{SPECIAL_RED}}"

var worldExplanation := "In the world map, divers can freely swim around encountering enemies, finding items and progressing to new areas. Use %s and move the camera around with the mouse to swim and look around. Use %s to switch between active divers. Divers also have special abilities they can use to interact with the world. Press %s to turn random encounters on or off - the blue Random Encounters indicator to the left of your health bar shows which." % [WASD_MARKER, _badge("Tab"), _badge("R")]

var maxilaniSwapTitle := "Maxilani: Swap"
var maxilaniSwapBody := "Press %s while Maxilani is the active diver to choose a teammate. Use %s/%s or %s/%s to choose, then %s or %s to swap positions. %s cancels. Use %s to position the other divers first. Swap uses no Oxygen." % [_badge("F"), _badge("A"), _badge("D"), _badge("Left"), _badge("Right"), _badge("Space"), _badge("Enter"), _badge("Esc"), _badge("Tab")]
var maxilaniSonarTitle := "Maxilani: Sonar"
var maxilaniSonarBody := "Maxilani has a built in sonar she can use to find hidden things in the world, which appear as red circles in the minimap on the top-right of the screen. Toggle Sonar On/Off with %s to consume 3 oxygen after every 3 seconds; anything hidden near you is revealed on the minimap as you swim around.

%s  [b]Small red circles[/b] mark hidden items, often under rocks you can break to gain them.

%s  [b]Large red circles[/b] mark item encounters. These are either special encounters where you use one diver's ability to play minigames against the enemy or regular random encounters where you gain items by defeating the enemy. Random encounters must be turned on to trigger these item fights." % [_badge("Q"), SMALL_MARKER, SPECIAL_MARKER]

var musashiAbilityTitle := "Musashi: Grapple"
var musashiGrappleBody:= "Press %s while Musashi is active to grapple golden targets. In aim mode, left-click fires and right-click or Escape cancels. An anchor pulls Musashi toward it; a floating light item reels toward Musashi instead. Grapple uses no Oxygen, and a miss can be retried immediately." % _badge("F")

var buckyAbilityTitle := "Bucky: Shockwave"
var buckyShockwaveBody:= "Press %s while Bucky is active to send out a shockwave that breaks nearby brown objects (rocks, doors, etc.). Broken objects may reveal items. Shockwave has a short cooldown and costs 12 Oxygen." % _badge("F")


# Per-diver HUD slot. CharacterAbilityPopup calls set_highlighted() to spotlight the explained diver.
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
