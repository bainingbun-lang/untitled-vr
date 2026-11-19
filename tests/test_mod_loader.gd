extends SceneTree

const ModLoaderScript = preload("res://core/mod_loader.gd")
const EventBusScript = preload("res://core/event_bus.gd")

const ROOT := "res://tests/fixtures/mods_boot"

var _failures: Array = []
var _case := ""


func _init() -> void:
	_case = "discover con json roto"
	_test_discover()

	_case = "validate con ModManifest"
	_test_validate()

	_case = "carga combinada con dependencias y rechazos"
	_test_load_all()

	_case = "directorio vacio"
	_test_empty()

	_case = "directorio inexistente"
	_test_missing_dir()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _ids_of(candidates: Array) -> Array:
	var ids: Array = []
	for candidate in candidates:
		ids.append(candidate["manifest"]["id"])
	ids.sort()
	return ids


func _test_discover() -> void:
	var loader := ModLoaderScript.new()
	var result: Dictionary = loader.discover(ROOT)
	_expect(not result["ok"], "discover debe reportar el json roto")
	_expect(
		result["rejected"].has("broken_json"),
		"broken_json debe figurar en rejected: %s" % str(result["rejected"])
	)
	_expect(
		str(result["rejected"].get("broken_json", "")).contains("JSON"),
		"el motivo del json roto debe mencionar JSON"
	)
	_expect(
		_ids_of(result["candidates"])
		== ["boot.base", "boot.dep", "boot.missing", "cyc.a", "cyc.b"],
		"candidatos incorrectos: %s" % str(_ids_of(result["candidates"]))
	)


func _test_validate() -> void:
	var loader := ModLoaderScript.new()
	var good: Dictionary = loader.validate({
		"schema_version": 1,
		"id": "val.mod",
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect(good["ok"], "el manifiesto minimo debe ser valido: %s" % str(good["errors"]))
	_expect(good["manifest"]["priority"] == 100, "priority por defecto debe ser 100")

	var bad: Dictionary = loader.validate({
		"schema_version": 1,
		"id": "VAL",
		"version": "1.0",
		"engine": "4.7",
	})
	_expect(not bad["ok"], "el manifiesto con id y version invalidos debe fallar")


func _test_load_all() -> void:
	var bus := EventBusScript.new()
	var initialized: Array = []
	bus.subscribe("modboot.loaded", func(payload): initialized.append(payload["id"]), "test")

	var loader := ModLoaderScript.new(bus)
	var report: Dictionary = loader.load_all(ROOT)

	_expect(
		report.has("loaded") and report.has("rejected") and report.has("order"),
		"el reporte debe contener loaded, rejected y order: %s" % str(report.keys())
	)
	_expect(
		report["loaded"] == ["boot.base", "boot.dep"],
		"loaded incorrecto: %s" % str(report["loaded"])
	)
	_expect(
		report["order"] == ["boot.base", "boot.dep"],
		"order debe colocar la dependencia antes: %s" % str(report["order"])
	)
	_expect(
		initialized == ["boot.base", "boot.dep"],
		"_mod_init debe ejecutarse en orden de dependencias: %s" % str(initialized)
	)

	var rejected: Dictionary = report["rejected"]
	_expect(rejected.has("broken_json"), "el json roto debe estar rechazado")
	_expect(
		str(rejected.get("broken_json", "")).contains("JSON"),
		"el motivo del json roto debe mencionar JSON"
	)
	_expect(rejected.has("boot.missing"), "la dependencia ausente debe estar rechazada")
	_expect(
		str(rejected.get("boot.missing", "")).contains("no está instalado"),
		"el motivo de la dependencia ausente debe ser explicito: %s"
		% str(rejected.get("boot.missing", ""))
	)
	_expect(
		rejected.has("cyc.a") and rejected.has("cyc.b"),
		"ambos modulos del ciclo deben estar rechazados: %s" % str(rejected)
	)
	_expect(
		str(rejected.get("cyc.a", "")).contains("circular"),
		"el motivo del ciclo debe mencionar circular"
	)
	_expect(
		str(rejected.get("cyc.b", "")).contains("circular"),
		"el motivo del ciclo debe mencionar circular"
	)
	_expect(
		loader.is_loaded("boot.base") and loader.is_loaded("boot.dep"),
		"los mods validos deben quedar cargados pese a los rechazos"
	)
	_expect(not loader.is_loaded("boot.missing"), "el mod con dependencia ausente no debe cargar")


func _test_empty() -> void:
	var loader := ModLoaderScript.new()
	var target := ROOT.path_join("empty")
	var discovered: Dictionary = loader.discover(target)
	_expect(discovered["ok"], "un directorio vacio debe descubrirse sin errores")
	_expect(discovered["candidates"].is_empty(), "no debe haber candidatos")
	_expect(discovered["rejected"].is_empty(), "no debe haber rechazos")

	var report: Dictionary = loader.load_all(target)
	_expect(report["loaded"].is_empty(), "loaded debe estar vacio")
	_expect(report["rejected"].is_empty(), "rejected debe estar vacio")
	_expect(report["order"].is_empty(), "order debe estar vacio")


func _test_missing_dir() -> void:
	var loader := ModLoaderScript.new()
	var target := ROOT.path_join("no_existe")
	var discovered: Dictionary = loader.discover(target)
	_expect(not discovered["ok"], "un directorio inexistente debe fallar")
	_expect(discovered["candidates"].is_empty(), "no debe haber candidatos")

	var report: Dictionary = loader.load_all(target)
	_expect(report["loaded"].is_empty(), "loaded debe estar vacio")
	_expect(not report["rejected"].is_empty(), "debe explicar por que no se pudo abrir")
	_expect(report["order"].is_empty(), "order debe estar vacio")
