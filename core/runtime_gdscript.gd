class_name RuntimeGDScript extends RuntimeAdapter

var _manifest: Dictionary
var _instance: Object

func load(manifest: Dictionary, dir: String) -> String:
	_manifest = manifest
	if manifest.has("pack"):
		var pack := str(manifest["pack"])
		var pack_path := ProjectSettings.globalize_path(dir.path_join(pack))
		if not ProjectSettings.load_resource_pack(pack_path, true):
			return "no se pudo cargar el pack '%s'" % pack
	return ""

func init(api: ModApi) -> String:
	if not _manifest.has("entry"):
		return ""
	var entry := str(_manifest["entry"])
	var script: Variant = load(entry)
	if script == null or not (script is Script) or not script.can_instantiate():
		return "no se pudo cargar la entrada '%s'" % entry
	var instance: Object = script.new()
	if instance == null or not instance.has_method("_mod_init"):
		return "la entrada '%s' no implementa _mod_init" % entry
	_instance = instance
	_instance._mod_init(api)
	return ""

func get_instance() -> Object:
	return _instance

func handle_event(event: String, payload: Dictionary) -> Variant:
	if _instance != null and _instance.has_method("handle_event"):
		return _instance.handle_event(event, payload)
	return null

func unload() -> void:
	if _instance != null and _instance.has_method("_mod_shutdown"):
		_instance._mod_shutdown()
	_instance = null
