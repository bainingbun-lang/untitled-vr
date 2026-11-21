class_name NPCRoutine
extends RefCounted

# Schedule entry: { "hour_start": float, "hour_end": float, "activity": String, "waypoints": Array[Vector2], "duration_range": Vector2, "metadata": Dictionary }
# Activity types: "patrol", "pause", "look_around", "converse", "office_work", "eat", "rest", "idle"
var schedule: Array = []

# Patrol waypoints: Array of { "id": String, "position": Vector2, "wait_time": float, "look_around": bool }
var patrol_waypoints: Array = []

# Current state
var current_activity: String = "idle"
var current_waypoint_index: int = -1
var activity_start_time: float = 0.0
var activity_duration: float = 0.0
var is_paused: bool = false
var conversation_partner: String = ""

func _init(initial_schedule: Array = [], initial_waypoints: Array = []) -> void:
	schedule = initial_schedule
	patrol_waypoints = initial_waypoints

func get_current_activity(sim_hour: float) -> Dictionary:
	if schedule.is_empty():
		return _get_default_activity(sim_hour)
	
	for entry in schedule:
		var start = float(entry.get("hour_start", 0.0))
		var end = float(entry.get("hour_end", 24.0))
		if _is_hour_in_range(sim_hour, start, end):
			var result = entry.duplicate(true)
			if not result.has("waypoints") and patrol_waypoints.size() > 0:
				result["waypoints"] = patrol_waypoints
			return result
	
	return _get_default_activity(sim_hour)

func _get_default_activity(sim_hour: float) -> Dictionary:
	if sim_hour >= 6.0 and sim_hour < 9.0:
		return {"activity": "patrol", "hour_start": 6.0, "hour_end": 9.0, "waypoints": patrol_waypoints}
	elif sim_hour >= 9.0 and sim_hour < 12.0:
		return {"activity": "office_work", "hour_start": 9.0, "hour_end": 12.0}
	elif sim_hour >= 12.0 and sim_hour < 14.0:
		return {"activity": "eat", "hour_start": 12.0, "hour_end": 14.0}
	elif sim_hour >= 14.0 and sim_hour < 18.0:
		return {"activity": "office_work", "hour_start": 14.0, "hour_end": 18.0}
	elif sim_hour >= 18.0 and sim_hour < 22.0:
		return {"activity": "patrol", "hour_start": 18.0, "hour_end": 22.0, "waypoints": patrol_waypoints}
	else:
		return {"activity": "rest", "hour_start": 22.0, "hour_end": 6.0}

func _is_hour_in_range(hour: float, start: float, end: float) -> bool:
	if start <= end:
		return hour >= start and hour < end
	else:
		return hour >= start or hour < end

func start_activity(activity_data: Dictionary, current_time: float) -> void:
	current_activity = str(activity_data.get("activity", "idle"))
	activity_start_time = current_time
	activity_duration = _calculate_duration(activity_data)
	current_waypoint_index = -1
	is_paused = false
	conversation_partner = ""

func _calculate_duration(activity_data: Dictionary) -> float:
	var dur_range: Variant = activity_data.get("duration_range", Vector2(30.0, 60.0))
	if dur_range is Vector2:
		return randf_range(dur_range.x, dur_range.y)
	return float(dur_range)

func update_activity(current_time: float, sim_hour: float) -> Dictionary:
	var elapsed = current_time - activity_start_time
	var activity_data = get_current_activity(sim_hour)
	
	if elapsed >= activity_duration or activity_data.get("activity") != current_activity:
		start_activity(activity_data, current_time)
		return {"changed": true, "activity": current_activity, "waypoint_index": current_waypoint_index}
	
	var result = {"changed": false, "activity": current_activity, "waypoint_index": current_waypoint_index}
	
	match current_activity:
		"patrol":
			result = _update_patrol(activity_data, current_time)
		"pause", "look_around":
			result = _update_pause(activity_data, current_time)
		"converse":
			result = _update_converse(activity_data, current_time)
		"office_work":
			result = _update_office_work(activity_data, current_time)
		"eat", "rest":
			result = _update_rest(activity_data, current_time)
	
	return result

