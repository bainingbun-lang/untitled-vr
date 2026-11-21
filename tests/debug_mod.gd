extends SceneTree

const ModRegistryScript = preload("res://core/mod_registry.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

const ROOT := "user://debug_mod"

func _init() -> void:
    var bus = EventBusScript.new()
    var registry = ModRegistryScript.new(bus)
    
    var mod_dir := ROOT.path_join("mods/test")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_dir))
    var content_dir := mod_dir.path_join("content")
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(content_dir))
    
    var manifest = {
        "schema_version": 1,
        "id": "test.debug",
        "version": "1.0.0",
        "engine": "4.7",
        "priority": 100,
    }
    var manifest_path := mod_dir.path_join("mod.json")
    var file := FileAccess.open(manifest_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(manifest))
    file.close()
    
    var weapon_json = {
        "content": [{
            "type": "weapon",
            "id": "test.debug:test_rifle",
            "name": "Test Rifle",
            "damage": 30.0,
            "fire_rate": 8.0,
            "range": 100.0,
            "mag": 30,
            "auto": true,
            "spread": 2.0,
            "pellets": 1,
            "tags": ["rifle", "test"],
            "reload_time": 2.0,
            "weight": 3.5,
            "impulse": 0.1,
            "uses_ammo": true,
            "penetration": 0.5,
            "falloff_start": 30.0,
            "falloff_end": 100.0,
            "falloff_min": 0.2,
            "projectile_speed": 0.0,
            "projectile_gravity": 0.0,
            "projectile_min_distance": 50.0,
            "impact_speed": 150.0,
            "effect_scale": 1.0,
            "max_penetrations": 2,
            "max_ricochets": 1,
            "model": "res://assets/models/weapons/test_rifle.gltf",
            "ammo_id": "test.debug:test_rifle_ammo",
            "caliber": "5.56x45mm"
        }]
    }
    var file2 := FileAccess.open(content_dir.path_join("weapons.json"), FileAccess.WRITE)
    file2.store_string(JSON.stringify(weapon_json))
    file2.close()
    
    print("Files in mod_dir: ", DirAccess.open(mod_dir).get_files())
    print("Files in content_dir: ", DirAccess.open(content_dir).get_files())
    
    var candidates = [{"manifest": manifest, "dir": mod_dir}]
    var load_result := registry.load_all(candidates)
    print("Load result: ", load_result)
    
    ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())
    
    var weapons := ContentRegistryScript.instance().entries("weapon")
    print("Weapons: ", weapons.keys())
    
    var public_weapons := ContentRegistryScript.instance().all("weapon")
    print("Public weapons: ", public_weapons.keys())
    
    if weapons.has("test.debug:test_rifle"):
        print("SUCCESS: test.debug:test_rifle found in entries")
    else:
        print("FAIL: test.debug:test_rifle NOT found in entries")
        print("ContentRegistry errors: ", ContentRegistryScript.instance().errors())
    
    quit(0)
