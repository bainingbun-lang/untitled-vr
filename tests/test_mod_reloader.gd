extends SceneTree

const FIXTURES := "res://tests/fixtures/mods_reload"
const USER_ROOT := "user://mods_reload_test"
const BASE_ID := "reload.base"
const DEP_ID := "reload.dep"

const LoaderScript = preload("res://core/mod_loader.gd")
const BusScript = preload("res://core/event_bus.gd")
const ReloaderScript = preload("res://core/mod_reloader.gd")

var _assertions := 0
var _failures: Array = []
var _generated: Array = []

func _init() -> void:
	_case_missing()
	_case_version_change()
	_case_broken_json()
	_case_bad_script()
	_case_dependents()
	_cleanup()
	if _failures.is_empty():
		print("PASS test_mod_reloader.gd (%d assertions)" % _assertions)
		quit(0)
	else:
		print("FAIL test_mod_reloader.gd (%d assertions, %d failures)" % [
			_assertions, _failures.size()
		])
		for item in _failures:
			print("  " + str(item))
		quit(1)

func _case_missing() -> int:
	var before := _failures.size()
	var setup := _setup("missing", FIXTURES.path_join("base_v1.gd"), false)
	var reloader = ReloaderScript.new()
	var result := reloader.reload(
		setup["registry"], setup["loader"], "reload.nope", setup["base_dir"]
	)
	_check(not bool(result.get("ok", true)), "mod inexistente debe devolver ok=false")
	_check(
		str(result.get("error", "")).contains("no esta cargado"),
		"el error debe indicar que el modulo no esta cargado"
	)
	_check(setup["registry"].is_loaded(BASE_ID), "un mod inexistente no debe alterar el registro")
	return _failures.size() - before

func _case_version_change() -> int:
	var before := _failures.size()
	var setup := _setup("version", FIXTURES.path_join("base_v1.gd"), false)
	var registry = setup["registry"]
	var entry := str(setup["entry_base"])
	_write(entry, _read(FIXTURES.path_join("base_v2.gd")))
	_write(
		str(setup["base_dir"]).path_join("mod.json"),
		_manifest_json(BASE_ID, "2.0.0", entry)
	)
	var reloader = ReloaderScript.new()
	var result := reloader.reload(registry, setup["loader"], BASE_ID, setup["base_dir"])
	_check(
		bool(result.get("ok", false)),
		"la recarga por cambio de version debe tener exito: %s" % str(result.get("error", ""))
	)
	var payload := {}
	setup["bus"].emit("reload.ping", payload)
	_check(
		str(payload.get("base_version", "")) == "2.0.0",
		"la instancia recargada debe responder con la version nueva: %s" % str(payload)
	)
	var record: Dictionary = registry._loaded.get(BASE_ID, {})
	var manifest: Dictionary = record.get("manifest", {})
	_check(
		str(manifest.get("version", "")) == "2.0.0",
		"el manifiesto del registro debe reflejar la version nueva"
	)
	var ids: Array = registry.loaded_ids()
	_check(ids.size() == 1 and ids[0] == BASE_ID, "el orden de carga debe conservarse")
	return _failures.size() - before

func _case_broken_json() -> int:
	var before := _failures.size()
	var setup := _setup("broken", FIXTURES.path_join("base_v1.gd"), false)
	var registry = setup["registry"]
	_write(
		str(setup["base_dir"]).path_join("mod.json"),
		"{\"schema_version\": 1, \"id\": \"reload.base\", "
	)
	var reloader = ReloaderScript.new()
	var result := reloader.reload(registry, setup["loader"], BASE_ID, setup["base_dir"])
	_check(not bool(result.get("ok", true)), "un JSON roto debe devolver ok=false")
	_check(
		str(result.get("error", "")).contains("JSON invalido"),
		"el error debe indicar JSON invalido"
	)
	_check(registry.is_loaded(BASE_ID), "rollback: el modulo anterior debe seguir cargado")
	var payload := {}
	setup["bus"].emit("reload.ping", payload)
	_check(
		str(payload.get("base_version", "")) == "1.0.0",
		"rollback: la instancia anterior debe seguir operativa: %s" % str(payload)
	)
	return _failures.size() - before

func _case_bad_script() -> int:
	var before := _failures.size()
	var setup := _setup("badscript", FIXTURES.path_join("base_v1.gd"), false)
	var registry = setup["registry"]
	var entry := str(setup["entry_base"])
	_write(entry, _read(FIXTURES.path_join("no_init.gd")))
	_write(
		str(setup["base_dir"]).path_join("mod.json"),
		_manifest_json(BASE_ID, "3.0.0", entry)
	)
	var reloader = ReloaderScript.new()
	var result := reloader.reload(registry, setup["loader"], BASE_ID, setup["base_dir"])
	_check(not bool(result.get("ok", true)), "un script sin _mod_init debe devolver ok=false")
	_check(
		str(result.get("error", "")).contains("_mod_init"),
		"el error debe indicar que falta _mod_init"
	)
	_check(registry.is_loaded(BASE_ID), "rollback: el modulo anterior debe seguir cargado")
	var payload := {}
	setup["bus"].emit("reload.ping", payload)
	_check(
		str(payload.get("base_version", "")) == "1.0.0",
		"rollback: la instancia anterior debe seguir operativa: %s" % str(payload)
	)
	return _failures.size() - before

