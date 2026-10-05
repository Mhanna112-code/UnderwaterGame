extends SceneTree
## FEED-001: result feedback must describe real changes, not requested values.
var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var move := {"formula": {"strength": 1}, "effects": [
		{"kind": "reduce_evasion", "amount": {"accuracy": 1}}
	]}
	for accuracy in [0, 1, 3, 5]:
		for evasion in [0, 1, 2, 3, 4]:
			var attacker := CombatantStats.new()
			attacker.accuracy = accuracy
			var defender := CombatantStats.new()
			defender.evasion = evasion
			defender.fill()
			var before := defender.evasion
			var result := CombatRules.resolve(attacker, defender, move)
			var changed := before - defender.evasion
			var effects := result.effects as Array
			if result.hit:
				if changed > 0 and not effects.has("EVA -%d" % changed):
					findings.append("FEED-001 real EVA change %d not reported at ACC%d/EVA%d: %s" % [changed, accuracy, evasion, effects])
				if changed == 0:
					for effect in effects:
						if String(effect).begins_with("EVA -") and int(String(effect).trim_prefix("EVA -")) > 0:
							findings.append("FEED-001 invented change at depleted EVA: " + String(effect))
			elif not effects.is_empty() or changed != 0:
				findings.append("FEED-001 missed attack claims a lasting target effect")
	for finding in findings:
		print("FINDING ", finding)
	print("COMBAT EFFECT FEEDBACK: 20 actual-pool cases clean" if findings.is_empty() else "COMBAT EFFECT FEEDBACK: FAILED")
	quit(0 if findings.is_empty() else 1)
