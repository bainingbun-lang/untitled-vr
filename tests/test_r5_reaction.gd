extends SceneTree

const CharacterModelScript = preload("res://core/game/character_model.gd")
const GameSessionScript = preload("res://core/game/game_session.gd")
const NpcDismemberReactionScript = preload("res://core/game/npc_dismember_reaction.gd")
const EventBusScript = preload("res://core/event_bus.gd")
const ModHooksScript = preload("res://core/game/mod_hooks.gd")

var _failures: Array = []
var _checks: int = 0
var _case: String = ""
var _root: Node3D = null
var _model: CharacterModel = null
var _reaction = null
var _bus
var _hooks

func _initialize() -> void:
	await process_frame
	_root = Node3D.new()
	root.add_child(_root)
	GameSessionScript.gore_enabled = true
	GameSessionScript.gore_level = 2
	
	_hooks = ModHooksScript.instance()
	_hooks.reset()
	_bus = EventBusScript.new()
	_hooks.bind(_bus)
	
	var results = []
	
	results.append(["reaccion: NPC cae al perder pierna", await test_fall_on_leg_loss()])
	results.append(["reaccion: NPC gatea al perder ambas piernas", await test_crawl_on_both_legs_lost()])
	results.append(["reaccion: NPC huye al perder brazo armado", await test_flee_on_armed_arm_loss()])
	results.append(["reaccion: suscripcion a limb_severed funciona", await test_limb_severed_subscription()])
	results.append(["reaccion: sin reaccion si gore desactivado", await test_no_reaction_gore_disabled()])
	
	for r in results:
		print("%s: %s" % [r[0], "PASS" if r[1] else "FAIL"])
	
	var all_passed = true
	for r in results:
		if not r[1]: 
			all_passed = false
	
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	
	_hooks.reset()
	_bus.clear()
	
	if all_passed:
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		for failure in _failures:
			print("FAIL: " + str(failure))
		quit(1)


func test_fall_on_leg_loss() -> bool:
	_model = CharacterModelScript.spawn(_root, "civil", 12345)
	await _wait_loaded()
	
	_reaction = NpcDismemberReactionScript.new()
	_model.add_child(_reaction)
	await process_frame
	
	var initial_state = _reaction.get_reaction_state()
	_expect(initial_state == "idle", "estado inicial idle: %s" % initial_state)
	
	# Check bus is bound
	var bus = ModHooksScript.instance().get_bus()
	_expect(bus != null, "bus esta enlazado")
	if bus == null:
		return false
	
	var leg_bone = _model.find_bone("leg.l")
	if leg_bone < 0:
		_expect(false, "hueso leg.l no encontrado")
		return false
	
	_model.accumulate_damage("leg.l", 200.0)
	await process_frame
	
	# Emit limb_severed event to simulate full integration
	var emit_result = ModHooksScript.emit("limb_severed", {
		"target": str(_model.get_instance_id()),
		"limb": "leg.l",
		"point": _model.global_position + Vector3(0, 0.5, 0),
		"severity": 1.0
	})
	_expect(emit_result.get("ok", false) == true, "evento emitido correctamente: %s" % str(emit_result.get("errors", [])))
	await process_frame
	
	var state = _reaction.get_reaction_state()
	_expect(state == "fall", "estado cambia a fall tras perder pierna: %s" % state)
	return state == "fall"


func test_crawl_on_both_legs_lost() -> bool:
	var model2 = CharacterModelScript.spawn(_root, "civil", 54321)
	await _wait_loaded_model(model2)
	
	var reaction2 = NpcDismemberReactionScript.new()
	model2.add_child(reaction2)
	await process_frame
	
	model2.accumulate_damage("leg.l", 200.0)
	await process_frame
	ModHooksScript.emit("limb_severed", {
		"target": str(model2.get_instance_id()),
		"limb": "leg.l",
		"point": model2.global_position + Vector3(0, 0.5, 0),
		"severity": 1.0
	})
	await process_frame
	
	model2.accumulate_damage("leg.r", 200.0)
	await process_frame
	ModHooksScript.emit("limb_severed", {
		"target": str(model2.get_instance_id()),
		"limb": "leg.r",
		"point": model2.global_position + Vector3(0, 0.5, 0),
		"severity": 1.0
	})
	await process_frame
	
	var state = reaction2.get_reaction_state()
	_expect(state == "crawl", "estado cambia a crawl tras perder ambas piernas: %s" % state)
	return state == "crawl"


func test_flee_on_armed_arm_loss() -> bool:
	var model3 = CharacterModelScript.spawn(_root, "soldier", 999)
	await _wait_loaded_model(model3)
	
	model3.set_meta("armed", true)
	
	var reaction3 = NpcDismemberReactionScript.new()
	model3.add_child(reaction3)
	await process_frame
	
	var arm_bone = model3.find_bone("arm.r")
	if arm_bone < 0:
		_expect(false, "hueso arm.r no encontrado")
		return false
	
	model3.accumulate_damage("arm.r", 200.0)
	await process_frame
	ModHooksScript.emit("limb_severed", {
		"target": str(model3.get_instance_id()),
		"limb": "arm.r",
		"point": model3.global_position + Vector3(0, 1.5, 0),
		"severity": 1.0
	})
	await process_frame
	
	var state = reaction3.get_reaction_state()
	_expect(state == "flee", "estado cambia a flee tras perder brazo armado: %s" % state)
	return state == "flee"


func test_limb_severed_subscription() -> bool:
	var model4 = CharacterModelScript.spawn(_root, "civil", 111)
	await _wait_loaded_model(model4)
	
	var reaction4 = NpcDismemberReactionScript.new()
	model4.add_child(reaction4)
	await process_frame
	
	var bus = ModHooksScript.instance().get_bus()
	_expect(bus.has_subscribers("limb_severed"), "bus tiene suscriptores a limb_severed")
	
	var sub_count = 0
	for key in bus._by_event.get("limb_severed", []):
		var sub = bus._subscriptions.get(key, {})
		if sub.get("owner", "").begins_with("npc_dismember_reaction"):
			sub_count += 1
	
	_expect(sub_count > 0, "hay suscripcion de npc_dismember_reaction a limb_severed")
	return bus.has_subscribers("limb_severed") and sub_count > 0


func test_no_reaction_gore_disabled() -> bool:
	GameSessionScript.gore_enabled = false
	
	var model5 = CharacterModelScript.spawn(_root, "civil", 222)
	await _wait_loaded_model(model5)
	
	var reaction5 = NpcDismemberReactionScript.new()
	model5.add_child(reaction5)
	await process_frame
	
	model5.accumulate_damage("leg.l", 200.0)
	await process_frame
	await process_frame
	
	var state = reaction5.get_reaction_state()
	_expect(state == "idle", "sin reaccion si gore desactivado: %s" % state)
	
	GameSessionScript.gore_enabled = true
	return state == "idle"


func _wait_loaded() -> void:
	while not _model.is_loaded():
		await process_frame


func _wait_loaded_model(model: CharacterModel) -> void:
	while not model.is_loaded():
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])