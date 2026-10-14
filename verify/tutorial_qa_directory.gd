extends SceneTree

func _initialize() -> void:
	var directory := OS.get_user_data_dir()
	print("TUTORIAL_QA_DIRECTORY|", directory)
	if not directory.ends_with("/UnderwaterGameQA/quick-tutorial-oct14"):
		push_error("QA SAVE ISOLATION: refuse to run verifiers against player data")
		quit(1)
	else:
		quit(0)
