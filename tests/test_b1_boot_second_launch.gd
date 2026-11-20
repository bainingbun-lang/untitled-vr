extends SceneTree

const BootstrapScript = preload("res://core/vr/vr_bootstrap.gd")
const SessionScript = preload("res://core/game/game_session.gd")
const BootScene = preload("res://scenes/vr/vr_boot.tscn")
const ModProfileScript = preload("res://core/mod_profile.gd")
const ModBackupScript = preload("res://core/mod_backup.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

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


func _initialize() -> void:
	await process_frame
	_test_second_launch_clean_state()
	await _test_second_launch_dirty_user_data()
	await _test_second_launch_corrupt_profile()
	await _test_second_launch_corrupt_backup()
	await _test_vr_bootstrap_shutdown()
	await _test_vr_boot_cleanup()
	_reset_global_state()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_second_launch_clean_state() -> void:
	_case = "segundo arranque con estado limpio"
	var mock := MockXR.new()
	mock.rates = [72.0, 90.0]
	BootstrapScript.interface_override = mock

	# Primer arranque
	var vp1 := SubViewport.new()
	root.add_child(vp1)
	var result1: Dictionary = BootstrapScript.boot(vp1, self)
	_expect(bool(result1["xr_active"]), "primer arranque OK: %s" % result1)
	_expect(BootstrapScript.is_xr_active(), "XR activo tras primer arranque")

	# Simular cierre limpio
	BootstrapScript.active = null
	BootstrapScript.last_result = {"xr_active": false, "reason": "not_run"}
	vp1.use_xr = false
	vp1.free()
	await process_frame

	# Segundo arranque
	var vp2 := SubViewport.new()
	root.add_child(vp2)
	var result2: Dictionary = BootstrapScript.boot(vp2, self)
	_expect(bool(result2["xr_active"]), "segundo arranque OK: %s" % result2)
	_expect(BootstrapScript.is_xr_active(), "XR activo tras segundo arranque")
	vp2.free()
	await process_frame


func _test_second_launch_dirty_user_data() -> void:
	_case = "segundo arranque con user:// sucio"
	# Crear archivos basura en user://
	var dirty_dirs := ["user://mods", "user://profiles", "user://backups", "user://saves"]
	for d in dirty_dirs:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	var f := FileAccess.open("user://mods/broken.txt", FileAccess.WRITE)
	if f:
		f.store_string("basura")
		f.close()
	f = FileAccess.open("user://profiles/corrupt.json", FileAccess.WRITE)
	if f:
		f.store_string("no es json valido")
		f.close()
	f = FileAccess.open("user://backups/invalid", FileAccess.WRITE)
	if f:
		f.store_string("invalido")
		f.close()

	var mock := MockXR.new()
	mock.rates = [72.0]
	BootstrapScript.interface_override = mock

	var vp := SubViewport.new()
	root.add_child(vp)
	var result: Dictionary = BootstrapScript.boot(vp, self)
	_expect(bool(result["xr_active"]), "arranque con user:// sucio OK: %s" % result)
	vp.free()
	await process_frame

	# Limpiar
	for d in dirty_dirs:
		_remove_dir_recursive(d)


func _test_second_launch_corrupt_profile() -> void:
	_case = "perfil corrupto en user:// no rompe el arranque"
	var profile := ModProfileScript.new("user://profiles")
	# Crear perfil corrupto
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://profiles"))
	var f := FileAccess.open("user://profiles/bad.json", FileAccess.WRITE)
	if f:
		f.store_string("{ json invalido")
		f.close()

	var result := profile.load_profile("bad")
	_expect(not result["ok"], "perfil corrupto reporta error: %s" % result["errors"])
	_expect(result["profile"] == {}, "perfil corrupto devuelve profile vacio")

	# Verificar que list() no crashea
	var names := profile.list()
	_expect(typeof(names) == TYPE_ARRAY, "list() no crashea con perfil corrupto: %s" % names)

	# Limpiar
	_remove_dir_recursive("user://profiles")


func _test_second_launch_corrupt_backup() -> void:
	_case = "backup corrupto en user:// no rompe el arranque"
	var backup := ModBackupScript.new("user://backups")
	# Crear backup corrupto
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://backups/badbackup"))
	var f := FileAccess.open("user://backups/badbackup/manifest.json", FileAccess.WRITE)
	if f:
		f.store_string("{ json invalido")
		f.close()

	var result := backup.verify("badbackup")
	_expect(not result["ok"], "backup corrupto reporta error: %s" % result["errors"])

	var restore_result := backup.restore("badbackup", "user://mods_test")
	_expect(not restore_result["ok"], "restaurar backup corrupto falla: " + str(restore_result["errors"]))

	# Verificar que list() no crashea
	var ids := backup.list()
	_expect(typeof(ids) == TYPE_ARRAY, "list() no crashea con backup corrupto: %s" % ids)

	# Limpiar
	_remove_dir_recursive("user://backups")


func _test_vr_bootstrap_shutdown() -> void:
	_case = "VrBootstrap.shutdown limpia XR correctamente"
	var mock := MockXR.new()
	mock.rates = [72.0]
	BootstrapScript.interface_override = mock

	var vp := SubViewport.new()
	root.add_child(vp)
	var result: Dictionary = BootstrapScript.boot(vp, self)
	_expect(bool(result["xr_active"]), "arranque OK")

	# Verificar estado antes de shutdown
	_expect(BootstrapScript.active != null, "active no es null")
	_expect(bool(BootstrapScript.last_result["xr_active"]), "last_result xr_active true")
	_expect(vp.use_xr, "viewport use_xr true")

	# Llamar shutdown
	if BootstrapScript.active != null and BootstrapScript.active.has_method("shutdown"):
		BootstrapScript.active.shutdown()
	else:
		_failures.append("%s: VrBootstrap no tiene metodo shutdown()" % _case)

	# Verificar estado después de shutdown
	_expect(not vp.use_xr, "viewport use_xr false tras shutdown")
	_expect(BootstrapScript.active == null, "active null tras shutdown")
	_expect(not bool(BootstrapScript.last_result.get("xr_active", false)), "last_result xr_active false tras shutdown")

	vp.free()
	await process_frame


func _test_vr_boot_cleanup() -> void:
	_case = "VrBoot limpia recursos en _exit_tree"
	var mock := MockXR.new()
	mock.rates = [72.0]
	BootstrapScript.interface_override = mock

	var boot := BootScene.instantiate()
	root.add_child(boot)
	await process_frame

	# Verificar que se crearon los nodos XR
	_expect(boot.get("origin") != null, "XROrigin3D creado")
	_expect(boot.get("xr_camera") != null, "XRCamera3D creado")
	_expect((boot.get("controllers") as Array).size() == 2, "dos controladores creados")

	# Simular salida del árbol (cambio de escena o cierre)
	boot.call("_exit_tree")
	await process_frame

	# Verificar limpieza
	_expect(boot.get("origin") == null or not is_instance_valid(boot.get("origin")), "origin limpiado")
	_expect(boot.get("xr_camera") == null or not is_instance_valid(boot.get("xr_camera")), "xr_camera limpiado")
	_expect(boot.get("menu") == null, "menu limpiado")
	_expect(boot.get("host") == null, "host limpiado")
	_expect(boot.get("calibration") == null, "calibration limpiada")
	_expect(boot.get("flow") == null, "flow limpiado")

	boot.free()
	await process_frame


func _reset_global_state() -> void:
	BootstrapScript.interface_override = null
	BootstrapScript.active = null
	BootstrapScript.last_result = {"xr_active": false, "reason": "not_run"}
	SessionScript.platform = ""
	SessionScript.platform_override = ""
	SessionScript.vr_menu_confirmed = false
	SessionScript.start_override = Callable()


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


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])