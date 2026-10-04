extends SceneTree
func _initialize() -> void:
	print("before: %s" % Input.mouse_mode)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("immediately after set: %s (CAPTURED=%s)" % [Input.mouse_mode, Input.MOUSE_MODE_CAPTURED])
	quit(0)