func _update_patrol(activity_data: Dictionary, current_time: float) -> Dictionary:
	var waypoints: Array = activity_data.get("waypoints", patrol_waypoints)
	if waypoints.is_empty():
		return {"changed": false, "activity": "idle", "waypoint_index": -1}
	
	if current_waypoint_index < 0:
		current_waypoint_index = 0
		var wp = waypoints[0]
		var wait = float(wp.get("wait_time", 2.0))
		activity_duration = wait
		activity_start_time = current_time
		return {"changed": true, "activity": "patrol", "waypoint_index": 0, "waypoint": wp, "action": "arrived"}
	
	var wp = waypoints[current_waypoint_index]
	var wait = float(wp.get("wait_time", 2.0))
	var elapsed = current_time - activity_start_time
	
	if elapsed >= wait:
		current_waypoint_index = (current_waypoint_index + 1) % waypoints.size()
		var next_wp = waypoints[current_waypoint_index]
		var next_wait = float(next_wp.get("wait_time", 2.0))
		activity_duration = next_wait
		activity_start_time = current_time
		return {"changed": true, "activity": "patrol", "waypoint_index": current_waypoint_index, "waypoint": next_wp, "action": "arrived"}
	
	if bool(wp.get("look_around", false)) and elapsed > wait * 0.5:
		return {"changed": false, "activity": "patrol", "waypoint_index": current_waypoint_index, "waypoint": wp, "action": "look_around"}
	
	return {"changed": false, "activity": "patrol", "waypoint_index": current_waypoint_index, "waypoint": wp, "action": "wait"}

func _update_pause(activity_data: Dictionary, current_time: float) -> Dictionary:
	var action = "pause"
	if current_activity == "look_around":
		action = "look_around"
	return {"changed": false, "activity": current_activity, "waypoint_index": -1, "action": action}

func _update_converse(activity_data: Dictionary, current_time: float) -> Dictionary:
	var partner = activity_data.get("partner_id", conversation_partner)
	if partner == "":
		return {"changed": true, "activity": "idle", "waypoint_index": -1, "reason": "no_partner"}
	
	conversation_partner = str(partner)
	var elapsed = current_time - activity_start_time
	if elapsed >= activity_duration:
		return {"changed": true, "activity": "idle", "waypoint_index": -1, "reason": "conversation_ended"}
	
	return {"changed": false, "activity": "converse", "waypoint_index": -1, "partner": conversation_partner, "progress": elapsed / activity_duration}

func _update_office_work(activity_data: Dictionary, current_time: float) -> Dictionary:
	var desk_id = str(activity_data.get("desk_id", ""))
	var elapsed = current_time - activity_start_time
	var progress = elapsed / activity_duration
	
	if progress < 0.1:
		return {"changed": false, "activity": "office_work", "waypoint_index": -1, "phase": "sit_down", "desk_id": desk_id, "progress": progress}
	elif progress < 0.9:
		return {"changed": false, "activity": "office_work", "waypoint_index": -1, "phase": "working", "desk_id": desk_id, "progress": progress}
	else:
		return {"changed": false, "activity": "office_work", "waypoint_index": -1, "phase": "stand_up", "desk_id": desk_id, "progress": progress}

func _update_rest(activity_data: Dictionary, current_time: float) -> Dictionary:
	return {"changed": false, "activity": current_activity, "waypoint_index": -1, "action": "resting"}

func get_current_stop(simulated_hour: float) -> Dictionary:
	var activity = get_current_activity(simulated_hour)
	var waypoints: Array = activity.get("waypoints", patrol_waypoints)
	
	if waypoints.is_empty():
		return {}
	
	if current_waypoint_index >= 0 and current_waypoint_index < waypoints.size():
		var wp = waypoints[current_waypoint_index]
		return {
			"waypoint_id": str(wp.get("id", "wp_%d" % current_waypoint_index)),
			"cell": wp.get("position", Vector2.ZERO),
			"goal": wp.get("position", Vector2.ZERO),
			"activity": current_activity,
			"duration": activity_duration
		}
	
	var first_wp = waypoints[0]
	return {
		"waypoint_id": str(first_wp.get("id", "wp_0")),
		"cell": first_wp.get("position", Vector2.ZERO),
		"goal": first_wp.get("position", Vector2.ZERO),
		"activity": current_activity,
		"duration": float(first_wp.get("wait_time", 2.0))
	}

func set_patrol_waypoints(waypoints: Array) -> void:
	patrol_waypoints = waypoints
	current_waypoint_index = -1

func add_patrol_waypoint(waypoint: Dictionary) -> void:
	patrol_waypoints.append(waypoint)

func clear_patrol_waypoints() -> void:
	patrol_waypoints.clear()
	current_waypoint_index = -1

func set_schedule(new_schedule: Array) -> void:
	schedule = new_schedule

func get_schedule() -> Array:
	return schedule

func set_conversation_partner(partner_id: String) -> void:
	conversation_partner = str(partner_id)

func get_conversation_partner() -> String:
	return conversation_partner

func get_patrol_waypoints() -> Array:
	return patrol_waypoints

func force_next_waypoint() -> void:
	if patrol_waypoints.size() > 0:
		current_waypoint_index = (current_waypoint_index + 1) % patrol_waypoints.size()