# The battle must contain no words.
#
# Five playtesters said they did not read the text, so "we removed the text"
# has to be a checked fact rather than a claim that decays the next time
# somebody adds a helpful label.
extends SceneTree
var frames := 0
var scene: Node
var findings: Array = []
func _initialize() -> void:
	scene = (load("res://game/battle.tscn") as PackedScene).instantiate()
	root.add_child(scene)
func _process(_d: float) -> bool:
	frames += 1
	if frames < 6:
		return false
	_walk(scene)
	for f in findings:
		print("FINDING  " + f)
	print("NOTEXT: clean" if findings.is_empty() else "NOTEXT: %d finding(s)" % findings.size())
	quit(0 if findings.is_empty() else 1)
	return true
func _walk(n: Node) -> void:
	if n is Label and String((n as Label).text).strip_edges() != "":
		findings.append("LABEL: %s says \"%s\"" % [n.name, (n as Label).text])
	if n is Label3D and String((n as Label3D).text).strip_edges() != "":
		var t := String((n as Label3D).text)
		# digits are allowed: a damage number was asked for by name
		if not t.lstrip("-+").is_valid_int():
			findings.append("LABEL3D: %s says \"%s\"" % [n.name, t])
	if n is Button and String((n as Button).text).strip_edges() != "":
		findings.append("BUTTON: %s says \"%s\"" % [n.name, (n as Button).text])
	for c in n.get_children():
		_walk(c)
