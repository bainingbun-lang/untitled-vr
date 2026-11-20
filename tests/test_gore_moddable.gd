extends SceneTree

const ModHooksScript = preload("res://core/game/mod_hooks.gd")
const ModApiScript = preload("res://core/mod_api.gd")
const GoreFxScript = preload("res://core/game/gore_fx.gd")
const EventBusScript = preload("res://core/event_bus.gd")

const GORE_MOD := "test.gore_mod"

class GoreModTarget extends RefCounted:
	var api
	var blood_count: int = 0
	var puddle_count: int = 0
	var decal_count: int = 0
	var part_count: int = 0
	var dismember_count: int = 0
	var last_payloads: Dictionary = {}

	func on_blood_spawned(payload: Dictionary) -> void:
		blood_count += 1
		last_payloads["blood"] = payload.duplicate(true)

	func on_puddle_created(payload: Dictionary) -> void:
		puddle_count += 1
		last_payloads["puddle"] = payload.duplicate(true)

	func on_decal_created(payload: Dictionary) -> void:
		decal_count += 1
		last_payloads["decal"] = payload.duplicate(true)

	func on_part_created(payload: Dictionary) -> void:
		part_count += 1
		last_payloads["part"] = payload.duplicate(true)

	func on_dismemberment(payload: Dictionary) -> void:
		dismember_count += 1
		last_payloads["dismember"] = payload.duplicate(true)


var _checks := 0
var _failures: Array = []
var _bus
var _hooks
var _parent_node


func _initialize() -> void:
	await process_frame
	_hooks = ModHooksScript.instance()
	_hooks.reset()
	_bus = EventBusScript.new()
	_hooks.bind(_bus)

	GoreFxScript.set_gore_enabled(true)

	_parent_node = Node3D.new()
	get_root().add_child(_parent_node)

	_test_gore_events_exist()
	_test_gore_events_emit()
	_test_gore_mod_hooks()
	_test_gore_profile_from_mod()

	_parent_node.queue_free()
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


func _test_gore_events_exist() -> void:
	var events: Dictionary = ModHooksScript.EVENTS
	_expect(events.has("gore_blood_spawned"), "evento gore_blood_spawned debe existir")
	_expect(events.has("gore_puddle_created"), "evento gore_puddle_created debe existir")
	_expect(events.has("gore_decal_created"), "evento gore_decal_created debe existir")
	_expect(events.has("gore_part_created"), "evento gore_part_created debe existir")
	_expect(events.has("gore_dismemberment"), "evento gore_dismemberment debe existir")

	var blood_spec := ModHooksScript.event_spec("gore_blood_spawned")
	_expect(blood_spec.has("payload"), "gore_blood_spawned debe tener payload")
	_expect(blood_spec["payload"].has("target"), "payload debe tener target")
	_expect(blood_spec["payload"].has("position"), "payload debe tener position")
	_expect(blood_spec["payload"].has("normal"), "payload debe tener normal")
	_expect(blood_spec["payload"].has("amount"), "payload debe tener amount")
	_expect(blood_spec["payload"].has("jet"), "payload debe tener jet")

	var puddle_spec := ModHooksScript.event_spec("gore_puddle_created")
	_expect(puddle_spec["payload"].has("size"), "gore_puddle_created debe tener size")

	var decal_spec := ModHooksScript.event_spec("gore_decal_created")
	_expect(decal_spec["payload"].has("size"), "gore_decal_created debe tener size")

	var part_spec := ModHooksScript.event_spec("gore_part_created")
	_expect(part_spec["payload"].has("zone"), "gore_part_created debe tener zone")
	_expect(part_spec["payload"].has("count"), "gore_part_created debe tener count")

	var dismember_spec := ModHooksScript.event_spec("gore_dismemberment")
	_expect(dismember_spec["payload"].has("limb"), "gore_dismemberment debe tener limb")
	_expect(dismember_spec["payload"].has("severity"), "gore_dismemberment debe tener severity")
	_expect(dismember_spec["payload"].has("piece_count"), "gore_dismemberment debe tener piece_count")


