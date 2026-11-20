extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModProfileScript = preload("res://core/mod_profile.gd")
const ModReloaderScript = preload("res://core/mod_reloader.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")

const ROOT := "user://test_mod_integration"

var _failures: Array = []
var _assertions: int = 0
var _case: String = ""

func _init() -> void:
	_cleanup()

	_case = "perfil -> loader -> registry -> content registry"
	_test_profile_to_registry_flow()

	_case = "mod con contenido data-driven se registra en ContentRegistry"
	_test_content_registration()

	_case = "reemplazo de contenido por prioridad y replaces"
	_test_content_replacement()

	_case = "perfil diff + registry load/unload sincronizado"
	_test_profile_registry_sync()

	_case = "recarga en caliente conserva contenido"
	_test_hot_reload_preserves_content()

	_case = "registro de multiples mods con dependencias"
	_test_multi_mod_dependencies()

	_cleanup()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _assertions)
		quit(0)
	else:
		print("FAIL (%d assertions): %s" % [_assertions, "; ".join(_failures)])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])

func _manifest(module_id: String, extra: Dictionary = {}) -> Dictionary:
	var base := {
		"schema_version": 1,
		"id": module_id,
		"version": "1.0.0",
		"engine": "4.7",
	}
	for key in extra:
		base[key] = extra[key]
	return base

func _make_entry(name: String, content: String) -> String:
	var dir := ROOT.path_join("mods").path_join(name)
	var entry := dir.path_join("entry.gd")
	_write(entry, content)
	return entry

const MODULE_SCRIPT := """extends RefCounted

var _api

func _mod_init(api):
	_api = api
	api.emit("mod.ready", {"id": api.module_id})

func _mod_shutdown():
	_api.emit("mod.shutdown", {"id": _api.module_id})
"""

func _write(path: String, content: String) -> void:
	var dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "no se pudo escribir '%s'" % path)
		return
	file.store_string(content)
	file.close()

func _remove_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = dir.get_next()
			continue
		var full := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _cleanup() -> void:
	_remove_dir(ROOT)

func _test_profile_to_registry_flow() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)
	var profile = ModProfileScript.new(ROOT)

	var mod1_entry := _make_entry("mod1", MODULE_SCRIPT)
	var mod1_manifest := _manifest("test.mod1", {"entry": mod1_entry, "priority": 100})

	var mod2_entry := _make_entry("mod2", MODULE_SCRIPT)
	var mod2_manifest := _manifest("test.mod2", {"entry": mod2_entry, "priority": 50})

	var profile_result := ModProfileScript.make("integration_test", ["test.mod1", "test.mod2"], false)
	_expect(profile_result["ok"], "perfil valido")

	var saved := profile.save(profile_result["profile"])
	_expect(saved["ok"], "save perfil ok")

	var loaded_profile := profile.load_profile("integration_test")
	_expect(loaded_profile["ok"], "load perfil ok")

	var candidates := [
		{"manifest": mod1_manifest, "dir": mod1_entry.get_base_dir()},
		{"manifest": mod2_manifest, "dir": mod2_entry.get_base_dir()},
	]

	var load_result: Dictionary = registry.load_all(candidates)
	_expect(load_result["ok"], "load_all ok: %s" % str(load_result["errors"]))
	_expect(load_result["loaded"] == ["test.mod2", "test.mod1"], "orden por prioridad: %s" % str(load_result["loaded"]))
	_expect(registry.is_loaded("test.mod1"), "mod1 cargado")
	_expect(registry.is_loaded("test.mod2"), "mod2 cargado")

	var diff := ModProfileScript.diff(registry.loaded_ids(), loaded_profile["profile"])
	_expect(diff["to_load"].is_empty(), "to_load vacio")
	_expect(diff["to_unload"].is_empty(), "to_unload vacio")

	var unload_result := registry.unload("test.mod1")
	_expect(unload_result["ok"], "unload ok")
	_expect(not registry.is_loaded("test.mod1"), "mod1 descargado")

	var diff2 := ModProfileScript.diff(registry.loaded_ids(), loaded_profile["profile"])
	_expect(diff2["to_load"] == ["test.mod1"], "to_load tiene mod1")
	_expect(diff2["to_unload"].is_empty(), "to_unload vacio")

