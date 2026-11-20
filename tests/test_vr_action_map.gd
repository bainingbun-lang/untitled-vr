extends SceneTree

const ActionMapScript = preload("res://core/vr/vr_action_map.gd")

class FakeSource extends RefCounted:
	var calls: Array = []
	var pose: Transform3D = Transform3D(Basis(), Vector3(1.0, 2.0, 3.0))
	var tracking: bool = true

	func is_pressed(action: String) -> bool:
		calls.append(action)
		return action == "grip"

	func get_pose(_hand: String) -> Transform3D:
		return pose

	func is_tracking(_hand: String) -> bool:
		return tracking

	func get_joint(_hand: String, _joint: String) -> Transform3D:
		return Transform3D.IDENTITY


var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _init() -> void:
	_case = "defaults por plataforma"
	_test_defaults()
	_case = "rebind y conflicto"
	_test_rebind()
	_case = "round-trip de perfil"
	_test_round_trip()
	_case = "perfil corrupto"
	_test_corrupt()
	_case = "accion desconocida"
	_test_unknown()
	_case = "resolucion de eventos"
	_test_events()
	_case = "adaptador InputSource"
	_test_adapter()

	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _test_defaults() -> void:
	var map = ActionMapScript.new()
	for platform in ActionMapScript.PLATFORMS:
		var candidate := map.default_profile(platform)
		_expect(not candidate.is_empty(), "default de %s no vacio" % platform)
		_expect(bool(map.validate_profile(candidate)["ok"]), "default de %s valido" % platform)
		_expect(str(candidate.get("platform", "")) == str(platform), "plataforma de %s" % platform)
		var signatures: Array = []
		for action in ActionMapScript.ACTIONS:
			_expect(candidate["bindings"].has(action), "%s tiene %s" % [platform, action])
			signatures.append(map.signature(candidate["bindings"][action]))
		_expect(_unique(signatures), "%s sin conflictos entre acciones" % platform)
	_expect(map.default_profile("psvr").is_empty(), "plataforma desconocida sin defaults")
	_expect(str(map.get_binding("grab", map.default_profile("quest"))["source_action"]) == "grip", \
		"grab de quest usa source_action grip")
	_expect(str(map.get_binding("grab", map.default_profile("pc_teclado"))["id"]) == "E", \
		"grab de teclado usa E")
	_expect(str(map.get_binding("menu", map.default_profile("pc_teclado"))["id"]) == "Escape", \
		"menu de teclado usa Escape")
	_expect(str(map.get_binding("move", map.default_profile("android_tactil"))["kind"]) == "axis", \
		"move tactil es eje")


func _test_rebind() -> void:
	var map = ActionMapScript.new("quest")
	var original: Dictionary = map.profile()
	var changed := map.rebind("grab", {"id": "grip_right", "hand": "right"})
	_expect(bool(changed["ok"]), "rebind aceptado: %s" % str(changed["errors"]))
	_expect(str(map.get_binding("grab")["id"]) == "grip_right", "id reasignado")
	_expect(str(map.get_binding("grab")["device"]) == "quest_controller", "campos no afectados se conservan")
	_expect(str(original["bindings"]["grab"]["id"]) == "grip", "perfil original no mutado")

	var conflict := map.rebind("trigger", {"id": "grip_right", "hand": "right"})
	_expect(not bool(conflict["ok"]), "conflicto rechazado")
	_expect(_has_error(conflict, "conflicto"), "conflicto reportado")
	_expect(str(map.get_binding("trigger")["id"]) == "trigger", "rebind fallido no muta")

	var swap := map.rebind("trigger", {"id": "grip_right", "hand": "right"}, true)
	_expect(bool(swap["ok"]), "swap aceptado: %s" % str(swap["errors"]))
	_expect(str(map.get_binding("trigger")["id"]) == "grip_right", "trigger toma la entrada")
	_expect(str(map.get_binding("grab")["id"]) == "trigger", "grab recibe la entrada intercambiada")
	_expect(bool(map.validate_profile(map.profile())["ok"]), "perfil tras swap sigue valido")

	_expect(not bool(map.rebind("fly", {"id": "x"})["ok"]), "rebind de accion desconocida rechazado")
	_expect(not bool(map.rebind("grab", {"extra": 1})["ok"]), "clave extra en rebind rechazada")


