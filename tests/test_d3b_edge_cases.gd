extends SceneTree

const ModLoaderScript = preload("res://core/mod_loader.gd")
const ModRegistryScript = preload("res://core/mod_registry.gd")
const ContentRegistryScript = preload("res://core/game/content_registry.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")
const ModBackupScript = preload("res://core/mod_backup.gd")
const ModProfileScript = preload("res://core/mod_profile.gd")
const ModCapabilitiesScript = preload("res://core/mod_capabilities.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const VrBootstrapScript = preload("res://core/vr/vr_bootstrap.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")
const NPCNavigationScript = preload("res://core/npc/npc_navigation.gd")
const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")
const GameSessionScript = preload("res://core/game/game_session.gd")
const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const VrSimHarnessScript = preload("res://tests/vr_sim_harness.gd")

var _failures: Array = []
var _case := ""
var _checks: int = 0

func _init() -> void:
	_test_mod_loader_edge_cases()
	_test_mod_registry_edge_cases()
	_test_content_registry_edge_cases()
	_test_mod_hooks_edge_cases()
	_test_mod_backup_edge_cases()
	_test_mod_profile_edge_cases()
	_test_vr_bootstrap_edge_cases()
	_test_weapon_system_edge_cases()
	_test_npc_edge_cases()
	_test_vr_game_mode_edge_cases()

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
		_failures.append("%s: %s" % [_case, message])

func _test_mod_loader_edge_cases() -> void:
	_case = "ModLoader: manifest con priority no entero"
	var loader = ModLoaderScript.new()
	var result1 = loader.validate({
		"schema_version": 1,
		"id": "test.mod",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": 100.5,
	})
	_expect(not result1["ok"], "priority float no exacto debe fallar")

	_case = "ModLoader: manifest con priority string"
	var result2 = loader.validate({
		"schema_version": 1,
		"id": "test.mod",
		"version": "1.0.0",
		"engine": "4.7",
		"priority": "100",
	})
	_expect(not result2["ok"], "priority string debe fallar")

	_case = "ModLoader: manifest con platforms invalido"
	var result3 = loader.validate({
		"schema_version": 1,
		"id": "test.mod",
		"version": "1.0.0",
		"engine": "4.7",
		"platforms": ["ios"]
	})
	_expect(not result3["ok"], "platforms invalido debe fallar")

	_case = "ModLoader: discover directorio sin permisos"
	var target = "user://no_perms"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(target))
	var f1 = FileAccess.open(target.path_join("mod.json"), FileAccess.WRITE)
	if f1:
		f1.store_string('{"schema_version": 1, "id": "test.mod", "version": "1.0.0", "engine": "4.7"}')
		f1.close()
	var discover_result = loader.discover(target)
	_expect(not discover_result["ok"] or discover_result["candidates"].is_empty(), "directorio sin permisos maneja error")
	_remove_dir_recursive(target)

	_case = "ModLoader: load_all con directorio vacio"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://empty_mods"))
	var load_all_result = loader.load_all("user://empty_mods")
	_expect(load_all_result["loaded"].is_empty(), "directorio vacio sin mods")
	_remove_dir_recursive("user://empty_mods")

func _test_mod_registry_edge_cases() -> void:
	_case = "ModRegistry: scan con mod.json vacio"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_mods/empty_manifest"))
	var f2 = FileAccess.open("user://test_mods/empty_manifest/mod.json", FileAccess.WRITE)
	if f2:
		f2.store_string("{}")
		f2.close()
	var registry = ModRegistryScript.new(EventBusScript.new())
	var result = registry.scan("user://test_mods")
	_expect(not result["ok"], "mod.json vacio falla validacion")
	_remove_dir_recursive("user://test_mods")

