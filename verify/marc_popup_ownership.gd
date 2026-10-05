extends SceneTree
## M97-P1..5: battle must own pause/screen; singleton lessons resume safely.

var findings: Array[String] = []
var capture_dir := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	var popup := root.get_node("CharacterAbilityPopup") as Control
	var panel := popup.find_child("AbilityExplanationPanel", true, false) as Control
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await _settle()
	world._on_title_spell_playtest()
	var battle := Battle.new()
	root.add_child(battle)
	await _settle()
	var pages: Array[Dictionary] = [{"title": "Held lesson", "body": "This must wait for combat."}]
	popup.call("open", pages)
	await _settle()
	_expect(not panel.visible and not paused, "M97-P1 opening info covers/pauses an actual Battle")
	if not findings.is_empty():
		popup.call("_close")
		battle.queue_free()
		world.queue_free()
		_finish()
		return
	# Game Over/title own pause; merely removing Battle is not permission to resume.
	paused = true
	battle.queue_free()
	await _settle()
	_expect(not panel.visible and paused, "M97-P3 held info reopened over a paused recovery/title owner")
	paused = false
	await _settle()
	_expect(panel.visible and _title(popup) == "Held lesson", "M97-P1 held page did not resume after combat")
	await _click(popup, "Close")
	_expect(not panel.visible and not paused, "M97-P1 resumed page did not release exploration")

	# Real post-tutorial pages and clip: pause/cursor are owned by this lesson.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	world._show_ability_popups()
	for _index in range(3):
		await _click(popup, "Next")
	await create_timer(0.3, true).timeout
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "M97-P4 captured cursor prevents clicking lesson controls")
	_expect("Grapple" in _title(popup), "M97-P2 real walkthrough did not reach Grapple")
	await _capture("popup-grapple-before-battle")
	battle = Battle.new()
	root.add_child(battle)
	await _settle()
	_expect(not panel.visible and not paused, "M97-P2 interrupted lesson still owns combat")
	for player in popup.find_children("*", "VideoStreamPlayer", true, false):
		_expect(not player.is_playing(), "M97-P2 hidden clip continues decoding during combat")
	await _capture("battle-without-popup")
	# A second caller must not overwrite the remaining real walkthrough.
	var second: Array[Dictionary] = [{"title": "Second lesson", "body": "Next caller in order."}]
	popup.call("open", second)
	battle.queue_free()
	await _settle()
	_expect("Grapple" in _title(popup), "M97-P5 later request overwrote interrupted Grapple page")
	await _capture("popup-grapple-resumed")
	await _click(popup, "Next")
	_expect("Shockwave" in _title(popup), "M97-P2 remaining Shockwave page was lost")
	await _click(popup, "Next")
	_expect(_title(popup) == "Inventory", "M97-P2 remaining Inventory page was lost")
	await _click(popup, "Close")
	_expect(_title(popup) == "Second lesson" and panel.visible, "M97-P5 second queued caller never resumed")
	await _click(popup, "Close")

	# Retain pages with a real Slot, then destroy its scene before resume.
	world._show_ability_popups()
	await _click(popup, "Next")
	battle = Battle.new()
	root.add_child(battle)
	await _settle()
	world.queue_free()
	await _settle()
	battle.queue_free()
	await _settle()
	_expect(not panel.visible and not paused, "M97-P3 stale World lesson reopened after its Slots were destroyed")

	# No battle: free the cursor and return to the caller's original mode.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Headless DisplayServer cannot capture an OS pointer; retain the mode it
	# actually supports. The native run independently exercises real capture.
	var caller_mode := Input.mouse_mode
	popup.call("open", pages)
	await _settle()
	_expect(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "M97-P4 no free cursor for ordinary popup")
	await _click(popup, "Close")
	_expect(Input.mouse_mode == caller_mode and not paused, "M97-P4 close failed to restore caller cursor/pause")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = true
	popup.call("open", pages)
	await _settle()
	await _click(popup, "Close")
	_expect(paused, "M97-P4 closing lesson steals prior modal pause")
	paused = false
	_finish()

func _title(popup: Control) -> String:
	return (popup.find_child("Title", true, false) as Label).text

func _click(popup: Control, text: String) -> void:
	for button in popup.find_children("*", "Button", true, false):
		if button.text == text and button.is_visible_in_tree():
			button.pressed.emit()
			await _settle()
			return
	findings.append("M97-P2 missing visible lesson control: " + text)

func _settle() -> void:
	for _frame in range(8):
		await process_frame

func _capture(label: String) -> void:
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(label + ".png"))

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)

func _finish() -> void:
	var audio := root.get_node_or_null("GameAudio")
	if audio != null:
		audio.release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("MARC POPUP OWNERSHIP: clean" if findings.is_empty() else "MARC POPUP OWNERSHIP: failed")
	quit(0 if findings.is_empty() else 1)
