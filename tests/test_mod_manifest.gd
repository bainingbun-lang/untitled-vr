extends SceneTree

const ModManifestScript = preload("res://core/mod_manifest.gd")

var _failures: Array = []
var _case := ""


func _init() -> void:
	_case = "manifiesto valido completo"
	_test_valid_full()

	_case = "minimo valido"
	_test_valid_minimal()

	_case = "falta id"
	_test_missing_id()

	_case = "version no semver"
	_test_invalid_version()

	_case = "schema_version distinto de 1"
	_test_invalid_schema_version()

	_case = "tipo incorrecto en priority"
	_test_invalid_priority_type()

	_case = "campo desconocido ignorado"
	_test_unknown_field()

	_case = "formatos validos de replaces"
	_test_valid_replaces_formats()

	_case = "formatos invalidos de replaces"
	_test_invalid_replaces_formats()

	_case = "conflicto real"
	_test_conflict_real()

	_case = "falso conflicto evitado"
	_test_no_false_conflict_distinct_owners()

	_case = "prioridades distintas"
	_test_no_conflict_distinct_priority()

	_case = "misma clave con y sin prefijo"
	_test_same_key_with_prefix()

	_case = "modulo repetido en replaces"
	_test_same_module_repeated()

	_case = "tres modulos misma prioridad"
	_test_three_modules_conflict()

	_case = "manifiesto invalido ignorado"
	_test_invalid_manifest_ignored()

	_case = "lista vacia"
	_test_empty_list()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _errors_text(result: Dictionary) -> String:
	return " | ".join(result["errors"])


func _expect_error(result: Dictionary, needle: String) -> void:
	_expect(not result["ok"], "se esperaba ok=false")
	var text := _errors_text(result)
	_expect(text.contains(needle), "se esperaba un error que contenga '%s', errores: %s" % [needle, text])


func _manifest(id: String, priority: int, replaces: Array) -> Dictionary:
	return {
		"schema_version": 1,
		"id": id,
		"version": "1.0.0",
		"engine": "4.7",
		"priority": priority,
		"replaces": replaces,
	}


func _test_valid_full() -> void:
	var data := {
		"schema_version": 1,
		"id": "autor.nombre",
		"version": "1.2.3",
		"engine": "4.7",
		"depends": {"base.core": ">=1.0.0"},
		"replaces": ["inventario", "otro.modulo:combate"],
		"priority": 50,
		"platforms": ["android", "pc"],
		"permissions": ["red", "archivos"],
	}
	var result := ModManifestScript.parse(data)
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect(result["manifest"]["priority"] == 50, "priority no se conservo")


func _test_valid_minimal() -> void:
	var data := {
		"schema_version": 1,
		"id": "a.b",
		"version": "0.1.0",
		"engine": "4.7",
	}
	var result := ModManifestScript.parse(data)
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	var manifest: Dictionary = result["manifest"]
	_expect(manifest["depends"] == {}, "depends por defecto debe ser {}")
	_expect(manifest["replaces"] == [], "replaces por defecto debe ser []")
	_expect(manifest["priority"] == 100, "priority por defecto debe ser 100")
	_expect(manifest["platforms"] == [], "platforms por defecto debe ser []")
	_expect(manifest["permissions"] == [], "permissions por defecto debe ser []")


func _test_missing_id() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 1,
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect_error(result, "id")


func _test_invalid_version() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 1,
		"id": "a.b",
		"version": "1.0",
		"engine": "4.7",
	})
	_expect_error(result, "version")


func _test_invalid_schema_version() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 2,
		"id": "a.b",
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect_error(result, "schema_version")


func _test_invalid_priority_type() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 1,
		"id": "a.b",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": "alta",
	})
	_expect_error(result, "priority")


func _test_unknown_field() -> void:
	var data := {
		"schema_version": 1,
		"id": "a.b",
		"version": "1.0.0",
		"engine": "4.7",
		"campo_extra": {"x": 1},
	}
	var result := ModManifestScript.parse(data)
	_expect(result["ok"], "errores inesperados: %s" % _errors_text(result))
	_expect(result["manifest"].has("campo_extra"), "el campo desconocido no se conservo")
	_expect(
		result["manifest"]["campo_extra"] == {"x": 1},
		"el valor del campo desconocido no se conservo"
	)


func _test_valid_replaces_formats() -> void:
	for value in ["combate", "otro.modulo:combate_2"]:
		var result := ModManifestScript.parse(_manifest("a.b", 100, [value]))
		_expect(result["ok"], "'%s' deberia ser valido: %s" % [value, _errors_text(result)])


func _test_invalid_replaces_formats() -> void:
	var invalids := [
		"a:b:c",
		"Owner:sistema",
		"owner:",
		":sistema",
		"owner:sis.tema",
		"owner:sis tema",
	]
	for value in invalids:
		var result := ModManifestScript.parse(_manifest("a.b", 100, [value]))
		_expect(not result["ok"], "'%s' deberia ser invalido" % value)


