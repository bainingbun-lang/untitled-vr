extends SceneTree

const DbScript = preload("res://core/game/item_db.gd")
const InvScript = preload("res://core/game/inventory.gd")
const CraftScript = preload("res://core/game/crafting.gd")

var _failures: Array = []
var _checks := 0
var _case := ""


func _init() -> void:
	var db := DbScript.new()
	_expect(db.register(_item("wood", "Madera", true, 10, 1.0)), "registrar madera")
	_expect(db.register(_item("iron", "Hierro", true, 5, 2.0)), "registrar hierro")
	_expect(db.register(_item("sword", "Espada", false, 1, 3.0)), "registrar espada")
	_expect(db.register(_item("herb", "Hierba", true, 10, 0.5)), "registrar hierba")
	_expect(db.register(_item("potion", "Pocion", true, 5, 1.0)), "registrar pocion")
	_expect(db.register(_item("gem", "Gema", false, 1, 1.0)), "registrar gema")
	_expect(db.register(_item("dust", "Polvo", false, 1, 0.5)), "registrar polvo")
	var craft := CraftScript.new(db)

	_case = "validacion y registro data-driven"
	_expect(craft.register(_recipe("sword_recipe", {"wood": 2, "iron": 1}, {"sword": 1}, 1.5, ["forge"])), "registrar receta de espada")
	_expect(craft.register(_recipe("potion_recipe", {"herb": 2}, {"potion": 1}, 0.5, [])), "registrar receta de pocion")
	_expect(craft.register(_recipe("gem_dust", {"gem": 1}, {"dust": 1, "potion": 1}, 2.0, [])), "registrar receta con dos salidas")
	_expect_array(craft.list(), ["gem_dust", "potion_recipe", "sword_recipe"], "listado ordenado")
	_expect_eq(int(craft.get_recipe("sword_recipe")["time"] * 10.0), 15.0, "tiempo normalizado")
	_expect_array(craft.get_recipe("sword_recipe")["station_tags"], ["forge"], "tags de estacion normalizados")
	var editable := craft.get_recipe("sword_recipe")
	editable["inputs"]["wood"] = 99
	_expect_eq(int(craft.get_recipe("sword_recipe")["inputs"]["wood"]), 2, "get_recipe devuelve copia profunda")
	_expect(craft.get_recipe("ghost").is_empty(), "receta desconocida vacia")
	_expect(not bool(CraftScript.parse({})["ok"]), "receta sin id rechazada")
	_expect(not bool(CraftScript.parse({"id": "Bad", "inputs": {"wood": 1}, "outputs": {"sword": 1}})["ok"]), "id con mayusculas rechazado")
	_expect(not bool(CraftScript.parse({"id": "bad", "inputs": {"wood": 0}, "outputs": {"sword": 1}})["ok"]), "cantidad 0 rechazada")
	_expect(not bool(CraftScript.parse({"id": "bad", "inputs": {}, "outputs": {"sword": 1}})["ok"]), "entradas vacias rechazadas")
	_expect(not bool(CraftScript.parse({"id": "bad", "inputs": {"wood": 1}, "outputs": {}})["ok"]), "salidas vacias rechazadas")
	_expect(not bool(CraftScript.parse({"id": "bad", "inputs": {"wood": 1}, "outputs": {"sword": 1}, "time": -1})["ok"]), "tiempo negativo rechazado")
	_expect(not bool(CraftScript.parse({"id": "bad", "inputs": {"wood": 1}, "outputs": {"sword": 1}, "station_tags": 5})["ok"]), "tags no Array rechazados")
	var alias := CraftScript.parse({"id": "alias_recipe", "entradas": {"wood": 1}, "salidas": {"sword": 1}, "tiempo": "3", "tags_estacion": [" Forge ", "forge"]})
	_expect(bool(alias["ok"]), "alias en espanol aceptados")
	_expect_array(alias["recipe"]["station_tags"], ["forge"], "tags de estacion sin duplicados")
	_expect_eq(float(alias["recipe"]["time"]), 3.0, "tiempo desde texto aceptado")

	_case = "crafteo correcto"
	var inv := InvScript.new(db, 10, -1.0)
	_expect(bool(inv.add("wood", 2)["ok"]), "agregar 2 maderas")
	_expect(bool(inv.add("iron", 1)["ok"]), "agregar 1 hierro")
	_expect(bool(craft.can_craft(inv, "sword_recipe", ["forge"])["ok"]), "can_craft con estacion correcta")
	var result := craft.craft(inv, "sword_recipe", ["forge"])
	_expect(bool(result["ok"]), "craft de espada exitoso")
	_expect_eq(str(result["recipe_id"]), "sword_recipe", "id de receta en resultado")
	_expect_eq(float(result["time"]), 1.5, "tiempo en resultado")
	_expect_eq(int(result["consumed"]["wood"]), 2, "entradas consumidas informadas")
	_expect_eq(int(result["produced"]["sword"]), 1, "salidas producidas informadas")
	_expect_eq(inv.count("wood"), 0, "madera consumida")
	_expect_eq(inv.count("iron"), 0, "hierro consumido")
	_expect_eq(inv.count("sword"), 1, "espada obtenida")
	_expect_eq(inv.total_weight(), 3.0, "peso final correcto")

	_case = "tags de estacion"
	var station_inv := InvScript.new(db, 10, -1.0)
	station_inv.add("wood", 2)
	station_inv.add("iron", 1)
	var station_before := station_inv.to_dict()
	_expect(not bool(craft.can_craft(station_inv, "sword_recipe")["ok"]), "sin tags no se puede craftear")
	var no_station := craft.craft(station_inv, "sword_recipe")
	_expect(not bool(no_station["ok"]), "craft sin estacion falla")
	_expect(_mentions(str(no_station["reason"]), "estacion"), "motivo de estacion informado")
	_expect_eq(station_inv.to_dict(), station_before, "inventario intacto sin estacion")
	_expect(not bool(craft.can_craft(station_inv, "sword_recipe", ["workbench"])["ok"]), "tag incorrecto rechazado")
	_expect(bool(craft.can_craft(station_inv, "sword_recipe", ["FORGE"])["ok"]), "tags se comparan sin capitalizacion")

	_case = "faltan entradas y atomicidad"
	var poor := InvScript.new(db, 10, -1.0)
	poor.add("wood", 1)
	var poor_before := poor.to_dict()
	var missing_check := craft.can_craft(poor, "sword_recipe", ["forge"])
	_expect(not bool(missing_check["ok"]), "can_craft detecta entradas faltantes")
	_expect(_mentions(str(missing_check["reason"]), "entradas"), "motivo entradas")
	_expect_eq((missing_check["missing"] as Array).size(), 2, "se informan madera y hierro faltantes")
	var iron_missing := 0
	for entry in missing_check["missing"]:
		if str(entry["id"]) == "iron":
			iron_missing = int(entry["amount"])
	_expect_eq(iron_missing, 1, "cantidad faltante de hierro")
	var poor_result := craft.craft(poor, "sword_recipe", ["forge"])
	_expect(not bool(poor_result["ok"]), "craft con entradas faltantes falla")
	_expect_eq(poor.to_dict(), poor_before, "inventario exactamente igual tras falta de entradas")
	_expect_eq(poor.count("wood"), 1, "madera no consumida al fallar")
	_expect_eq(poor.count("sword"), 0, "sin espada al fallar")

	_case = "sin espacio y atomicidad"
	var full := InvScript.new(db, 2, -1.0)
	full.add("wood", 3)
	full.add("iron", 2)
	var full_before := full.to_dict()
	var space_check := craft.can_craft(full, "sword_recipe", ["forge"])
	_expect(not bool(space_check["ok"]), "can_craft detecta salida sin espacio")
	_expect(_mentions(str(space_check["reason"]), "cabe"), "motivo de espacio")
	_expect_eq((space_check["blocked"] as Array).size(), 1, "se informa salida bloqueada")
	_expect_eq(str((space_check["blocked"] as Array)[0]["id"]), "sword", "salida bloqueada es la espada")
	var space_result := craft.craft(full, "sword_recipe", ["forge"])
	_expect(not bool(space_result["ok"]), "craft sin espacio falla")
	_expect_eq(full.to_dict(), full_before, "inventario exactamente igual tras falta de espacio")
	_expect_eq(full.count("wood"), 3, "entradas no consumidas al no caber salida")
	_expect_eq(full.count("sword"), 0, "sin espada creada")

	_case = "receta con varias salidas"
	var multi_inv := InvScript.new(db, 10, -1.0)
	multi_inv.add("gem", 1)
	_expect(bool(craft.can_craft(multi_inv, "gem_dust")["ok"]), "receta multi-salida craftable")
	var multi := craft.craft(multi_inv, "gem_dust")
	_expect(bool(multi["ok"]), "craft multi-salida exitoso")
	_expect_eq(multi_inv.count("gem"), 0, "gema consumida")
	_expect_eq(multi_inv.count("dust"), 1, "polvo obtenido")
	_expect_eq(multi_inv.count("potion"), 1, "pocion obtenida como segunda salida")
	_expect_eq((multi["produced"] as Dictionary).size(), 2, "dos salidas informadas")

	_case = "duplicados, items inexistentes y extension de mods"
	var duplicate := _recipe("sword_recipe", {"wood": 1}, {"potion": 1}, 1.0, [])
	_expect(not craft.register(duplicate), "id de receta duplicado rechazado")
	_expect(_mentions(str(craft.get_log()), "duplicado"), "duplicado registrado en log")
	_expect_eq(int(craft.get_recipe("sword_recipe")["inputs"]["wood"]), 2, "receta original intacta tras duplicado")
	var unknown_input := _recipe("bad_input", {"ghost": 1}, {"potion": 1}, 1.0, [])
	var unknown_output := _recipe("bad_output", {"wood": 1}, {"ghost": 1}, 1.0, [])
	_expect(not craft.register(unknown_input), "item de entrada inexistente rechazado")
	_expect(not craft.register(unknown_output), "item de salida inexistente rechazado")
	_expect(_mentions(str(craft.get_log()), "desconocido"), "item desconocido registrado en log")
	_expect(not craft.has("bad_input") and not craft.has("bad_output"), "recetas invalidas no registradas")
	_expect(db.register(_item("mod_ore", "Mineral del mod", true, 10, 1.0)), "mod registra item nuevo")
	_expect(craft.register(_recipe("mod_ingot", {"mod_ore": 2}, {"iron": 1}, 4.0, [])), "mod registra receta con item nuevo")
	_expect(craft.has("mod_ingot"), "receta del mod disponible")

	_case = "consulta de recetas craftables"
	var query_inv := InvScript.new(db, 12, -1.0)
	query_inv.add("herb", 4)
	_expect_array(craft.craftable(query_inv), ["potion_recipe"], "solo pocion craftable sin estacion")
	query_inv.add("wood", 2)
	query_inv.add("iron", 1)
	query_inv.add("gem", 1)
	_expect_array(craft.craftable(query_inv), ["gem_dust", "potion_recipe"], "sin estacion se excluye espada")
	_expect_array(craft.craftable(query_inv, ["forge"]), ["gem_dust", "potion_recipe", "sword_recipe"], "con estacion se incluye espada")
	_expect_array(craft.get_craftable(query_inv, ["forge"]), ["gem_dust", "potion_recipe", "sword_recipe"], "alias get_craftable")
	_expect_array(craft.get_craftable_recipes(query_inv, ["forge"]), ["gem_dust", "potion_recipe", "sword_recipe"], "alias get_craftable_recipes")

	_case = "serializacion de recetas"
	var snapshot := craft.to_dict()
	_expect_eq(int(snapshot["version"]), 1, "version del snapshot de recetas")
	_expect_eq((snapshot["recipes"] as Array).size(), 4, "cuatro recetas serializadas")
	var text := JSON.stringify(snapshot)
	var parsed = JSON.parse_string(text)
	_expect(parsed != null, "JSON de recetas valido")
	var restored := CraftScript.new(db)
	var loaded := restored.load_json(text)
	_expect(bool(loaded["ok"]), "load_json exitoso")
	_expect_eq(int(loaded["registered"]), 4, "cuatro recetas registradas desde JSON")
	_expect_array(restored.list(), craft.list(), "mismos ids tras round-trip")
	_expect_eq(restored.to_dict(), snapshot, "snapshot regenerado identico")
	_expect_eq(restored.get_recipe("sword_recipe"), craft.get_recipe("sword_recipe"), "receta compleja restaurada")
	var from_snapshot := CraftScript.new(db)
	_expect(bool(from_snapshot.load_snapshot(parsed)["ok"]), "load_snapshot desde JSON")
	_expect_eq(from_snapshot.to_dict(), snapshot, "load_snapshot round-trip exacto")
	var bad_version := snapshot.duplicate(true)
	bad_version["version"] = 99
	_expect(not bool(CraftScript.new(db).load_snapshot(bad_version)["ok"]), "version futura rechazada")
	_expect_array(CraftScript.new(db).list(), [], "instancias nuevas arrancan vacias")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _item(id: String, nombre: String, stackable: bool, max_stack: int, peso: float) -> Dictionary:
	return {
		"id": id,
		"nombre": nombre,
		"apilable": stackable,
		"max_stack": max_stack,
		"peso": peso,
	}


func _recipe(id: String, inputs: Dictionary, outputs: Dictionary, time: float, tags: Array) -> Dictionary:
	return {
		"id": id,
		"inputs": inputs,
		"outputs": outputs,
		"time": time,
		"station_tags": tags,
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
