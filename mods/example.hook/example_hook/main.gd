extends RefCounted

var _api
var shots: int = 0


func _mod_init(api) -> void:
	_api = api
	api.bind_target(self)


func on_weapon_fired(payload: Dictionary) -> void:
	shots += 1
	_api.set_value(payload, "hook_shot_count", shots, "read_events")


func on_damage_dealt(payload: Dictionary) -> void:
	var amount := float(payload.get("amount", 0.0))
	_api.set_value(payload, "amount", amount * 1.5)


func _mod_shutdown() -> void:
	pass
