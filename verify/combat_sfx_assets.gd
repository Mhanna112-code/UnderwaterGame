# Prepared Glassgoat gameplay-SFX intake contract.
#
# Usage: godot --headless --path . --script verify/combat_sfx_assets.gd
extends SceneTree

const DIRECTORY := "res://audio/sfx/combat"
const ASSETS := [
	["attack_swirl.ogg", 0.960, "7d802259a99e41367af60d86c76c0ff18e85037781d0529360189eb7bb76f582"],
	["swish_01.ogg", 0.268, "e41b241ef0359d3213e4a76ab74218d3285c43b536377db84e9e2c2a0ac3b045"],
	["swish_02.ogg", 0.247, "0dcc53ea979e7019c0e73ee5f75ef9b26922eee9f1882e02a07ad4d8a99d8111"],
	["swish_03.ogg", 0.232, "c1e38e73d57dbc1284c0154294270a3e544e6c3675b57220de4569a1981441fb"],
	["swish_04.ogg", 0.249, "6ca5c3befd0906781efbcef50754d21fdfc0903acf15093565713381871db8bd"],
	["swish_05.ogg", 0.248, "ed8ced0e66a0675ed4677dace6011e891da7b8e43b538126c006a0468f08a5c1"],
	["swish_06.ogg", 0.270, "faa37f0c4c6178477553ee5d4575becb732784e17e38f4d755ccfc72a020743e"],
	["fast_swish_01.ogg", 0.316, "ecdc0ed547c1770a213fcd36d181c965397db8035dfd234b83cdac7461dcf8c1"],
	["fast_swish_02.ogg", 0.244, "bd2990103e927dc34f44065383c29ef779834ea7c5f932d6a11ff5c7b7d1432e"],
	["fast_swish_03.ogg", 0.268, "96f8187940ad4061ec42bdf838f2a4179ffd66a3058169f5ff213a14282f5b5b"],
	["fast_swish_04.ogg", 0.221, "5e2a5d87f3b83a9deed8f3f6c75c73850a70f3c141ab0ff5442648536cc90e5d"],
	["fast_swish_05.ogg", 0.268, "02e00d59e25f9c66e45b35c0924c8d377313765d468a28d0820e589209d0eefe"],
	["heavy_hit.ogg", 4.900, "f1d9f767c7191694875075142fc78684cb0138d59c8f25c6c44a654612241721"],
	["shockwave_swirl.ogg", 10.000, "c21c07ae0fac261c4c5a60fc6be645c7ced2cb73c26323ab967f3c9690906dfc"],
]

var findings: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for definition in ASSETS:
		var path := "%s/%s" % [DIRECTORY, String(definition[0])]
		if not ResourceLoader.exists(path):
			findings.append("SFX-INTAKE-001: prepared derivative is missing: %s" % path)
			continue
		var stream := load(path) as AudioStream
		_expect(stream != null, "SFX-INTAKE-003: %s did not import as AudioStream" % path)
		if stream == null:
			continue
		_expect(absf(stream.get_length() - float(definition[1])) <= 0.03,
			"SFX-INTAKE-002: %s duration is not the reviewed trimmed derivative" % path)
		_expect(FileAccess.get_sha256(path) == String(definition[2]),
			"SFX-INTAKE-003: %s digest changed" % path)

	var directory := DirAccess.open(DIRECTORY)
	if directory != null:
		for filename in directory.get_files():
			_expect(not filename.to_lower().ends_with(".wav"),
				"SFX-INTAKE-003: raw 96 kHz WAV was committed to the web runtime: %s" % filename)
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		findings.append(message)

func _finish() -> void:
	for finding in findings:
		print("FINDING  " + finding)
	print("COMBAT SFX INTAKE: clean" if findings.is_empty() else "COMBAT SFX INTAKE: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