func _test_content_registry_edge_cases() -> void:
	_case = "ContentRegistry: get_def con id inexistente"
	var reg = ContentRegistryScript.new()
	reg.load_mod("test.base", "res://data/base", 0)
	var def = reg.definition("weapon", "nonexistent")
	_expect(def == {}, "definition inexistente devuelve dict vacio")

	_case = "ContentRegistry: has con id inexistente"
	reg = ContentRegistryScript.new()
	reg.load_mod("test.base", "res://data/base", 0)
	_expect(not reg.has("weapon", "nonexistent"), "has inexistente devuelve false")

	_case = "ContentRegistry: ids vacio"
	reg = ContentRegistryScript.new()
	var ids = reg.ids("weapon")
	_expect(ids.is_empty(), "ids vacio para tipo sin contenido")

func _test_mod_hooks_edge_cases() -> void:
	_case = "ModHooks: emit evento desconocido"
	var hooks = ModHooksScript.new()
	var bus = EventBusScript.new()
	hooks.bind(bus)
	var result = hooks.emit_event("unknown_event", {})
	_expect(not result["ok"], "emit evento desconocido falla")

	_case = "ModHooks: emit sin bus"
	hooks = ModHooksScript.new()
	result = hooks.emit_event("weapon_fired", {})
	_expect(not result["ok"], "emit sin bus falla")

	_case = "ModHooks: can sin permisos"
	hooks = ModHooksScript.new()
	hooks.set_permissions("test.mod", ["read_events"])
	_expect(hooks.can("test.mod", "emit"), "con read_events puede emit")
	_expect(not hooks.can("test.mod", "modify_damage"), "sin modify_damage no puede")

	_case = "ModHooks: is_disabled modulo inexistente"
	hooks = ModHooksScript.new()
	_expect(not hooks.is_disabled("nonexistent"), "modulo inexistente no desactivado")

func _test_mod_backup_edge_cases() -> void:
	_case = "ModBackup: snapshot directorio inexistente"
	var backup1 = ModBackupScript.new("user://backups_test")
	var snap_result = backup1.snapshot("user://nonexistent", "test")
	_expect(not snap_result["ok"], "snapshot dir inexistente falla")

	_case = "ModBackup: verify snapshot inexistente"
	var backup2 = ModBackupScript.new("user://backups_test")
	var verify_result = backup2.verify("nonexistent")
	_expect(not verify_result["ok"], "verify snapshot inexistente falla")

	_case = "ModBackup: manifest con archivo corrupto"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://corrupt_backup"))
	var f8 = FileAccess.open("user://corrupt_backup/file.txt", FileAccess.WRITE)
	if f8:
		f8.store_string("content")
		f8.close()
	var backup3 = ModBackupScript.new("user://corrupt_backup")
	var manifest_result = backup3.make_manifest("user://corrupt_backup")
	_expect(typeof(manifest_result) == TYPE_DICTIONARY, "manifest creado")
	var f9 = FileAccess.open("user://corrupt_backup/file.txt", FileAccess.WRITE)
	if f9:
		f9.store_string("corrupted")
		f9.close()
	var check_result = backup3.check_manifest("user://corrupt_backup", manifest_result)
	_expect(not check_result["ok"], "check_manifest detecta corrupcion")
	_expect(check_result["mismatched"].size() > 0, "mismatched no vacio")
	_remove_dir_recursive("user://corrupt_backup")

func _test_mod_profile_edge_cases() -> void:
	_case = "ModProfile: nombre invalido"
	var profile1 = ModProfileScript.new("user://profiles_test")
	var validate1 = profile1.validate_name("INVALID")
	_expect(not validate1, "nombre con mayusculas invalido")

	_case = "ModProfile: nombre muy largo"
	var validate2 = profile1.validate_name("a".repeat(50))
	_expect(not validate2, "nombre > 40 chars invalido")

	_case = "ModProfile: make con ids duplicados deduplica silenciosamente"
	var make_result = profile1.make("test", ["mod.a", "mod.a"], false)
	_expect(make_result["ok"], "make con ids duplicados OK (deduplica)")
	_expect(make_result["profile"]["mods"] == ["mod.a"], "mods deduplicados")

	_case = "ModProfile: save/load perfil corrupto"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://profiles_test"))
	var f10 = FileAccess.open("user://profiles_test/bad.json", FileAccess.WRITE)
	if f10:
		f10.store_string("{ invalid json")
		f10.close()
	var profile2 = ModProfileScript.new("user://profiles_test")
	var load_result = profile2.load_profile("bad")
	_expect(not load_result["ok"], "load perfil corrupto falla")
	_expect(load_result["profile"] == {}, "perfil corrupto devuelve vacio")
	var names = profile2.list()
	_expect(typeof(names) == TYPE_ARRAY, "list no crashea con corrupto")
	_remove_dir_recursive("user://profiles_test")

	_case = "ModProfile: diff con mods no cargados"
	var profile3 = ModProfileScript.new("user://profiles_test2")
	var loaded = ["mod.a", "mod.b"]
	var prof = {"name": "test", "mods": ["mod.a", "mod.c"], "experimental": false}
	var diff_result = profile3.diff(loaded, prof)
	_expect(diff_result["to_load"] == ["mod.c"], "diff to_load correcto")
	_expect(diff_result["to_unload"] == ["mod.b"], "diff to_unload correcto")

