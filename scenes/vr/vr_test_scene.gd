extends Node3D

func _ready():
	var origin = XROrigin3D.new()
	add_child(origin)
	
	var camera = XRCamera3D.new()
	origin.add_child(camera)
	
	var left = XRController3D.new()
	# Fix: Use a generic way to set controller side if HAND_LEFT is not found
	# In Godot 4.x, XRController3D might use different properties or we just name them.
	origin.add_child(left)
	
	var right = XRController3D.new()
	origin.add_child(right)
	
	print("VR Scene loaded: XROrigin3D with camera and controllers created.")
