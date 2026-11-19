class_name NPCLOD
extends RefCounted

var last_update_time: float = 0.0

func get_update_interval(distance: float) -> float:
	if distance < 10.0:
		return 0.0 # Every frame
	elif distance < 50.0:
		return 1.0 # Every second
	else:
		return 5.0 # Every 5 seconds

func should_update(current_time: float, distance: float) -> bool:
	var interval = get_update_interval(distance)
	if interval == 0.0:
		return true
	return (current_time - last_update_time) >= interval

func mark_updated(current_time: float) -> void:
	last_update_time = current_time