func _test_content_registration() -> void:
	ContentRegistryScript.reset()

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)

	var mod_dir := ROOT.path_join("mods/content_test")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_dir))
	var content_dir := mod_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(content_dir))

	var manifest := _manifest("test.contentmod", {"priority": 100})
	var manifest_path := mod_dir.path_join("mod.json")
	_write(manifest_path, JSON.stringify(manifest))

	var weapon_json := {
		"content": [{
			"type": "weapon",
			"id": "test.contentmod:test_rifle",
			"name": "Test Rifle",
			"damage": 30.0,
			"fire_rate": 8.0,
			"range": 100.0,
			"mag": 30,
			"auto": true,
			"spread": 2.0,
			"pellets": 1,
			"tags": ["rifle", "test"],
			"reload_time": 2.0,
			"weight": 3.5,
			"impulse": 0.1,
			"uses_ammo": true,
			"penetration": 0.5,
			"falloff_start": 30.0,
			"falloff_end": 100.0,
			"falloff_min": 0.2,
			"projectile_speed": 0.0,
			"projectile_gravity": 0.0,
			"projectile_min_distance": 50.0,
			"impact_speed": 150.0,
			"effect_scale": 1.0,
			"max_penetrations": 2,
			"max_ricochets": 1,
			"model": "res://assets/models/weapons/test_rifle.gltf",
			"ammo_id": "test.contentmod:test_rifle_ammo",
			"caliber": "5.56x45mm"
		}]
	}
	_write(content_dir.path_join("weapons.json"), JSON.stringify(weapon_json))

	var npc_json := {
		"content": [{
			"type": "npc_type",
			"id": "test.contentmod:test_zombie",
			"name": "Test Zombie",
			"role": "enemy",
			"models": ["res://assets/models/npcs/test_zombie.gltf"],
			"aliases": [],
			"health": 150.0,
			"speed": 2.5,
			"weapon_id": "",
			"zombie": true
		}]
	}
	_write(content_dir.path_join("npcs.json"), JSON.stringify(npc_json))

	var candidates := [{"manifest": manifest, "dir": mod_dir}]
	var load_result := registry.load_all(candidates)
	_expect(load_result["ok"], "load content mod ok: %s" % str(load_result["errors"]))

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var weapons := ContentRegistryScript.instance().entries("weapon")
	_expect(weapons.has("test.contentmod:test_rifle"), "arma registrada")
	_expect(weapons["test.contentmod:test_rifle"]["name"] == "Test Rifle", "nombre correcto")
	_expect(weapons["test.contentmod:test_rifle"]["damage"] == 30.0, "damage correcto")

	var npcs := ContentRegistryScript.instance().entries("npc_type")
	_expect(npcs.has("test.contentmod:test_zombie"), "npc registrado")
	_expect(npcs["test.contentmod:test_zombie"]["name"] == "Test Zombie", "nombre correcto")
	_expect(npcs["test.contentmod:test_zombie"]["zombie"] == true, "zombie flag")

	var public_weapons := ContentRegistryScript.instance().all("weapon")
	_expect(public_weapons.has("test_rifle"), "id publico disponible")
	_expect(public_weapons["test_rifle"]["id"] == "test_rifle", "id publico sin namespace")

