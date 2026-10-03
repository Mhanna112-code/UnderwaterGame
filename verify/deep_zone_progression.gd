# Proves battle-driven progression through the real Bomb Bot route fight.
#
# Bug caught: DZ-29 - progression helpers exist in isolation, but a normal
# authored victory never grants a level/Spell Point, auto-learns a move, or
# exposes that move in the next production battle.
#
# Usage: godot --headless --path . --script verify/deep_zone_progression.gd
extends SceneTree

const MAX_WALL_SECONDS := 180.0
const MAX_IDLE_SECONDS := 30.0

var world: World
var battle: Battle
var started_ms := 0
var last_action_ms := 0
var frames := 0
var bomb_result := ""
var checking_next_fight := false
var findings: Array[String] = []

func _initialize() -> void:
	seed(9629)
	EnemyRoster._rng.seed = 9629
	world = (load("res://game/world.tscn") as PackedScene).instantiate() as World
	world.skip_intro_for_test = true
	world.skip_tutorial_for_test = true
	root.add_child(world)
	started_ms = Time.get_ticks_msec()
	last_action_ms = started_ms

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		world.title_screen.close()
		paused = false
		world._first_encounter_started = true
		world._first_encounter_done = true
		for diver_value in world.divers:
			var diver := diver_value as Diver
			diver.stats.xp = diver.stats.xp_to_next - 1
			diver.stats.spell_points = 0
			diver.known_spells.clear()
			diver.equipped_spells.clear()
		(world.divers[world.active] as Diver).global_position = world.deep_zone_layout.route_points().bomb_bot as Vector3
		world._update_route_zone()
		world._update_deep_zone_blockers()
		return false

	if world.battle != null:
		battle = world.battle as Battle
		if checking_next_fight:
			return _report_next_fight()
		if not battle.finished.is_connected(_on_bomb_finished):
			battle.finished.connect(_on_bomb_finished)
		if battle._tutorial_continue_btn != null and battle._tutorial_continue_btn.visible:
			battle._tutorial_continue_btn.pressed.emit()
			last_action_ms = Time.get_ticks_msec()
		elif battle.target_menu.visible:
			_press_first(battle.target_buttons)
		elif battle.move_menu.visible:
			_press_first(battle.move_buttons)
		elif battle.main_menu.visible and is_instance_valid(battle.attack_btn) and not battle.attack_btn.disabled:
			battle.attack_btn.pressed.emit()
			last_action_ms = Time.get_ticks_msec()
	elif bomb_result == "won":
		_check_post_bomb_progression()
		var diver := world.divers[world.active] as Diver
		diver.global_position = world.deep_zone_layout.route_points().bomb_bot + Vector3(-8.0, 0.0, 0.0)
		world._update_deep_zone_blockers()
		diver.global_position = world.deep_zone_layout.route_points().sword_slayer as Vector3
		world._update_deep_zone_blockers()
		checking_next_fight = true
		last_action_ms = Time.get_ticks_msec()

	var elapsed := float(Time.get_ticks_msec() - started_ms) / 1000.0
	var idle := float(Time.get_ticks_msec() - last_action_ms) / 1000.0
	if elapsed > MAX_WALL_SECONDS:
		findings.append("DZ-29: progression route did not finish within %.0f seconds" % MAX_WALL_SECONDS)
		return _finish()
	if idle > MAX_IDLE_SECONDS:
		findings.append("DZ-29: progression route exposed no usable action for %.0f seconds" % MAX_IDLE_SECONDS)
		return _finish()
	return false

func _press_first(buttons: Array) -> void:
	for value in buttons:
		var button := value as Button
		if is_instance_valid(button) and button.visible and not button.disabled:
			button.pressed.emit()
			last_action_ms = Time.get_ticks_msec()
			return

func _on_bomb_finished(value: String) -> void:
	bomb_result = value
	last_action_ms = Time.get_ticks_msec()

func _check_post_bomb_progression() -> void:
	if bomb_result != "won":
		findings.append("DZ-29: Bomb Bot route fight ended '%s' instead of a victory" % bomb_result)
	for diver_value in world.divers:
		var diver := diver_value as Diver
		if diver.stats.level != 2:
			findings.append("DZ-29: %s did not level from the authored victory" % diver.model_name)
		if diver.known_spells.is_empty() or diver.equipped_spells.is_empty():
			findings.append("DZ-29: %s did not auto-learn and equip a new attack" % diver.model_name)
		elif diver.known_spells[0] != diver.equipped_spells[0]:
			findings.append("DZ-29: %s learned and equipped different first attacks" % diver.model_name)

func _report_next_fight() -> bool:
	if battle == null or battle.guardian_enemy_id != "sword_slayer":
		findings.append("DZ-29: progression could not reach the next authored battle")
		return _finish()
	for entry_value in battle.party:
		var entry := entry_value as Dictionary
		var equipped := entry.get("equipped_spells", []) as Array
		var move_names: Array[String] = []
		for move_value in battle._moves_for(entry):
			move_names.append(String((move_value as Dictionary).get("name", "")))
		for spell_id_value in equipped:
			var spell_id := String(spell_id_value)
			var definition := SpellTree.find_def(String(entry.model_name), spell_id)
			if definition.is_empty() or not move_names.has(String(definition.get("display", ""))):
				findings.append("DZ-29: %s's unlocked %s is absent from the next battle menu" % [String(entry.display_name), spell_id])
	return _finish()

func _finish() -> bool:
	for finding in findings:
		print("FINDING  " + finding)
	print("DEEP ZONE PROGRESSION: clean" if findings.is_empty() else "DEEP ZONE PROGRESSION: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
