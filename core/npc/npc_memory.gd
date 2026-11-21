class_name NPCMemory
extends RefCounted

# Event types: "danger", "threat", "attack", "hostile", "peligro", "conversation", "routine", "social", "help", "witness"
var events: Array = []
var capacity: int
var relations: Dictionary = {}

# Daily life memory
var known_waypoints: Dictionary = {}  # waypoint_id -> { "position": Vector2, "visit_count": int, "last_visit": float, "activity": String }
var known_entities: Dictionary = {}   # entity_id -> { "name": String, "role": String, "last_seen": float, "interaction_count": int, "relationship": float }
var conversation_history: Array = []  # { "partner_id": String, "topic": String, "time": float, "duration": float, "outcome": String }
var routine_memory: Dictionary = {}   # activity -> { "preferred_waypoints": Array, "avg_duration": float, "success_count": int }

# Location memory
var home_location: Vector2 = Vector2.ZERO
var work_location: Vector2 = Vector2.ZERO
var favorite_spots: Array = []  # { "id": String, "position": Vector2, "type": String, "visit_count": int }

func _init(initial_capacity: int = 64) -> void:
	capacity = initial_capacity

func add_event(event: Variant) -> void:
	events.append(event)
	if events.size() > capacity:
		events.remove_at(0)

func add_typed_event(event_type: String, data: Dictionary = {}, severity: float = 1.0) -> void:
	var event = {
		"type": event_type,
		"data": data,
		"severity": clamp(severity, 0.0, 1.0),
		"time": Time.get_ticks_msec() / 1000.0
	}
	add_event(event)

func set_relation(entity_id: String, value: float) -> void:
	relations[entity_id] = clamp(value, -1.0, 1.0)

func get_relation(entity_id: String) -> float:
	return relations.get(entity_id, 0.0)

func modify_relation(entity_id: String, delta: float) -> float:
	var current = get_relation(entity_id)
	var new_value = clamp(current + delta, -1.0, 1.0)
	relations[entity_id] = new_value
	return new_value

func get_events() -> Array:
	return events

func get_recent_events(count: int = 10) -> Array:
	var start = max(0, events.size() - count)
	return events.slice(start, events.size())

func get_events_by_type(event_type: String, max_count: int = 20) -> Array:
	var filtered: Array = []
	for event in events:
		if event is Dictionary and str(event.get("type", "")).to_lower() == event_type.to_lower():
			filtered.append(event)
			if filtered.size() >= max_count:
				break
	return filtered

func clear_events() -> void:
	events.clear()

# Waypoint memory
func record_waypoint_visit(waypoint_id: String, position: Vector2, activity: String, current_time: float) -> void:
	var entry = known_waypoints.get(waypoint_id, {})
	entry["position"] = position
	entry["visit_count"] = int(entry.get("visit_count", 0)) + 1
	entry["last_visit"] = current_time
	entry["activity"] = activity
	known_waypoints[waypoint_id] = entry

func get_waypoint_info(waypoint_id: String) -> Dictionary:
	return known_waypoints.get(waypoint_id, {})

func get_favorite_waypoints(activity: String = "", count: int = 5) -> Array:
	var filtered: Array = []
	for wp_id in known_waypoints.keys():
		var wp = known_waypoints[wp_id]
		if activity == "" or str(wp.get("activity", "")) == activity:
			filtered.append({"id": wp_id, "visit_count": int(wp.get("visit_count", 0)), "position": wp.get("position", Vector2.ZERO)})
	
	filtered.sort_custom(func(a, b): return int(b["visit_count"]) > int(a["visit_count"]))
	return filtered.slice(0, min(count, filtered.size()))

# Entity memory
func record_entity_interaction(entity_id: String, entity_name: String = "", entity_role: String = "", current_time: float = 0.0) -> void:
	var entry = known_entities.get(entity_id, {})
	entry["name"] = entity_name if entity_name != "" else entry.get("name", "Unknown")
	entry["role"] = entity_role if entity_role != "" else entry.get("role", "unknown")
	entry["last_seen"] = current_time if current_time > 0 else Time.get_unix_time_from_system()
	entry["interaction_count"] = int(entry.get("interaction_count", 0)) + 1
	known_entities[entity_id] = entry

func get_entity_info(entity_id: String) -> Dictionary:
	return known_entities.get(entity_id, {})

func get_known_entities(role_filter: String = "", min_relationship: float = -1.0) -> Array:
	var result: Array = []
	for eid in known_entities.keys():
		var ent = known_entities[eid]
		if role_filter != "" and str(ent.get("role", "")) != role_filter:
			continue
		var rel = get_relation(eid)
		if rel < min_relationship:
			continue
		result.append({"id": eid, "name": ent.get("name", "Unknown"), "role": ent.get("role", "unknown"), "relationship": rel, "interactions": int(ent.get("interaction_count", 0))})
	return result

