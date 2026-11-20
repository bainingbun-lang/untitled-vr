extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")

const MOD_ID := "untitled.example-hello"
const BUILD_DIR := "res://build/mods/untitled.example-hello"
const BUILD_MODS := "res://build/mods"

var _failures: Array = []
var _skip_reason := ""


func _init() -> void:
	var build_status := _ensure_build()
	if build_status == "skip":
		print("SKIP: %s" % _skip_reason)
		quit(0)
		return
	if build_status != "ok":
		_fail(_skip_reason if _skip_reason != "" else "no se pudo construir el mod de ejemplo")
		_finish()
		return

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)

	# res:// apunta al proyecto raiz en ejecucion desde el editor, asi que
	# puede listar build/mods; se usa la ruta absoluta solo como respaldo.
	var scan_result: Dictionary = registry.scan(BUILD_MODS)
	if not scan_result.get("ok", false) and scan_result.get("candidates", []).is_empty():
		scan_result = registry.scan(ProjectSettings.globalize_path(BUILD_MODS))
	if not scan_result.get("ok", false):
		_fail("scan fallo: %s" % "; ".join(scan_result.get("errors", [])))
		_finish()
		return

	var candidates: Array = scan_result.get("candidates", [])
	if not _has_candidate(candidates, MOD_ID):
		_fail("scan no encontro el manifiesto de %s" % MOD_ID)
		_finish()
		return

	var load_result: Dictionary = registry.load_all(candidates)
	if not load_result.get("loaded", []).has(MOD_ID):
		_fail(
			"load_all no cargo %s: %s"
			% [MOD_ID, "; ".join(load_result.get("errors", []))]
		)
		_finish()
		return

	var payload: Dictionary = {"count": 0}
	bus.emit("game.started", payload)
	if payload.get("greeted_by", "") != MOD_ID:
		_fail("el handler del PCK no escribio greeted_by")
	if int(payload.get("count", 0)) != 1:
		_fail("el handler del PCK no incremento count (count=%s)" % str(payload.get("count")))

	var unload_result: Dictionary = registry.unload(MOD_ID)
	if not unload_result.get("ok", false):
		_fail("unload fallo: %s" % "; ".join(unload_result.get("errors", [])))

	var payload_after: Dictionary = {"count": 0}
	bus.emit("game.started", payload_after)
	if payload_after.has("greeted_by"):
		_fail("tras unload el handler sigue activo (greeted_by presente)")
	if int(payload_after.get("count", 0)) != 0:
		_fail("tras unload count cambio (count=%s)" % str(payload_after.get("count")))

	_finish()


func _ensure_build() -> String:
	var base := ProjectSettings.globalize_path(BUILD_DIR)
	var pck := base.path_join("example_hello.pck")
	var manifest_dst := base.path_join("mod.json")
	if FileAccess.file_exists(pck) and FileAccess.file_exists(manifest_dst):
		return "ok"

	var src_script := ProjectSettings.globalize_path("res://mods/example.hello/example_hello/main.gd")
	var src_manifest := ProjectSettings.globalize_path("res://mods/example.hello/mod.json")
	if not FileAccess.file_exists(src_script) or not FileAccess.file_exists(src_manifest):
		_skip_reason = "fuentes del mod de ejemplo no disponibles para generar PCK con PCKPacker"
		return "skip"

	var mk_err := DirAccess.make_dir_recursive_absolute(base)
	if mk_err != OK and not DirAccess.dir_exists_absolute(base):
		_skip_reason = "no se pudo crear directorio de build para PCK (%s)" % str(mk_err)
		return "skip"

	var packer := PCKPacker.new()
	var pck_err := packer.pck_start(pck)
	if pck_err != OK:
		_skip_reason = "PCKPacker no disponible o fallo al iniciar PCK (%s)" % str(pck_err)
		return "skip"
	packer.add_file("res://example_hello/main.gd", src_script)
	packer.flush()

	var manifest_text := FileAccess.get_file_as_string(src_manifest)
	var mf := FileAccess.open(manifest_dst, FileAccess.WRITE)
	if mf == null:
		_skip_reason = "no se pudo escribir manifiesto de build con PCKPacker"
		return "skip"
	mf.store_string(manifest_text)
	mf.close()

	if FileAccess.file_exists(pck) and FileAccess.file_exists(manifest_dst):
		return "ok"
	_skip_reason = "no se generaron artefactos del mod con PCKPacker"
	return "skip"


func _has_candidate(candidates: Array, module_id: String) -> bool:
	for candidate in candidates:
		if typeof(candidate) != TYPE_DICTIONARY:
			continue
		var manifest: Dictionary = candidate.get("manifest", {})
		if str(manifest.get("id", "")) == module_id:
			return true
	return false


func _fail(message: String) -> void:
	_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)
