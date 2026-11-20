extends SceneTree

const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")
const VehicleDbScript = preload("res://core/game/vehicle_db.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const SurfaceScript = preload("res://core/game/surface_material.gd")

var _failed := false
var _assertions := 0


func _initialize() -> void:
	await process_frame
	var registry := ContentRegistryScript.reset()
	SurfaceScript.refresh()

	var base_weapons := WeaponDbScript.all()
	_expect(base_weapons.size() == 6, "el contenido base debe tener 6 armas")
	_expect(
		WeaponDbScript.list_ids() == [
			"assault_rifle", "bat", "pistol", "shotgun", "sniper_rifle", "submachine_gun"
		],
		"list_ids debe conservar el orden alfabetico actual"
	)
	_expect(
		float(base_weapons["pistol"].get("damage", -1.0)) == 24.0
		and float(base_weapons["pistol"].get("fire_rate", -1.0)) == 6.0
		and float(base_weapons["pistol"].get("spread", -1.0)) == 1.2
		and int(base_weapons["pistol"].get("mag", -1)) == 12,
		"la pistola base debe conservar sus valores"
	)
	_expect(
		int(base_weapons["shotgun"].get("pellets", -1)) == 8
		and float(base_weapons["shotgun"].get("penetration", -1.0)) == 0.25,
		"la escopeta base debe conservar balistica y perdigones"
	)
	_expect(
		bool(base_weapons["bat"].get("uses_ammo", true)) == false
		and float(base_weapons["bat"].get("range", -1.0)) == 2.4,
		"el bate base no debe consumir munición"
	)
	var expected_keys := [
		"name", "damage", "fire_rate", "range", "mag", "auto", "spread", "pellets", "tags",
		"reload_time", "weight", "impulse", "uses_ammo", "penetration", "falloff_start",
		"falloff_end", "falloff_min", "projectile_speed", "projectile_gravity",
		"projectile_min_distance", "impact_speed", "effect_scale", "max_penetrations",
		"max_ricochets", "id",
	]
	var keys: Array = (base_weapons["pistol"] as Dictionary).keys()
	keys.sort()
	expected_keys.sort()
	_expect(keys == expected_keys, "WeaponDb.all no debe exponer metadatos del registro")

	_expect(VehicleDbScript.list_ids().size() == 7, "deben existir 7 vehiculos base")
	_expect(
		str(VehicleDbScript.get_def("sedan").get("model_path", "")) == "res://assets/models/vehicles/sedan.glb",
		"VehicleDb debe seguir construyendo model_path"
	)
	_expect(SurfaceScript.IDS.size() == 7, "deben existir 7 superficies base")
	_expect(
		SurfaceScript.type_from("hormigon") == SurfaceScript.Type.CONCRETE
		and SurfaceScript.type_from("acero") == SurfaceScript.Type.METAL,
		"los alias de superficies deben conservarse"
	)
	_expect(
		is_equal_approx(SurfaceScript.penetration_of(SurfaceScript.Type.GLASS), 0.80),
		"la balistica de superficies debe venir de JSON"
	)

	var invalid := registry.validate(
		"weapon", {
			"type": "weapon", "id": "test.mod:malo", "name": "Malo", "damage": "mucho",
		}, "test.mod"
	)
	_expect(not bool(invalid.get("ok", true)), "la validacion debe rechazar campos invalidos")
	_expect(not invalid.get("errors", []).is_empty(), "la validacion debe informar errores")
	var wrong_owner := registry.validate(
		"weapon", _weapon("test.otro:arma"), "test.mod"
	)
	_expect(not bool(wrong_owner.get("ok", true)), "un mod no debe registrar ids de otro mod")

	var bad := registry.load_mod("test.bad", "res://tests/fixtures/content_bad")
	_expect(not bool(bad.get("ok", true)), "un modulo con contenido invalido debe marcar error")
	_expect(int(bad.get("registered", 0)) == 1, "solo la entrada valida del modulo se registra")
	_expect(WeaponDbScript.all().has("bueno"), "la entrada valida del modulo queda disponible")
	_expect(not WeaponDbScript.all().has("roto"), "la entrada invalida del modulo se descarta")
	_expect(WeaponDbScript.all().has("pistol"), "el contenido base no se ve afectado por modulos invalidos")

	var override := _weapon("test.override:pistol", 99.0)
	override["replaces"] = "untitled.base:pistol"
	registry.set_mod("test.override", {"weapon": {"test.override:pistol": override}}, 200)
	_expect(
		float(WeaponDbScript.get_def("pistol").get("damage", -1.0)) == 99.0,
		"un reemplazo explicito con mayor prioridad debe aplicarse"
	)
	_expect(
		str(registry.owner_of("weapon", "pistol")) == "test.override",
		"el registro debe informar el dueno del contenido efectivo"
	)
	_expect(registry.unload_mod("test.override"), "la descarga del modulo debe tener exito")
	_expect(
		float(WeaponDbScript.get_def("pistol").get("damage", -1.0)) == 24.0,
		"descargar el modulo debe restaurar el contenido base"
	)

	var items := ItemDbScript.new()
	var loaded_items := items.load_content()
	_expect(int(loaded_items.get("registered", 0)) == 6, "los items base deben cargarse desde datos")
	_expect(items.has("pistol"), "el id publico base debe seguir funcionando")
	_expect(
		str(items.get_def("shotgun").get("nombre", "")) == "Escopeta",
		"los items base conservan sus nombres"
	)

	registry.unload_mod("test.bad")
	ContentRegistryScript.reset()
	SurfaceScript.refresh()
	if _failed:
		print("FAIL")
		quit(1)
	else:
		print("PASS (%d assertions)" % _assertions)
		quit(0)


func _weapon(id: String, damage: float = 20.0) -> Dictionary:
	return {
		"id": id,
		"name": "Arma de prueba",
		"damage": damage,
		"fire_rate": 5.0,
		"range": 50.0,
		"mag": 10,
		"auto": false,
		"spread": 1.0,
		"pellets": 1,
		"tags": ["test"],
		"reload_time": 1.0,
		"weight": 1.0,
		"impulse": 0.05,
		"uses_ammo": true,
		"penetration": 0.5,
		"falloff_start": 10.0,
		"falloff_end": 50.0,
		"falloff_min": 0.4,
		"projectile_speed": 0.0,
		"projectile_gravity": 0.0,
		"projectile_min_distance": 30.0,
		"impact_speed": 100.0,
		"effect_scale": 1.0,
		"max_penetrations": 1,
		"max_ricochets": 0,
	}


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		printerr("FAIL: %s" % label)
