extends RefCounted

var _api

func _mod_init(api) -> void:
	_api = api
	api.bind_target(self)


func on_weapon_fired(payload: Dictionary) -> void:
	var weapon_id: String = str(payload.get("weapon_id", ""))
	_api.set_value(payload, "hook_logged", true, "read_events")
	_api.log("Weapon fired: %s" % weapon_id)


func on_damage_dealt(payload: Dictionary) -> void:
	var amount: float = float(payload.get("amount", 0.0))
	var target_id: String = str(payload.get("target_id", ""))
	_api.set_value(payload, "hook_damage_logged", true, "read_events")
	_api.log("Damage dealt to %s: %.1f" % [target_id, amount])


func on_npc_spawned(payload: Dictionary) -> void:
	var npc_id: String = str(payload.get("npc_id", ""))
	_api.log("NPC spawned: %s" % npc_id)


func on_player_joined(payload: Dictionary) -> void:
	var player_id: String = str(payload.get("player_id", ""))
	_api.log("Player joined: %s" % player_id)


func _mod_shutdown() -> void:
	pass