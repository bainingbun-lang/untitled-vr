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

	_case = "conflicto con misma prioridad"
	_test_conflict_same_priority()

	_case = "sin conflicto con prioridades distintas"
	_test_no_conflict_distinct_priority()

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


func _test_conflict_same_priority() -> void:
	var manifests := [
		{
			"id": "aa.uno",
			"priority": 100,
			"replaces": ["combate"],
		},
		{
			"id": "bb.dos",
			"priority": 100,
			"replaces": ["otro.modulo:combate"],
		},
	]
	var conflicts := ModManifestScript.find_conflicts(manifests)
	_expect(conflicts.size() == 1, "se esperaba 1 conflicto, se obtuvieron %d" % conflicts.size())
	if conflicts.size() > 0:
		var text: String = conflicts[0]
		_expect(text.contains("conflicto: combate"), "mensaje sin sistema: %s" % text)
		_expect(text.contains("aa.uno") and text.contains("bb.dos"), "mensaje sin modulos: %s" % text)
		_expect(text.contains("100"), "mensaje sin prioridad: %s" % text)


func _test_no_conflict_distinct_priority() -> void:
	var manifests := [
		{
			"id": "aa.uno",
			"priority": 100,
			"replaces": ["combate"],
		},
		{
			"id": "bb.dos",
			"priority": 200,
			"replaces": ["combate"],
		},
	]
	var conflicts := ModManifestScript.find_conflicts(manifests)
	_expect(conflicts.is_empty(), "no se esperaban conflictos, se obtuvieron %d" % conflicts.size())