func _test_content_replacement() -> void:
	ContentRegistryScript.reset()

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)

	var base_dir := ROOT.path_join("mods/base_mod")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var base_content_dir := base_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_content_dir))

	var base_manifest := _manifest("test.base", {"priority": 100})
	_write(base_dir.path_join("mod.json"), JSON.stringify(base_manifest))

	var base_weapon := {
		"content": [{
			"type": "weapon",
			"id": "test.base:ak47",
			"name": "AK-47 Base",
			"damage": 25.0,
			"fire_rate": 10.0,
			"range": 80.0,
			"mag": 30,
			"auto": true,
			"spread": 3.0,
			"pellets": 1,
			"tags": ["rifle", "base"],
			"reload_time": 2.5,
			"weight": 4.0,
			"impulse": 0.12,
			"uses_ammo": true,
			"penetration": 0.4,
			"falloff_start": 25.0,
			"falloff_end": 80.0,
			"falloff_min": 0.3,
			"projectile_speed": 0.0,
			"projectile_gravity": 0.0,
			"projectile_min_distance": 40.0,
			"impact_speed": 120.0,
			"effect_scale": 1.0,
			"max_penetrations": 1,
			"max_ricochets": 1,
			"model": "res://assets/models/weapons/ak47.gltf",
			"ammo_id": "test.base:ak47_ammo",
			"caliber": "7.62x39mm"
		}]
	}
	_write(base_content_dir.path_join("weapons.json"), JSON.stringify(base_weapon))

	var override_dir := ROOT.path_join("mods/override_mod")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(override_dir))
	var override_content_dir := override_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(override_content_dir))

	var override_manifest := _manifest("test.override", {"priority": 200, "replaces": ["test.base:ak47"]})
	_write(override_dir.path_join("mod.json"), JSON.stringify(override_manifest))

	var override_weapon := {
		"content": [{
			"type": "weapon",
			"id": "test.override:ak47",
			"name": "AK-47 Custom",
			"damage": 35.0,
			"fire_rate": 12.0,
			"range": 100.0,
			"mag": 40,
			"auto": true,
			"spread": 2.5,
			"pellets": 1,
			"tags": ["rifle", "custom"],
			"reload_time": 2.0,
			"weight": 3.8,
			"impulse": 0.15,
			"uses_ammo": true,
			"penetration": 0.6,
			"falloff_start": 35.0,
			"falloff_end": 100.0,
			"falloff_min": 0.25,
			"projectile_speed": 0.0,
			"projectile_gravity": 0.0,
			"projectile_min_distance": 50.0,
			"impact_speed": 140.0,
			"effect_scale": 1.2,
			"max_penetrations": 2,
			"max_ricochets": 2,
			"model": "res://assets/models/weapons/ak47_custom.gltf",
			"ammo_id": "test.override:ak47_ammo",
			"caliber": "7.62x39mm"
		}]
	}
	_write(override_content_dir.path_join("weapons.json"), JSON.stringify(override_weapon))

	var candidates := [
		{"manifest": base_manifest, "dir": base_dir},
		{"manifest": override_manifest, "dir": override_dir},
	]

	var load_result := registry.load_all(candidates)
	_expect(load_result["ok"], "load replacement mods ok: %s" % str(load_result["errors"]))

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var weapons := ContentRegistryScript.instance().entries("weapon")
	_expect(weapons.has("test.base:ak47"), "base ak47 registrado")
	_expect(weapons.has("test.override:ak47"), "override ak47 registrado")

	var public_weapons := ContentRegistryScript.instance().all("weapon")
	_expect(public_weapons.has("ak47"), "id publico ak47 disponible")
	_expect(public_weapons["ak47"]["id"] == "ak47", "id publico correcto")
	_expect(public_weapons["ak47"]["name"] == "AK-47 Custom", "gana el override por prioridad")
	_expect(public_weapons["ak47"]["damage"] == 35.0, "damage del override")

	var owner := ContentRegistryScript.instance().owner_of("weapon", "ak47")
	_expect(owner == "test.override", "dueño es override")

	var canonical := ContentRegistryScript.instance().canonical_id("weapon", "ak47")
	_expect(canonical == "test.override:ak47", "canonical_id resuelve al override")

