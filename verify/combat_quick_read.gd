# `combat quick read: resolved choices, optional context, and all-target
# previews agree with the live rules — guards against formula-first clutter
# and misleading target scope`.
#
# Usage: godot --headless --path . --script verify/combat_quick_read.gd
extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var battle := Battle.new()
	root.add_child(battle)
	await process_frame
	await process_frame
	battle._acting = battle.party[0]
	battle._start_party_turn(battle._acting)
	battle._show_moves()

	_test_quick_read_and_details(battle)
	_test_current_rule_context(battle)
	_test_all_target_preview_scope(battle)

	for failure in failures:
		push_error(failure)
	print("COMBAT QUICK READ: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	battle.queue_free()
	quit(0 if failures.is_empty() else 1)

func _test_quick_read_and_details(battle: Battle) -> void:
	var stabbing := _move_button(battle, "Scuba Stabbing")
	_expect(stabbing != null, "QUICK READ MISSING: Scuba Stabbing is absent from the active move menu")
	if stabbing != null:
		_expect("1 Damage" in stabbing.text and "2 Bleed" in stabbing.text,
			"QUICK READ WRONG: expected resolved 1 Damage / 2 Bleed, observed '%s'" % stabbing.text)
		_expect("STR" not in stabbing.text,
			"FORMULA-FIRST REGRESSION: default move choice exposes stat algebra '%s'" % stabbing.text)
		_expect("Damage" in stabbing.tooltip_text and "Bleed" in stabbing.tooltip_text,
			"MOVE CONTEXT MISSING: result-first choice has no on-demand Damage/Bleed explanation")
		var tooltip_view := stabbing.call("_make_custom_tooltip", stabbing.tooltip_text) as PanelContainer
		_expect(tooltip_view != null and tooltip_view.get_child_count() == 1,
			"TOOLTIP RENDER MISSING: contextual move detail has no custom readable surface")
		if tooltip_view != null and tooltip_view.get_child_count() == 1:
			var tooltip_label := tooltip_view.get_child(0) as Label
			_expect(tooltip_label != null and tooltip_label.autowrap_mode != TextServer.AUTOWRAP_OFF and tooltip_label.custom_minimum_size.x > 0.0,
				"TOOLTIP CLIPS: contextual move detail is not constrained to a wrapped width")
		if tooltip_view != null:
			tooltip_view.free()
		_expect(stabbing.call("_make_custom_tooltip", "") == null,
			"EMPTY TOOLTIP NOISE: buttons with no detail create a blank hover panel")

	# The result is the default surface. The prior formula toggle caused a
	# second menu state and made the lower combat panel look frozen during
	# review; optional explanation now belongs to the move itself.
	_expect(_button_starting_with(battle.move_menu, "Show formulas") == null,
		"FORMULA TOGGLE STILL PRESENT: Quick Read should not require a second result/formula menu state")

	# Context must still scale with the actor's actual current stats rather
	# than frozen base-stat prose. This also catches a tooltip implementation
	# that restores formulas but forgets the resolved button outcome.
	var acting_stats := battle._acting.stats as CombatantStats
	acting_stats.strength = 4
	battle._populate_move_menu(battle._acting)
	stabbing = _move_button(battle, "Scuba Stabbing")
	if stabbing != null:
		_expect("4 Damage" in stabbing.text and "5 Bleed" in stabbing.text,
			"HARDCODED QUICK READ: 4 STR still renders '%s'" % stabbing.text)
		_expect("persists for this battle" in stabbing.tooltip_text,
			"STATUS CONTEXT DRIFT: tooltip does not describe current persistent Bleed behavior")

func _test_current_rule_context(battle: Battle) -> void:
	var stats := battle._acting.stats as CombatantStats
	var flash_context := battle._move_tooltip_text(CombatMoves.SCUBA[2], stats)
	_expect("All enemies" in flash_context and "It lasts 3 turns." in flash_context,
		"ALL-TARGET CONTEXT DRIFT: Flash Blast context does not expose its live scope/duration")
	# Source order is not a stable game contract: the reconciliation removes the
	# retired Ramming Bite, so callers must identify an authored move by id rather
	# than holding a fourth-array-slot assumption. This also asserts the current
	# persistent-Bite and Accuracy-timed Shine contexts rather than the old
	# invented three-turn Bite text.
	var angler_bite := _enemy_combat("bite")
	var bite_context := battle._move_tooltip_text(angler_bite, stats)
	_expect("persists for this battle" in bite_context,
		"PERSISTENT BLEED CONTEXT DRIFT: Angler Bite must not advertise an invented expiry")
	var evasion_down := _enemy_combat("flash_blast")
	var evasion_context := battle._move_tooltip_text(evasion_down, stats)
	_expect("Evasion Down" in evasion_context and "It lasts 3 turns." in evasion_context,
		"STATUS LABEL/DURATION LEAK: Flash Blast's Accuracy-scaled Evasion Down is not rendered for a player")
	var revive_context := battle._move_tooltip_text({"name": "Revive", "effect": "revive"}, stats)
	_expect("One downed ally" in revive_context,
		"ALLY TARGET CONTEXT DRIFT: revive is incorrectly described as targeting an enemy")

func _test_all_target_preview_scope(battle: Battle) -> void:
	var second_stats := CombatantStats.new()
	second_stats.hp_max = 9
	second_stats.hp = 9
	second_stats.defense = 3
	second_stats.accuracy = 4
	second_stats.evasion = 2
	second_stats.evasion_current = 2
	var targets: Array = [battle.enemies[0] as Dictionary, {
		"display_name": "Second Target",
		"stats": second_stats,
	}]

	battle.call("_show_all_stat_preview", CombatMoves.SCUBA[2], targets)
	var extras = battle.get("_extra_enemy_stats_uis")
	_expect(extras is Array and (extras as Array).size() == 1,
		"ALL-TARGET PREVIEW INCOMPLETE: Flash Blast only previews the first target")
	battle.call("_clear_all_stat_preview")
	extras = battle.get("_extra_enemy_stats_uis")
	_expect(extras is Array and (extras as Array).is_empty(),
		"ALL-TARGET PREVIEW STALE: extra target stat panels survive after the hover ends")

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

func _enemy_combat(id: String) -> Dictionary:
	for move_value in EnemyMoves.ANGLER:
		var move := move_value as Dictionary
		if String(move.get("id", "")) == id:
			return move.get("combat", {}) as Dictionary
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
