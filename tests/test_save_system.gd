extends SceneTree

const SaveScript = preload("res://core/game/save_system.gd")
const DbScript = preload("res://core/game/item_db.gd")
const InvScript = preload("res://core/game/inventory.gd")

const SAVE_ROOT := "user://test_saves"

var _failures: Array = []
var _checks := 0
var _case := ""


func _init() -> void:
	_cleanup()

	_case = "round-trip de inventario y estados de NPC"
	_test_round_trip()

	_case = "checksum, rotacion y recuperacion desde .bak"
	_test_recovery()

	_case = "ambos archivos corruptos"
	_test_total_corruption()

	_case = "migracion v1 -> v2"
	_test_migrations()

	_case = "ranuras, listado y borrado"
	_test_slots()

	_case = "escritura interrumpida simulada"
	_test_interrupted_write()

	_cleanup()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_round_trip() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	_expect_eq(system.root_dir, SAVE_ROOT, "raiz configurable")
	_expect(SaveScript.validate_slot("alpha"), "nombre de ranura valido")
	_expect(not SaveScript.validate_slot("mal/slot"), "nombre de ranura con separador rechazado")

	var db = DbScript.new()
	_expect(db.register(_item("potion", "Pocion", true, 5, 1.0)), "registrar pocion")
	_expect(db.register(_item("coin", "Moneda", true, 100, 0.0)), "registrar moneda")
	var inv = InvScript.new(db, 6, 10.5)
	inv.add("potion", 3)
	inv.add("coin", 250)
	var snapshot := inv.to_dict()
	var data := {
		"inventory": snapshot,
		"npcs": {
			"guardia": {"state": "alert", "needs": {"hunger": 0.25}},
			"mercader": {"state": "idle"},
		},
		"flags": {"chapter": 2},
	}

	var saved := system.save("alpha", data)
	_expect(bool(saved["ok"]), "guardado correcto: %s" % str(saved["errors"]))
	_expect(system.exists("alpha"), "exists tras guardar")
	_expect(FileAccess.file_exists(system.slot_path("alpha")), "archivo principal creado")
	_expect(not FileAccess.file_exists(system.backup_path("alpha")), "sin copia en el primer guardado")
	_expect(not FileAccess.file_exists(system.temp_path("alpha")), "sin temporal tras guardar")

	var info := system.info("alpha")
	_expect(bool(info["ok"]), "info del guardado")
	_expect_eq(int(info["version"]), 2, "version actual en la cabecera")
	_expect(int(info["timestamp"]) > 0, "timestamp en la cabecera")
	_expect(str(info["checksum"]).length() == 64, "checksum SHA-256 en la cabecera")
	_expect_eq(str(info["checksum"]), SaveScript.compute_checksum(data), "checksum canonical del contenido")
	var raw: Variant = _read_json(system.slot_path("alpha"))
	_expect(typeof(raw) == TYPE_DICTIONARY, "archivo guardado es JSON objeto")
	if typeof(raw) == TYPE_DICTIONARY:
		_expect((raw as Dictionary).has("version"), "cabecera contiene version")
		_expect((raw as Dictionary).has("timestamp"), "cabecera contiene timestamp")
		_expect((raw as Dictionary).has("checksum"), "cabecera contiene checksum")
		_expect((raw as Dictionary).has("data"), "cabecera contiene data")

	var loaded := system.load_slot("alpha")
	_expect(bool(loaded["ok"]), "carga correcta: %s" % str(loaded["errors"]))
	_expect_eq(str(loaded["source"]), "main", "cargado desde el archivo principal")
	_expect(not bool(loaded["recovered"]), "sin recuperacion en round-trip")
	_expect(not bool(loaded["migrated"]), "sin migracion en round-trip")
	_expect_eq(int(loaded["version"]), 2, "version cargada")
	_expect_eq(loaded["data"], data, "round-trip exacto de Dictionary anidado")
	_expect_eq((loaded["data"] as Dictionary)["inventory"], snapshot, "to_dict de Inventory conservado")
	_expect_eq(((loaded["data"] as Dictionary)["npcs"] as Dictionary)["guardia"], \
		(data["npcs"] as Dictionary)["guardia"], "estado de NPC conservado")
	_expect(_mentions(str(system.get_log()), "guardado alpha"), "operacion registrada en el log")