func _test_profile_registry_sync() -> void:
	ContentRegistryScript.reset()

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)
	var profile = ModProfileScript.new(ROOT)

	var mod_a_entry := _make_entry("mod_a", MODULE_SCRIPT)
	var mod_a_manifest := _manifest("test.mod_a", {"entry": mod_a_entry, "priority": 100})

	var mod_b_entry := _make_entry("mod_b", MODULE_SCRIPT)
	var mod_b_manifest := _manifest("test.mod_b", {"entry": mod_b_entry, "priority": 50})

	var mod_c_entry := _make_entry("mod_c", MODULE_SCRIPT)
	var mod_c_manifest := _manifest("test.mod_c", {"entry": mod_c_entry, "priority": 150})

	var profile_result := ModProfileScript.make("sync_test", ["test.mod_a", "test.mod_b"], false)
	_expect(profile_result["ok"], "perfil valido")
	profile.save(profile_result["profile"])

	var candidates := [
		{"manifest": mod_a_manifest, "dir": mod_a_entry.get_base_dir()},
		{"manifest": mod_b_manifest, "dir": mod_b_entry.get_base_dir()},
	]
	var load_result := registry.load_all(candidates)
	_expect(load_result["ok"], "carga inicial ok")

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var loaded_profile := profile.load_profile("sync_test")
	var diff := ModProfileScript.diff(registry.loaded_ids(), loaded_profile["profile"])
	_expect(diff["to_load"].is_empty(), "sin mods por cargar")
	_expect(diff["to_unload"].is_empty(), "sin mods por descargar")

	registry.unload("test.mod_b")
	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	loaded_profile = profile.load_profile("sync_test")
	diff = ModProfileScript.diff(registry.loaded_ids(), loaded_profile["profile"])
	_expect(diff["to_load"] == ["test.mod_b"], "mod_b por cargar")
	_expect(diff["to_unload"].is_empty(), "sin mods por descargar")

	var c_result := registry.load_all([{"manifest": mod_c_manifest, "dir": mod_c_entry.get_base_dir()}])
	_expect(c_result["ok"], "cargar mod_c ok")
	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	loaded_profile = profile.load_profile("sync_test")
	diff = ModProfileScript.diff(registry.loaded_ids(), loaded_profile["profile"])
	_expect(diff["to_unload"] == ["test.mod_c"], "mod_c por descargar (no esta en perfil)")
	_expect(diff["to_load"] == ["test.mod_b"], "mod_b sigue por cargar")

func _test_hot_reload_preserves_content() -> void:
	ContentRegistryScript.reset()

	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)

	var mod_dir := ROOT.path_join("mods/reload_test")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(mod_dir))
	var content_dir := mod_dir.path_join("content")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(content_dir))

	var manifest := _manifest("test.reload", {"priority": 100})
	var manifest_path := mod_dir.path_join("mod.json")
	_write(manifest_path, JSON.stringify(manifest))

	var entry_script := """extends RefCounted
var _api
func _mod_init(api):
	_api = api
	api.emit("mod.ready", {"id": api.module_id})
func _mod_shutdown():
	pass
"""
	_write(mod_dir.path_join("entry.gd"), entry_script)

	var weapon_v1 := {
		"content": [{
			"type": "weapon",
			"id": "test.reload:pistol",
			"name": "Pistol V1",
			"damage": 20.0,
			"fire_rate": 5.0,
			"range": 50.0,
			"mag": 15,
			"auto": false,
			"spread": 1.0,
			"pellets": 1,
			"tags": ["pistol", "test"],
			"reload_time": 1.5,
			"weight": 1.0,
			"impulse": 0.05,
			"uses_ammo": true,
			"penetration": 0.2,
			"falloff_start": 15.0,
			"falloff_end": 50.0,
			"falloff_min": 0.3,
			"projectile_speed": 0.0,
			"projectile_gravity": 0.0,
			"projectile_min_distance": 20.0,
			"impact_speed": 100.0,
			"effect_scale": 0.8,
			"max_penetrations": 1,
			"max_ricochets": 0,
			"model": "res://assets/models/weapons/pistol.gltf",
			"ammo_id": "test.reload:pistol_ammo",
			"caliber": "9x19mm"
		}]
	}
	_write(content_dir.path_join("weapons.json"), JSON.stringify(weapon_v1))

	var candidates := [{"manifest": manifest, "dir": mod_dir}]
	var load_result := registry.load_all(candidates)
	_expect(load_result["ok"], "carga inicial ok: %s" % str(load_result["errors"]))

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var weapons_before := ContentRegistryScript.instance().entries("weapon")
	_expect(weapons_before.has("test.reload:pistol"), "arma antes de recargar")
	_expect(weapons_before["test.reload:pistol"]["damage"] == 20.0, "damage v1")

	var weapon_v2 := weapon_v1.duplicate(true)
	weapon_v2["content"][0]["damage"] = 25.0
	weapon_v2["content"][0]["name"] = "Pistol V2"
	_write(content_dir.path_join("weapons.json"), JSON.stringify(weapon_v2))

	var reloader = ModReloaderScript.new()
	var reload_result := reloader.reload(registry, loader, "test.reload", mod_dir)
	_expect(reload_result["ok"], "recarga ok: %s" % reload_result.get("error", ""))

	ContentRegistryScript.instance().sync_loaded(registry.loaded_ids())

	var weapons_after := ContentRegistryScript.instance().entries("weapon")
	_expect(weapons_after.has("test.reload:pistol"), "arma despues de recargar")
	_expect(weapons_after["test.reload:pistol"]["damage"] == 25.0, "damage actualizado a v2")
	_expect(weapons_after["test.reload:pistol"]["name"] == "Pistol V2", "nombre actualizado a v2")

