extends SceneTree

const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModResolverScript = preload("res://core/mod_resolver.gd")
const ModManifestScript = preload("res://core/mod_manifest.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const ModLintScript = preload("res://core/mod_lint.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")
const EventBusScript = preload("res://core/event_bus.gd")

var _failures: Array = []
var _checks: int = 0
var _case: String = ""

func _initialize() -> void:
	await process_frame
	
	_case = "mod_loader: discover con directorio inexistente"
	_test_discover_missing_dir()
	
	_case = "mod_loader: validate con schema_version float que es entero"
	_test_validate_schema_version_float()
	
	_case = "mod_loader: load_all con mod que tiene prioridad negativa"
	_test_load_negative_priority()
	
	_case = "mod_registry: scan con directorio inexistente"
	_test_registry_scan_missing_dir()
	
	_case = "mod_registry: load_all con candidatos invalidos"
	_test_registry_load_all_invalid()
	
	_case = "content_registry: load_mod con id invalido"
	_test_content_load_invalid_id()
	
	_case = "content_registry: load_mod con content duplicado dentro del mismo mod"
	_test_content_duplicate_content_same_mod()
	
	_case = "content_registry: validate weapon con todos los campos opcionales"
	_test_content_validate_weapon_full()
	
	_case = "content_registry: validate weapon con campos faltantes obligatorios"
	_test_content_validate_weapon_missing_required()
	
	_case = "content_registry: validate npc_type con role invalido"
	_test_content_validate_npc_type_invalid_role()
	
	_case = "content_registry: canonical_id con id publico y canonico"
	_test_content_canonical_id_both()
	
	_case = "content_registry: all() devuelve solo ids publicos"
	_test_content_all_public_ids()
	
	_case = "mod_manifest: parse con id que no sigue convencion"
	_test_manifest_parse_invalid_id_format()
	
	_case = "mod_manifest: parse con version invalida"
	_test_manifest_parse_invalid_version()
	
	_case = "mod_lint: check con mod.json valido pero content vacio"
	_test_lint_empty_content()
	
	_case = "mod_lint: check con entry que apunta a archivo inexistente"
	_test_lint_missing_entry()
	
	_case = "mod_lint: check con hooks que tienen prioridad fuera de rango"
	_test_lint_hooks_priority_out_of_range()
	
	_case = "mod_hooks: is_event con evento conocido"
	_test_hooks_is_event_known()
	
	_case = "mod_hooks: is_event con evento desconocido"
	_test_hooks_is_event_unknown()
	
	_case = "mod_hooks: emit orden por prioridad"
	_test_hooks_priority_order()
	
	_case = "mod_loader: load_all con mod que tiene dependencia circular de 3"
	_test_load_all_3way_cycle()
	
	_case = "mod_loader: load_all respeta orden de prioridad (menor numero = mayor prioridad)"
	_test_load_all_priority_order()
	
	_case = "mod_registry: unload bloqueado por dependientes"
	_test_registry_unload_blocked()
	
	_case = "content_registry: sync_loaded elimina mods no cargados"
	_test_registry_sync_loaded_removes()
	
	_case = "mod_loader: validate normaliza enteros en schema_version y priority"
	_test_loader_normalize_ints()
	
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
		_failures.append("[%s] %s" % [_case, message])

func _expect_error(result: Dictionary, expected_msg: String) -> void:
	_checks += 1
	if result["ok"]:
		_failures.append("[%s] Se esperaba error pero ok=true" % _case)
	elif not str(result["errors"]).contains(expected_msg):
		_failures.append("[%s] Error no contiene '%s': %s" % [_case, expected_msg, str(result["errors"])])

func _make_temp_mod_dir(mod_id: String, manifest: Dictionary, content: Dictionary = {}) -> String:
	var dir := "user://test_mods_d3a/%s" % mod_id
	var da := DirAccess.open("user://test_mods_d3a")
	if da == null:
		DirAccess.make_dir_recursive_absolute("user://test_mods_d3a")
	
	da = DirAccess.open(dir)
	if da == null:
		DirAccess.make_dir_recursive_absolute(dir)
	
	var file := FileAccess.open(dir.path_join("mod.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(manifest))
		file.close()
	
	if not content.is_empty():
		var content_dir := dir.path_join("content")
		DirAccess.make_dir_recursive_absolute(content_dir)
		for type_name in content:
			# Put all entries of same type in one file to avoid filename collision
			var root = {"content": content[type_name]}
			var fname := "%s.json" % type_name
			file = FileAccess.open(content_dir.path_join(fname), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(root))
				file.close()
	
	return dir

func _cleanup_test_mods() -> void:
	var da := DirAccess.open("user://test_mods_d3a")
	if da != null:
		da.list_dir_begin()
		var name := da.get_next()
		while name != "":
			if name != "." and name != "..":
				var path := "user://test_mods_d3a".path_join(name)
				_remove_dir_recursive(path)
			name = da.get_next()
		da.list_dir_end()
		da.remove_absolute("user://test_mods_d3a")

func _remove_dir_recursive(path: String) -> void:
	var da := DirAccess.open(path)
	if da != null:
		da.list_dir_begin()
		var name := da.get_next()
		while name != "":
			if name != "." and name != "..":
				var child := path.path_join(name)
				if da.current_is_dir():
					_remove_dir_recursive(child)
				else:
					DirAccess.remove_absolute(child)
			name = da.get_next()
		da.list_dir_end()
		DirAccess.remove_absolute(path)

func _test_discover_missing_dir() -> void:
	var loader := ModLoaderScript.new()
	var result := loader.discover("user://no_existe_d3a_123")
	_expect(not result["ok"], "directorio inexistente debe fallar")
	_expect(result["candidates"].is_empty(), "sin candidatos")
	_expect(not result["rejected"].is_empty(), "con razon de rechazo")

func _test_validate_schema_version_float() -> void:
	var loader := ModLoaderScript.new()
	var result := loader.validate({
		"schema_version": 1.0,
		"id": "test.mod",
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect(result["ok"], "schema_version 1.0 (float) debe ser valido")
	_expect(result["manifest"]["schema_version"] == 1, "schema_version normalizado a int")

func _test_load_negative_priority() -> void:
	var loader := ModLoaderScript.new()
	var bus := EventBusScript.new()
	var parent_dir = "user://test_mods_d3a"
	_make_temp_mod_dir("test.priority", {
		"schema_version": 1,
		"id": "test.priority",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": -50
	})
	var discovered := loader.discover(parent_dir)
	var report := loader.load_all(parent_dir)
	_expect(discovered["candidates"].size() == 1, "discover encuentra el mod: %s" % str(discovered))
	_expect(report["loaded"].has("test.priority"), "mod con prioridad negativa se carga: %s" % str(report))
	_expect(report["order"].size() > 0, "orden no vacio")
	_cleanup_test_mods()

func _test_registry_scan_missing_dir() -> void:
	var registry := ModRegistryScript.new(EventBusScript.new())
	var result: Dictionary = registry.scan("user://no_existe_d3a_456")
	_expect(not result["ok"], "scan directorio inexistente falla")
	_expect(result["candidates"].is_empty(), "sin candidatos")

func _test_registry_load_all_invalid() -> void:
	var registry := ModRegistryScript.new(EventBusScript.new())
	var result: Dictionary = registry.load_all([])
	_expect(result["ok"], "load_all con array vacio es ok")
	_expect(result["loaded"].is_empty(), "sin mods cargados")

func _test_content_load_invalid_id() -> void:
	var registry := ContentRegistryScript.new()
	var result := registry.load_mod("INVALID_ID", "user://test_mods_d3a/doesnt_exist")
	_expect(not result["ok"], "id invalido falla")
	_expect(str(result["errors"]).contains("invalido"), "error menciona id invalido")

func _test_content_duplicate_content_same_mod() -> void:
	var registry := ContentRegistryScript.new()
	var dir = _make_temp_mod_dir("test.dup", {
		"schema_version": 1,
		"id": "test.dup",
		"version": "1.0.0",
		"engine": "4.7",
	}, {
		"weapon": [
			{"type": "weapon", "id": "test.dup:gun1", "name": "Gun 1", "damage": 10.0, "fire_rate": 1.0, "range": 100.0, "mag": 30, "auto": true, "spread": 0.1, "pellets": 1, "tags": ["test"], "reload_time": 2.0, "weight": 3.0, "impulse": 100.0, "uses_ammo": true, "penetration": 0.5, "falloff_start": 10.0, "falloff_end": 100.0, "falloff_min": 0.2, "projectile_speed": 500.0, "projectile_gravity": 0.0, "projectile_min_distance": 1.0, "impact_speed": 10.0, "effect_scale": 1.0, "max_penetrations": 2, "max_ricochets": 1},
			{"type": "weapon", "id": "test.dup:gun1", "name": "Gun 1 Dup", "damage": 20.0, "fire_rate": 1.0, "range": 100.0, "mag": 30, "auto": true, "spread": 0.1, "pellets": 1, "tags": ["test"], "reload_time": 2.0, "weight": 3.0, "impulse": 100.0, "uses_ammo": true, "penetration": 0.5, "falloff_start": 10.0, "falloff_end": 100.0, "falloff_min": 0.2, "projectile_speed": 500.0, "projectile_gravity": 0.0, "projectile_min_distance": 1.0, "impact_speed": 10.0, "effect_scale": 1.0, "max_penetrations": 2, "max_ricochets": 1},
		]
	})
	var result := registry.load_mod("test.dup", dir)
	_expect(not result["ok"], "contenido duplicado en mismo mod falla: %s" % str(result))
	_expect(str(result["errors"]).contains("duplicado"), "error menciona duplicado: %s" % str(result["errors"]))
	_cleanup_test_mods()

func _test_content_validate_weapon_full() -> void:
	var registry := ContentRegistryScript.new()
	var result := registry.validate("weapon", {
		"type": "weapon",
		"id": "test.mod:full_gun",
		"name": "Full Gun",
		"damage": 25.0,
		"fire_rate": 0.1,
		"range": 500.0,
		"mag": 30,
		"auto": true,
		"spread": 0.05,
		"pellets": 1,
		"tags": ["rifle", "auto"],
		"reload_time": 2.5,
		"weight": 3.5,
		"impulse": 150.0,
		"uses_ammo": true,
		"penetration": 0.7,
		"falloff_start": 50.0,
		"falloff_end": 400.0,
		"falloff_min": 0.3,
		"projectile_speed": 800.0,
		"projectile_gravity": 9.8,
		"projectile_min_distance": 0.5,
		"impact_speed": 50.0,
		"effect_scale": 1.2,
		"max_penetrations": 3,
		"max_ricochets": 2,
		"model": "res://models/gun.glb",
		"ammo_id": "test.mod:556",
		"caliber": "5.56mm",
		"description": "A fully featured weapon"
	}, "test.mod")
	_expect(result["ok"], "arma con todos los campos valida")
	_expect(result["definition"]["damage"] == 25.0, "damage preservado")
	_expect(result["definition"]["tags"].size() == 2, "tags preservados")

func _test_content_validate_weapon_missing_required() -> void:
	var registry := ContentRegistryScript.new()
	var result := registry.validate("weapon", {
		"type": "weapon",
		"id": "test.mod:bad_gun",
		"name": "Bad Gun",
		"damage": 25.0,
		"fire_rate": 0.1,
	}, "test.mod")
	_expect(not result["ok"], "arma sin campos obligatorios falla")
	_expect(result["errors"].size() > 0, "tiene errores")

func _test_content_validate_npc_type_invalid_role() -> void:
	var registry := ContentRegistryScript.new()
	var result := registry.validate("npc_type", {
		"type": "npc_type",
		"id": "test.mod:bad_npc",
		"name": "Bad NPC",
		"role": "invalid_role",
		"models": ["res://model.glb"],
		"health": 100.0,
		"speed": 5.0,
		"zombie": false
	}, "test.mod")
	_expect(result["ok"], "role invalido pero string no vacio pasa")

func _test_content_canonical_id_both() -> void:
	ContentRegistryScript.instance().load_base()
	var canonical := ContentRegistryScript.instance().canonical_id("weapon", "untitled.base:pistol")
	_expect(not canonical.is_empty(), "canonical_id encuentra id canonico: %s" % canonical)
	_expect(canonical == "untitled.base:pistol", "devuelve id canonico completo")

func _test_content_all_public_ids() -> void:
	ContentRegistryScript.instance().load_base()
	var entries := ContentRegistryScript.instance().all("weapon")
	var keys := entries.keys()
	_expect(keys.size() > 0, "hay entradas: %s" % str(keys))
	for key in keys:
		_expect(not key.contains(":"), "keys son ids publicos sin prefijo de mod: %s" % key)

func _test_manifest_parse_invalid_id_format() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 1,
		"id": "INVALID",
		"version": "1.0.0",
		"engine": "4.7",
	})
	_expect(not result["ok"], "id invalido falla")
	_expect(str(result["errors"]).contains("id"), "error menciona id")

func _test_manifest_parse_invalid_version() -> void:
	var result := ModManifestScript.parse({
		"schema_version": 1,
		"id": "test.mod",
		"version": "not-a-version",
		"engine": "4.7",
	})
	_expect(not result["ok"], "version invalida falla")
	_expect(str(result["errors"]).contains("version"), "error menciona version")

func _test_lint_empty_content() -> void:
	var dir = _make_temp_mod_dir("test.emptycontent", {
		"schema_version": 1,
		"id": "test.emptycontent",
		"version": "1.0.0",
		"engine": "4.7",
	}, {})
	var result := ModLintScript.check(dir)
	_expect(result["ok"], "mod sin content pasa lint")
	_cleanup_test_mods()

func _test_lint_missing_entry() -> void:
	var dir = _make_temp_mod_dir("test.missingentry", {
		"schema_version": 1,
		"id": "test.missingentry",
		"version": "1.0.0",
		"engine": "4.7",
		"entry": "res://scripts/nonexistent.gd"
	}, {})
	var result := ModLintScript.check(dir)
	_expect(not result["ok"], "entry inexistente falla lint")
	_expect(str(result["errors"]).contains("entry"), "error menciona entry")
	_cleanup_test_mods()

func _test_lint_hooks_priority_out_of_range() -> void:
	var dir = _make_temp_mod_dir("test.hooksprio", {
		"schema_version": 1,
		"id": "test.hooksprio",
		"version": "1.0.0",
		"engine": "4.7",
		"hooks": {
			"weapon_fired": {"method": "spawn", "priority": 1500}
		}
	}, {})
	var result := ModLintScript.check(dir)
	_expect(result["ok"], "priority alto es warning no error: %s" % str(result))
	_expect(str(result["warnings"]).contains("fuera de rango"), "warning menciona rango: %s" % str(result["warnings"]))
	_cleanup_test_mods()

func _test_hooks_is_event_known() -> void:
	_expect(ModHooksScript.is_event("weapon_fired"), "weapon_fired es evento conocido")
	_expect(ModHooksScript.is_event("weapon_reloaded"), "weapon_reloaded es evento conocido")
	_expect(ModHooksScript.is_event("projectile_hit"), "projectile_hit es evento conocido")
	_expect(ModHooksScript.is_event("damage_dealt"), "damage_dealt es evento conocido")

func _test_hooks_is_event_unknown() -> void:
	_expect(not ModHooksScript.is_event("on_unknown_event"), "evento desconocido retorna false")
	_expect(not ModHooksScript.is_event(""), "string vacio retorna false")

func _test_hooks_priority_order() -> void:
	var hooks = ModHooksScript.instance()
	hooks.reset()
	var bus = EventBusScript.new()
	hooks.bind(bus)
	
	var results: Array = []
	
	bus.subscribe("weapon_fired", func(payload): results.append("low"), "test", 100)
	bus.subscribe("weapon_fired", func(payload): results.append("high"), "test", 200)
	bus.subscribe("weapon_fired", func(payload): results.append("medium"), "test", 150)
	
	var result := ModHooksScript.emit("weapon_fired", {})
	
	_expect(results.size() == 3, "tres hooks llamados: %s" % str(results))
	_expect(results[0] == "high", "prioridad alta primero: %s" % str(results))
	_expect(results[1] == "medium", "prioridad media segundo")
	_expect(results[2] == "low", "prioridad baja ultimo")

func _test_load_all_3way_cycle() -> void:
	var loader := ModLoaderScript.new()
	var dir = _make_temp_mod_dir("cyc.a", {
		"schema_version": 1,
		"id": "cyc.a",
		"version": "1.0.0",
		"engine": "4.7",
		"depends": {"cyc.b": "^1.0.0"}
	})
	_make_temp_mod_dir("cyc.b", {
		"schema_version": 1,
		"id": "cyc.b",
		"version": "1.0.0",
		"engine": "4.7",
		"depends": {"cyc.c": "^1.0.0"}
	})
	_make_temp_mod_dir("cyc.c", {
		"schema_version": 1,
		"id": "cyc.c",
		"version": "1.0.0",
		"engine": "4.7",
		"depends": {"cyc.a": "^1.0.0"}
	})
	
	var result := loader.load_all("user://test_mods_d3a")
	_expect(result["rejected"].has("cyc.a"), "cyc.a rechazado por ciclo: %s" % str(result["rejected"]))
	_expect(result["rejected"].has("cyc.b"), "cyc.b rechazado por ciclo")
	_expect(result["rejected"].has("cyc.c"), "cyc.c rechazado por ciclo")
	_expect(str(result["rejected"]["cyc.a"]).contains("circular"), "motivo menciona circular: %s" % str(result["rejected"]["cyc.a"]))
	_cleanup_test_mods()

func _test_load_all_priority_order() -> void:
	var loader := ModLoaderScript.new()
	
	_make_temp_mod_dir("test.low", {
		"schema_version": 1,
		"id": "test.low",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 50
	})
	_make_temp_mod_dir("test.med", {
		"schema_version": 1,
		"id": "test.med",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 100
	})
	_make_temp_mod_dir("test.high", {
		"schema_version": 1,
		"id": "test.high",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 200
	})
	
	var report := loader.load_all("user://test_mods_d3a")
	_expect(report["order"].size() == 3, "tres mods cargados: %s" % str(report["order"]))
	_expect(report["order"][0] == "test.low", "menor prioridad (50) primero: %s" % str(report["order"]))
	_expect(report["order"][1] == "test.med", "prioridad media (100) segundo")
	_expect(report["order"][2] == "test.high", "mayor prioridad (200) ultimo")
	_cleanup_test_mods()

func _test_registry_unload_blocked() -> void:
	var registry := ModRegistryScript.new(EventBusScript.new())
	ContentRegistryScript.instance().load_base()
	var result := registry.load_all([{"manifest": {"id": "test.base", "version": "1.0.0", "engine": "4.7", "schema_version": 1}, "dir": "res://data/base"}])
	_expect(result["ok"], "load_all base ok")
	
	var before := registry.loaded_ids().size()
	var unload_result := registry.unload("untitled.base")
	_expect(not unload_result["ok"], "base mod no se puede descargar (tiene dependientes en content_registry)")
	_expect(unload_result["errors"].size() > 0, "tiene error")
	var after := registry.loaded_ids().size()
	_expect(after == before, "base mod sigue cargado")

func _test_registry_sync_loaded_removes() -> void:
	ContentRegistryScript.instance().load_base()
	var dir = _make_temp_mod_dir("test.sync", {
		"schema_version": 1,
		"id": "test.sync",
		"version": "1.0.0",
		"engine": "4.7",
	}, {
		"weapon": [{"type": "weapon", "id": "test.sync:gun", "name": "Sync Gun", "damage": 10.0, "fire_rate": 1.0, "range": 100.0, "mag": 30, "auto": true, "spread": 0.1, "pellets": 1, "tags": ["test"], "reload_time": 2.0, "weight": 3.0, "impulse": 100.0, "uses_ammo": true, "penetration": 0.5, "falloff_start": 10.0, "falloff_end": 100.0, "falloff_min": 0.2, "projectile_speed": 500.0, "projectile_gravity": 0.0, "projectile_min_distance": 1.0, "impact_speed": 10.0, "effect_scale": 1.0, "max_penetrations": 2, "max_ricochets": 1}]
	})
	var result := ContentRegistryScript.instance().load_mod("test.sync", dir)
	_expect(result["ok"], "load_mod ok: %s" % str(result))
	_expect(ContentRegistryScript.instance().has("weapon", "test.sync:gun"), "arma cargada")
	
	ContentRegistryScript.instance().sync_loaded(["untitled.base"])
	_expect(not ContentRegistryScript.instance().has("weapon", "test.sync:gun"), "sync_loaded elimina mod no en lista")
	_cleanup_test_mods()

func _test_loader_normalize_ints() -> void:
	var loader := ModLoaderScript.new()
	var result := loader.validate({
		"schema_version": 1.0,
		"id": "test.mod",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 100.0
	})
	_expect(result["ok"], "validate ok con floats enteros: %s" % str(result))
	_expect(result["manifest"]["schema_version"] == 1, "schema_version normalizado")
	_expect(result["manifest"]["priority"] == 100, "priority normalizado")