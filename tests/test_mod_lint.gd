extends SceneTree

const ModLintScript = preload("res://core/mod_lint.gd")

const ROOT := "res://tests/fixtures/mods_lint"
const VALID := ROOT + "/valid"
const NO_ENTRY := ROOT + "/no_entry"
const TRAVERSAL := ROOT + "/traversal"
const NONPORTABLE := ROOT + "/nonportable"
const BROKEN_JSON := ROOT + "/broken_json"
const MISSING := ROOT + "/no_existe"

var _failures: Array = []
var _case := ""
var _assertions := 0


func _init() -> void:
	_case = "mod valido"
	_test_valid()

	_case = "entry ausente en disco"
	_test_no_entry()

	_case = "path traversal"
	_test_traversal()

	_case = "nombre no portable"
	_test_nonportable()

	_case = "json roto"
	_test_broken_json()

	_case = "directorio inexistente"
	_test_missing_dir()

	_case = "ruta absoluta rechazada"
	_test_absolute_path()

	_case = "tamano maximo"
	_test_size_limit()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		print("FAIL (%d assertions): %s" % [_assertions, "; ".join(_failures)])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _errors_text(report: Dictionary) -> String:
	return " | ".join(report["errors"])


func _warnings_text(report: Dictionary) -> String:
	return " | ".join(report["warnings"])


func _expect_error(report: Dictionary, needle: String) -> void:
	_expect(not report["ok"], "se esperaba ok=false")
	_expect(
		_errors_text(report).contains(needle),
		"se esperaba un error con '%s', errores: %s" % [needle, _errors_text(report)]
	)


func _test_valid() -> void:
	var report: Dictionary = ModLintScript.check(VALID)
	_expect(report["ok"], "el mod valido debe pasar: %s" % _errors_text(report))
	_expect(report["errors"].is_empty(), "el mod valido no debe tener errores")
	_expect(report["warnings"].is_empty(), "el mod valido no debe tener avisos: %s" % _warnings_text(report))


func _test_no_entry() -> void:
	var report: Dictionary = ModLintScript.check(NO_ENTRY)
	_expect_error(report, "no existe")


func _test_traversal() -> void:
	var report: Dictionary = ModLintScript.check(TRAVERSAL)
	_expect_error(report, "traversal")


func _test_nonportable() -> void:
	var report: Dictionary = ModLintScript.check(NONPORTABLE)
	_expect_error(report, "backslash")
	_expect(
		_warnings_text(report).contains("mayusculas"),
		"se esperaba un aviso por mayusculas: %s" % _warnings_text(report)
	)


func _test_broken_json() -> void:
	var report: Dictionary = ModLintScript.check(BROKEN_JSON)
	_expect_error(report, "JSON invalido")


func _test_missing_dir() -> void:
	var report: Dictionary = ModLintScript.check(MISSING)
	_expect_error(report, "no se pudo abrir")


func _test_absolute_path() -> void:
	var report: Dictionary = ModLintScript.check("/" + "tmp/mod")  # ruta absoluta a proposito: debe rechazarse
	_expect_error(report, "no portable")


func _test_size_limit() -> void:
	var report: Dictionary = ModLintScript.check(VALID, 16)
	_expect(not report["ok"], "un limite de 16 bytes debe fallar")
	_expect(
		_errors_text(report).contains("demasiado grande"),
		"se esperaba un error de tamano: %s" % _errors_text(report)
	)