func _test_recovery() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	var one := {"step": 1, "npcs": {"guardia": {"state": "idle"}}}
	var two := {"step": 2, "npcs": {"guardia": {"state": "walk"}}}
	var three := {"step": 3, "npcs": {"guardia": {"state": "alert"}}}

	_expect(bool(system.save("alpha", one)["ok"]), "primer guardado de la serie")
	_expect(bool(system.save("alpha", two)["ok"]), "segundo guardado de la serie")
	_expect(FileAccess.file_exists(system.backup_path("alpha")), "segundo guardado crea .bak")
	_expect_eq(SaveScript.normalize(_read_json(system.backup_path("alpha")))["data"], one, "primera rotacion: .bak guarda la version anterior")
	_expect(bool(system.save("alpha", three)["ok"]), "tercer guardado de la serie")
	_expect_eq(SaveScript.normalize(_read_json(system.backup_path("alpha")))["data"], two, "segunda rotacion: .bak se actualiza")

	var tampered := {
		"version": 2,
		"timestamp": 123,
		"checksum": "0000000000000000000000000000000000000000000000000000000000000000",
		"data": {"step": 99},
	}
	_write_raw(system.slot_path("alpha"), JSON.stringify(tampered))
	var recovered := system.load_slot("alpha")
	_expect(bool(recovered["ok"]), "carga recupera datos del .bak: %s" % str(recovered["errors"]))
	_expect(bool(recovered["recovered"]), "se marca la recuperacion")
	_expect_eq(str(recovered["source"]), "backup", "origen de la recuperacion")
	_expect_eq(recovered["data"], two, "datos recuperados del .bak")
	_expect(_mentions(str(recovered["main_errors"]), "checksum"), "checksum principal invalido detectado")
	_expect(bool(recovered["repaired"]), "archivo principal reparado automaticamente")
	_expect_eq(SaveScript.normalize(_read_json(system.slot_path("alpha")))["data"], two, "principal reparado con datos recuperados")
	_expect(FileAccess.file_exists(system.backup_path("alpha")), "la copia se conserva tras la reparacion")

	var after_repair := system.load_slot("alpha")
	_expect(bool(after_repair["ok"]), "carga tras reparacion")
	_expect_eq(str(after_repair["source"]), "main", "tras reparar se carga desde principal")
	_expect(not bool(after_repair["recovered"]), "ya no hay recuperacion tras reparar")

	_write_raw(system.slot_path("alpha"), '{"version": 2, "data":')
	var truncated := system.load_slot("alpha")
	_expect(bool(truncated["ok"]), "JSON truncado se recupera desde .bak")
	_expect(bool(truncated["recovered"]), "JSON truncado marca recuperacion")
	_expect_eq(truncated["data"], two, "JSON truncado recupera la copia valida")


func _test_total_corruption() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	_expect(bool(system.save("broken", {"a": 1})["ok"]), "guardado base para corromper")
	_expect(bool(system.save("broken", {"a": 2})["ok"]), "guardado base con .bak")
	var garbage := "contenido no parseable"
	_write_raw(system.slot_path("broken"), garbage)
	_write_raw(system.backup_path("broken"), garbage)
	var loaded := system.load_slot("broken")
	_expect(not bool(loaded["ok"]), "fallo controlado cuando ambos estan corruptos")
	_expect_eq(loaded["data"], {}, "sin datos ante corrupcion total")
	_expect((loaded["errors"] as Array).size() >= 2, "se informan ambos fallos")
	_expect(_mentions(str(loaded["errors"]), "principal"), "error menciona el archivo principal")
	_expect(_mentions(str(loaded["errors"]), "seguridad"), "error menciona la copia de seguridad")
	_expect(_read(system.slot_path("broken")) == garbage, "carga fallida no sobrescribe el archivo corrupto")
	_expect(system.list().has("broken"), "la ranura corrupta sigue listada")
	var info := system.info("broken")
	_expect(not bool(info["ok"]), "info tambien detecta la corrupcion")
	_expect((info["errors"] as Array).size() > 0, "info devuelve errores controlados")


