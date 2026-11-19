extends RefCounted

var _api = null

func _mod_init(api) -> void:
	_api = api
	api.subscribe("reload.ping", _on_ping, 100)

func _on_ping(payload: Dictionary) -> void:
	payload["base_version"] = "2.0.0"

func _mod_shutdown() -> void:
	_api = null
