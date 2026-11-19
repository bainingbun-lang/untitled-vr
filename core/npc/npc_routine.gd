class_name NPCRoutine
extends RefCounted

# Stop structure: { "waypoint_id": String, "duration": float }
var stops: Array = []

func _init(initial_stops: Array = []):
	stops = initial_stops

func get_current_stop(simulated_hour: float) -> Dictionary:
	if stops.is_empty():
		return {}
	
	# Simple routine logic: split 24h among stops
	# In a real scenario, stops would have start times.
	# For this core logic, we assume stops are distributed across the day.
	var stop_duration = 24.0 / stops.size()
	var index = int(simulated_hour / stop_duration) % stops.size()
	return stops[index]
