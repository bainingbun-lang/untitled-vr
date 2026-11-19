extends RefCounted

var seen: Array = []


func _mod_init(api):
	api.subscribe("boot.probe", _on_probe)
	api.emit("boot.loaded", {"id": api.module_id})


func _on_probe(payload):
	seen.append(payload.get("value", 0))