func _case_dependents() -> int:
	var before := _failures.size()
	var setup := _setup("deps", FIXTURES.path_join("base_v1.gd"), true)
	var registry = setup["registry"]
	var entry := str(setup["entry_base"])
	_write(entry, _read(FIXTURES.path_join("base_v2.gd")))
	_write(
		str(setup["base_dir"]).path_join("mod.json"),
		_manifest_json(BASE_ID, "2.0.0", entry)
	)
	var reloader = ReloaderScript.new()
	var result := reloader.reload(registry, setup["loader"], BASE_ID, setup["base_dir"])
	_check(
		bool(result.get("ok", false)),
		"la recarga con dependientes debe tener exito: %s" % str(result.get("error", ""))
	)
	_check(registry.is_loaded(BASE_ID), "el modulo recargado debe estar cargado")
	_check(registry.is_loaded(DEP_ID), "el modulo dependiente debe seguir cargado")
	var ids: Array = registry.loaded_ids()
	_check(
		ids.size() == 2 and ids[0] == BASE_ID and ids[1] == DEP_ID,
		"el orden de dependencias debe conservarse: %s" % str(ids)
	)
	var payload := {}
	setup["bus"].emit("reload.ping", payload)
	_check(
		str(payload.get("base_version", "")) == "2.0.0",
		"el modulo recargado debe responder con la version nueva: %s" % str(payload)
	)
	_check(
		str(payload.get("dep_marker", "")) == "dep-ok",
		"el dependiente debe seguir operativo: %s" % str(payload)
	)
	return _failures.size() - before

func _setup(case_name: String, base_source: String, with_dep: bool) -> Dictionary:
	_ensure_dirs(case_name)
	var case_root := USER_ROOT.path_join(case_name)
	var base_dir := case_root.path_join(BASE_ID)
	var dep_dir := case_root.path_join(DEP_ID)
	var entry_base := FIXTURES.path_join("gen_%s_base.gd" % case_name)
	var entry_dep := FIXTURES.path_join("gen_%s_dep.gd" % case_name)
	_generated.append(entry_base)
	_write(entry_base, _read(base_source))
	_write(
		base_dir.path_join("mod.json"),
		_manifest_json(BASE_ID, "1.0.0", entry_base)
	)
	if with_dep:
		_generated.append(entry_dep)
		_write(entry_dep, _read(FIXTURES.path_join("dep.gd")))
		_write(
			dep_dir.path_join("mod.json"),
			_manifest_json(DEP_ID, "1.0.0", entry_dep, '{"reload.base": ">=1.0.0"}')
		)
	var bus = BusScript.new()
	var loader = LoaderScript.new(bus)
	var initial := loader.load_all(case_root)
	_check(
		bool(initial.get("ok", false)),
		"la carga inicial de %s debe tener exito: %s" % [
			case_name, str(initial.get("rejected", {}))
		]
	)
	return {
		"loader": loader,
		"registry": loader.get_registry(),
		"bus": bus,
		"base_dir": base_dir,
		"entry_base": entry_base,
	}

func _ensure_dirs(case_name: String) -> void:
	var root := DirAccess.open("user://")
	if root == null:
		_check(false, "no se pudo abrir user://")
		return
	if not root.dir_exists("mods_reload_test"):
		root.make_dir("mods_reload_test")
	var test_root := DirAccess.open(USER_ROOT)
	if not test_root.dir_exists(case_name):
		test_root.make_dir(case_name)
	var case_root := DirAccess.open(USER_ROOT.path_join(case_name))
	if not case_root.dir_exists(BASE_ID):
		case_root.make_dir(BASE_ID)
	if not case_root.dir_exists(DEP_ID):
		case_root.make_dir(DEP_ID)

func _manifest_json(
	id: String, version: String, entry: String, depends: String = ""
) -> String:
	var text := "{\n  \"schema_version\": 1,\n  \"id\": \"%s\",\n  \"version\": \"%s\",\n  \"engine\": \"4.7\",\n" % [
		id, version
	]
	if not depends.is_empty():
		text += "  \"depends\": %s,\n" % depends
	text += "  \"entry\": \"%s\"\n}\n" % entry
	return text

func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "no se pudo leer '%s'" % path)
		return ""
	var text := file.get_as_text()
	file.close()
	return text

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "no se pudo escribir '%s'" % path)
		return
	file.store_string(text)
	file.close()

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)

func _cleanup() -> void:
	for path in _generated:
		DirAccess.remove_absolute(str(path))