func _test_conflict_real() -> void:
	var conflicts := ModManifestScript.find_conflicts([
		_manifest("aa.uno", 100, ["combate"]),
		_manifest("bb.dos", 100, ["untitled.base:combate"]),
	])
	_expect(conflicts.size() == 1, "se esperaba 1 conflicto, se obtuvieron %d" % conflicts.size())
	if conflicts.size() == 1:
		var conflict: Dictionary = conflicts[0]
		_expect(conflict["owner"] == "untitled.base", "owner incorrecto: %s" % conflict["owner"])
		_expect(conflict["system"] == "combate", "sistema incorrecto: %s" % conflict["system"])
		_expect(conflict["priority"] == 100, "prioridad incorrecta: %s" % conflict["priority"])
		_expect(
			conflict["modules"] == ["aa.uno", "bb.dos"],
			"modulos incorrectos: %s" % str(conflict["modules"])
		)
		var message: String = conflict["message"]
		_expect(message.contains("untitled.base"), "mensaje sin owner: %s" % message)
		_expect(message.contains("combate"), "mensaje sin sistema: %s" % message)
		_expect(message.contains("100"), "mensaje sin prioridad: %s" % message)
		_expect(
			message.contains("aa.uno") and message.contains("bb.dos"),
			"mensaje sin modulos: %s" % message
		)
	var resolved := ModManifestScript.resolve_replacements([
		_manifest("aa.uno", 100, ["combate"]),
		_manifest("bb.dos", 100, ["combate"]),
	])
	_expect(
		not resolved.has("untitled.base:combate"),
		"el empate no debe resolverse: %s" % str(resolved)
	)


func _test_no_false_conflict_distinct_owners() -> void:
	var conflicts := ModManifestScript.find_conflicts([
		_manifest("a.uno", 100, ["a.uno:combate"]),
		_manifest("b.dos", 100, ["b.dos:combate"]),
	])
	_expect(conflicts.is_empty(), "no se esperaban conflictos, se obtuvieron %d" % conflicts.size())


func _test_no_conflict_distinct_priority() -> void:
	var manifests := [
		_manifest("aa.uno", 100, ["combate"]),
		_manifest("bb.dos", 200, ["combate"]),
	]
	var conflicts := ModManifestScript.find_conflicts(manifests)
	_expect(conflicts.is_empty(), "no se esperaban conflictos, se obtuvieron %d" % conflicts.size())
	var resolved := ModManifestScript.resolve_replacements(manifests)
	_expect(
		resolved.get("untitled.base:combate", "") == "bb.dos",
		"se esperaba ganador bb.dos, se obtuvo %s" % str(resolved)
	)


func _test_same_key_with_prefix() -> void:
	var manifests := [
		_manifest("aa.uno", 100, ["combate", "untitled.base:combate"]),
		_manifest("bb.dos", 100, ["combate"]),
	]
	var conflicts := ModManifestScript.find_conflicts(manifests)
	_expect(conflicts.size() == 1, "se esperaba 1 conflicto, se obtuvieron %d" % conflicts.size())
	if conflicts.size() == 1:
		_expect(
			conflicts[0]["modules"] == ["aa.uno", "bb.dos"],
			"modulos duplicados o incorrectos: %s" % str(conflicts[0]["modules"])
		)


func _test_same_module_repeated() -> void:
	var conflicts := ModManifestScript.find_conflicts([
		_manifest("aa.uno", 100, ["combate", "combate"]),
	])
	_expect(conflicts.is_empty(), "un modulo no debe conflictuar consigo mismo")


func _test_three_modules_conflict() -> void:
	var conflicts := ModManifestScript.find_conflicts([
		_manifest("aa.uno", 100, ["combate"]),
		_manifest("bb.dos", 100, ["combate"]),
		_manifest("cc.tres", 100, ["untitled.base:combate"]),
	])
	_expect(conflicts.size() == 1, "se esperaba 1 conflicto, se obtuvieron %d" % conflicts.size())
	if conflicts.size() == 1:
		_expect(
			conflicts[0]["modules"] == ["aa.uno", "bb.dos", "cc.tres"],
			"modulos incorrectos: %s" % str(conflicts[0]["modules"])
		)


func _test_invalid_manifest_ignored() -> void:
	var conflicts := ModManifestScript.find_conflicts([
		_manifest("aa.uno", 100, ["combate"]),
		{
			"id": "MAL",
			"priority": 100,
			"replaces": ["combate"],
		},
	])
	_expect(conflicts.is_empty(), "el manifiesto invalido no debe producir conflictos")


func _test_empty_list() -> void:
	_expect(ModManifestScript.find_conflicts([]).is_empty(), "la lista vacia no debe tener conflictos")
