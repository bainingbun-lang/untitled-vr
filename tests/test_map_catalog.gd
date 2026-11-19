extends SceneTree

const CatalogScript = preload("res://core/maps/map_catalog.gd")
const RegistryScript = preload("res://core/maps/map_registry.gd")

var _failures: Array = []
var _checks := 0
var _case := ""


func _init() -> void:
	_case = "registro de prueba"
	var registry = _build_registry()
	_expect(registry.list().size() == 4, "el registro de prueba debe tener 4 mapas")

	_case = "filtro vacio y compatibilidad"
	var catalog = CatalogScript.new(registry)
	var all_ids := ["alpha", "beta", "gamma", "zeta"]
	_expect_array(catalog.filter({}), all_ids, "filter({}) debe devolver todos los ids ordenados")
	_expect_array(catalog.filter({"status": "compatible"}), ["beta", "zeta"], "status compatible")
	_expect_array(catalog.filter({"compatibility_status": "compatible_with_warnings"}), ["alpha", "gamma"], "compatibility_status compatible_with_warnings")
	_expect_array(catalog.filter({"status": 0}), ["beta", "zeta"], "status por valor enum int")
	_expect_array(catalog.filter({"status": "compatible,compatible_with_warnings"}), all_ids, "status como lista separada por comas")
	_expect_array(catalog.filter({"status": ["compatible_with_warnings", "compatible"]}), all_ids, "status como Array")
	_expect_array(catalog.filter({"status": "compatible", "compatibility": "compatible_with_warnings"}), all_ids, "alias de status combinados")
	_expect_array(catalog.filter({"compatibility": "warnings"}), ["alpha", "gamma"], "alias de valor warnings")

	_case = "filtrado por plataformas"
	_expect_array(catalog.filter({"platform": "android"}), ["alpha", "gamma"], "plataforma android (alias singular)")
	_expect_array(catalog.filter({"platforms": ["vr"]}), ["alpha"], "plataforma vr")
	_expect_array(catalog.filter({"supported_platforms": "pc"}), ["beta", "gamma"], "alias supported_platforms y mayusculas")
	_expect_array(catalog.filter({"platforms": ["android", "vr"]}), ["alpha"], "todas las plataformas pedidas deben estar declaradas")
	_expect_array(catalog.filter({"platform": "console"}), [], "una plataforma no declarada no coincide")

	_case = "filtrado por etiquetas"
	_expect_array(catalog.filter({"tags": ["forest"]}), ["alpha", "gamma"], "etiqueta forest")
	_expect_array(catalog.filter({"tag": "FOREST"}), ["alpha", "gamma"], "alias tag sin importar mayusculas")
	_expect_array(catalog.filter({"tags": ["forest", "puzzle"]}), ["alpha"], "todas las etiquetas pedidas deben estar presentes")
	_expect_array(catalog.filter({"tags": ["nope"]}), [], "una etiqueta ausente no coincide")

	_case = "filtrado por numero de jugadores"
	_expect_array(catalog.filter({"players": 4}), ["alpha", "gamma"], "4 jugadores dentro del rango")
	_expect_array(catalog.filter({"player_count": 2}), ["alpha", "beta"], "alias player_count")
	_expect_array(catalog.filter({"players": 1}), ["beta"], "1 jugador solo en beta")
	_expect_array(catalog.filter({"players": 16}), [], "fuera de todos los rangos")
	_expect_array(catalog.filter({"players_min": 4}), ["alpha", "gamma"], "minimo de jugadores soportado")
	_expect_array(catalog.filter({"min_players": 6}), ["alpha", "gamma"], "alias min_players")
	_expect_array(catalog.filter({"min_player_count": 8}), ["gamma"], "alias min_player_count")
	_expect_array(catalog.filter({"players_max": 2}), ["alpha", "beta"], "maximo de jugadores compatible")
	_expect_array(catalog.filter({"max_players": 2}), ["alpha", "beta"], "alias max_players")
	_expect_array(catalog.filter({"max_player_count": 1}), ["beta"], "alias max_player_count")

	_case = "combinacion de criterios"
	_expect_array(catalog.filter({"status": "compatible", "platform": "pc"}), ["beta"], "estado y plataforma a la vez")
	_expect_array(catalog.filter({"tags": ["forest"], "players_min": 7}), ["gamma"], "etiquetas y jugadores a la vez")
	_expect_array(catalog.filter({"status": "compatible", "platforms": ["android"]}), [], "sin compatibilidad android")
	_expect(not _log_mentions(catalog.get_log(), "ignorado"), "los campos del estandar ya no deben ignorarse")

	_case = "retrocompatibilidad"
	_expect_array(catalog.filter({"status": "compatible"}), ["beta", "zeta"], "zeta no tiene campos opcionales y sigue filtrando por estado")
	_expect_array(catalog.filter({"platforms": ["android"]}), ["alpha", "gamma"], "zeta se excluye solo al pedir plataformas")
	_expect_array(catalog.filter({"players": 1}), ["beta"], "zeta se excluye al pedir un numero de jugadores")

	_case = "criterios y valores invalidos"
	catalog.clear_log()
	_expect_array(catalog.filter({"foo": 1}), [], "un criterio desconocido debe dar error controlado y devolver []")
	_expect(_log_mentions(catalog.get_log(), "criterio desconocido"), "el error controlado debe quedar registrado")
	_expect_array(catalog.filter({"status": "bogus"}), [], "un valor de compatibilidad invalido debe dar error controlado")
	_expect_array(catalog.filter({"platforms": 42}), [], "plataformas con tipo invalido")
	_expect(_log_mentions(catalog.get_log(), "valor invalido"), "el valor invalido debe quedar registrado")
	_expect_array(catalog.filter({"players": 0}), [], "jugadores fuera de rango")
	_expect_array(catalog.filter({"tags": {}}), [], "etiquetas con tipo invalido")

	_case = "sin registro"
	var empty_catalog = CatalogScript.new(null)
	_expect_array(empty_catalog.filter({}), [], "sin MapRegistry debe devolver [] sin crashar")

	_case = "determinismo"
	var reverse = RegistryScript.new()
	for id in ["zeta", "gamma", "beta", "alpha"]:
		_expect(reverse.register(_map_for(id)), "debe registrar %s en orden inverso" % id)
	_expect_array(CatalogScript.new(reverse).filter({}), all_ids, "el orden de insercion no debe afectar el resultado")
	_expect_array(CatalogScript.new(reverse).filter({"status": "compatible_with_warnings"}), ["alpha", "gamma"], "el filtro de estado es determinista")
	_expect_array(CatalogScript.new(reverse).filter({"tags": ["forest"]}), ["alpha", "gamma"], "el filtro de etiquetas es determinista")

	_case = "integridad del registro"
	_expect_array(catalog.filter({}), all_ids, "filter no debe mutar el registro")
	_expect(registry.list().size() == 4, "filter no debe anadir ni quitar mapas")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _build_registry():
	var registry = RegistryScript.new()
	for id in ["zeta", "alpha", "beta", "gamma"]:
		_expect(registry.register(_map_for(id)), "debe registrar %s" % id)
	return registry


func _map_for(id: String) -> Dictionary:
	match id:
		"alpha":
			return _make_map(id, "Custom-License", {
				"platforms": ["android", "vr"],
				"tags": ["forest", "puzzle"],
				"players_min": 2,
				"players_max": 6,
			})
		"beta":
			return _make_map(id, "Apache-2.0", {
				"platforms": ["pc"],
				"tags": ["city"],
				"players_min": 1,
				"players_max": 2,
			})
		"gamma":
			return _make_map(id, "Unknown-License", {
				"platforms": ["Android", "PC"],
				"tags": ["forest", "ruins"],
				"players_min": 4.0,
				"players_max": 8,
			})
		_:
			return _make_map(id, "MIT", {})


func _make_map(id: String, license: String, extra: Dictionary) -> Dictionary:
	var meta: Dictionary = {
		"id": id,
		"license": license,
		"has_collisions": true,
		"has_navigation": true,
		"spawn_points": [Vector3(0, 0, 0)],
	}
	for key in extra.keys():
		meta[key] = extra[key]
	return meta


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_array(actual: Array, expected: Array, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


func _log_mentions(log: Array, fragment: String) -> bool:
	for entry in log:
		if fragment in str(entry):
			return true
	return false
