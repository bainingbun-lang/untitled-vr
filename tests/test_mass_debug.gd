extends SceneTree

func _initialize() -> void:
	await process_frame
	var HandAnchorScript = load("res://core/vr/hand_anchor.gd")
	var anchor = HandAnchorScript.new()
	anchor.anchor_mass = 0.1
	root.add_child(anchor)
	await physics_frame
	print("mass: ", anchor.mass)
	print("anchor_mass: ", anchor.anchor_mass)
	if anchor.mass == 0.1:
		print("PASS")
		quit(0)
	else:
		print("FAIL")
		quit(1)