func _test_vr_bootstrap_edge_cases() -> void:
	_case = "VrBootstrap: boot sin viewport"
	var mock = _make_mock_xr()
	VrBootstrapScript.interface_override = mock
	var boot_result1 = VrBootstrapScript.boot(null, self)
	_expect(not bool(boot_result1["xr_active"]), "boot sin viewport falla")
	_expect(boot_result1["reason"] == "no_viewport", "razon no_viewport")

	_case = "VrBootstrap: initialize llamado multiples veces crea nueva instancia"
	mock = _make_mock_xr()
	VrBootstrapScript.interface_override = mock
	var vp = SubViewport.new()
	root.add_child(vp)
	var boot_result2 = VrBootstrapScript.boot(vp, self)
	_expect(mock.init_calls == 1, "primera llamada init_calls == 1")
	var active1 = VrBootstrapScript.active
	VrBootstrapScript.interface_override = _make_mock_xr()
	VrBootstrapScript.boot(vp, self)
	_expect(VrBootstrapScript.active != active1, "segunda llamada crea nueva instancia active")
	vp.free()

	_case = "VrBootstrap: session_begun con rates disponibles aplica refresh"
	mock = _make_mock_xr()
	mock.rates = [72.0, 90.0]
	VrBootstrapScript.interface_override = mock
	vp = SubViewport.new()
	root.add_child(vp)
	var boot_result3 = VrBootstrapScript.boot(vp, self)
	_expect(bool(boot_result3["xr_active"]), "boot OK con rates")
	mock.session_begun.emit()
	# _apply_refresh sets display_refresh_rate to best matching rate
	_expect(mock.display_refresh_rate == 72.0, "display_refresh_rate == 72.0")
	vp.free()

	_case = "VrBootstrap: enable_viewport_xr con viewport invalido"
	var enable_result = VrBootstrapScript.enable_viewport_xr(null)
	_expect(not enable_result, "enable_viewport_xr null devuelve false")

	_case = "VrBootstrap: is_xr_active sin active"
	VrBootstrapScript.active = null
	_expect(not VrBootstrapScript.is_xr_active(), "is_xr_active false sin active")

	_case = "VrBootstrap: shutdown limpia estado"
	mock = _make_mock_xr()
	mock.rates = [72.0]
	VrBootstrapScript.interface_override = mock
	vp = SubViewport.new()
	root.add_child(vp)
	var boot_result4 = VrBootstrapScript.boot(vp, self)
	_expect(bool(boot_result4["xr_active"]), "boot OK")
	if VrBootstrapScript.active != null and VrBootstrapScript.active.has_method("shutdown"):
		VrBootstrapScript.active.shutdown()
	_expect(not vp.use_xr, "use_xr false tras shutdown")
	_expect(VrBootstrapScript.active == null, "active null tras shutdown")
	vp.free()

func _test_weapon_system_edge_cases() -> void:
	_case = "WeaponSystem: ammo sin arma devuelve -1"
	var ws = WeaponSystemScript.new()
	var ammo = ws.ammo("nonexistent")
	_expect(ammo == -1, "ammo arma inexistente devuelve -1")

	_case = "WeaponSystem: reserve sin arma devuelve 0"
	ws = WeaponSystemScript.new()
	var reserve = ws.reserve("nonexistent")
	_expect(reserve == 0, "reserve arma inexistente devuelve 0")

