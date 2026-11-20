extends SceneTree

const DbScript = preload("res://core/game/item_db.gd")
const InvScript = preload("res://core/game/inventory.gd")

var _failures: Array = []
var _checks := 0
var _case := ""


func _init() -> void:
	_case = "definiciones y validacion"
	var db = DbScript.new()
	_expect(db.register(_item("potion", "Pocion", true, 5, 1.0, ["consumable", "magic"])), "registrar pocion")
	_expect(db.register(_item("rock", "Roca", false, 1, 3.0, ["material"])), "registrar roca")
	_expect(db.register(_item("coin", "Moneda", true, 100, 0.0, ["currency"])), "registrar moneda")
	_expect(db.has("potion"), "has(potion)")
	_expect_eq(str(db.get_def("potion")["nombre"]), "Pocion", "nombre normalizado")
	_expect_eq(int(db.get_def("potion")["max_stack"]), 5, "max_stack normalizado")
	_expect_array(db.list(), ["coin", "potion", "rock"], "list ordenado")
	_expect(not db.register({}), "definicion sin id rechazada")
	_expect(not db.register({"id": "bad", "nombre": ""}), "nombre ausente rechazado")
	_expect(not db.register({"id": "bad", "nombre": "Mal", "peso": -1.0}), "peso negativo rechazado")
	_expect(not db.register({"id": "bad", "nombre": "Mal", "max_stack": 0}), "max_stack 0 rechazado")
	_expect(not db.register({"id": "bad", "nombre": "Mal", "tags": {}}), "tags no Array rechazados")
	_expect(not db.register({"id": "Bad ID", "nombre": "Mal"}), "id con mayusculas/espacio rechazado")
	_expect(not db.has("bad"), "ninguna definición invalida se registra")
	var editable = db.get_def("potion")
	editable["nombre"] = "Modificada"
	_expect_eq(str(db.get_def("potion")["nombre"]), "Pocion", "get_def devuelve copia")
	_expect(db.get_def("ghost").is_empty(), "definicion desconocida vacia")

	_case = "definiciones desde JSON"
	var json_db = DbScript.new()
	var json_text := '{"items":[{"id":"j_potion","nombre":"Pocion JSON","apilable":true,"max_stack":10,"peso":0.5,"tags":["json"]},{"id":"j_rock","nombre":"Roca JSON","peso":2}]}'
	var loaded = json_db.load_json(json_text)
	_expect(bool(loaded["ok"]), "load_json valido")
	_expect_eq(int(loaded["registered"]), 2, "load_json registra dos items")
	_expect(json_db.has("j_potion") and json_db.has("j_rock"), "items JSON disponibles")
	_expect_eq(float(json_db.get_def("j_rock")["peso"]), 2.0, "peso por defecto aceptado desde JSON")
	_expect_eq(int(json_db.get_def("j_rock")["max_stack"]), 1, "no apilable implica max_stack 1")
	_expect(not bool(json_db.load_json("null")["ok"]), "JSON sin definiciones rechazado")
	_expect(not bool(json_db.load_json("5")["ok"]), "JSON de tipo invalido rechazado")

	_case = "item desconocido"
	var unknown_inv = InvScript.new(db, 6, -1.0)
	var unknown_before = unknown_inv.to_dict()
	var unknown_result = unknown_inv.add("ghost", 3)
	_expect(not bool(unknown_result["ok"]), "add de item desconocido falla")
	_expect_eq(int(unknown_result["added"]), 0, "no se agrega nada desconocido")
	_expect_eq(int(unknown_result["rejected"]), 3, "se informa el rechazo")
	_expect(_mentions(str(unknown_result["reason"]), "desconocido"), "motivo desconocido")
	_expect_eq(unknown_inv.to_dict(), unknown_before, "inventario intacto tras item desconocido")
	_expect_eq(unknown_inv.total_weight(), 0.0, "peso intacto tras item desconocido")
	_expect(not bool(unknown_inv.can_add("ghost", 1)["ok"]), "can_add rechaza desconocido")
	_expect_eq(int(unknown_inv.remove("ghost", 1)["removed"]), 0, "remove desconocido no quita nada")

	_case = "apilado"
	var stack_inv = InvScript.new(db, 10, -1.0)
	var stack_result = stack_inv.add("potion", 3)
	_expect(bool(stack_result["ok"]) and int(stack_result["added"]) == 3, "agregar 3 pociones")
	_expect_eq(stack_inv.used_slots(), 1, "3 pociones caben en un slot")
	_expect_eq(stack_inv.count("potion"), 3, "contar 3 pociones")
	stack_result = stack_inv.add("potion", 4)
	_expect(bool(stack_result["ok"]), "agregar 4 pociones mas")
	_expect_eq(stack_inv.count("potion"), 7, "total 7 pociones")
	_expect_eq(stack_inv.used_slots(), 2, "7 pociones usan dos stacks")
	var potion_slots := _slots_for(stack_inv, "potion")
	_expect_array(potion_slots, [5, 2], "stacks lleno y parcial")
	_expect_eq(stack_inv.total_weight(), 7.0, "peso de 7 pociones")
	var coin_result = stack_inv.add("coin", 250)
	_expect(bool(coin_result["ok"]), "agregar 250 monedas")
	_expect_eq(stack_inv.count("coin"), 250, "contar monedas")
	_expect_array(_slots_for(stack_inv, "coin"), [100, 100, 50], "monedas se reparten en stacks de 100")
	var rock_result = stack_inv.add("rock", 2)
	_expect(bool(rock_result["ok"]), "agregar 2 rocas")
	_expect_array(_slots_for(stack_inv, "rock"), [1, 1], "rocas no apilables ocupan slots distintos")
	_expect_eq(stack_inv.used_slots(), 7, "slots ocupados totales")
	_expect_eq(stack_inv.total_weight(), 13.0, "peso total 7 + 6")

	_case = "overflow de slots"
	var slot_inv = InvScript.new(db, 2, -1.0)
	var overflow = slot_inv.add("rock", 3)
	_expect(not bool(overflow["ok"]), "exceso de rocas rechazado")
	_expect_eq(int(overflow["added"]), 2, "se agrega lo que cabe")
	_expect_eq(int(overflow["rejected"]), 1, "se informa el exceso")
	_expect(_mentions(str(overflow["reason"]), "slots"), "motivo sin slots")
	_expect_eq(slot_inv.used_slots(), 2, "inventario lleno")
	_expect_eq(slot_inv.total_weight(), 6.0, "peso de las rocas aceptadas")
	var slot_check = slot_inv.can_add("rock", 1)
	_expect(not bool(slot_check["ok"]), "can_add detecta lleno")
	_expect_eq(int(slot_check["added"]), 0, "can_add no agrega")
	_expect_eq(slot_inv.used_slots(), 2, "can_add no muta")
	var no_slot = slot_inv.add("potion", 1)
	_expect(not bool(no_slot["ok"]), "pocion no cabe en inventario lleno")
	_expect_eq(int(no_slot["added"]), 0, "nada agregado")
	_expect_eq(slot_inv.count("potion"), 0, "sin pociones")
	_expect(bool(slot_inv.remove("rock", 1)["ok"]), "liberar un slot")
	_expect_eq(slot_inv.used_slots(), 1, "un slot libre")
	_expect(bool(slot_inv.add("potion", 1)["ok"]), "pocion cabe tras liberar slot")

	_case = "capacidad por peso"
	var weight_inv = InvScript.new(db, 10, 6.0)
	var weight_result = weight_inv.add("rock", 2)
	_expect(bool(weight_result["ok"]), "dos rocas caben en 6.0")
	_expect_eq(weight_inv.total_weight(), 6.0, "peso en el limite")
	weight_result = weight_inv.add("rock", 1)
	_expect(not bool(weight_result["ok"]), "tercera roca excede peso")
	_expect_eq(int(weight_result["added"]), 0, "tercera roca no se agrega")
	_expect(_mentions(str(weight_result["reason"]), "peso"), "motivo peso excedido")
	weight_result = weight_inv.add("potion", 1)
	_expect(not bool(weight_result["ok"]), "pocion tambien excede peso")
	_expect_eq(weight_inv.total_weight(), 6.0, "peso no cambia")
	_expect(bool(weight_inv.remove("rock", 1)["ok"]), "quitar una roca")
	_expect_eq(weight_inv.total_weight(), 3.0, "peso baja a 3.0")
	_expect(bool(weight_inv.add("potion", 2)["ok"]), "dos pociones caben")
	_expect_eq(weight_inv.total_weight(), 5.0, "peso 5.0")
	weight_result = weight_inv.add("potion", 2)
	_expect(not bool(weight_result["ok"]), "solo cabe una pocion mas")
	_expect_eq(int(weight_result["added"]), 1, "agregado parcial por peso")
	_expect_eq(int(weight_result["rejected"]), 1, "exceso por peso informado")
	_expect_eq(weight_inv.total_weight(), 6.0, "peso en el limite otra vez")
	_expect_eq(weight_inv.count("potion"), 3, "tres pociones en total")

	_case = "extraccion"
	var remove_inv = InvScript.new(db, 10, -1.0)
	remove_inv.add("potion", 7)
	var removed = remove_inv.remove("potion", 6)
	_expect(bool(removed["ok"]), "extraer 6 pociones")
	_expect_eq(int(removed["removed"]), 6, "extraidas 6")
	_expect_eq(remove_inv.count("potion"), 1, "queda 1 pocion")
	_expect_eq(remove_inv.used_slots(), 1, "un stack restante")
	removed = remove_inv.remove("potion", 5)
	_expect(not bool(removed["ok"]), "pedir 5 cuando queda 1 falla")
	_expect_eq(int(removed["removed"]), 1, "extrae lo disponible")
	_expect_eq(int(removed["rejected"]), 4, "informa faltante")
	_expect_eq(remove_inv.count("potion"), 0, "sin pociones")
	_expect_eq(remove_inv.used_slots(), 0, "sin slots ocupados")
	_expect_eq(remove_inv.total_weight(), 0.0, "peso cero")
	_expect_eq(int(remove_inv.remove("potion", 0)["removed"]), 0, "cantidad 0 no extrae")

	_case = "transferencia atomica"
	var src = InvScript.new(db, 8, -1.0)
	var dst = InvScript.new(db, 2, 3.0)
	src.add("rock", 2)
	dst.add("rock", 1)
	var src_before = src.to_dict()
	var dst_before = dst.to_dict()
	var transfer = src.transfer(dst, "rock", 1)
	_expect(not bool(transfer["ok"]), "destino sin peso rechaza transferencia")
	_expect(_mentions(str(transfer["reason"]), "destino"), "motivo destino")
	_expect_eq(src.to_dict(), src_before, "origen intacto al fallar")
	_expect_eq(dst.to_dict(), dst_before, "destino intacto al fallar")
	transfer = src.transfer(dst, "potion", 99)
	_expect(not bool(transfer["ok"]), "origen insuficiente rechaza transferencia")
	_expect(_mentions(str(transfer["reason"]), "origen"), "motivo origen")
	_expect_eq(src.to_dict(), src_before, "origen intacto por falta de stock")
	_expect_eq(dst.to_dict(), dst_before, "destino intacto por falta de stock")
	transfer = src.transfer(null, "rock", 1)
	_expect(not bool(transfer["ok"]), "destino nulo rechazado")
	_expect_eq(src.to_dict(), src_before, "origen intacto con destino nulo")
	transfer = src.transfer(src, "rock", 1)
	_expect(not bool(transfer["ok"]), "transferencia a si mismo rechazada")
	_expect_eq(src.to_dict(), src_before, "origen intacto en autotransferencia")

	var rich = InvScript.new(db, 8, -1.0)
	var empty = InvScript.new(db, 8, 10.0)
	rich.add("potion", 7)
	transfer = rich.transfer(empty, "potion", 7)
	_expect(bool(transfer["ok"]), "transferencia exitosa")
	_expect_eq(int(transfer["transferred"]), 7, "transferidas 7")
	_expect_eq(rich.count("potion"), 0, "origen vacio")
	_expect_eq(empty.count("potion"), 7, "destino con 7")
	_expect_eq(rich.total_weight() + empty.total_weight(), 7.0, "peso conservado")
	transfer = empty.transfer(rich, "potion", 3)
	_expect(bool(transfer["ok"]), "transferencia parcial exitosa")
	_expect_eq(empty.count("potion"), 4, "destino parcial queda con 4")
	_expect_eq(rich.count("potion"), 3, "origen recibe 3")

	_case = "serializacion y restauracion exacta"
	var saved = InvScript.new(db, 8, -1.0)
	saved.add("potion", 7)
	saved.add("coin", 250)
	saved.add("rock", 2)
	saved.remove("potion", 5)
	var snapshot = saved.to_dict()
	_expect_eq(int(snapshot["version"]), 1, "version del snapshot")
	_expect_eq(int(snapshot["slot_capacity"]), 8, "capacidad serializada")
	_expect_eq((snapshot["slots"] as Array).size(), 8, "todos los slots serializados")
	_expect((snapshot["slots"] as Array)[0].is_empty(), "slot vacio se conserva")
	_expect_eq(int((snapshot["slots"] as Array)[1]["count"]), 2, "stack parcial se conserva")

	var restored = InvScript.new(db, 1, 100.0)
	_expect(restored.restore(snapshot), "restaurar snapshot")
	_expect_eq(restored.to_dict(), snapshot, "snapshot regenerado identico")
	_expect_eq(restored.slots(), saved.slots(), "slots identicos")
	_expect_eq(restored.slot_capacity(), 8, "capacidad restaurada")
	_expect_eq(restored.max_weight(), -1.0, "limite de peso restaurado")
	_expect_eq(restored.total_weight(), saved.total_weight(), "peso restaurado")
	_expect_eq(restored.count("coin"), 250, "contenido restaurado")

	var text = JSON.stringify(snapshot)
	var parsed = JSON.parse_string(text)
	_expect(parsed != null, "JSON del snapshot valido")
	var from_json = InvScript.new(db)
	_expect(from_json.restore(parsed), "restaurar desde JSON")
	_expect_eq(from_json.to_dict(), snapshot, "round-trip JSON exacto")

	var restored_before = restored.to_dict()
	var bad_unknown = snapshot.duplicate(true)
	bad_unknown["slots"][1] = {"id": "ghost", "count": 2}
	_expect(not restored.restore(bad_unknown), "snapshot con id desconocido rechazado")
	_expect_eq(restored.to_dict(), restored_before, "restore fallido no muta")

	var bad_count = snapshot.duplicate(true)
	bad_count["slots"][1] = {"id": "potion", "count": 99}
	_expect(not restored.restore(bad_count), "snapshot con exceso de stack rechazado")
	_expect_eq(restored.to_dict(), restored_before, "restore invalido no muta")

	var bad_size = snapshot.duplicate(true)
	bad_size["slots"] = []
	_expect(not restored.restore(bad_size), "snapshot con tamano incorrecto rechazado")
	_expect_eq(restored.to_dict(), restored_before, "restore con tamano invalido no muta")

	var bad_version = snapshot.duplicate(true)
	bad_version["version"] = 99
	_expect(not restored.restore(bad_version), "version futura rechazada")
	_expect_eq(restored.to_dict(), restored_before, "restore con version invalida no muta")

	var heavy = InvScript.new(db, 2, 3.0)
	heavy.add("rock", 1)
	var heavy_before = heavy.to_dict()
	var heavy_bad = heavy_before.duplicate(true)
	heavy_bad["slots"][1] = {"id": "rock", "count": 1}
	_expect(not heavy.restore(heavy_bad), "snapshot que excede peso rechazado")
	_expect_eq(heavy.to_dict(), heavy_before, "restore con exceso de peso no muta")
	_expect(_mentions(str(restored.get_log()), "desconocido"), "error de restore registrado")

	_case = "extension de mods e ids duplicados"
	var mod_db = DbScript.new()
	var mod_item := _item("mod_sword", "Espada del mod", false, 1, 2.0, ["weapon", "mod"])
	_expect(mod_db.register(mod_item), "mod registra item nuevo")
	_expect(not mod_db.register(mod_item.duplicate(true)), "id duplicado rechazado")
	_expect(_mentions(str(mod_db.get_log()), "duplicado"), "error de duplicado registrado")
	_expect(mod_db.has("mod_sword"), "item del mod sigue disponible")
	var colliding := _item("mod_sword", "Otra espada", true, 9, 1.0, [])
	_expect(not mod_db.register(colliding), "mismo id con otros datos rechazado")
	_expect_eq(str(mod_db.get_def("mod_sword")["nombre"]), "Espada del mod", "definicion original intacta")
	_expect_eq(mod_db.list().size(), 1, "no se duplica la definicion")

	var batch_db = DbScript.new()
	var batch := '{"items":[{"id":"a","nombre":"A","peso":1},{"id":"a","nombre":"B","peso":2}]}'
	var batch_result = batch_db.load_json(batch)
	_expect(not bool(batch_result["ok"]), "lote con duplicado no es ok")
	_expect_eq(int(batch_result["registered"]), 1, "solo se registra el primero")
	_expect_eq(str(batch_db.get_def("a")["nombre"]), "A", "primera definicion prevalece")

	var mod_inv = InvScript.new(mod_db, 4, -1.0)
	_expect(bool(mod_inv.add("mod_sword", 1)["ok"]), "item del mod se puede agregar")
	_expect_eq(mod_inv.count("mod_sword"), 1, "item del mod contado")
	_expect_eq(mod_inv.total_weight(), 2.0, "peso del item del mod")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _item(id: String, nombre: String, stackable: bool, max_stack: int, peso: float, tags: Array = []) -> Dictionary:
	return {
		"id": id,
		"nombre": nombre,
		"apilable": stackable,
		"max_stack": max_stack,
		"peso": peso,
		"tags": tags,
	}


func _slots_for(inv, id: String) -> Array:
	var amounts: Array = []
	for slot in inv.slots():
		if not slot.is_empty() and str(slot["id"]) == id:
			amounts.append(int(slot["count"]))
	return amounts


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
