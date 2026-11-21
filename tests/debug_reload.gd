extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModProfileScript = preload("res://core/mod_profile.gd")
const ModReloaderScript = preload("res://core/mod_reloader.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

const ROOT := "user://debug_reload"

func _init() -> void:
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
    var file2 := FileAccess.open(mod_dir.path_join("entry.gd"), FileAccess.WRITE)
    file2.store_string(entry_script)
    file2.close()
    
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
            "fire_mode": "semi",
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
    var file3 := FileAccess.open(content_dir.path_join("weapons.json"), FileAccess.WRITE)
    file3.store_string(JSON.stringify(weapon_v1))
    file3.close()
    
    var candidates := [{"manifest": manifest, "dir": mod_dir}]
    var load_result := registry.load_all(candidates)
    print("Initial load result: ", load_result)
    print("Loaded IDs: ", registry.loaded_ids())
    
    ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())
    
    var weapons_before := ContentRegistryScript.instance().entries("weapon")
    print("Weapons before reload: ", weapons_before.keys())
    print("Has test.reload:pistol before: ", weapons_before.has("test.reload:pistol"))
    print("ContentRegistry errors before: ", ContentRegistryScript.instance().errors())
    
    var weapon_v2 := weapon_v1.duplicate(true)
    weapon_v2["content"][0]["damage"] = 25.0
    weapon_v2["content"][0]["name"] = "Pistol V2"
    var file4 := FileAccess.open(content_dir.path_join("weapons.json"), FileAccess.WRITE)
    file4.store_string(JSON.stringify(weapon_v2))
    file4.close()
    
    print("Updated content file: ", FileAccess.get_file_as_string(content_dir.path_join("weapons.json")))
    
    var reloader = ModReloaderScript.new()
    var reload_result := reloader.reload(registry, loader, "test.reload", mod_dir)
    print("Reload result: ", reload_result)
    print("Loaded IDs after reload: ", registry.loaded_ids())
    
    ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())
    
    var weapons_after := ContentRegistryScript.instance().entries("weapon")
    print("Weapons after reload: ", weapons_after.keys())
    print("Has test.reload:pistol after: ", weapons_after.has("test.reload:pistol"))
    print("ContentRegistry errors after: ", ContentRegistryScript.instance().errors())
    
    if weapons_after.has("test.reload:pistol"):
        print("Damage after: ", weapons_after["test.reload:pistol"]["damage"])
        print("Name after: ", weapons_after["test.reload:pistol"]["name"])
    
    quit(0)
