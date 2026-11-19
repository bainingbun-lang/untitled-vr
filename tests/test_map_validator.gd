extends SceneTree

const ValidatorScript = preload("res://core/maps/map_validator.gd")

var _checks := 0
var _failures: Array = []
var _case := ""


func _init() -> void:
	var validator = ValidatorScript.new()
	var status = ValidatorScript.Status

	_case = "casos originales sin campos opcionales"
	_expect_status(validator.validate(_base("map_01", "MIT")), status.COMPATIBLE, "mapa completo")
	_expect_status(validator.validate(_without(_base("map_02", "MIT"), "has_navigation")), status.REQUIRES_ADAPTATION, "sin navegacion")
	_expect_status(validator.validate(_without(_base("map_03", "MIT"), "id")), status.INCOMPATIBLE, "sin id")
	_expect_status(validator.validate(_base("map_04", "Unknown-Lic")), status.COMPATIBLE_WITH_WARNINGS, "licencia desconocida")
	_expect_status(validator.validate(_with(_base("map_05", "MIT"), "spawn_points", [])), status.REQUIRES_ADAPTATION, "sin spawn points")
	_expect_status(validator.validate(_without(_base("map_06", "MIT"), "license")), status.INCOMPATIBLE, "sin licencia")
	_expect_status(validator.validate(_without(_base("map_07", "MIT"), "has_collisions")), status.REQUIRES_ADAPTATION, "sin colisiones")

	_case = "campos opcionales validos"
	var complete := _base("map_10", "MIT")
	complete["platforms"] = ["android", "pc", "vr"]
	complete["tags"] = ["forest", "puzzle"]
	complete["players_min"] = 2
	complete["players_max"] = 4
	_expect_status(validator.validate(complete), status.COMPATIBLE, "plataformas, etiquetas y rango validos")
	_expect_status(validator.validate(_with(_base("map_11", "MIT"), "platforms", [])), status.COMPATIBLE, "lista de plataformas vacia")
	_expect_status(validator.validate(_with(_base("map_12", "MIT"), "tags", [])), status.COMPATIBLE, "lista de etiquetas vacia")
	_expect_status(validator.validate(_with(_base("map_13", "MIT"), "platforms", [" Android ", "VR"])), status.COMPATIBLE, "plataformas se comparan sin importar mayusculas")
	_expect_status(validator.validate(_with(_base("map_14", "MIT"), "players_min", 3)), status.COMPATIBLE, "solo limite inferior")
	_expect_status(validator.validate(_with(_base("map_15", "MIT"), "players_max", 3)), status.COMPATIBLE, "solo limite superior")
	_expect_status(validator.validate(_with(_base("map_16", "MIT"), "players_min", 3.0)), status.COMPATIBLE, "numero JSON entero 3.0")
	var equal := _base("map_17", "MIT")
	equal["players_min"] = 3
	equal["players_max"] = 3
	_expect_status(validator.validate(equal), status.COMPATIBLE, "rango de un solo valor")
	var ordered := _base("map_18", "MIT")
	ordered["players_min"] = 1
	ordered["players_max"] = 8
	_expect_status(validator.validate(ordered), status.COMPATIBLE, "rango amplio ordenado")

	_case = "plataformas invalidas"
	var bad_platform_type: Dictionary = validator.validate(_with(_base("map_20", "MIT"), "platforms", "android"))
	_expect_status(bad_platform_type, status.REQUIRES_ADAPTATION, "plataformas como String")
	_expect_error(bad_platform_type, "platforms", "mensaje de plataformas")
	var bad_platform_value: Dictionary = validator.validate(_with(_base("map_21", "MIT"), "platforms", ["android", "console"]))
	_expect_status(bad_platform_value, status.REQUIRES_ADAPTATION, "plataforma desconocida")
	_expect_error(bad_platform_value, "console", "mensaje de plataforma desconocida")
	_expect_status(validator.validate(_with(_base("map_22", "MIT"), "platforms", [1])), status.REQUIRES_ADAPTATION, "plataforma no string")

	_case = "etiquetas invalidas"
	var bad_tags_type: Dictionary = validator.validate(_with(_base("map_30", "MIT"), "tags", "forest"))
	_expect_status(bad_tags_type, status.REQUIRES_ADAPTATION, "etiquetas como String")
	_expect_error(bad_tags_type, "tags", "mensaje de etiquetas")
	_expect_status(validator.validate(_with(_base("map_31", "MIT"), "tags", ["forest", 7])), status.REQUIRES_ADAPTATION, "etiqueta no string")

	_case = "rango de jugadores invalido"
	_expect_status(validator.validate(_with(_base("map_40", "MIT"), "players_min", 2.5)), status.REQUIRES_ADAPTATION, "min fraccionario")
	_expect_status(validator.validate(_with(_base("map_41", "MIT"), "players_max", "4")), status.REQUIRES_ADAPTATION, "max como String")
	_expect_status(validator.validate(_with(_base("map_42", "MIT"), "players_min", true)), status.REQUIRES_ADAPTATION, "min como bool")
	_expect_status(validator.validate(_with(_base("map_43", "MIT"), "players_min", 0)), status.REQUIRES_ADAPTATION, "min menor que 1")
	_expect_status(validator.validate(_with(_base("map_44", "MIT"), "players_max", 0)), status.REQUIRES_ADAPTATION, "max menor que 1")
	var inverted := _base("map_45", "MIT")
	inverted["players_min"] = 6
	inverted["players_max"] = 2
	var inverted_result: Dictionary = validator.validate(inverted)
	_expect_status(inverted_result, status.REQUIRES_ADAPTATION, "min mayor que max")
	_expect_error(inverted_result, "players_min", "mensaje de rango invertido")

	_case = "prioridad de estados"
	var broken := _without(_base("map_50", "MIT"), "id")
	broken["platforms"] = "pc"
	_expect_status(validator.validate(broken), status.INCOMPATIBLE, "un id faltante sigue siendo incompatible")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _base(id: String, license: String) -> Dictionary:
	return {
		"id": id,
		"license": license,
		"has_navigation": true,
		"has_collisions": true,
		"spawn_points": [Vector3(0, 0, 0)],
	}


func _with(data: Dictionary, key: String, value) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result[key] = value
	return result


func _without(data: Dictionary, key: String) -> Dictionary:
	var result: Dictionary = data.duplicate(true)
	result.erase(key)
	return result


func _expect_status(result: Dictionary, expected: int, message: String) -> void:
	_checks += 1
	var actual: int = result.get("status", -1)
	if actual != expected:
		_failures.append(
			"[%s] %s (esperado %d, obtenido %d: %s)"
			% [_case, message, expected, actual, str(result.get("errors", []))]
		)


func _expect_error(result: Dictionary, needle: String, message: String) -> void:
	_checks += 1
	var found := false
	for item in result.get("errors", []):
		if needle in str(item):
			found = true
			break
	if not found:
		_failures.append("[%s] %s (no se encontro '%s' en %s)" % [_case, message, needle, str(result.get("errors", []))])
