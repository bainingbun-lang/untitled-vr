extends RefCounted


func _mod_init(api):
	api.emit("modboot.loaded", {"id": api.module_id})
