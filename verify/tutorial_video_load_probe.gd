# Throwaway probe: confirms the newly-added .ogv tutorial clips actually
# exist and load as valid VideoStream resources, not just present on disk.
# Usage: godot --headless --path . --script verify/tutorial_video_load_probe.gd
extends SceneTree

func _initialize() -> void:
	for key in TutorialContent.ABILITY_MEDIA.keys():
		var path := String(TutorialContent.ABILITY_MEDIA[key])
		var exists := ResourceLoader.exists(path)
		var loaded = load(path) if exists else null
		print("%-10s %-45s exists=%s loaded=%s" % [key, path, exists, loaded != null])
	quit(0)