func _test_round_trip() -> void:
	var map = ActionMapScript.new("pc_vr")
	_expect(bool(map.rebind("menu", {"id": "menu_new"})["ok"]), "rebind previo al round-trip")
	var serialized: Dictionary = map.to_dictionary()
	var restored := ActionMapScript.new().from_dictionary(serialized)
	_expect(restored == serialized, "restauracion identica al Dictionary")
	_expect(bool(ActionMapScript.new().validate_profile(restored)["ok"]), "perfil restaurado valido")
	var reordered := {
		"bindings": map.to_dictionary()["bindings"],
		"platform": "pc_vr",
		"version": 1,
	}
	_expect(ActionMapScript.new().from_dictionary(reordered) == serialized, \
		"orden de claves no altera la restauracion")
	var nested: Dictionary = restored["bindings"]["menu"].duplicate(true)
	nested["id"] = "otro"
	restored["bindings"]["menu"] = nested
	_expect(str(serialized["bindings"]["menu"]["id"]) == "menu_new", "restauracion sin alias mutables")


func _test_corrupt() -> void:
	var map = ActionMapScript.new()
	var valid: Dictionary = map.profile()
	var cases: Array = []
	cases.append({})
	cases.append("no es un perfil")
	var bad_version: Dictionary = valid.duplicate(true)
	bad_version["version"] = 2
	cases.append(bad_version)
	var bad_platform: Dictionary = valid.duplicate(true)
	bad_platform["platform"] = "psvr"
	cases.append(bad_platform)
	var extra_key: Dictionary = valid.duplicate(true)
	extra_key["extra"] = true
	cases.append(extra_key)
	var extra_action: Dictionary = valid.duplicate(true)
	extra_action["bindings"]["fly"] = valid["bindings"]["grab"].duplicate(true)
	cases.append(extra_action)
	var missing_binding: Dictionary = valid.duplicate(true)
	missing_binding["bindings"].erase("move")
	cases.append(missing_binding)
	var bad_binding: Dictionary = valid.duplicate(true)
	bad_binding["bindings"]["grab"] = "no es binding"
	cases.append(bad_binding)
	var bad_threshold: Dictionary = valid.duplicate(true)
	bad_threshold["bindings"]["grab"]["threshold"] = 3.0
	cases.append(bad_threshold)
	var bad_hand: Dictionary = valid.duplicate(true)
	bad_hand["bindings"]["grab"]["hand"] = "both"
	cases.append(bad_hand)
	var bad_id: Dictionary = valid.duplicate(true)
	bad_id["bindings"]["grab"]["id"] = "grip|otro"
	cases.append(bad_id)
	var duplicate: Dictionary = valid.duplicate(true)
	duplicate["bindings"]["grab"]["id"] = "trigger"
	duplicate["bindings"]["grab"]["hand"] = "any"
	cases.append(duplicate)

	for candidate in cases:
		var checked := map.validate_profile(candidate)
		_expect(not bool(checked["ok"]), "perfil corrupto rechazado: %s" % str(candidate).substr(0, 32))
		_expect(not (checked["errors"] as Array).is_empty(), "perfil corrupto reporta errores")
		_expect(map.from_dictionary(candidate).is_empty(), "from_dictionary rechaza corrupto")
	_expect(map.profile() == valid, "validacion no muta el perfil activo")


func _test_unknown() -> void:
	var map = ActionMapScript.new("quest")
	var event := {
		"platform": "quest",
		"kind": "button",
		"device": "quest_controller",
		"id": "grip",
		"hand": "left",
		"pressed": true,
	}
	_expect(map.get_binding("fly").is_empty(), "binding de accion desconocida vacio")
	_expect(map.get_source_action("fly").is_empty(), "source_action de accion desconocida vacio")
	var resolved := map.resolve("fly", event)
	_expect(not bool(resolved["ok"]), "resolve rechaza accion desconocida")
	_expect(_has_error(resolved, "accion desconocida"), "error explicito de accion desconocida")
	_expect(map.action_from_event({"kind": "gesture", "device": "otro", "id": "x"}) == "", \
		"evento sin accion conocida devuelve cadena vacia")
	_expect(not bool(map.validate_event({"kind": "button", "device": "x", "id": ""})["ok"]), \
		"evento con id vacio rechazado")
	_expect(not bool(map.validate_event({"kind": "button", "device": "x", "id": "y", "pressed": 1})["ok"]), \
		"evento con pressed no bool rechazado")