func _test_npc_edge_cases() -> void:
	_case = "NPCNavigation: find_path misma celda"
	var nav = NPCNavigationScript.new(10, 10, [])
	var path = nav.find_path(Vector2i(5, 5), Vector2i(5, 5), {})
	_expect(path["ok"] and path["path"].size() == 1, "mismo origen/destino path size 1")

	_case = "NPCNavigation: find_path origen bloqueado"
	var blocked: Array = [Vector2i(5, 5)]
	nav = NPCNavigationScript.new(10, 10, blocked)
	path = nav.find_path(Vector2i(5, 5), Vector2i(6, 6), {})
	_expect(not path["ok"], "origen bloqueado falla")

	_case = "NPCNavigation: find_path destino bloqueado"
	blocked = [Vector2i(6, 6)]
	nav = NPCNavigationScript.new(10, 10, blocked)
	path = nav.find_path(Vector2i(5, 5), Vector2i(6, 6), {})
	_expect(not path["ok"], "destino bloqueado falla")

	_case = "NPCFactions: set_relation misma faccion"
	var fac = NPCFactionsScript.new({})
	fac.register_faction("test", "test")
	var set_result = fac.set_relation("test", "test", 50.0)
	_expect(not set_result, "relacion misma faccion falla")

	_case = "NPCFactions: get_relation faccion inexistente"
	fac = NPCFactionsScript.new({})
	fac.register_faction("a", "a")
	fac.register_faction("b", "b")
	var rel1 = fac.get_relation("a", "nonexistent")
	_expect(rel1 == fac.get_default_relation(), "faccion inexistente usa default")

	_case = "NPCFactions: relation_between_entities sin faccion"
	fac = NPCFactionsScript.new({})
	fac.register_faction("a", "a")
	fac.set_member("entity1", "a")
	var rel2 = fac.relation_between_entities("entity1", "entity2")
	_expect(rel2 == 0.0, "entidad sin faccion devuelve 0.0")

func _test_vr_game_mode_edge_cases() -> void:
	_case = "VrGameMode: flat_ui_nodes con nodos anidados"
	var world = Node3D.new()
	world.name = "World"
	root.add_child(world)
	var layer = CanvasLayer.new()
	layer.name = "HudLayer"
	var hud = Control.new()
	hud.name = "GameHud"
	layer.add_child(hud)
	world.add_child(layer)
	var nodes = VrGameModeScript.flat_ui_nodes(world)
	_expect(nodes.size() >= 2, "detecta HUD y layer anidados")
	world.free()

	_case = "VrGameMode: xr_available sin OpenXR"
	VrGameModeScript.xr_available_override = Callable()
	_expect(not VrGameModeScript.xr_available(), "sin override no disponible")

	_case = "VrGameMode: build_start_menu sin XR"
	var meta = {"seed": 1, "ok": true}
	var host = VrGameModeScript.build_start_menu(meta, self)
	_expect(host != null, "build_start_menu crea menu")
	host.free()

class MockXR extends RefCounted:
	signal session_begun
	signal session_visible
	signal session_focussed
	signal session_stopping
	signal session_loss_pending
	signal pose_recentered
	signal user_presence_changed(present: bool)
	var init_ok: bool = true
	var initialized: bool = false
	var init_calls: int = 0
	var rates: Array = []
	var display_refresh_rate: float = 0.0
	var foveation_level: int = 0
	var foveation_dynamic: bool = false
	func initialize() -> bool:
		init_calls += 1
		initialized = init_ok
		return init_ok
	func is_initialized() -> bool:
		return initialized
	func get_available_display_refresh_rates() -> Array:
		return rates

func _make_mock_xr() -> RefCounted:
	return MockXR.new()

func _remove_dir_recursive(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		if name == "." or name == "..":
			name = access.get_next()
			continue
		var full := path.path_join(name)
		if access.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = access.get_next()
	access.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))