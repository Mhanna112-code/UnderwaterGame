# Captured follow-up contract from Glassgoat's September 2 Discord feedback.
# Usage: godot --headless --path . --script verify/glassgoat_discord_followup.gd
extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_complete_roster_contract()
	await _test_result_first_move_menu()
	await _test_semantic_feedback_colors()
	for failure in failures:
		push_error(failure)
	print("GLASSGOAT DISCORD FOLLOW-UP: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_complete_roster_contract() -> void:
	var expected := {
		"Staff_Diver": [10, 1, 0, 3, 3, 3],
		"Prototype_1(1910)": [10, 2, 2, 2, 2, 2],
		"Prototype_V(1922)": [10, 4, 4, 1, 0, 1],
	}
	for model_name in expected:
		var stats: Dictionary = Diver.BASE_STATS[model_name]
		var actual := [stats.hp, stats.strength, stats.defense, stats.agility, stats.evasion, stats.accuracy]
		_expect(actual == expected[model_name],
			"ROSTER CONTRACT DRIFT: %s expected %s, observed %s" % [model_name, expected[model_name], actual])
	_expect(Cast.display_name("Prototype_V(1922)") == "Bucky",
		"BUCKY IDENTITY MISSING: the third diver still displays as '%s'" % Cast.display_name("Prototype_V(1922)"))

func _test_result_first_move_menu() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	await process_frame
	battle._acting = battle.party[0]
	battle._start_party_turn(battle._acting)
	battle._show_moves()

	var stabbing := _move_button(battle, "Scuba Stabbing")
	_expect(stabbing != null, "RESULT-FIRST MENU MISSING: Scuba Stabbing is absent")
	if stabbing != null:
		_expect("1 Damage" in stabbing.text and "2 Bleed" in stabbing.text,
			"RESULT-FIRST MENU WRONG: expected resolved 1 Damage / 2 Bleed, observed '%s'" % stabbing.text)
		_expect("STR" not in stabbing.text,
			"FORMULA POLLUTION: default move choice exposes stat algebra '%s'" % stabbing.text)
		# "Status Effect" is a matched label _populate_move_menu() looks for
		# to attach a hover tooltip pulled from TutorialContent.STATUS_
		# CONDITIONS - guards both halves: the label wording itself, and
		# that the tooltip lookup actually found Bleed's entry.
		_expect("Status Effect: 2 Bleed" in stabbing.text,
			"STATUS EFFECT LABEL MISSING: expected 'Status Effect: 2 Bleed', observed '%s'" % stabbing.text)
		_expect("Bleed" in stabbing.tooltip_text and stabbing.tooltip_text != "",
			"STATUS EFFECT TOOLTIP MISSING: Scuba Stabbing's button has no Bleed explanation on hover")

	# Electric Touch's "EVA -3" isn't a CombatantStats status (no
	# STATUS_CONDITIONS entry, no add_status() call) but it's just as
	# opaque to a new player as one - it should still get an explanation,
	# pulled from TutorialContent.EFFECT_KIND_EXPLANATIONS instead.
	var electric := _move_button(battle, "Electric Touch")
	_expect(electric != null and "Evasion" in electric.tooltip_text and electric.tooltip_text != "",
		"NON-STATUS EFFECT TOOLTIP MISSING: Electric Touch's reduce_evasion has no explanation on hover")

	# A resolved preview must be computed from the acting character, not copied
	# from Scuba's base values. The same authored move at 4 STR is 4/5.
	var acting_stats := battle._acting.stats as CombatantStats
	acting_stats.strength = 4
	battle._populate_move_menu(battle._acting)
	stabbing = _move_button(battle, "Scuba Stabbing")
	if stabbing != null:
		_expect("4 Damage" in stabbing.text and "5 Bleed" in stabbing.text,
			"HARDCODED MOVE PREVIEW: 4 STR still renders '%s'" % stabbing.text)

	# The "Show formulas" on-demand control was removed - result-first is now
	# the only move-menu display, with no way back to raw stat algebra.
	_expect(_button_starting_with(battle.move_menu, "Show formulas") == null,
		"FORMULA CONTROL STILL PRESENT: the retired details toggle is back in the move menu")
	battle.queue_free()
	await process_frame

func _move_button(battle: Battle, move_name: String) -> Button:
	for button_value in battle.move_buttons:
		var button := button_value as Button
		if button.text.get_slice("\n", 0) == move_name:
			return button
	return null

func _button_starting_with(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and (child as Button).text.begins_with(prefix):
			return child as Button
	return null

func _test_semantic_feedback_colors() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	await process_frame
	var target := battle.enemies[0] as Dictionary
	battle._show_combat_feedback(target, {
		"hit": true, "damage": 3, "absorbed": 0, "debuff": "",
		"changed": 0, "dodged": false, "effects": ["Bleed 2"],
	})
	var damage_label: Label3D
	var bleed_label: Label3D
	for child in battle._stage_vp.get_children():
		if not child is Label3D:
			continue
		var label := child as Label3D
		if label.text == "-3":
			damage_label = label
		elif label.text == "Bleed 2":
			bleed_label = label
	_expect(damage_label != null and bleed_label != null,
		"SINGLE-COLOR OUTCOME: simultaneous damage and Bleed are not separate visible messages")
	if damage_label != null:
		var color := damage_label.modulate
		_expect(color.r > color.g * 1.5 and color.r > color.b * 1.3,
			"DAMAGE COLOR DRIFT: damage is not visibly red (%s)" % color)
	if bleed_label != null:
		var color := bleed_label.modulate
		_expect(color.r > color.g and color.b > color.g,
			"NEGATIVE-EFFECT COLOR DRIFT: Bleed is not visibly purple (%s)" % color)
	battle.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
