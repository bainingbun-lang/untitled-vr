extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")
const ModApiScript = preload("res://core/mod_api.gd")
const DamageableScript = preload("res://core/game/damageable.gd")
const WeaponSystemScript = preload("res://core/game/weapon_system.gd")

const HOOK_MOD := "untitled.example-hook"

class HookTarget extends RefCounted:
	var api
	var shots: int = 0
	var damage_calls: int = 0

	func on_weapon_fired(payload: Dictionary) -> void:
		shots += 1
		api.set_value(payload, "hook_shot_count", shots, "read_events")

	func on_damage_dealt(payload: Dictionary) -> void:
		damage_calls += 1
		api.set_value(payload, "amount", float(payload.get("amount", 0.0)) * 1.5)

	func bad_modify(payload: Dictionary) -> void:
		payload["amount"] = 999.0

	func bad_error(_payload: Dictionary) -> Dictionary:
		return {"ok": false, "error": "boom"}

	func hog(_payload: Dictionary) -> void:
		while api.checkpoint():
			pass

	func mark_order(payload: Dictionary) -> void:
		var current: Array = payload.get("order", [])
		current.append(api.module_id)
		payload["order"] = current

	func slow_handler(_payload: Dictionary) -> void:
		var value := 0
		for i in range(200000):
			value += i


var _checks := 0
var _failures: Array = []
var _bus
var _hooks


func _initialize() -> void:
	await process_frame
	_hooks = ModHooksScript.instance()
	_hooks.reset()
	_bus = EventBusScript.new()
	_hooks.bind(_bus)

	_test_catalog()
	_test_manifest_hooks()
	_test_denied_permissions()
	_test_failure_isolation()
	_test_dependency_order()
	_test_game_integration()
	_bus.clear()

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


func _test_catalog() -> void:
	var events: Dictionary = ModHooksScript.EVENTS
	_expect(events.size() == 19, "deben existir 19 eventos publicos, hay %d" % events.size())
	for raw_event in events:
		var event := str(raw_event)
		var seen: Array = [0, {}]
		var handler := func(payload):
			seen[0] = int(seen[0]) + 1
			seen[1] = payload.duplicate(true)
		var subscription_id: int = _bus.subscribe(event, handler, "test.catalogo")
		var sample: Dictionary = {}
		var defaults: Dictionary = ModHooksScript.event_spec(event).get("payload", {})
		for key in defaults:
			sample[key] = defaults[key]
		var result: Dictionary = ModHooksScript.emit(event, sample)
		_expect(int(seen[0]) == 1, "%s debe emitirse una sola vez" % event)
		_expect(int(result.get("handled", 0)) == 1, "%s debe tener un handler atendido" % event)
		var delivered: Dictionary = seen[1]
		var payload_ok := true
		for key in defaults:
			if not delivered.has(key) or delivered[key] != defaults[key]:
				payload_ok = false
		_expect(payload_ok, "%s debe entregar su payload documentado: %s" % [event, str(delivered)])
		_bus.unsubscribe(subscription_id)


func _test_manifest_hooks() -> void:
	var path := "res://mods/example.hook/mod.json"
	_expect(FileAccess.file_exists(path), "el manifiesto de example.hook debe existir")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(not manifest.is_empty(), "el manifiesto debe ser JSON valido")

	var api = ModApiScript.new(HOOK_MOD, _bus, [], manifest)
	var target := HookTarget.new()
	target.api = api
	var registered := api.bind_target(target)
	_expect(registered == 2, "los hooks declarativos deben registrar 2 handlers, se registraron %d" % registered)
	_expect(api.has_permission("read_events"), "example.hook debe poder leer eventos")
	_expect(api.has_permission("modify_damage"), "example.hook debe poder modificar dano")
	_expect(not api.network_request(), "la red debe estar denegada por defecto")

	var fired: Dictionary = ModHooksScript.emit("weapon_fired", {
		"weapon_id": "pistol", "damage": 20.0, "pellets": 1,
	})
	_expect(target.shots == 1, "el hook declarativo debe contar un disparo")
	_expect(
		int(fired.get("payload", {}).get("hook_shot_count", 0)) == 1,
		"el hook debe anotar el numero de disparos en el payload"
	)
	_expect((fired.get("modified_by", []) as Array).has(HOOK_MOD), "el mod debe aparecer como modificador")

	var damaged: Dictionary = ModHooksScript.emit("damage_dealt", {"amount": 20.0})
	_expect(target.damage_calls == 1, "el hook de dano debe ejecutarse una vez")
	_expect(
		is_equal_approx(float(damaged.get("payload", {}).get("amount", 0.0)), 30.0),
		"el mod debe multiplicar el dano 20 -> 30"
	)
	api._release()


func _test_denied_permissions() -> void:
	var api = ModApiScript.new("test.denied", _bus, ["read_events"])
	var payload := {"amount": 10.0}
	_expect(not api.request("spawn_entities"), "spawn_entities debe denegarse sin permiso")
	_expect(not api.request("inventory"), "inventory debe denegarse sin permiso")
	_expect(not api.network_request(), "network siempre se deniega")
	_expect(not api.set_value(payload, "amount", 99.0), "set_value sin modify_damage debe fallar")
	_expect(is_equal_approx(float(payload["amount"]), 10.0), "el payload denegado no debe cambiar")
	_expect(not _hooks.is_disabled("test.denied"), "una accion denegada no desactiva al mod")
	api._release()


