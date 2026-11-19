extends SceneTree

const LoaderScript = preload("res://core/maps/map_loader.gd")
const RegistryScript = preload("res://core/maps/map_registry.gd")
const FIXTURES := "res://tests/fixtures/maps"

var _failures: Array = []
var _case := ""
var _checks := 0


func _init() -> void:
	_case = "carga desde fixtures"
	var loader = LoaderScript.new()
	var registry = RegistryScript.new()
	var report: Dictionary = loader.load_dir(FIXTURES, registry)

	_expect(report.has("registered"), "el reporte debe tener 'registered'")
	_expect(report.has("rejected"), "el reporte debe tener 'rejected'")
	_expect(report.get("registered") is Array, "'registered' debe ser Array")
	_expect(report.get("rejected") is Array, "'rejected' debe ser Array")

	_expect(report["registered"].size() == 2, "se esperaban 2 mapas registrados, se obtuvieron %d" % report["registered"].size())
	_expect(report["registered"].has("map_alpha"), "map_alpha debe registrarse")
	_expect(report["registered"].has("map_beta"), "map_beta debe registrarse aunque haya fallos previos")
	_expect(not registry.get_map("map_alpha").is_empty(), "get_map debe devolver map_alpha")
	_expect(not registry.get_map("map_beta").is_empty(), "get_map debe devolver map_beta")

	_case = "adaptacion de spawn_points"
	var alpha: Dictionary = registry.get_map("map_alpha")
	var alpha_points: Array = alpha.get("spawn_points", [])
	_expect(alpha_points.size() == 2, "map_alpha debe tener 2 spawn points, tiene %d" % alpha_points.size())
	if alpha_points.size() >= 2:
		_expect(alpha_points[0] == Vector3(0, 0, 0), "primer spawn point de alpha debe ser Vector3(0,0,0), es %s" % str(alpha_points[0]))
		_expect(alpha_points[1] == Vector3(4, 0, 4), "segundo spawn point de alpha debe ser Vector3(4,0,4), es %s" % str(alpha_points[1]))
	var beta: Dictionary = registry.get_map("map_beta")
	var beta_points: Array = beta.get("spawn_points", [])
	_expect(beta_points.size() == 1, "map_beta debe tener 1 spawn point, tiene %d" % beta_points.size())
	if beta_points.size() >= 1:
		_expect(beta_points[0] == Vector3(1, 2, 3), "spawn point en objeto debe adaptarse a Vector3(1,2,3), es %s" % str(beta_points[0]))

	_case = "rechazos con motivo"
	_expect(report["rejected"].size() == 4, "se esperaban 4 rechazos, se obtuvieron %d" % report["rejected"].size())
	for file_name in ["a_broken.json", "c_invalid_nav.json", "d_duplicate.json", "e_invalid_no_license.json"]:
		var entry := _rejected_for(report, file_name)
		_expect(not entry.is_empty(), "%s debe figurar en rejected" % file_name)
		_expect(not str(entry.get("reason", "")).is_empty(), "%s debe incluir motivo" % file_name)
		_expect(not str(entry.get("motivo", "")).is_empty(), "%s debe incluir 'motivo'" % file_name)

	var duplicate := _rejected_for(report, "d_duplicate.json")
	_expect("duplicado" in str(duplicate.get("reason", "")).to_lower(), "el rechazo duplicado debe indicar duplicado")
	_expect(registry.get_map("map_no_nav").is_empty(), "el mapa sin navegacion no debe registrarse")
	_expect(registry.get_map("map_no_license").is_empty(), "el mapa sin licencia no debe registrarse")
	_expect(_rejected_for(report, "ignored.txt").is_empty(), "los archivos no-json deben ignorarse")

	_case = "segunda carga no duplica"
	var second: Dictionary = loader.load_dir(FIXTURES, registry)
	_expect(second["registered"].is_empty(), "la segunda carga no debe registrar ids duplicados")
	_expect(registry.get_map("map_alpha").get("id") == "map_alpha", "el mapa original debe permanecer tras la segunda carga")

	_case = "directorio inexistente"
	var missing: Dictionary = loader.load_dir("res://tests/fixtures/maps/no_existe", RegistryScript.new())
	_expect(missing["registered"].is_empty(), "un directorio inexistente no debe registrar mapas")
	_expect(missing["rejected"].size() >= 1, "un directorio inexistente debe reportar rechazo")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _rejected_for(report: Dictionary, file_name: String) -> Dictionary:
	for entry in report["rejected"]:
		if entry.get("file") == file_name:
			return entry
	return {}
