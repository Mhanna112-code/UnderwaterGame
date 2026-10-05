# In-game audio-settings contract.
#
# Usage: godot --headless --path . --script verify/audio_settings_ui.gd
extends SceneTree

const TEST_SETTINGS_PATH := "user://audio_settings_ui_test.cfg"

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_remove_test_settings()
	var manager_script := load("res://game/audio_manager.gd")
	var menu_script := load("res://game/inventory_menu.gd")
	_expect(manager_script != null and menu_script != null,
		"AUDIO-UI-001: production manager or Escape menu did not load")
	if manager_script == null or menu_script == null:
		_finish()
		return

	var manager: Node = manager_script.new()
	manager.set("settings_path", TEST_SETTINGS_PATH)
	root.add_child(manager)
	var menu: Control = menu_script.new()
	menu.set("audio_manager", manager)
	root.add_child(menu)
	await process_frame
	menu.call("open")

	var audio_tab := menu.find_child("AudioTab", true, false) as Button
	_expect(audio_tab != null,
		"AUDIO-UI-001: normal Escape menu has no Audio tab")
	if audio_tab == null:
		_cleanup(menu, manager)
		return
	audio_tab.pressed.emit()
	await process_frame

	var music_slider := menu.find_child("MusicVolumeSlider", true, false) as HSlider
	var sfx_slider := menu.find_child("SFXVolumeSlider", true, false) as HSlider
	var music_mute := menu.find_child("MusicMuteToggle", true, false) as CheckButton
	var sfx_mute := menu.find_child("SFXMuteToggle", true, false) as CheckButton
	_expect(music_slider != null and sfx_slider != null and music_mute != null and sfx_mute != null,
		"AUDIO-UI-001: Audio tab is missing one or more interactive controls")
	if music_slider == null or sfx_slider == null or music_mute == null or sfx_mute == null:
		_cleanup(menu, manager)
		return
	_expect(music_slider.is_visible_in_tree() and sfx_slider.is_visible_in_tree(),
		"AUDIO-UI-001: audio controls are not visible after using the normal tab")
	_expect(music_slider.custom_minimum_size.x >= 320.0 and sfx_slider.custom_minimum_size.x >= 320.0,
		"AUDIO-UI-005: audio sliders do not reserve a usable gameplay-menu width")

	music_slider.value = 37.0
	sfx_slider.value = 64.0
	music_mute.button_pressed = true
	music_mute.toggled.emit(true)
	sfx_mute.button_pressed = false
	sfx_mute.toggled.emit(false)
	await process_frame
	_expect(manager.get_audio_settings() == {
		"music_volume": 0.37,
		"music_muted": true,
		"sfx_volume": 0.64,
		"sfx_muted": false,
	}, "AUDIO-UI-002: UI controls crossed or overwrote independent Music/SFX settings")

	music_mute.button_pressed = false
	music_mute.toggled.emit(false)
	_expect(is_equal_approx(float(manager.get_audio_settings().music_volume), 0.37),
		"AUDIO-UI-004: unmuting Music destroyed its slider value")
	music_slider.value = 0.0
	_expect(not bool(manager.get_audio_settings().music_muted)
		and is_zero_approx(float(manager.get_audio_settings().music_volume)),
		"AUDIO-UI-004: zero Music volume was conflated with mute")
	music_slider.value = 37.0
	manager.save_audio_settings()

	menu.queue_free()
	manager.queue_free()
	await process_frame
	var restored: Node = manager_script.new()
	restored.set("settings_path", TEST_SETTINGS_PATH)
	root.add_child(restored)
	await process_frame
	_expect(restored.get_audio_settings() == {
		"music_volume": 0.37,
		"music_muted": false,
		"sfx_volume": 0.64,
		"sfx_muted": false,
	}, "AUDIO-UI-003: persisted UI settings did not survive manager recreation")

	var reopened: Control = menu_script.new()
	reopened.set("audio_manager", restored)
	root.add_child(reopened)
	await process_frame
	reopened.call("open")
	var reopened_tab := reopened.find_child("AudioTab", true, false) as Button
	if reopened_tab != null:
		reopened_tab.pressed.emit()
		await process_frame
		var reopened_music := reopened.find_child("MusicVolumeSlider", true, false) as HSlider
		var reopened_sfx := reopened.find_child("SFXVolumeSlider", true, false) as HSlider
		_expect(reopened_music != null and reopened_sfx != null
			and is_equal_approx(reopened_music.value, 37.0)
			and is_equal_approx(reopened_sfx.value, 64.0),
			"AUDIO-UI-003: reopened Audio tab did not rehydrate persisted values")
	reopened.queue_free()
	restored.queue_free()
	await process_frame
	_remove_test_settings()
	_finish()

func _cleanup(menu: Control, manager: Node) -> void:
	menu.queue_free()
	manager.queue_free()
	await process_frame
	_remove_test_settings()
	_finish()

func _remove_test_settings() -> void:
	var path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("AUDIO SETTINGS UI: clean" if findings.is_empty() else "AUDIO SETTINGS UI: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