func _test_migrations() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	var registered := system.register_migration(1, Callable(self, "_v1_to_v2"))
	_expect(bool(registered["ok"]), "registrar migracion v1 -> v2")
	_expect(system.has_migration(1), "migracion registrada consultable")
	_expect(not bool(system.register_migration(2, Callable(self, "_v1_to_v2"))["ok"]), \
		"no se puede migrar desde la version actual")
	_expect(not bool(system.register_migration(1, Callable())["ok"]), "Callable invalido rechazado")

	var old := {"old_score": 7, "inventory": {"version": 1}}
	var saved := system.save("legacy", old, 1)
	_expect(bool(saved["ok"]), "guardado en formato v1")
	_expect_eq(int(saved["version"]), 1, "version grabada v1")
	_expect_eq(int(system.info("legacy")["version"]), 1, "info lee cabecera v1")

	var loaded := system.load_slot("legacy")
	_expect(bool(loaded["ok"]), "carga con migracion: %s" % str(loaded["errors"]))
	_expect(bool(loaded["migrated"]), "se marca la migracion aplicada")
	_expect_eq(loaded["applied_migrations"], [1], "se aplica el gancho de la v1")
	_expect_eq(int(loaded["original_version"]), 1, "version original conservada en el resultado")
	_expect_eq(int(loaded["version"]), 2, "version migrada a la actual")
	_expect_eq(int(loaded["data"]["score"]), 7, "migracion transforma los datos")
	_expect(not (loaded["data"] as Dictionary).has("old_score"), "campo antiguo eliminado")
	_expect((loaded["data"] as Dictionary).has("flags"), "migracion agrega campos nuevos")
	_expect(bool(loaded["repaired"]), "resultado migrado se persiste")
	_expect_eq(int(system.info("legacy")["version"]), 2, "cabecera actualizada tras migrar")
	var second := system.load_slot("legacy")
	_expect(bool(second["ok"]), "segunda carga tras migracion")
	_expect(not bool(second["migrated"]), "migracion no se repite")
	_expect_eq(second["data"], loaded["data"], "datos estables tras migracion")

	system.register_migration(1, Callable(self, "_bad_hook"))
	_expect(bool(system.save("bad_migration", old, 1)["ok"]), "guardado v1 con gancho invalido")
	var bad := system.load_slot("bad_migration")
	_expect(not bool(bad["ok"]), "migracion invalida produce error controlado")
	_expect(_mentions(str(bad["errors"]), "valor invalido"), "error de migracion explicito")
	_expect_eq(int(system.info("bad_migration")["version"]), 1, "migracion fallida no sobrescribe el guardado")

	var fresh = SaveScript.new(SAVE_ROOT)
	_expect(bool(fresh.save("no_hook", old, 1)["ok"]), "guardado v1 sin ganchos")
	var no_hook := fresh.load_slot("no_hook")
	_expect(not bool(no_hook["ok"]), "sin gancho de migracion hay error controlado")
	_expect(_mentions(str(no_hook["errors"]), "sin gancho"), "error indica el gancho ausente")
	system.clear_migrations()
	_expect(not system.has_migration(1), "clear_migrations elimina los ganchos")


