# Tune the goblin by measurement, not by taste.
#
# SALVAGE's rule: the judge bands never move, the content does. Bands are
# casual 55 to 90 percent, greedy at least 6 turns, greedy loses at least
# 8 squad HP. This walks limb HP against attack damage and prints every
# configuration, marking the ones that land.
#
# Usage: godot --headless --path . --script verify/sweep.gd
extends SceneTree

const SEEDS := 60

func _init() -> void:
	var base: Dictionary = (Encounters.ALL["goblin"] as Dictionary)
	print("%-14s %-8s %-8s %-8s %s" % ["limb hp", "casual", "g.turns", "g.hp", ""])
	var landed: Array = []
	for hp_add in [0, 3, 6, 9]:
		for dmg_add in [0, 1, 2]:
			var enc: Dictionary = base.duplicate(true)
			for l in enc.limbs:
				l.hp = int(l.hp) + hp_add
			for a in enc.attacks:
				a.dmg = int(a.dmg) + dmg_add
			Encounters.ALL["goblin_probe"] = enc

			var cas := _run("casual")
			var gre := _run("greedy")
			var ok: bool = cas.rate >= 55.0 and cas.rate <= 90.0 and gre.turns >= 6.0 and gre.hp >= 8.0
			print("%-14s %6.1f%%  %7.1f  %7.1f  %s" % [
				"+%d hp +%d dmg" % [hp_add, dmg_add], cas.rate, gre.turns, gre.hp,
				"IN BAND" if ok else ""])
			if ok:
				landed.append({"hp": hp_add, "dmg": dmg_add, "cas": cas.rate, "turns": gre.turns, "hp_lost": gre.hp})

	print("")
	if landed.is_empty():
		print("SWEEP: nothing landed in band; the shape needs changing, not the numbers")
		quit(1)
		return
	# prefer the one nearest the middle of the casual band
	var best: Dictionary = landed[0]
	for l in landed:
		if absf(float(l.cas) - 72.5) < absf(float(best.cas) - 72.5):
			best = l
	print("SWEEP: %d configuration(s) land. Best is +%d limb hp, +%d damage (casual %.1f%%, greedy %.1f turns, %.1f HP)" % [
		landed.size(), int(best.hp), int(best.dmg), float(best.cas), float(best.turns), float(best.hp_lost)])
	quit(0)

func _run(policy: String) -> Dictionary:
	var wins := 0
	var turns := 0.0
	var hp := 0.0
	for s in range(SEEDS):
		var r: Dictionary = Bots.run_fight(s, policy, "goblin_probe", 40)
		if bool(r.win):
			wins += 1
			turns += float(r.turns)
			hp += float(r.get("hp_lost", 0))
	return {"rate": 100.0 * float(wins) / float(SEEDS),
			"turns": turns / float(maxi(wins, 1)),
			"hp": hp / float(maxi(wins, 1))}