func _test_failure_isolation() -> void:
	var bad := ModApiScript.new("test.bad", _bus, ["read_events"])
	var target := HookTarget.new()
	target.api = bad
	_expect(bad.subscribe("damage_dealt", Callable(target, "bad_modify")) > 0, "suscripcion del mod malicioso")
	var result: Dictionary = ModHooksScript.emit("damage_dealt", {"amount": 10.0})
	_expect(not bool(result.get("ok", true)), "la modificacion ilegal debe marcar el evento como fallido")
	_expect(
		is_equal_approx(float(result.get("payload", {}).get("amount", 0.0)), 10.0),
		"el dano modificado sin permiso debe restaurarse"
	)
	_expect(_hooks.is_disabled("test.bad"), "el mod que modifica sin permiso debe desactivarse")
	_expect(not _bus.has_subscribers("damage_dealt"), "al desactivarse deben retirarse sus suscripciones")
	var after: Dictionary = ModHooksScript.emit("damage_dealt", {"amount": 10.0})
	_expect(int(after.get("handled", 0)) == 0, "el mod desactivado no debe volver a ejecutarse")
	bad._release()

	var failing := ModApiScript.new("test.failing", _bus, ["read_events"])
	var failing_target := HookTarget.new()
	failing_target.api = failing
	failing.subscribe("wave_started", Callable(failing_target, "bad_error"))
	var failed: Dictionary = ModHooksScript.emit("wave_started", {"wave": 1})
	_expect(not bool(failed.get("ok", true)), "un handler con error debe fallar el evento")
	_expect(_hooks.is_disabled("test.failing"), "un mod que devuelve error debe desactivarse")
	failing._release()

	var hog_api := ModApiScript.new("test.hog", _bus, ["read_events"])
	var hog_target := HookTarget.new()
	hog_target.api = hog_api
	hog_api.subscribe("map_loaded", Callable(hog_target, "hog"))
	_hooks.configure(100000, 200)
	var hogged: Dictionary = ModHooksScript.emit("map_loaded", {"map_id": "test"})
	_expect(_hooks.is_disabled("test.hog"), "un mod que agota el presupuesto debe desactivarse")
	_expect(bool(hogged.get("ok", true)), "el evento debe terminar y no afectar al juego")
	_expect(_hooks.instruction_count("test.hog") >= 200, "debe contarse el presupuesto de instrucciones")
	_hooks.configure()
	hog_api._release()

	var slow := ModApiScript.new("test.slow", _bus, ["read_events"])
	var slow_target := HookTarget.new()
	slow_target.api = slow
	slow.subscribe("item_picked", Callable(slow_target, "slow_handler"))
	_hooks.configure(1, 10000)
	var timed: Dictionary = ModHooksScript.emit("item_picked", {"item_id": "pistol"})
	_expect(not bool(timed.get("ok", true)), "el limite de tiempo debe marcar una violacion")
	_expect(_hooks.is_disabled("test.slow"), "el mod lento debe desactivarse")
	_hooks.configure()
	slow._release()


func _test_dependency_order() -> void:
	var candidates: Array = [
		{"manifest": {"id": "test.c", "version": "1.0.0", "priority": 100, "depends": {"test.b": "*"}}},
		{"manifest": {"id": "test.b", "version": "1.0.0", "priority": 100, "depends": {"test.a": "*"}}},
		{"manifest": {"id": "test.a", "version": "1.0.0", "priority": 100, "depends": {}}},
	]
	var order: Array = _hooks.dependency_order(candidates)
	_expect(
		order == ["test.a", "test.b", "test.c"],
		"el orden debe colocar dependencias primero: %s" % str(order)
	)


func _test_game_integration() -> void:
	var seen: Array = [0, {}]
	var handler := func(payload):
		seen[0] = int(seen[0]) + 1
		seen[1] = payload.duplicate(true)
	_bus.subscribe("damage_dealt", handler, "test.integration")

	var damageable = DamageableScript.new()
	damageable.take_zone_damage("head", 10.0, Vector3.ZERO, Vector3.UP)
	_expect(int(seen[0]) == 1, "Damageable debe emitir damage_dealt una vez")
	_expect(
		is_equal_approx(float((seen[1] as Dictionary).get("amount", 0.0)), 20.0),
		"el multiplicador de cabeza debe aplicarse al payload del evento"
	)
	_expect(is_equal_approx(damageable.health, 80.0), "la vida debe quedar en 80 tras 20 de dano")
	damageable.free()

	var jam_seen: Array = [0]
	var jam_handler := func(_payload): jam_seen[0] = int(jam_seen[0]) + 1
	_bus.subscribe("weapon_jammed", jam_handler, "test.integration")
	var weapon = WeaponSystemScript.new()
	weapon.set_manual_lock("pistol", "encasquillado")
	weapon.set_manual_lock("pistol", "encasquillado")
	_expect(int(jam_seen[0]) == 1, "weapon_jammed debe emitirse una sola vez por encasquillamiento")
	weapon.free()