# Conversation memory
func record_conversation(partner_id: String, topic: String, duration: float, outcome: String, current_time: float = 0.0) -> void:
	var entry = {
		"partner_id": partner_id,
		"topic": topic,
		"duration": duration,
		"outcome": outcome,
		"time": current_time if current_time > 0 else Time.get_unix_time_from_system()
	}
	conversation_history.append(entry)
	if conversation_history.size() > 50:
		conversation_history.remove_at(0)

func get_recent_conversations(count: int = 10) -> Array:
	var start = max(0, conversation_history.size() - count)
	return conversation_history.slice(start, conversation_history.size())

func get_conversation_partners() -> Array:
	var partners: Array = []
	for conv in conversation_history:
		var pid = str(conv.get("partner_id", ""))
		if pid != "" and not partners.has(pid):
			partners.append(pid)
	return partners

# Routine memory
func record_routine_activity(activity: String, waypoints: Array, duration: float, success: bool) -> void:
	var entry = routine_memory.get(activity, {})
	entry["avg_duration"] = (float(entry.get("avg_duration", duration)) + duration) * 0.5
	entry["success_count"] = int(entry.get("success_count", 0)) + (1 if success else 0)
	entry["total_attempts"] = int(entry.get("total_attempts", 0)) + 1
	
	var pref_wps = entry.get("preferred_waypoints", []) as Array
	for wp in waypoints:
		var wp_id = str(wp.get("id", wp.get("waypoint_id", "")))
		if wp_id != "" and not pref_wps.has(wp_id):
			pref_wps.append(wp_id)
	entry["preferred_waypoints"] = pref_wps
	
	routine_memory[activity] = entry

func get_routine_info(activity: String) -> Dictionary:
	return routine_memory.get(activity, {})

func get_preferred_waypoints_for_activity(activity: String) -> Array:
	var info = get_routine_info(activity)
	return info.get("preferred_waypoints", [])

# Location memory
func set_home_location(position: Vector2) -> void:
	home_location = position

func set_work_location(position: Vector2) -> void:
	work_location = position

func add_favorite_spot(spot_id: String, position: Vector2, spot_type: String) -> void:
	for spot in favorite_spots:
		if str(spot.get("id", "")) == spot_id:
			spot["position"] = position
			spot["type"] = spot_type
			spot["visit_count"] = int(spot.get("visit_count", 0)) + 1
			return
	favorite_spots.append({"id": spot_id, "position": position, "type": spot_type, "visit_count": 1})

func get_favorite_spots(spot_type: String = "") -> Array:
	if spot_type == "":
		return favorite_spots
	var result: Array = []
	for spot in favorite_spots:
		if str(spot.get("type", "")) == spot_type:
			result.append(spot)
	return result

func visit_favorite_spot(spot_id: String) -> void:
	for spot in favorite_spots:
		if str(spot.get("id", "")) == spot_id:
			spot["visit_count"] = int(spot.get("visit_count", 0)) + 1
			break

# Utility
func get_danger_level() -> float:
	var best: float = 0.0
	var total: float = float(events.size())
	if total == 0:
		return 0.0
	
	for i in range(events.size()):
		var event: Variant = events[i]
		var kind: String = ""
		var severity: float = 1.0
		if event is Dictionary:
			var entry: Dictionary = event
			kind = str(entry.get("type", entry.get("kind", entry.get("event", "")))).to_lower()
			severity = clamp(float(entry.get("severity", entry.get("intensity", entry.get("value", 1.0)))), 0.0, 1.0)
		elif event is String:
			kind = (event as String).to_lower()
		else:
			continue
		
		if _is_danger_kind(kind):
			var recency: float = float(i + 1) / total
			best = max(best, severity * (0.5 + 0.5 * recency))
	
	return clamp(best, 0.0, 1.0)

func _is_danger_kind(kind: String) -> bool:
	return kind.contains("danger") or kind.contains("threat") or kind.contains("attack") or kind.contains("hostile") or kind.contains("peligro")

func get_social_memory() -> Dictionary:
	return {
		"relations": relations.duplicate(true),
		"known_entities": known_entities.duplicate(true),
		"recent_conversations": get_recent_conversations(5)
	}

func get_routine_memory() -> Dictionary:
	return {
		"known_waypoints": known_waypoints.duplicate(true),
		"routine_memory": routine_memory.duplicate(true),
		"favorite_spots": favorite_spots.duplicate(true),
		"home": home_location,
		"work": work_location
	}

func get_full_memory_dump() -> Dictionary:
	return {
		"events": events.duplicate(true),
		"relations": relations.duplicate(true),
		"known_entities": known_entities.duplicate(true),
		"known_waypoints": known_waypoints.duplicate(true),
		"conversation_history": conversation_history.duplicate(true),
		"routine_memory": routine_memory.duplicate(true),
		"favorite_spots": favorite_spots.duplicate(true),
		"home_location": home_location,
		"work_location": work_location
	}