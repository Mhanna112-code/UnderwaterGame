# Ordinary random encounters must expose both delivered enemy models, rather
# than making the Swordfish a guardian-only preview asset.
extends SceneTree

# 48 independent actor rolls makes a one-species sample vanishingly unlikely
# while still exercising real Battle construction rather than a private helper.
const SAMPLES := 48
var findings: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_expect(EnemyRoster.id_for_roll(0.0) == "angler" and EnemyRoster.id_for_roll(0.4999) == "angler" and EnemyRoster.id_for_roll(0.5) == "swordfish_duelist" and EnemyRoster.id_for_roll(0.9999) == "swordfish_duelist",
		"ORDINARY ROSTER: 50/50 roll boundary selects Angler then Swordfish — guards against an unreachable roster entry")
	_expect(Battle.encounter_intro([{"display_name": "Swordfish Duelist"}]) == "Swordfish Duelist blocks the way!",
		"ORDINARY ROSTER: lone battle announces the visible enemy — guards against stale Angler-only combat copy")

	seed(20260906)
	var seen: Dictionary = {}
	for _sample in range(SAMPLES):
		var battle := Battle.new()
		root.add_child(battle)
		await process_frame
		await process_frame
		for entry_value in battle.enemies:
			var actor := (entry_value as Dictionary).actor as Goblin
			var enemy_id := actor.enemy_id() if actor != null else "none"
			seen[enemy_id] = true
			_expect(enemy_id in EnemyRoster.ORDINARY_IDS,
				"ORDINARY ROSTER: every random actor has a declared ordinary identity — guards against bad roster dispatch (got '%s')" % enemy_id)
		battle.queue_free()
		await process_frame
	_expect(seen.has("angler") and seen.has("swordfish_duelist"),
		"ORDINARY ROSTER: seeded normal battles include Angler and Swordfish — guards against the Swordfish being guardian-only (saw %s)" % [seen.keys()])

	if findings.is_empty():
		print("ORDINARY ROSTER: clean — random packs draw Angler and Swordfish; fixed guardians remain site-selected")
		quit(0)
		return
	for finding in findings:
		print("FINDING  " + finding)
	quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		findings.append(message)
