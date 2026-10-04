extends SceneTree
## INT-07: real revival must restore an initially absent actor/card/usable turn.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	Engine.time_scale = 8.0
	for downed in range(3):
		await _case(downed, "potion")
		if downed != 2:
			await _case(downed, "spell")
	Engine.time_scale = 1.0
	root.get_node("GameAudio").release_streams_for_shutdown()
	for finding in findings:
		print("FINDING ", finding)
	print("COMBAT INITIALLY DOWNED: clean" if findings.is_empty() else "COMBAT INITIALLY DOWNED: %d findings" % findings.size())
	quit(0 if findings.is_empty() else 1)

func _case(downed: int, method: String) -> void:
	var sources: Array[Diver] = []
	for model in Cast.ALL:
		var diver := Diver.new()
		diver.model_name = model
		root.add_child(diver)
		sources.append(diver)
	var bucky := sources[2]
	while bucky.stats.level < 6:
		bucky.stats.gain_xp(10)
	SpellTree.learn_all_available(bucky, ["reef_plate"])
	sources[downed].stats.hp = 0
	var resource := sources[downed].stats
	var inventory := {"potion": 2}
	var battle := Battle.new()
	battle.party_source = sources
	battle.inventory_source = inventory
	battle.campaign_key_items_source.assign(["reef_plate"])
	battle.ordinary_enemy_ids.assign(["angler"])
	seed(62507)
	root.add_child(battle)
	await process_frame
	var entry := battle.party[downed] as Dictionary
	var normal_scale := (entry.actor as Node3D).scale
	var home: Vector3 = entry.home_pos
	_expect(not (entry.actor as Node3D).visible and not (entry.card as Control).visible,
		"INT-07 fixture did not begin with an actually absent/downed fighter")
	var outcomes: Array[String] = []
	battle.finished.connect(func(result: String) -> void: outcomes.append(result))
	var restored := false
	var observations := {"swing": false}
	battle.player_swing_staged.connect(func(actor: Node3D, _target: Node3D) -> void:
		if actor == entry.actor and resource.hp > 0:
			observations.swing = true)
	var spent := false
	var actions := 0
	var deadline := Time.get_ticks_msec() + 25000
	var before_oxygen := bucky.stats.oxygen
	while not observations.swing and outcomes.is_empty() and Time.get_ticks_msec() < deadline and actions < 15:
		if battle._tutorial_awaiting_enter:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.pressed = true
			Input.parse_input_event(event)
		if spent and resource.hp > 0 and not restored:
			await create_timer(0.8).timeout
			var actor := entry.actor as Diver
			_expect(actor.is_visible_in_tree(), "INT-07 recovery restored HP but initially hidden actor stayed invisible")
			_expect(actor.scale.is_equal_approx(normal_scale), "INT-07 revival applies nonexistent death shrink compensation")
			_expect(actor.position.distance_to(home) < 0.02, "INT-07 revival lifts initially downed actor away from stage home")
			_expect((entry.card as Control).visible and (entry.hp_bar as ProgressBar).value > 0,
				"INT-07 restored fighter card/bar stayed down")
			_expect(entry.stats == resource and sources[downed].stats.hp == 10,
				"INT-07 restoration lost authoritative party resource or expected HP")
			if method == "spell":
				_expect(absf(bucky.stats.oxygen - (before_oxygen - 28.0)) < 0.05,
					"INT-07 actual revival did not pay 28 Oxygen")
			else:
				_expect(int(inventory.get("potion", 0)) == 1, "INT-07 potion restoration did not spend exactly one item")
			restored = true
			if "--capture-revival" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				var path := "res://docs/evidence/maze-campaign-integration/revive-%d-%s.png" % [downed, method]
				_expect(root.get_texture().get_image().save_png(path) == OK,
					"INT-07 could not capture native revival presentation")
		if battle.main_menu.is_visible_in_tree() and not battle.attack_btn.disabled and not battle._busy and battle._acting.has("model_name"):
			var actor_model := String(battle._acting.model_name)
			if not spent and (method == "potion" or actor_model == bucky.model_name):
				if method == "potion":
					battle.items_btn.pressed.emit()
					await process_frame
					var potion := _button(battle.item_menu, "Potion", true)
					_expect(potion != null, "INT-07 actual potion missing from Items")
					if potion != null:
						potion.pressed.emit()
				else:
					_expect(await _move(battle, "Tidal Revival"), "INT-07 actual earned revival unavailable")
				await process_frame
				_expect(await _target(battle, Cast.display_name(sources[downed].model_name)), "INT-07 actual ally picker excludes downed diver")
				spent = true
			elif restored and actor_model == sources[downed].model_name:
				var move := "Axe Kick" if downed == 0 else "Precise Tap" if downed == 1 else "Guard Bash"
				_expect(await _move(battle, move), "INT-07 revived fighter has no usable attack")
				await process_frame
				if not battle.target_buttons.is_empty():
					(battle.target_buttons[0] as Button).pressed.emit()
			else:
				# Real non-damaging actions keep the test opponent alive until
				# the restored actor gets a normal queue turn. No enemy stats change.
				var move := "Flash Blast" if actor_model == "Staff_Diver" else "Weaken" if actor_model == "Prototype_1(1910)" else "Mending Current"
				_expect(await _move(battle, move), "INT-07 waiting move unavailable: " + move)
				await process_frame
				if not battle.target_buttons.is_empty():
					(battle.target_buttons[0] as Button).pressed.emit()
			actions += 1
		await process_frame
	_expect(restored and observations.swing, "INT-07 restored HP did not return actor to an actual usable turn")
	for diver in sources:
		_expect(diver.stats.hp_max == 10, "INT-07 fixture inflated HP")
	print("INITIAL DOWN CASE|target=", downed, "|method=", method, "|restored=", restored,
		"|actual_swing=", observations.swing, "|actions=", actions, "|hp=", resource.hp, "|o2=", bucky.stats.oxygen)
	battle.queue_free()
	for diver in sources:
		diver.queue_free()
	await process_frame
	await process_frame

func _button(parent: Node, label: String, prefix := false) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		var button := node as Button
		if button.is_visible_in_tree() and not button.disabled and (button.text.begins_with(label) if prefix else button.text.get_slice("\n", 0) == label):
			return button
	return null

func _move(battle: Battle, name: String) -> bool:
	battle.attack_btn.pressed.emit()
	await process_frame
	var selected: Button
	for button in battle.move_buttons:
		if (button as Button).text.get_slice("\n", 0) == name and not (button as Button).disabled:
			selected = button as Button
	if selected == null:
		return false
	var pages := 0
	while not selected.is_visible_in_tree() and pages < 8 and not battle._move_down_btn.disabled:
		battle._move_down_btn.pressed.emit()
		await process_frame
		pages += 1
	if not selected.is_visible_in_tree():
		return false
	selected.pressed.emit()
	return true

func _target(battle: Battle, name: String) -> bool:
	for node in battle.target_buttons:
		var button := node as Button
		if button.is_visible_in_tree() and button.text.begins_with(name):
			button.pressed.emit()
			return true
	return false

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
