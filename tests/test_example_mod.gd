extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")

const MOD_ID := "untitled.example-hello"
const BUILD_DIR := "res://build/mods/untitled.example-hello"
const BUILD_MODS := "res://build/mods"

var _failures: Array = []


func _init() -> void:
	if not _ensure_build():
		_fail("no se pudo construir el mod de ejemplo")
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


func _ensure_build() -> bool:
	var base := ProjectSettings.globalize_path(BUILD_DIR)
	var pck := base.path_join("example_hello.pck")
	var manifest := base.path_join("mod.json")
	if FileAccess.file_exists(pck) and FileAccess.file_exists(manifest):
		return true

	var script := ProjectSettings.globalize_path("res://tools/build_example_mod.sh")
	var code := OS.execute("bash", [script], [], true)
	return code == 0


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
