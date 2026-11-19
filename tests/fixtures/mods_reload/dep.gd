extends RefCounted

func _mod_init(api) -> void:
	api.subscribe("reload.ping", _on_ping, 100)

func _on_ping(payload: Dictionary) -> void:
	payload["dep_marker"] = "dep-ok"
