class_name NPCMemory
extends RefCounted

var events: Array = []
var capacity: int
var relations: Dictionary = {}

func _init(initial_capacity: int = 32):
	capacity = initial_capacity

func add_event(event: Variant) -> void:
	events.append(event)
	if events.size() > capacity:
		events.remove_at(0)

func set_relation(entity_id: String, value: float) -> void:
	relations[entity_id] = clamp(value, -1.0, 1.0)

func get_relation(entity_id: String) -> float:
	return relations.get(entity_id, 0.0)

func get_events() -> Array:
	return events
