extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")

const ROOT := "user://test_mods"

const MODULE_SCRIPT := """extends RefCounted

var _api


func _mod_init(api):
	_api = api
	api.emit("mod.ready", {"id": api.module_id})
	api.subscribe("mod.ping", _on_ping)


func _on_ping(_payload):
	_api.emit("mod.pong", {"id": _api.module_id})


func _mod_shutdown():
	_api.emit("mod.shutdown", {"id": _api.module_id})
"""

const EMPTY_SCRIPT := """extends RefCounted


var sin_init := true
"""

var _failures: Array = []
var _case := ""


func _init() -> void:
	_remove_dir(ROOT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

	_case = "scan valido con json invalido"
	_test_scan()

	_case = "load_all ejecuta _mod_init"
	_test_load_entry()

	_case = "suscripcion via api"
	_test_subscription()

	_case = "dependencia inexistente"
	_test_missing_dependency()

	_case = "conflicto de reemplazo"
	_test_conflict()

	_case = "entry invalida y dependientes omitidos"
	_test_bad_entry()

	_case = "unload libera suscripciones"
	_test_unload()

	_case = "unload bloqueado por dependiente"
	_test_unload_with_dependent()

	_case = "load_all idempotente"
	_test_idempotent()

	_remove_dir(ROOT)

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _manifest(module_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"id": module_id,
		"version": "1.0.0",
		"engine": "4.7",
	}


func _write(path: String, content: String) -> void:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "no se pudo escribir '%s'" % path)
		return
	file.store_string(content)
	file.close()


func _make_entry(name: String, content: String = MODULE_SCRIPT) -> String:
	var dir := ROOT.path_join("mods").path_join(name)
	var entry := dir.path_join("entry.gd")
	_write(entry, content)
	return entry


func _candidate(manifest: Dictionary, dir: String = "") -> Dictionary:
	return {"manifest": manifest, "dir": dir}


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_scan() -> void:
	var scan_root := ROOT.path_join("scan")
	_write(scan_root.path_join("aa/mod.json"), JSON.stringify(_manifest("aa.uno")))
	_write(scan_root.path_join("bb/mod.json"), JSON.stringify(_manifest("bb.dos")))
	_write(scan_root.path_join("cc/mod.json"), "{ esto no es json ")

	var registry = ModRegistryScript.new(EventBusScript.new())
	var result: Dictionary = registry.scan(scan_root)

	_expect(not result["ok"], "scan debe reportar ok=false por el json invalido")
	_expect(result["errors"].size() == 1, "se esperaba 1 error, se obtuvieron %d" % result["errors"].size())
	_expect(
		result["candidates"].size() == 2,
		"se esperaban 2 candidatos, se obtuvieron %d" % result["candidates"].size()
	)
	var ids: Array = []
	for candidate in result["candidates"]:
		ids.append(candidate["manifest"]["id"])
	ids.sort()
	_expect(ids == ["aa.uno", "bb.dos"], "ids escaneados incorrectos: %s" % str(ids))


func _test_load_entry() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var ready := [0]
	bus.subscribe("mod.ready", func(_p): ready[0] += 1, "test")

	var entry := _make_entry("t2")
	var manifest := _manifest("t2.mod")
	manifest["entry"] = entry

	var result: Dictionary = registry.load_all([_candidate(manifest, entry.get_base_dir())])
	_expect(result["ok"], "load_all debe ser ok: %s" % str(result["failed"]))
	_expect(result["loaded"] == ["t2.mod"], "loaded incorrecto: %s" % str(result["loaded"]))
	_expect(registry.is_loaded("t2.mod"), "is_loaded debe ser true")
	_expect(registry.loaded_ids() == ["t2.mod"], "loaded_ids incorrecto")
	_expect(registry.get_instance("t2.mod") != null, "la instancia debe existir")
	_expect(ready[0] == 1, "_mod_init debe ejecutarse una vez, se ejecuto %d" % ready[0])


func _test_subscription() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var pong := [0]
	bus.subscribe("mod.pong", func(_p): pong[0] += 1, "test")

	var entry := _make_entry("t3")
	var manifest := _manifest("t3.mod")
	manifest["entry"] = entry
	registry.load_all([_candidate(manifest, entry.get_base_dir())])

	var emitted: Dictionary = bus.emit("mod.ping")
	_expect(emitted["ok"], "emit debe ser ok")
	_expect(pong[0] == 1, "el handler del modulo debe invocarse, se invocaron %d" % pong[0])


func _test_missing_dependency() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)

	var good_entry := _make_entry("t4_good")
	var good := _manifest("t4.good")
	good["entry"] = good_entry

	var missing := _manifest("t4.dep")
	missing["depends"] = {"x.y": "*"}

	var result: Dictionary = registry.load_all([
		_candidate(good, good_entry.get_base_dir()),
		_candidate(missing, ROOT.path_join("mods/t4_dep")),
	])

	_expect(registry.is_loaded("t4.good"), "el modulo sin problemas debe cargar")
	_expect(not registry.is_loaded("t4.dep"), "el modulo con dependencia ausente no debe cargar")
	_expect(result["failed"].has("t4.dep"), "t4.dep debe figurar en failed")
	_expect(not result["errors"].is_empty(), "debe haber errores de resolucion")


