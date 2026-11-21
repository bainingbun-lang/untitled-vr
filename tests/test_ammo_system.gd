extends SceneTree

# D (W4_weapons): sistema de municion - reservas por calibre, cajas y lookup
# de calibre por arma. Adapta refs/godot_weapon_manager (ammo_reserve) y
# refs/GodotWeapons (Ammo) al pipeline de contenido de este proyecto.

const AmmoSystemScript := preload("res://core/game/ammo_system.gd")

var ammo_system

var _checks: int = 0
var _failures: Array = []

func _initialize() -> void:
	await process_frame
	ammo_system = AmmoSystemScript.get_singleton()

	_run_test_ammo_data_loaded()
	_run_test_reserve_operations()
	_run_test_ammo_box_definitions()
	_run_test_caliber_lookup()
	_run_test_max_reserve_limits()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)

func _run_test_ammo_data_loaded() -> void:
	for ammo_id in ["9mm", "556", "762x39", "12g", "338lapua"]:
		_expect(ammo_system.has_ammo_type(ammo_id), "existe el tipo de municion '%s'" % ammo_id)

	var data_9mm = ammo_system.get_ammo_data("9mm")
	_expect(str(data_9mm.get("caliber", "")) == "9x19mm", "9mm tiene calibre 9x19mm")
	_expect(float(data_9mm.get("damage", 0.0)) > 0.0, "9mm tiene damage")
	_expect(not data_9mm.get("magazine_sizes", []).is_empty(), "9mm tiene magazine_sizes")
	_expect(not data_9mm.get("box_sizes", []).is_empty(), "9mm tiene box_sizes")
	_expect(float(data_9mm.get("price_per_round", 0.0)) > 0.0, "9mm tiene precio por bala")

	var data_12g = ammo_system.get_ammo_data("12g")
	_expect(str(data_12g.get("caliber", "")) == "12 Gauge", "12g tiene calibre 12 Gauge")
	_expect(int(data_12g.get("pellets", 0)) == 8, "12g tiene 8 perdigones")

func _run_test_reserve_operations() -> void:
	ammo_system.set_reserve("9mm", 0)
	_expect(ammo_system.get_reserve("9mm") == 0, "reserva inicial 0")

	_expect(ammo_system.add_reserve("9mm", 50) == 50, "anade 50 balas")
	_expect(ammo_system.get_reserve("9mm") == 50, "reserva 50 tras anadir")
	_expect(ammo_system.add_reserve("9mm", 30) == 30, "anade 30 balas mas")
	_expect(ammo_system.get_reserve("9mm") == 80, "reserva 80")

	_expect(ammo_system.remove_reserve("9mm", 20) == 20, "quita 20 balas")
	_expect(ammo_system.get_reserve("9mm") == 60, "reserva 60 tras quitar")

	_expect(ammo_system.can_afford("9mm", 50), "puede pagar 50 balas")
	_expect(not ammo_system.can_afford("9mm", 70), "no puede pagar 70 balas")

	_expect(ammo_system.remove_reserve("9mm", 999) == 60, "no quita mas de lo que hay")
	_expect(ammo_system.get_reserve("9mm") == 0, "reserva nunca negativa")
	_expect(ammo_system.add_reserve("tipo_inexistente", 10) == 0, "tipo desconocido devuelve 0")

func _run_test_ammo_box_definitions() -> void:
	var boxes_9mm = ammo_system.get_boxes_for_ammo_type("9mm")
	_expect(boxes_9mm.size() >= 3, "9mm tiene al menos 3 tamanos de caja")

	var box_def = ammo_system.get_box_definition("ammo_box_9mm_medium")
	_expect(not box_def.is_empty(), "existe la caja mediana de 9mm")
	_expect(str(box_def.get("ammo_type", "")) == "9mm", "la caja es de 9mm")
	_expect(int(box_def.get("rounds", 0)) == 50, "la caja mediana tiene 50 balas")
	_expect(str(box_def.get("model", "")) != "", "la caja tiene modelo")
	_expect(float(box_def.get("weight_kg", 0.0)) > 0.0, "la caja tiene peso")
	_expect(int(box_def.get("price", 0)) > 0, "la caja tiene precio")

	var pickup_data = ammo_system.create_ammo_box_pickup_data("ammo_box_9mm_medium")
	_expect(not pickup_data.is_empty(), "crea datos de pickup")
	_expect(str(pickup_data.get("type", "")) == "ammo_box", "tipo ammo_box")
	_expect(str(pickup_data.get("ammo_type", "")) == "9mm", "municion 9mm")
	_expect(int(pickup_data.get("rounds", 0)) == 50, "50 balas")
	_expect(str(pickup_data.get("caliber", "")) == "9x19mm", "calibre visible 9x19mm")

	var sizes_12g = []
	for box in ammo_system.get_boxes_for_ammo_type("12g"):
		sizes_12g.append(int(box.get("rounds", 0)))
	_expect(sizes_12g.has(10) and sizes_12g.has(25), "cajas de 12g: 10 y 25 balas")

func _run_test_caliber_lookup() -> void:
	_expect(ammo_system.get_caliber_for_weapon("pistol") == "9mm", "pistola usa 9mm")
	_expect(ammo_system.get_caliber_for_weapon("submachine_gun") == "9mm", "subfusil usa 9mm")
	_expect(ammo_system.get_caliber_for_weapon("assault_rifle") == "556", "rifle de asalto usa 5.56")
	_expect(ammo_system.get_caliber_for_weapon("shotgun") == "12g", "escopeta usa 12 gauge")
	_expect(ammo_system.get_caliber_for_weapon("sniper_rifle") == "762x51", "francotirador usa 7.62x51")
	_expect(ammo_system.get_caliber_for_weapon("bat").is_empty(), "el bate es cuerpo a cuerpo (sin calibre)")
	_expect(ammo_system.get_caliber_for_weapon("arma_inexistente").is_empty(), "arma desconocida no inventa calibre")

	_expect(ammo_system.get_caliber_name("9mm") == "9x19mm", "nombre de calibre 9x19mm")
	_expect(ammo_system.get_caliber_name("12g") == "12 Gauge", "nombre de calibre 12 Gauge")
	_expect(ammo_system.get_caliber_name("inexistente") == "inexistente", "calibre desconocido devuelve el id")

func _run_test_max_reserve_limits() -> void:
	var max_reserve = ammo_system.get_max_reserve("9mm")
	_expect(max_reserve > 0, "reserva maxima positiva")

	ammo_system.set_reserve("9mm", 0)
	var added = ammo_system.add_reserve("9mm", max_reserve + 100)
	_expect(added == max_reserve, "no se supera la reserva maxima")
	_expect(ammo_system.get_reserve("9mm") == max_reserve, "reserva clavada en el maximo")

	ammo_system.set_reserve("9mm", max(max_reserve + 500, 0))
	_expect(ammo_system.get_reserve("9mm") == max_reserve, "set_reserve tambien se limita")
	ammo_system.set_reserve("9mm", 0)