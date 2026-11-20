extends SceneTree

const ItemDbScript = preload("res://core/game/item_db.gd")
const InvScript = preload("res://core/game/inventory.gd")
const LoadoutScript = preload("res://core/game/loadout.gd")
const VrBagScript = preload("res://core/vr/vr_bag.gd")
const HotbarScene = preload("res://scenes/ui/hotbar.tscn")
const WEAPON_DB_PATH := "res://core/game/weapon_db.gd"
const FALLBACK_WEAPONS := ["assault_rifle", "bat", "pistol"]

var _checks := 0
var _failures: Array = []
var _case := ""


func _initialize() -> void:
	await process_frame

	_case = "kit completo en inventario"
	var db = _make_db()
	var expected := _expected_weapons()
	var inv = InvScript.new(db, 16, -1.0)
	_expect(bool(inv.add("medkit", 2)["ok"]), "item no arma previo en inventario")
	var kit = LoadoutScript.give_starting_kit(inv, db)
	_expect(bool(kit["ok"]), "kit entregado sin errores")
	var given: Array = (kit["given"] as Array).duplicate()
	given.sort()
	_expect_eq(given, expected, "todas las armas entregadas")
	for id in expected:
		_expect_eq(inv.count(str(id)), 1, "arma en inventario: %s" % str(id))
	_expect_eq(inv.count("medkit"), 2, "items previos conservados")
	_expect_eq(inv.used_slots(), expected.size() + 1, "una ranura por arma mas el item previo")
	var repeated = LoadoutScript.give_starting_kit(inv, db)
	_expect(bool(repeated["ok"]), "kit repetido sigue siendo valido")
	_expect_eq((repeated["already_owned"] as Array).size(), expected.size(), "armas ya presentes informadas")
	_expect_eq(inv.used_slots(), expected.size() + 1, "kit repetido no duplica")
	_expect_eq((repeated["missing"] as Array).size(), 0, "sin faltantes al repetir")
	_expect((kit["reasons"] as Dictionary).is_empty(), "sin motivos de error con capacidad")
	var fresh_db = ItemDbScript.new()
	var fresh_inv = InvScript.new(fresh_db, 16, -1.0)
	var fresh_kit = LoadoutScript.give_starting_kit(fresh_inv, fresh_db)
	_expect(bool(fresh_kit["ok"]), "kit registra armas en base vacia")
	var fresh_given: Array = (fresh_kit["given"] as Array).duplicate()
	fresh_given.sort()
	_expect_eq(fresh_given, expected, "todas las armas disponibles sin registro previo")

	_case = "inventario lleno y parcial"
	var full_inv = InvScript.new(db, 1, -1.0)
	_expect(bool(full_inv.add("medkit", 1)["ok"]), "inventario lleno con item no arma")
	var full = LoadoutScript.give_starting_kit(full_inv, db)
	_expect(not bool(full["ok"]), "inventario lleno reporta fallo")
	_expect((full["given"] as Array).is_empty(), "ningun arma entregada sin espacio")
	_expect_eq((full["missing"] as Array).size(), expected.size(), "todas las armas faltan")
	_expect(not (full["reasons"] as Dictionary).is_empty(), "motivos de falta de capacidad informados")
	_expect_eq(full_inv.used_slots(), 1, "inventario lleno intacto")
	_expect_eq(full_inv.count("medkit"), 1, "contenido previo intacto")
	var partial_inv = InvScript.new(db, 2, -1.0)
	var partial = LoadoutScript.give_starting_kit(partial_inv, db)
	_expect(not bool(partial["ok"]), "entrega parcial no es ok")
	_expect_eq((partial["given"] as Array).size(), 2, "entregan dos armas")
	_expect_eq((partial["missing"] as Array).size(), expected.size() - 2, "informa el resto")
	_expect_eq(partial_inv.used_slots(), 2, "capacidad maxima respetada")
	_expect(not bool(LoadoutScript.give_starting_kit(null, db)["ok"]), "inventario nulo controlado")
	_expect(not bool(LoadoutScript.give_starting_kit(partial_inv, null)["ok"]), "base nula controlada")

	_case = "hotbar y seleccion"
	var hotbar = HotbarScene.instantiate()
	root.add_child(hotbar)
	await process_frame
	hotbar.setup(inv, db)
	await process_frame
	var buttons: Array = hotbar.call("slot_buttons")
	_expect_eq(buttons.size(), expected.size(), "una ranura por arma en la hotbar")
	_expect(hotbar.get_node_or_null("Slots") != null, "contenedor de ranuras construido")
	var first_button: Control = buttons[0] as Control
	_expect(first_button != null and first_button.custom_minimum_size.x >= 96.0, "ranura apta para tactil")
	var seen: Array = []
	hotbar.selected.connect(func(item_id: String) -> void: seen.append(item_id))
	hotbar.call("select", 1)
	_expect_eq(seen.size(), 1, "senal selected emitida al seleccionar")
	_expect_eq(str(seen[0]), str(expected[1]), "id del arma seleccionada por indice")
	_expect_eq(str(hotbar.call("current_id")), str(expected[1]), "indice actual coherente")
	hotbar.call("select", 999)
	_expect_eq(seen.size(), 1, "indice fuera de rango no emite")
	_expect(hotbar.call("select_id", str(expected[0])), "seleccion por id")
	_expect_eq(str(seen[seen.size() - 1]), str(expected[0]), "senal por id coherente")
	var number := InputEventKey.new()
	number.keycode = KEY_3
	number.pressed = true
	hotbar.call("handle_input", number)
	_expect_eq(str(seen[seen.size() - 1]), str(expected[2]), "tecla numerica selecciona")
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	hotbar.call("handle_input", wheel_down)
	_expect_eq(int(hotbar.call("current_index")), 3, "rueda abajo avanza")
	var wheel_up := InputEventMouseButton.new()
	wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel_up.pressed = true
	hotbar.call("handle_input", wheel_up)
	_expect_eq(int(hotbar.call("current_index")), 2, "rueda arriba retrocede")
	var target_button: Control = buttons[1] as Control
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = target_button.get_global_rect().get_center()
	touch.pressed = true
	hotbar.call("handle_input", touch)
	_expect_eq(int(hotbar.call("current_index")), 1, "toque selecciona la ranura")
	hotbar.queue_free()
	await process_frame

	_case = "bolso VR abre solo en su zona"
	var bag = VrBagScript.new(expected)
	bag.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)
	var center := bag.bag_center()
	_expect(center.z > 0.0, "bolso detras de la cabeza")
	_expect(center.x > 0.0, "bolso junto al hombro")
	_expect(center.y < 1.6, "bolso a la altura de la cadera")
	_expect(bag.is_in_bag_zone(center), "centro del bolso dentro de la zona")
	_expect(bag.open(center), "abre con la mano en la zona")
	_expect(bag.is_open(), "estado abierto")
	_expect(not bag.open(Vector3(0.0, 1.6, 0.0)), "no abre con la mano en la cabeza")
	_expect(not bag.is_open(), "mano fuera de zona cierra el bolso")
	_expect(bag.open(center), "vuelve a abrir al entrar en la zona")
	bag.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.RIGHT)
	var rotated := bag.bag_center()
	_expect(rotated.x < -0.3, "zona sigue la orientacion de la cabeza")
	_expect(not bag.open(center), "zona anterior deja de servir")
	_expect(bag.open(rotated), "nueva zona abre correctamente")
	bag.close()
	_expect(not bag.is_open(), "cerrar funciona")

	_case = "take y stow"
	var bag2 = VrBagScript.new(expected)
	bag2.set_head_pose(Vector3(0.0, 1.6, 0.0), Vector3.FORWARD)
	var center2 := bag2.bag_center()
	var first_id := str(expected[0])
	_expect(not bag2.take(first_id), "bolso cerrado impide sacar")
	_expect(bag2.open(center2), "bolso abierto para take")
	_expect(bag2.take(first_id), "take saca el arma al bolso")
	_expect(not bag2.items().has(first_id), "arma sale de la lista del bolso")
	_expect_eq(bag2.held_in("right"), first_id, "arma en la mano derecha por defecto")
	_expect(bag2.has_item(first_id), "arma empunada sigue disponible")
	_expect(not bag2.take(first_id), "no se puede sacar dos veces la misma arma")
	_expect(not bag2.take("ghost"), "id desconocido rechazado")
	bag2.stow()
	_expect_eq(bag2.held_in("right"), "", "mano libre tras stow")
	_expect(bag2.items().has(first_id), "arma guardada de vuelta")
	bag2.stow()
	_expect_eq(bag2.items().size(), expected.size(), "stow sin arma no duplica")
	bag2.close()
	_expect(not bag2.take(first_id), "bolso cerrado vuelve a impedir take")

	_case = "doble arma en la misma mano"
	var bag3 = VrBagScript.new(expected)
	bag3.open(bag3.bag_center())
	var gun_a := str(expected[0])
	var gun_b := str(expected[1])
	var gun_c := str(expected[2])
	_expect(bag3.take(gun_a, "right"), "primera arma en mano derecha")
	_expect(not bag3.take(gun_b, "right"), "segunda arma rechazada en la misma mano")
	_expect_eq(bag3.held_in("right"), gun_a, "mano derecha conserva su arma")
	_expect(bag3.take(gun_b, "left"), "otra mano puede sacar otra arma")
	_expect(not bag3.take(gun_a, "left"), "misma arma no se duplica entre manos")
	_expect_eq(bag3.items().size(), expected.size() - 2, "dos armas fuera del bolso")
	bag3.stow("right")
	_expect_eq(bag3.held_in("right"), "", "mano derecha liberada")
	_expect(bag3.items().has(gun_a), "arma derecha guardada")
	_expect(bag3.take(gun_c, "right"), "mano liberada puede sacar otra arma")
	_expect_eq(bag3.held_in("right"), gun_c, "nueva arma en mano derecha")
	bag3.stow("left")
	_expect_eq(bag3.held_in("left"), "", "mano izquierda liberada")
	_expect_eq(bag3.items().size(), expected.size() - 1, "solo queda un arma empunada")

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _make_db():
	var db = ItemDbScript.new()
	var weapons = _weapon_db()
	if weapons != null and weapons.has_method("register_items"):
		weapons.register_items(db)
	else:
		for id in FALLBACK_WEAPONS:
			_expect(db.register(_item(id, id, false, 1, 1.0, ["weapon"])), "arma de prueba registrada")
	_expect(db.register(_item("medkit", "Botiquin", true, 5, 0.5, ["consumable"])), "item no arma registrado")
	return db


func _weapon_db():
	if ResourceLoader.exists(WEAPON_DB_PATH):
		return load(WEAPON_DB_PATH)
	return null


func _expected_weapons() -> Array:
	var ids: Array = []
	var weapons = _weapon_db()
	if weapons != null and weapons.has_method("list_ids"):
		ids = (weapons.call("list_ids") as Array).duplicate()
	else:
		ids = FALLBACK_WEAPONS.duplicate()
	ids.sort()
	return ids


func _item(id: String, nombre: String, stackable: bool, max_stack: int, peso: float, tags: Array) -> Dictionary:
	return {
		"id": id,
		"nombre": nombre,
		"apilable": stackable,
		"max_stack": max_stack,
		"peso": peso,
		"tags": tags,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])
