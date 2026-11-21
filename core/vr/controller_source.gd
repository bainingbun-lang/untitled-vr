class_name ControllerSource extends InputSource

var left_controller: XRController3D
var right_controller: XRController3D

func _init(left: XRController3D = null, right: XRController3D = null):
	left_controller = left
	right_controller = right

func get_pose(hand: String) -> Transform3D:
	var controller = _get_controller(hand)
	if controller:
		return controller.global_transform
	return Transform3D.IDENTITY

func is_pressed(action: String) -> bool:
	if action == "squeeze" or action == "grip":
		return (left_controller and left_controller.is_button_pressed(XRController3D.BUTTON_GRIP)) or \
			   (right_controller and right_controller.is_button_pressed(XRController3D.BUTTON_GRIP))
	return false

func is_tracking(hand: String) -> bool:
	var controller = _get_controller(hand)
	return controller != null and controller.get_tracker().is_active() if controller and controller.get_tracker() else false

func get_joint(_hand: String, _joint: String) -> Transform3D:
	return Transform3D.IDENTITY

func _get_controller(hand: String) -> XRController3D:
	if hand == "left":
		return left_controller
	if hand == "right":
		return right_controller
	return null
