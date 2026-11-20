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

	var mod_dir := ROOT.path_join("mods/content_test")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_dir))
	var content_dir := mod_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(content_dir))

	var manifest := {
		"schema_version": 1,
		"id": "test.contentmod",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 100,
	}
	var manifest_path := mod_dir.path_join("mod.json")
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest))
	file.close()

	var npc_json := {
		"content": [{
			"type": "npc_type",
			"id": "test.contentmod:test_zombie",
			"name": "Test Zombie",
			"role": "enemy",
			"models": ["res://assets/models/npcs/test_zombie.gltf"],
			"aliases": [],
			"health": 150.0,
			"speed": 2.5,
			"weapon_id": "",
			"zombie": true,
			"tags": ["zombie", "test"]
		}]
	}
	var npc_path := content_dir.path_join("npcs.json")
	file = FileAccess.open(npc_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(npc_json))
	file.close()
	
	print("NPC file exists: " + str(FileAccess.file_exists(npc_path)))
	print("NPC file content: " + FileAccess.get_file_as_string(npc_path))

	var candidates := [{"manifest": manifest, "dir": mod_dir}]
	var load_result := registry.load_all(candidates)
	print("load_result: " + str(load_result))

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var npcs := ContentRegistryScript.instance().entries("npc_type")
	print("npcs keys: " + str(npcs.keys()))
	
	# Also test direct validation
	var reg = ContentRegistryScript.instance()
	var result := reg.validate("npc_type", {
		"type": "npc_type",
		"id": "test.contentmod:test_zombie",
		"name": "Test Zombie",
		"role": "enemy",
		"models": ["res://assets/models/npcs/test_zombie.gltf"],
		"aliases": [],
		"health": 150.0,
		"speed": 2.5,
		"weapon_id": "",
		"zombie": true,
		"tags": ["zombie", "test"]
	}, "test.contentmod")
	print("validate result: " + str(result))
	
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