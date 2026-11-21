extends SceneTree

const ContentRegistryScript = preload("res://core/game/content_registry.gd")

var _failures: Array = []
var _checks := 0
var _case := ""

func _initialize() -> void:
	_case = "content_registry.instancia_y_carga_base"
	var registry := ContentRegistryScript.instance()
	_expect(registry != null, "instancia obtenida")
	var base := registry.load_base()
	_expect(bool(base.get("ok", false)), "base mod cargado correctamente")

	_case = "content_registry.armas_registradas"
	var ids := registry.ordered_ids("weapon")
	_expect(ids.size() >= 6, "al menos 6 armas registradas")
	for id in ["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"]:
		_expect(bool(registry.has("weapon", id)), "arma registrada: %s" % id)
		var def := registry.definition("weapon", id)
		_expect(not def.is_empty(), "definicion no vacia para %s" % id)
		_expect(str(def.get("id", "")) == id, "id publico coherente para %s" % id)

	_case = "content_registry.canonical_id"
	_expect(registry.canonical_id("weapon", "pistol") == "untitled.base:pistol", "canonical id de pistol")
	_expect(registry.canonical_id("weapon", "untitled.base:pistol") == "untitled.base:pistol", "canonical id ya canonico")
	_expect(registry.canonical_id("weapon", "no_existe").is_empty(), "canonical id de inexistente vacio")

	_case = "content_registry.owner_of"
	_expect(registry.owner_of("weapon", "pistol") == "untitled.base", "dueno de pistol es untitled.base")
	_expect(registry.owner_of("weapon", "no_existe").is_empty(), "dueno de inexistente vacio")

	_case = "content_registry.ids_y_all"
	var id_list := registry.ids("weapon")
	_expect(id_list.size() >= 6, "al menos 6 ids")
	var all_defs := registry.all("weapon")
	_expect(all_defs.size() >= 6, "al menos 6 definiciones en all()")
	for id in all_defs.keys():
		var d := all_defs.get(id, {}) as Dictionary
		_expect(str(d.get("id", "")) == id, "id en all() coincide con clave: %s" % id)

	_case = "content_registry.validacion"
	var valid_weapon := {
		"id": "untitled.base:test_arma",
		"name": "Arma de prueba",
		"damage": 10.0,
		"fire_rate": 5.0,
		"range": 30.0,
		"mag": 10,
		"auto": false,
		"fire_mode": "semi",
		"spread": 1.0,
		"pellets": 1,
		"tags": ["weapon"],
		"reload_time": 1.0,
		"weight": 1.0,
		"impulse": 0.1,
		"uses_ammo": true,
		"penetration": 0.1,
		"falloff_start": 5.0,
		"falloff_end": 30.0,
		"falloff_min": 0.5,
		"projectile_speed": 0.0,
		"projectile_gravity": 0.0,
		"projectile_min_distance": 1.0,
		"impact_speed": 100.0,
		"effect_scale": 1.0,
		"max_penetrations": 0,
		"max_ricochets": 0,
	}
	var result := registry.validate("weapon", valid_weapon, "untitled.base")
	_expect(bool(result.get("ok", false)), "arma valida pasa validacion")
	var invalid_weapon := {
		"id": "BAD_ID",
		"name": "Arma invalida",
	}
	var result2 := registry.validate("weapon", invalid_weapon, "untitled.base")
	_expect(not bool(result2.get("ok", false)), "arma invalida rechazada")
	_expect(result2.get("errors").size() > 0, "errores reportados para arma invalida")

	_case = "content_registry.errores"
	registry.clear_errors()
	_expect(registry.errors().size() == 0, "errores vacios despues de clear_errors")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for f in _failures:
			print("FAIL: " + f)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures.append("[%s] %s" % [_case, msg])
