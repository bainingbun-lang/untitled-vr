extends SceneTree

const ModProfileScript = preload("res://core/mod_profile.gd")

const ROOT := "user://test_mod_profile_root"

var _failures: Array = []
var _case := ""


func _init() -> void:
	_cleanup()

	_case = "make normaliza duplicados y orden"
	_test_make()

	_case = "nombre invalido"
	_test_invalid_name()

	_case = "save y load identicos"
	_test_round_trip()

	_case = "list incluye el perfil"
	_test_list()

	_case = "diff puro"
	_test_diff()

	_case = "mark_last_good y last_good"
	_test_last_good()

	_case = "delete exige confirm"
	_test_delete()

	_cleanup()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _test_make() -> void:
	var result := ModProfileScript.make("perfil-a", ["mod.b", "mod.a", "mod.b", "mod.a"])
	_expect(result["ok"], "make debe ser ok: %s" % str(result["errors"]))
	var profile: Dictionary = result["profile"]
	_expect(profile["name"] == "perfil-a", "el nombre debe conservarse")
	_expect(profile["mods"] == ["mod.a", "mod.b"], "mods debe quedar unico y ordenado")
	_expect(profile["experimental"] == false, "experimental debe ser false por defecto")


func _test_invalid_name() -> void:
	var invalid := ["Mayusculas", "con espacio", "", "a".repeat(41), "acentuado-é"]
	for name in invalid:
		var result := ModProfileScript.make(name, [])
		_expect(not result["ok"], "nombre invalido debe fallar: '%s'" % name)
		_expect(not (result["errors"] as Array).is_empty(), "debe reportar error para '%s'" % name)

	_expect(ModProfileScript.validate_name("ok-123"), "nombre valido debe aceptarse")
	_expect(not ModProfileScript.validate_name("No-ok"), "mayusculas deben rechazarse")


func _test_round_trip() -> void:
	var profiles = ModProfileScript.new(ROOT)
	var profile := ModProfileScript.make("principal", ["beta.mod", "alpha.mod"], true)
	_expect(profile["ok"], "make del perfil debe ser ok: %s" % str(profile["errors"]))

	var saved: Dictionary = profiles.save(profile["profile"])
	_expect(saved["ok"], "save debe ser ok: %s" % str(saved["errors"]))

	var loaded: Dictionary = profiles.load_profile("principal")
	_expect(loaded["ok"], "load_profile debe ser ok: %s" % str(loaded["errors"]))
	var loaded_profile: Dictionary = loaded["profile"]
	_expect(loaded_profile["name"] == "principal", "el nombre debe ser identico")
	_expect(loaded_profile["mods"] == ["alpha.mod", "beta.mod"], "mods debe ser identico y ordenado")
	_expect(loaded_profile["experimental"] == true, "experimental debe conservarse")

	var missing: Dictionary = profiles.load_profile("no-existe")
	_expect(not missing["ok"], "load_profile de inexistente debe fallar")


func _test_list() -> void:
	var profiles = ModProfileScript.new(ROOT)
	var names: Array = profiles.list()
	_expect(names.has("principal"), "list debe incluir principal")
	_expect(not names.has("last_good"), "list no debe incluir last_good")


func _test_diff() -> void:
	var result := ModProfileScript.diff(["a", "b"], {"mods": ["b", "c"]})
	_expect(result["to_load"] == ["c"], "to_load debe ser [c]")
	_expect(result["to_unload"] == ["a"], "to_unload debe ser [a]")

	var empty := ModProfileScript.diff([], {"mods": []})
	_expect((empty["to_load"] as Array).is_empty(), "diff vacio no debe cargar nada")
	_expect((empty["to_unload"] as Array).is_empty(), "diff vacio no debe descargar nada")


func _test_last_good() -> void:
	var profiles = ModProfileScript.new(ROOT)
	var marked: Dictionary = profiles.mark_last_good("principal")
	_expect(marked["ok"], "mark_last_good debe ser ok: %s" % str(marked["errors"]))
	_expect(profiles.last_good() == "principal", "last_good debe devolver principal")

	var invalid: Dictionary = profiles.mark_last_good("No-ok")
	_expect(not invalid["ok"], "mark_last_good con nombre invalido debe fallar")

	var names: Array = profiles.list()
	_expect(names.has("principal"), "list debe seguir incluyendo principal")
	_expect(not names.has("last_good"), "last_good.json no debe listarse como perfil")


func _test_delete() -> void:
	var profiles = ModProfileScript.new(ROOT)

	var refused: Dictionary = profiles.delete("principal", false)
	_expect(not refused["ok"], "delete sin confirm debe fallar")
	_expect(
		(refused["errors"] as Array).has("borrado requiere confirm=true"),
		"delete sin confirm debe explicar el motivo"
	)
	_expect(profiles.load_profile("principal")["ok"], "el perfil no debe borrarse sin confirm")

	var accepted: Dictionary = profiles.delete("principal", true)
	_expect(accepted["ok"], "delete con confirm debe funcionar")
	_expect(not profiles.load_profile("principal")["ok"], "el perfil ya no debe existir")
	_expect(not (profiles.list() as Array).has("principal"), "list ya no debe incluir principal")


func _cleanup() -> void:
	_remove_dir(ROOT)


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
