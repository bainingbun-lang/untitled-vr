extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

const ROOT := "user://test_mod_integration"

func _init() -> void:
	_cleanup()

func _initialize() -> void:
	await process_frame
	
	ContentRegistryScript.reset()

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)

	var mod_dir := ROOT.path_join("mods/reload_test")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_dir))
	var content_dir := mod_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(content_dir))

	var manifest := {
		"schema_version": 1,
		"id": "test.reload",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 100,
	}
	var manifest_path := mod_dir.path_join("mod.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()

	var entry_script := """extends RefCounted
var _api
func _mod_init(api):
	_api = api
	api.emit("mod.ready", {"id": api.module_id})
func _mod_shutdown():
	pass
"""
	file = FileAccess.open(mod_dir.path_join("entry.gd"), FileAccess.WRITE)
	file.store_string(entry_script)
	file.close()

	var weapon_v1 := {
		"content": [{
			"type": "weapon",
			"id": "test.reload:pistol",
			"name": "Pistol V1",
			"damage": 20.0,
			"fire_rate": 5.0,
			"range": 50.0,
			"mag": 15,
			"auto": false,
			"spread": 1.0,
			"pellets": 1,
			"tags": ["pistol", "test"],
			"reload_time": 1.5,
			"weight": 1.0,
			"impulse": 0.05,
			"uses_ammo": true,
			"penetration": 0.2,
			"falloff_start": 15.0,
			"falloff_end": 50.0,
			"falloff_min": 0.3,
			"projectile_speed": 0.0,
			"projectile_gravity": 0.0,
			"projectile_min_distance": 20.0,
			"impact_speed": 100.0,
			"effect_scale": 0.8,
			"max_penetrations": 1,
			"max_ricochets": 0,
			"model": "res://assets/models/weapons/pistol.gltf",
			"ammo_id": "test.reload:pistol_ammo",
			"caliber": "9x19mm"
		}]
	}
	file = FileAccess.open(content_dir.path_join("weapons.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(weapon_v1))
	file.close()

	# Test load_mod directly
	print("=== Direct load_mod test ===")
	var load_result := ContentRegistryScript.instance().load_mod("test.reload", mod_dir, 100)
	print("load_mod result: " + str(load_result))

	var weapons_before := ContentRegistryScript.instance().entries("weapon")
	print("weapons_before keys: " + str(weapons_before.keys()))
	print("weapons_before has test.reload:pistol: " + str(weapons_before.has("test.reload:pistol")))
	
	# Check the mod in the registry
	print("=== Mods in registry ===")
	var all_mods = ContentRegistryScript.instance().all_mods()
	print("all_mods: " + str(all_mods.keys()))
	
	_cleanup()
	quit(0)

func _cleanup() -> void:
	var dir := DirAccess.open(ROOT)
	if dir != null:
		dir.list_dir_begin()
		var name := dir.get_next()
		while name != "":
			if name != "." and name != "..":
				var path := ROOT.path_join(name)
				_remove_dir_recursive(path)
			name = dir.get_next()
		dir.list_dir_end()
		dir.remove_absolute(ROOT)

func _remove_dir_recursive(path: String) -> void:
	var da := DirAccess.open(path)
	if da != null:
		da.list_dir_begin()
		var name := da.get_next()
		while name != "":
			if name != "." and name != "..":
				var child := path.path_join(name)
				if da.current_is_dir():
					_remove_dir_recursive(child)
				else:
					DirAccess.remove_absolute(ProjectSettings.globalize_path(child))
			name = da.get_next()
		da.list_dir_end()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))