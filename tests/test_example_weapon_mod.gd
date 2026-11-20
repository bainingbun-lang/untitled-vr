extends SceneTree

const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModReloaderScript = preload("res://core/mod_reloader.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const WeaponDbScript = preload("res://core/game/weapon_db.gd")
const ItemDbScript = preload("res://core/game/item_db.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")

const MOD_ID := "untitled.example-weapon"
const MOD_DIR := "res://mods/example.weapon"
const WEAPON_ID := "rust_pistol"

var _failed := false
var _assertions := 0


func _initialize() -> void:
	await process_frame
	var registry := ContentRegistryScript.reset()
	var bus := EventBusScript.new()
	var loader := ModLoaderScript.new(bus)
	var mod_registry = loader.get_registry()

	var data: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(MOD_DIR.path_join("mod.json"))
	)
	_expect(typeof(data) == TYPE_DICTIONARY, "el manifiesto del mod debe ser JSON valido")
	var validation: Dictionary = loader.validate(data)
	_expect(bool(validation.get("ok", false)), "el manifiesto del mod debe ser valido")

	var loaded: Dictionary = mod_registry.load_all([
		{"manifest": validation.get("manifest", {}), "dir": MOD_DIR},
	])
	_expect(mod_registry.is_loaded(MOD_ID), "el mod de ejemplo debe cargarse por el ModRegistry")
	_expect(bool(loaded.get("ok", false)), "la carga del mod no debe reportar errores")

	var def: Dictionary = WeaponDbScript.get_def(WEAPON_ID)
	_expect(not def.is_empty(), "el arma del mod debe estar en WeaponDb")
	_expect(str(def.get("id", "")) == WEAPON_ID, "el id publico debe conservarse sin namespace")
	_expect(
		str(def.get("model", "")) == "res://assets/models/weapons/v2/rust_pistol.gltf",
		"el arma debe apuntar al modelo descargado e importado"
	)
	_expect(
		FileAccess.file_exists(str(def.get("model", "")) + ".import"),
		"el modelo del arma debe tener un .import generado por Godot"
	)
	_expect(
		float(def.get("damage", -1.0)) == 22.0
		and int(def.get("mag", -1)) == 10
		and bool(def.get("uses_ammo", false)),
		"el arma del mod debe conservar sus datos"
	)
	_expect(
		float(def.get("penetration", -1.0)) == 0.32
		and float(def.get("projectile_speed", -1.0)) == 0.0,
		"el arma del mod debe usar balistica normal"
	)
	_expect(
		int(def.get("max_penetrations", -1)) == 1
		and int(def.get("max_ricochets", -1)) == 1,
		"el arma del mod debe declarar limites de balistica"
	)

	var items := ItemDbScript.new()
	items.load_content()
	_expect(
		str(items.get_def(WEAPON_ID).get("nombre", "")) == "Pistola oxidada",
		"el item del mod debe registrarse con id namespaced"
	)
	_expect(registry.has("ammo", "rust_pistol_ammo"), "la municion del mod debe registrarse")

	var world := Node3D.new()
	root.add_child(world)
	await process_frame
	var weapon_system := WeaponSystemScript.new()
	world.add_child(weapon_system)
	await process_frame
	var shot: Dictionary = weapon_system.fire(
		WEAPON_ID, Vector3(0, 2, 0), Vector3(0, 0, -1),
		world.get_world_3d().direct_space_state, []
	)
	_expect(bool(shot.get("fired", false)), "el arma del mod debe disparar con WeaponSystem")
	_expect(
		str(shot.get("weapon_id", "")) == WEAPON_ID and str(shot.get("error", "x")).is_empty(),
		"el disparo debe resolverse con el id del mod sin errores"
	)
	_expect(int(shot.get("pellets", 0)) == 1, "el disparo debe usar una bala")

	var reloader := ModReloaderScript.new()
	var reloaded: Dictionary = reloader.reload(mod_registry, loader, MOD_ID, MOD_DIR)
	_expect(bool(reloaded.get("ok", false)), "la recarga en caliente del mod debe tener exito")
	_expect(mod_registry.is_loaded(MOD_ID), "el mod debe seguir cargado tras la recarga")
	_expect(
		float(WeaponDbScript.get_def(WEAPON_ID).get("damage", -1.0)) == 22.0,
		"el contenido del mod debe sobrevivir a la recarga en caliente"
	)

	mod_registry.unload(MOD_ID)
	_expect(not WeaponDbScript.all().has(WEAPON_ID), "descargar el mod debe retirar su arma")
	_expect(WeaponDbScript.all().has("pistol"), "descargar el mod no debe afectar al contenido base")

	weapon_system.queue_free()
	world.queue_free()
	ContentRegistryScript.reset()
	if _failed:
		print("FAIL")
		quit(1)
	else:
		print("PASS (%d assertions)" % _assertions)
		quit(0)


func _expect(condition: bool, label: String) -> void:
	_assertions += 1
	if not condition:
		_failed = true
		printerr("FAIL: %s" % label)
