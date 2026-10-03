# Capture the production in-game Audio tab at browser review resolution.
#
# Usage:
#   godot --path . --resolution 1280x720 \
#     --script tools/shoot_audio_settings.gd -- <out.png>
extends SceneTree

const CAPTURE_SETTINGS_PATH := "user://audio_settings_capture.cfg"

var out_png := "/tmp/audio-settings-1280x720.png"
var world: World
var frame := 0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_png = String(args[0])
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.set("settings_path", CAPTURE_SETTINGS_PATH)
		audio.call("set_music_volume", 0.65)
		audio.call("set_sfx_volume", 0.80)
		audio.call("set_music_muted", false)
		audio.call("set_sfx_muted", false)
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 1:
		world.title_screen.new_game_chosen.emit(1)
		return false
	if frame == 4:
		var onboarding := root.get_node_or_null("CharacterAbilityPopup")
		if onboarding != null and onboarding.visible:
			onboarding.call("_close")
		world.inventory_menu.open()
		world.inventory_menu.call("_switch_to", "audio")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return false
	if frame < 35:
		return false
	root.get_texture().get_image().save_png(out_png)
	var capture_path := ProjectSettings.globalize_path(CAPTURE_SETTINGS_PATH)
	if FileAccess.file_exists(capture_path):
		DirAccess.remove_absolute(capture_path)
	print("audio settings shot  %s" % out_png)
	return true
