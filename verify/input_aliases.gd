# `modal controls: A/D + Space operate Swap and Space advances narration while
# legacy arrow/Enter controls remain — guards against inconsistent controls`.
extends SceneTree

const TIMEOUT_MS := 9000
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _run() -> void:
	var world := (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	root.add_child(world)
	await process_frame
	await process_frame
	world.title_screen.new_game_chosen.emit(3)
	await process_frame

	var requester := world.divers[0] as Diver
	world.target_selector.start_selection(requester)
	var first := world.target_selector.current_target()
	world._unhandled_input(_key(KEY_D))
	if world.target_selector.current_target() == first:
		findings.append("SWAP D ALIAS: D did not cycle to the next teammate")
	world._unhandled_input(_key(KEY_SPACE))
	if world.target_selector.selecting:
		findings.append("SWAP SPACE ALIAS: Space did not confirm the selected teammate")

	world.target_selector.start_selection(requester)
	var arrow_first := world.target_selector.current_target()
	world._unhandled_input(_key(KEY_RIGHT))
	if world.target_selector.current_target() == arrow_first:
		findings.append("SWAP LEGACY RIGHT: adding aliases must retain Right Arrow cycling")
	world._unhandled_input(_key(KEY_ENTER))
	if world.target_selector.selecting:
		findings.append("SWAP LEGACY ENTER: adding aliases must retain Enter confirmation")

	world._start_battle("", false, "angler", world.divers, false, true)
	var deadline := Time.get_ticks_msec() + TIMEOUT_MS
	while (world.battle == null or not world.battle._tutorial_awaiting_enter) and Time.get_ticks_msec() < deadline:
		await process_frame
	if world.battle == null or not world.battle._tutorial_awaiting_enter:
		findings.append("TUTORIAL FIXTURE: live tutorial narration wait did not appear")
	else:
		world.battle._unhandled_input(_key(KEY_SPACE))
		if world.battle._tutorial_awaiting_enter:
			findings.append("TUTORIAL SPACE ALIAS: Space did not advance live narration")
		world.battle._tutorial_awaiting_enter = true
		world.battle._unhandled_input(_key(KEY_KP_ENTER))
		if world.battle._tutorial_awaiting_enter:
			findings.append("TUTORIAL LEGACY ENTER: adding Space must retain keypad Enter")

	for finding in findings:
		push_error(finding)
	if findings.is_empty():
		print("INPUT ALIASES: Swap and tutorial accept additive controls without dropping legacy keys")
	world.queue_free()
	await process_frame
	var audio := root.get_node_or_null("GameAudio")
	if audio != null and audio.has_method("release_streams_for_shutdown"):
		audio.call("release_streams_for_shutdown")
	await process_frame
	quit(0 if findings.is_empty() else 1)