func _test_multi_mod_dependencies() -> void:
	var bus = EventBusScript.new()
	var registry = ModRegistryScript.new(bus)
	var loader = ModLoaderScript.new(bus)

	var lib_entry := _make_entry("lib", MODULE_SCRIPT)
	var lib_manifest := _manifest("test.lib", {"entry": lib_entry, "priority": 100, "version": "1.0.0"})

	var plugin_entry := _make_entry("plugin", MODULE_SCRIPT)
	var plugin_manifest := _manifest("test.plugin", {
		"entry": plugin_entry,
		"priority": 100,
		"version": "1.0.0",
		"depends": {"test.lib": "^1.0.0"}
	})

	var app_entry := _make_entry("app", MODULE_SCRIPT)
	var app_manifest := _manifest("test.app", {
		"entry": app_entry,
		"priority": 100,
		"version": "1.0.0",
		"depends": {"test.lib": "^1.0.0", "test.plugin": "^1.0.0"}
	})

	var candidates := [
		{"manifest": lib_manifest, "dir": lib_entry.get_base_dir()},
		{"manifest": plugin_manifest, "dir": plugin_entry.get_base_dir()},
		{"manifest": app_manifest, "dir": app_entry.get_base_dir()},
	]

	var load_result := registry.load_all(candidates)
	_expect(load_result["ok"], "carga con dependencias ok: %s" % str(load_result["errors"]))
	_expect(load_result["loaded"].has("test.lib"), "lib cargado")
	_expect(load_result["loaded"].has("test.plugin"), "plugin cargado")
	_expect(load_result["loaded"].has("test.app"), "app cargado")

	var loaded_order := registry.loaded_ids()
	var lib_idx := loaded_order.find("test.lib")
	var plugin_idx := loaded_order.find("test.plugin")
	var app_idx := loaded_order.find("test.app")
	_expect(lib_idx < plugin_idx, "lib antes que plugin")
	_expect(plugin_idx < app_idx, "plugin antes que app")

	var bad_app_manifest := _manifest("test.badapp", {
		"entry": app_entry,
		"priority": 100,
		"version": "1.0.0",
		"depends": {"test.nonexistent": "^1.0.0"}
	})
	var bad_candidates := [{"manifest": bad_app_manifest, "dir": app_entry.get_base_dir()}]
	var bad_result := registry.load_all(bad_candidates)
	_expect(not bad_result["ok"], "carga sin dependencia falla")
	_expect(bad_result["failed"].has("test.badapp"), "bad_app en failed")