func _test_events() -> void:
	var map = ActionMapScript.new("quest")
	var grab_event := {
		"platform": "quest",
		"kind": "button",
		"device": "quest_controller",
		"id": "grip",
		"hand": "left",
		"pressed": true,
	}
	_expect(map.action_from_event(grab_event) == "grab", "evento grip resuelve grab")
	var resolved := map.resolve("grab", grab_event)
	_expect(bool(resolved["ok"]) and bool(resolved["matched"]), "resolve grab con match")
	_expect(float(resolved["value"]) == 1.0, "valor digital unitario")

	var released: Dictionary = grab_event.duplicate(true)
	released["pressed"] = false
	_expect(map.action_from_event(released) == "", "pressed=false no dispara grab")
	var wrong_platform: Dictionary = grab_event.duplicate(true)
	wrong_platform["platform"] = "pc_vr"
	_expect(map.action_from_event(wrong_platform) == "", "plataforma distinta no dispara")
	var wrong_hand: Dictionary = grab_event.duplicate(true)
	wrong_hand["hand"] = "right"
	_expect(map.action_from_event(wrong_hand) == "", "mano distinta no dispara")
	var implicit: Dictionary = grab_event.duplicate(true)
	implicit.erase("pressed")
	_expect(map.action_from_event(implicit) == "grab", "evento sin pressed implica pulso")

	var move_event := {
		"kind": "axis",
		"device": "quest_controller",
		"id": "thumbstick",
		"hand": "left",
		"value": Vector2(0.9, 0.1),
	}
	_expect(map.action_from_event(move_event) == "move", "eje resuelve move")
	var move_resolved := map.resolve("move", move_event)
	_expect(move_resolved["value"] == Vector2(0.9, 0.1), "valor analogico conservado")
	var weak: Dictionary = move_event.duplicate(true)
	weak["value"] = Vector2(0.1, 0.0)
	_expect(map.action_from_event(weak) == "", "eje bajo umbral no dispara")
	_expect(map.action_from_event({
		"platform": "pc_teclado", "kind": "key", "device": "keyboard", "id": "Escape",
	}, map.default_profile("pc_teclado")) == "menu", "tecla Escape resuelve menu en teclado")
	_expect(map.action_from_event({
		"platform": "android_tactil", "kind": "touch", "device": "touchscreen", "id": "grab_pad", "hand": "left",
	}, map.default_profile("android_tactil")) == "grab", "toque resuelve grab en android")


func _test_adapter() -> void:
	var map = ActionMapScript.new("quest")
	var fake := FakeSource.new()
	var adapter = ActionMapScript.InputSourceAdapter.new(fake, map)
	_expect(adapter.is_pressed("grab"), "adaptador traduce grab a grip")
	_expect(fake.calls == ["grip"], "adaptador llama al source con la accion mapeada")
	_expect(adapter.get_pose("left") == fake.pose, "adaptador delega get_pose")
	_expect(adapter.is_tracking("right"), "adaptador delega is_tracking")
	_expect(adapter.get_joint("left", "thumb") == Transform3D.IDENTITY, "adaptador delega get_joint")
	_expect(not adapter.is_pressed("fly"), "accion desconocida no consulta al source")
	_expect(fake.calls == ["grip"], "accion desconocida no anade llamadas")

	adapter.configure(ActionMapScript.new("pc_teclado"))
	_expect(not adapter.is_pressed("grab"), "teclado no mapea a InputSource")
	_expect(fake.calls == ["grip"], "teclado no consulta al source")

	_expect(bool(map.rebind("grab", {"source_action": "squeeze"})["ok"]), "rebind de source_action")
	adapter.configure(map)
	_expect(not adapter.is_pressed("grab"), "adaptador usa el nuevo source_action")
	_expect(fake.calls == ["grip", "squeeze"], "adaptador propaga el rebind al source")

	var empty_adapter = ActionMapScript.InputSourceAdapter.new()
	_expect(not empty_adapter.is_pressed("grab"), "adaptador sin source devuelve false")
	_expect(empty_adapter.get_pose("left") == Transform3D.IDENTITY, "adaptador sin source usa pose identidad")
	_expect(not empty_adapter.is_tracking("left"), "adaptador sin source no rastrea")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _has_error(result: Dictionary, needle: String) -> bool:
	for error in result.get("errors", []):
		if str(error).contains(needle):
			return true
	return false


func _unique(values: Array) -> bool:
	for i in range(values.size()):
		for j in range(i + 1, values.size()):
			if values[i] == values[j]:
				return false
	return true
