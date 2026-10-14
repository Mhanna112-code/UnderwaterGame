extends SceneTree

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var popup := TutorialResultPopup.new()
	root.add_child(popup)
	var bodies := ["Your party, items and save are unchanged. Retry the lesson or return to exploring.", "A loss in this practice fight does not take your earned items or overwrite your checkpoint. ".repeat(16)]
	for size in [Vector2i(360, 480), Vector2i(360, 640), Vector2i(720, 480), Vector2i(1280, 720)]:
		root.size = size
		for body in bodies:
			for action in ["Retry", "Exit to World"]:
				popup.open("Practice ended", body)
				for frame in range(6):
					await process_frame
				checks += 1
				if not root.get_visible_rect().encloses(popup._title.get_global_rect()) or popup._body.get_global_rect().position.x < 0 or popup._body.get_global_rect().end.x > size.x:
					failures.append("QT12: result title/body extends horizontally outside the viewport")
				var chosen: Button
				for node in popup.find_children("*", "Button", true, false):
					var button := node as Button
					checks += 1
					if not button.is_visible_in_tree() or button.disabled or not root.get_visible_rect().encloses(button.get_global_rect()):
						failures.append("QT12: %s at %s is clipped or unusable: %s" % [button.text, str(size), str(button.get_global_rect())])
					if button.text == action:
						chosen = button
				if not failures.is_empty():
					break
				if OS.get_cmdline_user_args().has("--capture") and body == bodies[0] and action == "Retry" and DisplayServer.get_name() != "headless":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png("res://docs/evidence/quick-tutorial-oct14/result-%dx%d.png" % [size.x, size.y])
				var result := []
				var retry_callback := func() -> void: result.append("Retry")
				var exit_callback := func() -> void: result.append("Exit to World")
				popup.retry_chosen.connect(retry_callback)
				popup.exit_chosen.connect(exit_callback)
				chosen.emit_signal("pressed")
				checks += 1
				if result != [action] or popup.visible or paused:
					failures.append("QT12: result action did not close/unpause exactly once")
				popup.retry_chosen.disconnect(retry_callback)
				popup.exit_chosen.disconnect(exit_callback)
			if not failures.is_empty():
				break
		if not failures.is_empty():
			break
	for failure in failures:
		push_error(failure)
	popup.queue_free()
	print("TUTORIAL RESULT LAYOUT|checks=%d|failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