func _test_slots() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	_expect(bool(system.save("slot_a", {"id": "a"})["ok"]), "guardar ranura a")
	_expect(bool(system.save("slot_b", {"id": "b"})["ok"]), "guardar ranura b")
	_expect(bool(system.save("slot_c", {"id": "c"})["ok"]), "guardar ranura c")
	var expected := ["alpha", "bad_migration", "broken", "legacy", "no_hook", "slot_a", "slot_b", "slot_c"]
	_expect_array(system.list(), expected, "listado ordenado de ranuras")
	_expect(system.exists("slot_a"), "exists de ranura existente")
	_expect(not system.exists("missing"), "exists de ranura ausente")
	var refused := system.delete("slot_a", false)
	_expect(not bool(refused["ok"]), "borrado sin confirmacion rechazado")
	_expect(_mentions(str(refused["errors"]), "confirm"), "borrado exige confirm=true")
	_expect(system.exists("slot_a"), "borrado sin confirmacion no elimina la ranura")
	var accepted := system.delete("slot_a", true)
	_expect(bool(accepted["ok"]), "borrado con confirmacion")
	_expect(not system.exists("slot_a"), "ranura borrada")
	_expect(not system.list().has("slot_a"), "listado tras borrado")
	_expect(not bool(system.delete("slot_a", true)["ok"]), "borrar dos veces falla")
	_expect(not bool(system.save("mal/slot", {})["ok"]), "ranura invalida rechazada al guardar")
	_expect(not bool(system.load_slot("mal/slot")["ok"]), "ranura invalida rechazada al cargar")
	_expect_eq(system.list().size(), 7, "cantidad de ranuras tras borrado")
	var bad_system = SaveScript.new("res://saves")
	var bad_save := bad_system.save("x", {})
	_expect(not bool(bad_save["ok"]), "raiz res:// rechazada")
	_expect(_mentions(str(bad_save["errors"]), "user://"), "error explica el motivo de la raiz")
	_expect(not bool(bad_system.load_slot("x")["ok"]), "carga con raiz invalida falla sin escrituras")
	_expect_array(bad_system.list(), [], "listado con raiz invalida vacio")


func _test_interrupted_write() -> void:
	var system = SaveScript.new(SAVE_ROOT)
	_expect(bool(system.save("interrupt", {"step": 1})["ok"]), "guardado previo a la interrupcion")
	_write_raw(system.temp_path("interrupt"), '{"version": 2, "data":')
	_expect(FileAccess.file_exists(system.temp_path("interrupt")), "temporal incompleto simulado")
	var loaded := system.load_slot("interrupt")
	_expect(bool(loaded["ok"]), "temporal incompleto no afecta la carga")
	_expect_eq(loaded["data"], {"step": 1}, "se carga el ultimo guardado completo")
	_expect_eq(str(loaded["source"]), "main", "el temporal nunca se usa como fuente")
	_expect(not system.list().has("interrupt.sav.tmp"), "temporal no aparece en el listado")

	_write_raw(system.temp_path("fresh"), "parcial")
	_expect(FileAccess.file_exists(system.temp_path("fresh")), "temporal de ranura nueva simulado")
	var missing := system.load_slot("fresh")
	_expect(not bool(missing["ok"]), "temporal sin principal no crea una ranura valida")
	_expect(_mentions(str(missing["errors"]), "principal"), "error por falta de principal")
	_expect(not system.list().has("fresh"), "ranura incompleta no se lista")
	var retry := system.save("fresh", {"ok": true})
	_expect(bool(retry["ok"]), "guardado tras interrupcion")
	_expect(not FileAccess.file_exists(system.temp_path("fresh")), "temporal consumido y eliminado")
	var final := system.load_slot("fresh")
	_expect(bool(final["ok"]), "carga tras reintentar")
	_expect_eq(final["data"], {"ok": true}, "datos tras reintentar")


func _v1_to_v2(data: Dictionary) -> Dictionary:
	var migrated := data.duplicate(true)
	migrated["score"] = int(migrated.get("old_score", 0))
	migrated.erase("old_score")
	migrated["flags"] = {"migrated_from": 1}
	return migrated


func _bad_hook(_data: Dictionary) -> String:
	return "no es un Dictionary"


func _item(id: String, nombre: String, stackable: bool, max_stack: int, peso: float) -> Dictionary:
	return {
		"id": id,
		"nombre": nombre,
		"apilable": stackable,
		"max_stack": max_stack,
		"peso": peso,
	}


func _mentions(text: String, fragment: String) -> bool:
	return text.find(fragment) >= 0


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


func _expect_array(actual: Array, expected: Array, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return JSON.parse_string(text)


func _write_raw(path: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "no se pudo escribir '%s'" % path)
		return
	file.store_string(content)
	file.close()


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _cleanup() -> void:
	_remove_dir(SAVE_ROOT)


func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(str(name))))
	for name in dir.get_directories():
		_remove_dir(path.path_join(str(name)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
