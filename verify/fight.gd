# Is the goblin fight actually a fight?
#
# The sim is ported and proven, but this encounter is new, and a new
# encounter is a claim about numbers until something plays it. This runs
# both SALVAGE's bot policies over many seeds and reports the same three
# figures that project pinned its bands to: how often a careless player
# wins, how fast a greedy one does, and what winning costs.
#
# Usage: godot --headless --path . --script verify/fight.gd [-- <encounter>]
extends SceneTree

const SEEDS := 200

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var enc := String(args[0]) if args.size() > 0 else "goblin"
	var findings: Array = []

	for policy in ["casual", "greedy"]:
		var wins := 0
		var turns := 0.0
		var hp_lost := 0.0
		var unfinished := 0
		for s in range(SEEDS):
			# run_fight reports win/turns/hp_lost/downed, not an outcome
			# string. Reading a key that is not there returns null and the
			# whole sweep silently measures nothing.
			var r: Dictionary = Bots.run_fight(s, policy, enc, 40)
			if bool(r.win):
				wins += 1
				turns += float(r.turns)
				hp_lost += float(r.get("hp_lost", 0))
			elif int(r.turns) > 40:
				unfinished += 1
		var rate := 100.0 * float(wins) / float(SEEDS)
		var avg_turns: float = turns / float(maxi(wins, 1))
		var avg_hp: float = hp_lost / float(maxi(wins, 1))
		print("%-7s  win %5.1f%%   turns %4.1f   squad HP lost %4.1f%s" % [
			policy, rate, avg_turns, avg_hp,
			"   UNFINISHED %d" % unfinished if unfinished > 0 else ""])

		if unfinished > 0:
			findings.append("STALLS: %s failed to finish %d of %d fights within 40 turns" % [policy, unfinished, SEEDS])
		if policy == "casual":
			if rate < 20.0:
				findings.append("UNWINNABLE: a careless player wins only %.1f%% of the time" % rate)
			if rate > 95.0:
				findings.append("FREE: a careless player wins %.1f%% of the time, so nothing is being asked" % rate)
		if policy == "greedy":
			if rate < 50.0:
				findings.append("UNFAIR: even a greedy player only wins %.1f%%" % rate)
			if avg_turns < 3.0:
				findings.append("OVER FAST: greedy clears it in %.1f turns, too short to be a fight" % avg_turns)
			if avg_hp < 1.0:
				findings.append("PAINLESS: greedy wins losing %.1f HP, so the enemy never lands" % avg_hp)

	for f in findings:
		print("FINDING  " + f)
	print("FIGHT: clean" if findings.is_empty() else "FIGHT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