func _test_gore_events_emit() -> void:
	GoreFxScript.clear()

	var blood_seen := [0, {}]
	_bus.subscribe("gore_blood_spawned", func(p): blood_seen[0] += 1; blood_seen[1] = p.duplicate(true), "test.blood")
	GoreFxScript.blood_hit(_parent_node, Vector3(0, 1, 0), Vector3.UP, 10.0)
	_expect(blood_seen[0] == 1, "blood_hit debe emitir gore_blood_spawned")
	_expect(blood_seen[1].has("target"), "payload debe tener target")
	_expect(blood_seen[1].has("amount"), "payload debe tener amount")
	_expect(float(blood_seen[1]["amount"]) == 10.0, "amount debe ser 10.0")

	var puddle_seen := [0, {}]
	_bus.subscribe("gore_puddle_created", func(p): puddle_seen[0] += 1; puddle_seen[1] = p.duplicate(true), "test.puddle")
	GoreFxScript.puddle(_parent_node, Vector3(0, 1, 0), Vector3.UP, 0.5)
	_expect(puddle_seen[0] == 1, "puddle debe emitir gore_puddle_created")
	_expect(puddle_seen[1].has("size"), "payload debe tener size")

	var decal_seen := [0, {}]
	_bus.subscribe("gore_decal_created", func(p): decal_seen[0] += 1; decal_seen[1] = p.duplicate(true), "test.decal")
	GoreFxScript._add_decal(_parent_node, Vector3(0, 1, 0), Vector3.UP, 0.3)
	_expect(decal_seen[0] == 1, "_add_decal debe emitir gore_decal_created")

	var part_seen := [0, {}]
	_bus.subscribe("gore_part_created", func(p): part_seen[0] += 1; part_seen[1] = p.duplicate(true), "test.part")
	var dismember_seen := [0, {}]
	_bus.subscribe("gore_dismemberment", func(p): dismember_seen[0] += 1; dismember_seen[1] = p.duplicate(true), "test.dismember")
	GoreFxScript.dismember(_parent_node, Vector3(0, 1, 0), 1.0, "arm", 3)
	_expect(part_seen[0] == 3, "dismember debe emitir gore_part_created 3 veces")
	_expect(dismember_seen[0] == 1, "dismember debe emitir gore_dismemberment una vez")
	_expect(dismember_seen[1].has("limb"), "dismemberment payload debe tener limb")
	_expect(str(dismember_seen[1]["limb"]) == "arm", "limb debe ser 'arm'")

	GoreFxScript.clear()


func _test_gore_mod_hooks() -> void:
	GoreFxScript.clear()

	var manifest := {
		"id": GORE_MOD,
		"version": "1.0.0",
		"hooks": {
			"gore_blood_spawned": ["on_blood_spawned"],
			"gore_puddle_created": ["on_puddle_created"],
			"gore_decal_created": ["on_decal_created"],
			"gore_part_created": ["on_part_created"],
			"gore_dismemberment": ["on_dismemberment"],
		},
		"permissions": ["read_events"],
	}

	var api = ModApiScript.new(GORE_MOD, _bus, ["read_events"], manifest)
	var target := GoreModTarget.new()
	target.api = api
	var registered := api.bind_target(target)
	_expect(registered == 5, "deben registrarse 5 hooks de gore, se registraron %d" % registered)

	GoreFxScript.blood_hit(_parent_node, Vector3.ZERO, Vector3.UP, 5.0)
	GoreFxScript.puddle(_parent_node, Vector3.ZERO, Vector3.UP, 0.3)
	GoreFxScript._add_decal(_parent_node, Vector3.ZERO, Vector3.UP, 0.2)
	GoreFxScript.dismember(_parent_node, Vector3.ZERO, 0.5, "leg", 2)

	_expect(target.blood_count == 2, "mod debe recibir gore_blood_spawned 2 veces (explicit + dismember)")
	_expect(target.puddle_count == 1, "mod debe recibir gore_puddle_created")
	_expect(target.decal_count == 3, "mod debe recibir gore_decal_created 3 veces (blood_hit internal + explicit + dismember internal)")
	_expect(target.part_count == 2, "mod debe recibir gore_part_created 2 veces")
	_expect(target.dismember_count == 1, "mod debe recibir gore_dismemberment")

	api._release()
	GoreFxScript.clear()


func _test_gore_profile_from_mod() -> void:
	var ContentRegistryScript = preload("res://core/game/content_registry.gd")
	var registry := ContentRegistryScript.reset()

	var gore_profile := {
		"type": "gore_profile",
		"id": "test.gore:custom",
		"name": "Custom Gore",
		"level": "extreme",
		"decal_limit": 100,
		"particle_limit": 200,
		"parts_limit": 20,
		"puddle_limit": 30,
	}

	var result: Dictionary = registry.validate("gore_profile", gore_profile, "test.gore")
	_expect(bool(result.get("ok", false)), "gore_profile debe validarse: %s" % str(result.get("errors", [])))

	var def: Dictionary = result.get("definition", {})
	_expect(def.has("level"), "def debe tener level")
	_expect(str(def["level"]) == "extreme", "level debe ser extreme")
	_expect(int(def["decal_limit"]) == 100, "decal_limit debe ser 100")

	registry.set_mod("test.gore", {"gore_profile": {"test.gore:custom": {"def": def, "meta": {}}}}, 100)
	var profile: Dictionary = registry.definition("gore_profile", "test.gore:custom")
	_expect(not profile.is_empty(), "perfil debe cargarse via set_mod")

	GoreFxScript.apply_profile(profile)
	_expect(GoreFxScript.limit_decals == 64, "decal_limit debe clamp a MAX_DECALS (64)")
	_expect(GoreFxScript.limit_parts == 12, "parts_limit debe clamp a MAX_PARTS (12)")

	registry.reset()
	GoreFxScript.clear()