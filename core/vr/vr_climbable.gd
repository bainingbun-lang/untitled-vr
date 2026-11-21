class_name VrClimbable
extends Node3D

## VrClimbable - Adapted from godot-xr-tools XRToolsClimbable
##
## Adds climbing support to any StaticBody3D or Node3D.
## For climbing to work, the player must have VrClimb integrated into VrRig.


## Whether the grip control must be held to keep holding the climbable
@export var press_to_hold: bool = true

## Optional grab points (Node3D children with specific names)
var _grab_points: Array[Node3D] = []

## Dictionary of temporary grabs keyed by the hand/controller node
var _grab_temps: Dictionary[Node3D, Node3D] = {}

## Dictionary of active grabs keyed by the hand/controller node
var _grabs: Dictionary[Node3D, Node3D] = {}


func _ready() -> void:
	# Get all grab points (children that are Node3D and named "grab_point_*")
	for child in get_children():
		if child is Node3D and child.name.begins_with("grab_point"):
			_grab_points.push_back(child)


## Called by VrClimb when user presses the grip action while holding this object
func action() -> void:
	pass


## Whether this can be picked up by VrClimb
func can_pick_up(_by: Node3D) -> bool:
	return true


## Gets the grab handle for a specific hand
func get_grab_handle(by: Node3D) -> Node3D:
	return _grabs.get(by, null)


## Whether this is currently picked up by any hand
func is_picked_up() -> bool:
	return not _grabs.is_empty()


## Called by VrClimb when this is let go by a controller
func let_go(
		by: Node3D,
		_p_linear_velocity: Vector3,
		_p_angular_velocity: Vector3
) -> void:
	_grabs.erase(by)


## Called by VrClimb when this is picked up by a controller
func pick_up(by: Node3D) -> void:
	# Get the best permanent grab-point
	var point := _get_grab_point(by)
	if not point:
		# Get a temporary grab-point for the pickup
		point = _grab_temps.get(by)
		if not point:
			# Create a new temporary grab-point childed to the climbable
			point = Node3D.new()
			add_child(point)
			_grab_temps[by] = point

		# Set the temporary to the current position (only if controller is in tree)
		if by.is_inside_tree():
			point.global_transform = by.global_transform

	# Save the grab
	_grabs[by] = point


## Ignores highlighting requests
func request_highlight(_from: Node3D, _on: bool) -> void:
	pass


## Finds the most suitable grab-point for the grabber
func _get_grab_point(by: Node3D) -> Node3D:
	var best_fitness: float = 0.0
	var best_point: Node3D = null
	
	for point in _grab_points:
		if not is_instance_valid(point):
			continue
		var fitness: float = _calculate_fitness(point, by)
		if fitness > best_fitness:
			best_fitness = fitness
			best_point = point
	
	return best_point


func _calculate_fitness(point: Node3D, grabber: Node3D) -> float:
	# Fitness based on distance (closer is better)
	if not grabber.is_inside_tree():
		return 0.0
	var distance: float = point.global_position.distance_to(grabber.global_position)
	return 1.0 / (distance + 0.1)