func _test_conflict() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)

	var one := _manifest("t5.uno")
	one["replaces"] = ["sistema"]
	var two := _manifest("t5.dos")
	two["replaces"] = ["sistema"]

	var result: Dictionary = registry.load_all([
		_candidate(one, ROOT.path_join("mods/t5_uno")),
		_candidate(two, ROOT.path_join("mods/t5_dos")),
	])

	_expect(registry.loaded_ids().is_empty(), "ningun modulo en conflicto debe cargar")
	_expect(not registry.is_loaded("t5.uno"), "t5.uno no debe cargar")
	_expect(not registry.is_loaded("t5.dos"), "t5.dos no debe cargar")
	_expect(not result["errors"].is_empty(), "debe haber un error de conflicto")
	_expect(result["failed"].has("t5.uno"), "t5.uno debe figurar en failed")
	_expect(result["failed"].has("t5.dos"), "t5.dos debe figurar en failed")


func _test_bad_entry() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)

	var bad := _manifest("t6.bad")
	bad["entry"] = ROOT.path_join("mods/t6_bad/no_existe.gd")

	var no_init_entry := _make_entry("t6_noinit", EMPTY_SCRIPT)
	var no_init := _manifest("t6.noinit")
	no_init["entry"] = no_init_entry

	var dependent := _manifest("t6.dep")
	dependent["depends"] = {"t6.bad": "*"}

	var good_entry := _make_entry("t6_good")
	var good := _manifest("t6.good")
	good["entry"] = good_entry

	var result: Dictionary = registry.load_all([
		_candidate(bad, ROOT.path_join("mods/t6_bad")),
		_candidate(no_init, no_init_entry.get_base_dir()),
		_candidate(dependent, ROOT.path_join("mods/t6_dep")),
		_candidate(good, good_entry.get_base_dir()),
	])

	_expect(result["failed"].has("t6.bad"), "la entry inexistente debe fallar")
	_expect(result["failed"].has("t6.noinit"), "la entry sin _mod_init debe fallar")
	_expect(not registry.is_loaded("t6.dep"), "el dependiente debe omitirse")
	_expect(registry.is_loaded("t6.good"), "el modulo sano debe cargar")


func _test_unload() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var pong := [0]
	var shutdown := [0]
	bus.subscribe("mod.pong", func(_p): pong[0] += 1, "test")
	bus.subscribe("mod.shutdown", func(_p): shutdown[0] += 1, "test")

	var entry := _make_entry("t7")
	var manifest := _manifest("t7.mod")
	manifest["entry"] = entry
	registry.load_all([_candidate(manifest, entry.get_base_dir())])

	bus.emit("mod.ping")
	_expect(pong[0] == 1, "antes de unload el handler debe invocarse, se invoco %d" % pong[0])

	var result: Dictionary = registry.unload("t7.mod")
	_expect(result["ok"], "unload debe ser ok: %s" % str(result["errors"]))
	_expect(shutdown[0] == 1, "_mod_shutdown debe ejecutarse una vez")
	_expect(not registry.is_loaded("t7.mod"), "is_loaded debe ser false tras unload")
	_expect(registry.loaded_ids().is_empty(), "loaded_ids debe quedar vacio")
	_expect(registry.get_instance("t7.mod") == null, "la instancia debe retirarse")

	bus.emit("mod.ping")
	_expect(pong[0] == 1, "tras unload el handler no debe invocarse, total %d" % pong[0])


func _test_unload_with_dependent() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)

	var base_entry := _make_entry("t8_base")
	var base := _manifest("t8.base")
	base["entry"] = base_entry

	var dep_entry := _make_entry("t8_dep")
	var dep := _manifest("t8.dep")
	dep["entry"] = dep_entry
	dep["depends"] = {"t8.base": "*"}

	registry.load_all([
		_candidate(base, base_entry.get_base_dir()),
		_candidate(dep, dep_entry.get_base_dir()),
	])
	_expect(registry.is_loaded("t8.base"), "la base debe cargar")
	_expect(registry.is_loaded("t8.dep"), "el dependiente debe cargar")

	var result: Dictionary = registry.unload("t8.base")
	_expect(not result["ok"], "unload debe fallar por el dependiente")
	_expect(not result["errors"].is_empty(), "debe reportar el motivo")
	_expect(registry.is_loaded("t8.base"), "la base debe seguir cargada")
	_expect(registry.is_loaded("t8.dep"), "el dependiente debe seguir cargado")


func _test_idempotent() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var ready := [0]
	bus.subscribe("mod.ready", func(_p): ready[0] += 1, "test")

	var entry := _make_entry("t9")
	var manifest := _manifest("t9.mod")
	manifest["entry"] = entry
	var candidates := [_candidate(manifest, entry.get_base_dir())]

	registry.load_all(candidates)
	var second: Dictionary = registry.load_all(candidates)

	_expect(ready[0] == 1, "_mod_init no debe ejecutarse dos veces, se ejecuto %d" % ready[0])
	_expect(registry.loaded_ids() == ["t9.mod"], "loaded_ids no debe duplicar: %s" % str(registry.loaded_ids()))
	_expect(second["loaded"].is_empty(), "la segunda carga no debe reportar modulos nuevos")
