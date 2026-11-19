extends SceneTree

const BootScript = preload("res://core/boot.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const MapRegistryScript = preload("res://core/maps/map_registry.gd")

const FIXTURES := "res://tests/fixtures/boot"
const CLEAN_MODS := FIXTURES + "/mods"
const CLEAN_MAPS := FIXTURES + "/maps"
const EMPTY_MODS := FIXTURES + "/empty_mods"
const EMPTY_MAPS := FIXTURES + "/empty_maps"
const BAD_MODS := "res://tests/fixtures/mods_boot"
const BAD_MAPS := "res://tests/fixtures/maps"
const MISSING := FIXTURES + "/no_existe"

var _failures: Array = []
var _case := ""
var _checks := 0


func _init() -> void:
	_case = "contrato y arranque limpio"
	_test_clean_boot()

	_case = "bus compartido y registros"
	_test_wiring()

	_case = "fallo en mods no bloquea mapas"
	_test_mods_failure_isolation()

	_case = "fallo en mapas no bloquea mods"
	_test_maps_failure_isolation()

	_case = "directorios inexistentes"
	_test_missing_dirs()

	_case = "rutas vacias"
	_test_empty_paths()

	_case = "directorios vacios"
	_test_empty_dirs()

	_case = "arranque repetido"
	_test_repeatability()

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


func _ids(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(str(value))
	result.sort()
	return result


func _test_clean_boot() -> void:
	var boot := BootScript.new()
	var report: Dictionary = boot.run(CLEAN_MODS, CLEAN_MAPS)
	_expect(report is Dictionary, "run debe devolver un Dictionary")
	_expect(
		report.has("mods") and report.has("maps") and report.has("ok"),
		"el reporte debe contener mods, maps y ok: %s" % str(report.keys())
	)
	_expect(report.get("mods") is Dictionary, "mods debe ser un Dictionary")
	_expect(report.get("maps") is Dictionary, "maps debe ser un Dictionary")
	_expect(bool(report["mods"].get("ok", false)), "el arranque limpio de mods debe ser ok")
	_expect(
		_ids(report["mods"].get("loaded", [])) == ["boot.clean"],
		"loaded incorrecto: %s" % str(report["mods"].get("loaded", []))
	)
	_expect(report["mods"].get("rejected", {}).is_empty(), "no debe haber mods rechazados")
	_expect(
		_ids(report["maps"].get("registered", [])) == ["boot.map"],
		"registered incorrecto: %s" % str(report["maps"].get("registered", []))
	)
	_expect(report["maps"].get("rejected", []).is_empty(), "no debe haber mapas rechazados")
	_expect(bool(report.get("ok", false)), "ok debe ser true cuando todo carga")


func _test_wiring() -> void:
	var boot := BootScript.new()
	boot.run(CLEAN_MODS, CLEAN_MAPS)
	_expect(boot.bus != null and boot.bus.get_script() == EventBusScript, "debe construir ModEventBus")
	_expect(
		boot.mod_registry != null and boot.mod_registry.get_script() == ModRegistryScript,
		"debe construir ModRegistry"
	)
	_expect(
		boot.map_registry != null and boot.map_registry.get_script() == MapRegistryScript,
		"debe construir MapRegistry"
	)
	_expect(boot.mod_registry.is_loaded("boot.clean"), "el mod debe quedar en el registro de mods")
	_expect(
		not boot.map_registry.get_map("boot.map").is_empty(),
		"el mapa debe quedar en el registro de mapas"
	)
	var instance = boot.mod_registry.get_instance("boot.clean")
	_expect(instance != null, "debe existir la instancia del modulo de entrada")
	_expect(boot.bus.has_subscribers("boot.probe"), "el mod debe usar el bus construido por Boot")
	if instance != null:
		boot.bus.emit("boot.probe", {"value": 7})
		_expect(instance.seen == [7], "el handler del mod debe recibir el evento del bus: %s" % str(instance.seen))


func _test_mods_failure_isolation() -> void:
	var boot := BootScript.new()
	var report: Dictionary = boot.run(BAD_MODS, CLEAN_MAPS)
	_expect(not bool(report["mods"].get("ok", true)), "los mods con fallos deben reportar ok=false")
	_expect(report["mods"].get("rejected", {}).has("broken_json"), "debe registrarse el JSON roto")
	_expect(_ids(report["mods"].get("loaded", [])).has("boot.base"), "los mods validos deben cargar")
	_expect(
		_ids(report["maps"].get("registered", [])) == ["boot.map"],
		"los mapas deben cargar aunque fallen los mods: %s" % str(report["maps"].get("registered", []))
	)
	_expect(report["maps"].get("rejected", []).is_empty(), "los mapas limpios no deben rechazarse")
	_expect(not bool(report.get("ok", true)), "ok debe ser false si falla una de las dos fases")


func _test_maps_failure_isolation() -> void:
	var report: Dictionary = BootScript.new().run(CLEAN_MODS, BAD_MAPS)
	_expect(bool(report["mods"].get("ok", false)), "los mods limpios deben cargar pese a los mapas")
	_expect(
		_ids(report["mods"].get("loaded", [])) == ["boot.clean"],
		"loaded de mods incorrecto: %s" % str(report["mods"].get("loaded", []))
	)
	_expect(report["maps"].get("rejected", []).size() == 4, "los mapas con fallos deben reportar 4 rechazos")
	_expect(_ids(report["maps"].get("registered", [])).has("map_alpha"), "los mapas validos deben registrar")
	_expect(not bool(report.get("ok", true)), "ok debe ser false si falla una de las dos fases")


func _test_missing_dirs() -> void:
	var report: Dictionary = BootScript.new().run(MISSING + "_mods", MISSING + "_maps")
	_expect(not bool(report["mods"].get("ok", true)), "un directorio de mods inexistente debe ser controlado")
	_expect(_ids(report["mods"].get("loaded", [])).is_empty(), "no deben cargarse mods")
	_expect(not report["mods"].get("rejected", {}).is_empty(), "debe explicar el fallo de mods")
	_expect(_ids(report["maps"].get("registered", [])).is_empty(), "no deben registrarse mapas")
	_expect(report["maps"].get("rejected", []).size() >= 1, "debe explicar el fallo de mapas")
	_expect(not bool(report.get("ok", true)), "ok debe ser false con rutas inexistentes")


func _test_empty_paths() -> void:
	var report: Dictionary = BootScript.new().run("", "")
	_expect(not bool(report["mods"].get("ok", true)), "una ruta de mods vacia debe ser controlada")
	_expect(_ids(report["mods"].get("loaded", [])).is_empty(), "no deben cargarse mods")
	_expect(_ids(report["maps"].get("registered", [])).is_empty(), "no deben registrarse mapas")
	_expect(report["maps"].get("rejected", []).size() >= 1, "debe explicar la ruta de mapas vacia")
	_expect(not bool(report.get("ok", true)), "ok debe ser false con rutas vacias")


func _test_empty_dirs() -> void:
	var report: Dictionary = BootScript.new().run(EMPTY_MODS, EMPTY_MAPS)
	_expect(bool(report["mods"].get("ok", false)), "un directorio de mods vacio no es un error")
	_expect(_ids(report["mods"].get("loaded", [])).is_empty(), "no deben cargarse mods")
	_expect(_ids(report["maps"].get("registered", [])).is_empty(), "no deben registrarse mapas")
	_expect(report["maps"].get("rejected", []).is_empty(), "no deben rechazarse mapas")
	_expect(bool(report.get("ok", false)), "ok debe ser true si no hay nada que cargar ni fallos")


func _test_repeatability() -> void:
	var boot := BootScript.new()
	var first: Dictionary = boot.run(CLEAN_MODS, CLEAN_MAPS)
	var second: Dictionary = boot.run(CLEAN_MODS, CLEAN_MAPS)
	_expect(
		_ids(first["mods"].get("loaded", [])) == _ids(second["mods"].get("loaded", [])),
		"un segundo run debe reconstruir el estado de mods"
	)
	_expect(
		_ids(first["maps"].get("registered", [])) == _ids(second["maps"].get("registered", [])),
		"un segundo run debe reconstruir el estado de mapas"
	)
