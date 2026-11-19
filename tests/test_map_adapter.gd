extends SceneTree

var _checks := 0
var _failures: Array = []
var _case := ""


func _init():
	var MapAdapter = load("res://core/maps/map_adapter.gd")
	_case = "casos originales"
	var valid := {
		"id": "map_ok",
		"version": "1.2.0",
		"author": "Tester",
		"license": "MIT",
		"scale": 1.0,
		"has_navigation": true,
		"has_collisions": true,
		"spawn_points": [Vector3(0, 0, 0)]
	}

	var r1: Dictionary = MapAdapter.adapt(valid)
	_check(
		"valido",
		r1["ok"] == true
		and (r1["errors"] as Array).is_empty()
		and (r1["warnings"] as Array).is_empty()
		and r1["meta"]["id"] == "map_ok"
		and r1["meta"]["author"] == "Tester",
		str(r1)
	)
	_expect(
		"los mapas sin campos opcionales conservan el estado valido",
		r1["meta"]["platforms"] == [] and r1["meta"]["tags"] == []
			and r1["meta"]["players_min"] == 1 and r1["meta"]["players_max"] == 1,
		str(r1)
	)

	var legacy := {
		"map_id": "map_legacy",
		"licence": "Apache-2.0",
		"hasNavMesh": "true",
		"collision_shapes": "1",
		"spawns": "0,1,0",
		"mapScale": "2.5",
		"creator": "Legacy Author"
	}
	var r2: Dictionary = MapAdapter.adapt(legacy)
	var meta2: Dictionary = r2["meta"]
	var spawns2: Array = meta2["spawn_points"]
	_check(
		"campos renombrados",
		r2["ok"] == true
		and (r2["errors"] as Array).is_empty()
		and meta2["id"] == "map_legacy"
		and meta2["license"] == "Apache-2.0"
		and meta2["has_navigation"] == true
		and meta2["has_collisions"] == true
		and spawns2.size() == 1
		and spawns2[0] == Vector3(0, 1, 0)
		and meta2["scale"] == 2.5
		and meta2["author"] == "Legacy Author"
		and _has_warning(r2["warnings"], "renombrado"),
		str(r2)
	)

	var missing := {
		"license": "MIT",
		"has_navigation": true,
		"has_collisions": true,
		"spawn_points": [Vector3.ZERO]
	}
	var r3: Dictionary = MapAdapter.adapt(missing)
	_check(
		"faltante critico",
		r3["ok"] == false and _has_error(r3["errors"], "unique identifier"),
		str(r3)
	)

	var wrong := {
		"id": "map_bad",
		"license": "MIT",
		"has_navigation": "quizas",
		"has_collisions": [],
		"spawn_points": 42,
		"scale": "abc"
	}
	var r4: Dictionary = MapAdapter.adapt(wrong)
	_check(
		"tipos incorrectos",
		r4["ok"] == false
		and (r4["errors"] as Array).size() >= 3
		and r4["meta"]["id"] == "map_bad"
		and r4["meta"]["scale"] == 1.0,
		str(r4)
	)

	var r5: Dictionary = MapAdapter.adapt({})
	var meta5: Dictionary = r5["meta"]
	_check(
		"vacio",
		r5["ok"] == false
		and (r5["errors"] as Array).size() >= 5
		and meta5["version"] == "1.0.0"
		and meta5["author"] == "Unknown"
		and meta5["scale"] == 1.0
		and (meta5["spawn_points"] as Array).is_empty()
		and (meta5["forbidden_zones"] as Array).is_empty()
		and (meta5["performance_profiles"] as Dictionary).is_empty(),
		str(r5)
	)
	_expect(
		"valores por defecto de los campos opcionales",
		meta5["platforms"] == [] and meta5["tags"] == []
			and meta5["players_min"] == 1 and meta5["players_max"] == 1,
		str(r5)
	)

	var extra: Dictionary = valid.duplicate(true)
	extra["legacy_custom"] = 7
	extra["editor_notes"] = "nota"
	var r6: Dictionary = MapAdapter.adapt(extra)
	_check(
		"campos desconocidos preservados",
		r6["ok"] == true
		and r6["meta"]["legacy_custom"] == 7
		and r6["meta"]["editor_notes"] == "nota"
		and _has_warning(r6["warnings"], "legacy_custom")
		and _has_warning(r6["warnings"], "desconocido"),
		str(r6)
	)

	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["map_id"] = "should_not_win"
	var r7: Dictionary = MapAdapter.adapt(duplicate)
	_check(
		"canonico prevalece sobre alias",
		r7["ok"] == true
		and r7["meta"]["id"] == "map_ok"
		and _has_warning(r7["warnings"], "map_id"),
		str(r7)
	)

	var unknown_license: Dictionary = valid.duplicate(true)
	unknown_license["license"] = "Custom-License"
	var r8: Dictionary = MapAdapter.adapt(unknown_license)
	_check(
		"warning del validador",
		r8["ok"] == true
		and (r8["errors"] as Array).is_empty()
		and _has_warning(r8["warnings"], "Unknown license"),
		str(r8)
	)

	var jsonish: Dictionary = valid.duplicate(true)
	jsonish["spawn_points"] = "[{\"x\":0,\"y\":0,\"z\":0}]"
	jsonish["performance_profiles"] = "{\"android\":{\"max_objects\":100}}"
	var r9: Dictionary = MapAdapter.adapt(jsonish)
	_check(
		"json dentro de strings",
		r9["ok"] == true
		and (r9["meta"]["spawn_points"] as Array).size() == 1
		and (r9["meta"]["performance_profiles"] as Dictionary).has("android"),
		str(r9)
	)

	_case = "campos opcionales canonicales"
	var full: Dictionary = valid.duplicate(true)
	full["platforms"] = " Android, vr,android "
	full["tags"] = "forest,puzzle,forest"
	full["players_min"] = "2"
	full["players_max"] = 4.0
	var r10: Dictionary = MapAdapter.adapt(full)
	_expect(
		"texto y numeros convertidos",
		r10["ok"] == true
		and (r10["errors"] as Array).is_empty()
		and r10["meta"]["platforms"] == ["android", "vr"]
		and r10["meta"]["tags"] == ["forest", "puzzle"]
		and r10["meta"]["players_min"] == 2
		and r10["meta"]["players_max"] == 4,
		str(r10)
	)

	var aliased: Dictionary = valid.duplicate(true)
	aliased["supported_platforms"] = ["mobile", "pc"]
	aliased["tag"] = ["forest"]
	aliased["min_players"] = 1
	aliased["max_players"] = 6
	var r11: Dictionary = MapAdapter.adapt(aliased)
	_expect(
		"alias convertidos y renombrados",
		r11["ok"] == true
		and r11["meta"]["platforms"] == ["android", "pc"]
		and r11["meta"]["tags"] == ["forest"]
		and r11["meta"]["players_min"] == 1
		and r11["meta"]["players_max"] == 6
		and _has_warning(r11["warnings"], "supported_platforms")
		and _has_warning(r11["warnings"], "min_players"),
		str(r11)
	)

	var json_optional: Dictionary = valid.duplicate(true)
	json_optional["platforms"] = "[\"android\",\"quest\"]"
	json_optional["tags"] = "[\"forest\"]"
	var r12: Dictionary = MapAdapter.adapt(json_optional)
	_expect(
		"listas JSON en los campos opcionales",
		r12["ok"] == true
		and r12["meta"]["platforms"] == ["android", "vr"]
		and r12["meta"]["tags"] == ["forest"],
		str(r12)
	)

	var dup2: Dictionary = valid.duplicate(true)
	dup2["platforms"] = ["pc"]
	dup2["platform"] = "vr"
	var r13: Dictionary = MapAdapter.adapt(dup2)
	_expect(
		"canonico prevalece sobre alias opcional",
		r13["ok"] == true
		and r13["meta"]["platforms"] == ["pc"]
		and _has_warning(r13["warnings"], "platform"),
		str(r13)
	)

	_case = "campos opcionales invalidos"
	var invalid: Dictionary = valid.duplicate(true)
	invalid["platforms"] = ["android", "console"]
	invalid["tags"] = true
	invalid["players_min"] = 5
	invalid["players_max"] = 2
	var r14: Dictionary = MapAdapter.adapt(invalid)
	_expect(
		"errores de tipo y rango reportados",
		r14["ok"] == false
		and _has_error(r14["errors"], "platforms")
		and _has_error(r14["errors"], "tags")
		and _has_error(r14["errors"], "players_min"),
		str(r14)
	)

	var fractional: Dictionary = valid.duplicate(true)
	fractional["players_max"] = 2.5
	var r15: Dictionary = MapAdapter.adapt(fractional)
	_expect(
		"jugadores fraccionarios rechazados",
		r15["ok"] == false and _has_error(r15["errors"], "players_max"),
		str(r15)
	)

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _check(name: String, condition: bool, detail: String) -> void:
	_expect(name, condition, detail)


func _expect(name: String, condition: bool, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s -> %s" % [_case, name, detail])


func _has_error(errors: Array, needle: String) -> bool:
	for item in errors:
		if str(item).contains(needle):
			return true
	return false


func _has_warning(warnings: Array, needle: String) -> bool:
	for item in warnings:
		if str(item).contains(needle):
			return true
	return false
