class_name RuntimeAdapter extends RefCounted

# Contrato: load() e init() devuelven "" si van bien, o un texto de error.
func load(manifest: Dictionary, dir: String) -> String:
	return "RuntimeAdapter.load no implementado"

func init(api: ModApi) -> String:
	return "RuntimeAdapter.init no implementado"

func get_instance() -> Object:
	return null

func handle_event(event: String, payload: Dictionary) -> Variant:
	return null

func unload() -> void:
	pass
