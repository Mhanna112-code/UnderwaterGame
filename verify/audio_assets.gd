# Canonical runtime audio intake check.
#
# Usage: godot --headless --path . --script verify/audio_assets.gd
extends SceneTree

const ASSETS := [
	["res://audio/music/exploration_loop.ogg", 105.974, "5af14408aa0bb8c8dfc9290c87afef214b4d07fe4e765ae6641cdaf5859a42f8"],
	["res://audio/music/battle_intro.ogg", 15.000, "9e7dfbd99c85214233cbc47c499076f4622e8deec5a009e697461dd1e99857e4"],
	["res://audio/music/battle_loop.ogg", 88.645, "545242b724a36055b5631df2fd89aad7a66ae66f71ca46060f954dea0245dadd"],
	["res://audio/music/tethys_candidate_intro.ogg", 105.368, "4ca570fdbe1a19112877d8b35e9aab2ae1e6bf4899e5174f5e93fc3b0bacc224"],
	["res://audio/music/tethys_loop.ogg", 97.412, "62972b88f9bb00984abaf492d7e426ce2348537b1262dc7b59efd2e1bdf17bbd"],
	["res://audio/music/title_candidate_intro.ogg", 62.501, "d7da5835dad5eb69867f14e8ebc3cf35ee0b3a2311111d32ba424e4a9fe2461e"],
	["res://audio/music/title_loop.ogg", 62.501, "9c10bf21e47386de428fc3b41755e48cef948faa7c0e0529d3458d4eee0496a2"],
	["res://audio/music/victory_candidate_intro.ogg", 18.412, "af53ff067c466697c9d3d7a197521bdc7711986bddbfaca81f3267ab874e04ca"],
	["res://audio/music/victory_loop.ogg", 14.546, "d36bc5995d1d6b1937117cfa3cf1c7334689f5c45df6fcaa2e5e2c26a3197fdb"],
	["res://audio/music/game_over.ogg", 11.668, "fde8c2f09fa239a48c93e860979af6d46b94bf216ad05fd629c9a498e6e8872f"],
	# OPEN-005: the Cordys cue must come from the pinned Phoenix derivatives,
	# not the obsolete demo MP3 or an untracked local copy.
	["res://audio/music/final_boss_intro.ogg", 22.589, "e00bd3d8601cffad0fd9d2232853ceefcaa974aa06b0d924a4208cdf8f9c675f"],
	["res://audio/music/final_boss_loop.ogg", 90.353, "dfa5e61d103c53b9420dc58085079684a5dd2d25e2fde835ef37bba45f14eda4"],
	["res://audio/sfx/ui/hover.wav", 4.039, "0a33872ad6512eac29043f86292019f28e00418702978f817c3495d02bca6778"],
	["res://audio/sfx/ui/click.wav", 4.039, "fa4ba4bd62e94c085dc790c100d16cad6ce3dd72b5bf8ed530aedfc281bd4922"],
	["res://audio/sfx/ui/start_game.wav", 7.295, "e3bd6c7e8e5b8587b8be2ad318bed5518ce4bb84fbc6477253af13e626e5a5ab"],
]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for definition in ASSETS:
		var path := String(definition[0])
		var expected_length := float(definition[1])
		var expected_sha := String(definition[2])
		if not ResourceLoader.exists(path):
			findings.append("MISSING: %s" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			findings.append("IMPORT: %s did not load as AudioStream" % path)
			continue
		if absf(stream.get_length() - expected_length) > 0.05:
			findings.append("DURATION: %s expected %.3fs, got %.3fs" % [path, expected_length, stream.get_length()])
		var actual_sha := FileAccess.get_sha256(path)
		if actual_sha != expected_sha:
			findings.append("DIGEST: %s expected %s, got %s" % [path, expected_sha, actual_sha])

	for finding in findings:
		print("FINDING  " + finding)
	print("AUDIO ASSETS: clean" if findings.is_empty() else "AUDIO ASSETS: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
