class_name GrabController extends Node3D

var input_source # Removed InputSource type hint to avoid parse error during tests
var hand: String = "right"
var grab_radius: float = 0.2
var grabbed_object: Node3D = null
var tracking_lost_time: float = 0.0
const TRACKING_THRESHOLD = 0.5

func _process(delta: float):
	if not input_source:
		return
	
	if input_source.is_pressed("grip"):
		if not grabbed_object:
			try_grab()
	else:
		release()

	if not input_source.is_tracking(hand):
		tracking_lost_time += delta
		if tracking_lost_time >= TRACKING_THRESHOLD:
			release()
	else:
		tracking_lost_time = 0.0

	if grabbed_object:
		grabbed_object.global_transform = input_source.get_pose(hand)

func try_grab():
	var objects = _get_nearby_objects()
	if objects.size() > 0:
		grabbed_object = objects[0]

func release():
	grabbed_object = null

func _get_nearby_objects() -> Array:
	var results = []
	var pose = input_source.get_pose(hand)
	var tree = get_tree()
	if not tree:
		return []
	var all_nodes = tree.get_nodes_in_group("grabbable")
	var closest_dist = grab_radius
	var closest_node = null
	
	for node in all_nodes:
		if node is Node3D:
			var dist = pose.origin.distance_to(node.global_transform.origin)
			if dist < closest_dist:
				closest_dist = dist
				closest_node = node
	
	if closest_node:
		results.append(closest_node)
	return results
