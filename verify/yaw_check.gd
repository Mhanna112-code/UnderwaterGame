extends SceneTree

func _initialize() -> void:
	var t := Transform3D(Vector3(-4.37114e-08, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, -4.37114e-08), Vector3(31.3579, 1.52881, -18.6907))
	print("basis.get_euler().y = %.4f" % t.basis.get_euler().y)
	var node := CSGBox3D.new()
	node.transform = t
	print("node.rotation.y = %.4f" % node.rotation.y)
	quit(0)
