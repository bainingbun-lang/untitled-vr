extends RefCounted

var _api


func _mod_init(api) -> void:
	_api = api
	api.subscribe("game.started", _on_game_started, 100)


func _on_game_started(payload: Dictionary) -> void:
	payload["greeted_by"] = "untitled.example-hello"
	payload["count"] = int(payload.get("count", 0)) + 1


func _mod_shutdown() -> void:
	pass
