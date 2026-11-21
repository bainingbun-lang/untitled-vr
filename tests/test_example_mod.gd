extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModProfileScript = preload("res://core/mod_profile.gd")

const ROOT := "user://example_mod_test"

func _init() -> void:
    var bus = EventBusScript.new()
    var registry = ModRegistryScript.new(bus)
    var loader = ModLoaderScript.new(bus)
    
    var mod_dir := "res://mods/example.hello"
    print("Loading mod from: ", mod_dir)
    
    var manifest_path := mod_dir.path_join("mod.json")
    var file := FileAccess.open(manifest_path, FileAccess.READ)
    if file == null:
        print("ERROR: Could not open manifest at ", manifest_path)
        quit(1)
    var text := file.get_as_text()
    file.close()
    var manifest: Variant = JSON.parse_string(text)
    if manifest == null or typeof(manifest) != TYPE_DICTIONARY:
        print("ERROR: Invalid manifest JSON")
        quit(1)
    
    print("Manifest: ", manifest)
    
    var candidates := [{"manifest": manifest, "dir": mod_dir}]
    var load_result := registry.load_all(candidates)
    print("Load result: ", load_result)
    
    if not bool(load_result.get("ok", false)):
        print("ERROR: Load failed: ", load_result.get("errors", []))
        quit(1)
    
    print("Loaded IDs: ", registry.loaded_ids())
    _expect(registry.is_loaded("untitled.example-hello"), "mod esta cargado")
    
    # Test mod entry point
    var mod_record: Variant = registry._loaded.get("untitled.example-hello", {})
    print("Mod record: ", mod_record)
    
    # Test unload
    var unload_result := registry.unload("untitled.example-hello")
    print("Unload result: ", unload_result)
    _expect(bool(unload_result.get("ok", false)), "mod descargado ok")
    _expect(not registry.is_loaded("untitled.example-hello"), "mod ya no esta cargado")
    
    print("SUCCESS: Example mod loads and unloads without errors")
    quit(0)

func _expect(condition: bool, message: String) -> void:
    if not condition:
        print("ASSERTION FAILED: ", message)
        quit(1)
    else:
        print("OK: ", message)
