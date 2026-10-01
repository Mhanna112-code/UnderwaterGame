# Throwaway probe: confirms the newly-added .ogv tutorial clips actually
# exist and load as valid VideoStream resources, not just present on disk.
# Usage: godot --headless --path . --script verify/tutorial_video_load_probe.gd
extends SceneTree

func _check(table_name: String, table: Dictionary) -> void:
	print("--- %s ---" % table_name)
	for key in table.keys():
		var path := String(table[key])
		var exists := ResourceLoader.exists(path)
		var loaded = load(path) if exists else null
		print("%-10s %-55s exists=%s loaded=%s" % [key, path, exists, loaded != null])

func _initialize() -> void:
	_check("ABILITY_MEDIA", TutorialContent.ABILITY_MEDIA)
	_check("SPECIAL_ENCOUNTER_MEDIA", TutorialContent.SPECIAL_ENCOUNTER_MEDIA)
	quit(0)
