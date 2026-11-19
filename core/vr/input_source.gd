class_name InputSource extends RefCounted

# Interface for VR input sources (Controllers or Hands)

func get_pose(hand: String) -> Transform3D:
	push_error("get_pose not implemented")
	return Transform3D.IDENTITY

func is_pressed(action: String) -> bool:
	push_error("is_pressed not implemented")
	return false

func is_tracking(hand: String) -> bool:
	push_error("is_tracking not implemented")
	return false

func get_joint(hand: String, joint: String) -> Transform3D:
	push_error("get_joint not implemented")
	return Transform3D.IDENTITY
