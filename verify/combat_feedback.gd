# Verifies that Glassgoat's rules are legible in the actual battle UI, not
# merely present in the arithmetic. This catches the regressions behind
# issues #18, #19 and #20: missing damage/dodge feedback and hidden stats.
#
# Usage: godot --headless --path . --script verify/combat_feedback.gd
extends SceneTree

var battle: Battle
var frames := 0
var failures: Array[String] = []

func _initialize() -> void:
	battle = Battle.new()
	root.add_child(battle)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 4:
		return false
	battle._acting = battle.party[0]
	battle._start_party_turn(battle._acting)
	_expect((battle.enemies[0].status_label as Label).text == "",
		"ENEMY STATS POLLUTE HUD: enemy stats must stay hidden until target selection")
	battle._show_moves()
	var move_names: Array[String] = []
	for button in battle.move_buttons:
		move_names.append((button as Button).text.get_slice("\n", 0))
	_expect(move_names == ["Electric Touch", "Scuba Stabbing", "Flash Blast", "Multiple Knee Combo", "Axe Kick"],
		"AUTHORED KIT NOT VISIBLE: Scuba's five Group_StatsV2 moves must appear in the real move menu")

	battle._on_move_chosen(CombatMoves.SCUBA[0])
	var target_text := (battle.target_buttons[0] as Button).text
	_expect("DEF" in target_text and "EVA" in target_text and "ACC" in target_text,
		"TARGET STATS HIDDEN: selecting a target must reveal DEF, current/max EVA and ACC")
	battle._show_moves_or_items_from_target_menu()
	battle._on_move_chosen(CombatMoves.SCUBA[2])
	_expect((battle.target_buttons[0] as Button).text.begins_with("All enemies"),
		"ALL-FOE TARGETING HIDDEN: Flash Blast must clearly commit against the whole enemy line")

	var target := battle.enemies[0] as Dictionary
	battle._show_combat_feedback(target, {"hit": false, "damage": 0, "effects": []})
	battle._show_combat_feedback(target, {"hit": true, "damage": 3, "effects": ["Bleed 2"]})
	battle._show_combat_feedback(target, {"hit": true, "damage": 0, "absorbed": 0, "effects": []})
	var feedback: Array[String] = []
	for child in battle._stage_vp.get_children():
		if child is Label3D:
			feedback.append((child as Label3D).text)
	_expect("DODGE" in feedback, "DODGE FEEDBACK MISSING: a miss must be visible over its target")
	_expect("-3" in feedback and "Bleed 2" in feedback,
		"DAMAGE/STATUS FEEDBACK MISSING: damage and applied status must be separately colorable over the target")
	_expect("ABSORBED" in feedback, "ABSORBED FEEDBACK MISSING: a zero-damage hit must not look like a dodge")

	for failure in failures:
		push_error(failure)
	print("COMBAT FEEDBACK: %s" % ("clean" if failures.is_empty() else "%d failure(s)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
	return true

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
