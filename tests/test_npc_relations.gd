extends SceneTree

const NPCRelationsScript = preload("res://core/npc/npc_relations.gd")
const NPCFactionsScript = preload("res://core/npc/npc_factions.gd")
const NPCBehavior = preload("res://core/npc/npc_behavior.gd")
const NPCStateMachine = preload("res://core/npc/npc_state_machine.gd")
const NPCPersonality = preload("res://core/npc/npc_personality.gd")
const NPCNeeds = preload("res://core/npc/npc_needs.gd")
const NPCMemory = preload("res://core/npc/npc_memory.gd")
const NPCRoutine = preload("res://core/npc/npc_routine.gd")
const NPCController = preload("res://core/npc/npc_controller.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""


func _init() -> void:
	_case = "limites de afinidad"
	var rel = NPCRelationsScript.new()
	_expect_eq(rel.get_base_affinity("player", "npc"), 0.0, "afinidad por defecto neutra")
	_expect(rel.set_affinity("player", "npc", 250.0), "fijar afinidad alta")
	_expect_eq(rel.get_base_affinity("player", "npc"), 100.0, "tope superior 100")
	_expect(rel.set_affinity("player", "npc", -250.0), "fijar afinidad baja")
	_expect_eq(rel.get_base_affinity("player", "npc"), -100.0, "tope inferior -100")
	_expect(not rel.set_affinity("", "npc", 5.0), "id de origen vacio rechazado")
	_expect(not rel.set_affinity("player", "npc|otro", 5.0), "id con separador rechazado")
	_expect(not rel.set_affinity("player", "player", 5.0), "par consigo mismo rechazado")
	_expect_eq(rel.get_affinity("player", "player"), 0.0, "consulta degenerada neutra")
	_expect(not bool(rel.apply_event("player", "npc", "unknown")["ok"]), "evento desconocido rechazado")
	_expect(not bool(rel.apply_event("player", "npc", "help", {"intensity": "x"})["ok"]), "intensity no numerico rechazado")

	_case = "decaimiento hacia neutro"
	var decay = NPCRelationsScript.new({"decay_rate": 2.0})
	decay.set_affinity("player", "npc", 100.0)
	decay.tick(10.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), 80.0, "decaimiento 2.0/s durante 10s")
	decay.tick(100.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), 0.0, "decaimiento no cruza el neutro")
	decay.set_affinity("player", "npc", -50.0)
	decay.tick(10.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), -30.0, "decaimiento de negativo hacia 0")
	decay.tick(5.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), -20.0, "decaimiento continuo")
	decay.set_decay_rate(10.0)
	decay.tick(5.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), 0.0, "tasa mayor absorbe el resto")
	decay.tick(-5.0)
	_expect_eq(decay.get_base_affinity("player", "npc"), 0.0, "delta negativo no aumenta afinidad")

	_case = "eventos con tope por tick"
	var events = NPCRelationsScript.new({"tick_cap": 40.0})
	var helped: Dictionary = events.apply_event("player", "npc", "help")
	_expect(bool(helped["ok"]) and is_equal_approx(float(helped["applied"]), 12.0), "ayuda suma 12")
	var attacked: Dictionary = events.apply_event("player", "npc", "aggression")
	_expect(bool(attacked["ok"]) and is_equal_approx(float(attacked["applied"]), -25.0), "agresion resta 25")
	var gifted: Dictionary = events.apply_event("player", "npc", "gift")
	_expect(bool(gifted["ok"]), "regalo dentro del tope se acepta")
	_expect(bool(gifted["capped"]), "regalo se limita por presupuesto")
	_expect(is_equal_approx(float(gifted["applied"]), 3.0), "solo caben 3 del regalo")
	_expect_eq(events.get_tick_usage("player"), 40.0, "presupuesto del tick agotado")
	_expect_eq(events.get_base_affinity("player", "npc"), -10.0, "neto 12 - 25 + 3")
	events.tick(0.0)
	_expect_eq(events.get_tick_usage("player"), 0.0, "tick renueva el presupuesto")
	var gifted_again: Dictionary = events.apply_event("player", "npc", "gift")
	_expect(is_equal_approx(float(gifted_again["applied"]), 8.0), "nuevo tick aplica el regalo completo")
	_expect_eq(events.get_base_affinity("player", "npc"), -2.0, "afinidad acumulada -2")
	events.set_tick_cap(1000.0)
	var soft_gift: Dictionary = events.apply_event("player", "npc", "gift", {"intensity": 0.5})
	_expect(is_equal_approx(float(soft_gift["applied"]), 4.0), "intensity escala el evento")
	var zero_event: Dictionary = events.apply_event("player", "npc", "help", {"intensity": 0.0})
	_expect(str(zero_event["reason"]) == "zero_delta", "intensity 0 no cambia afinidad")

	_case = "facciones y herencia"
	var factions = NPCFactionsScript.new()
	_expect(factions.register_faction("guild", "Gremio"), "registrar faccion gremio")
	_expect(factions.register_faction("bandits", "Bandidos"), "registrar faccion bandidos")
	_expect(not factions.register_faction("guild"), "faccion duplicada rechazada")
	_expect(factions.set_member("hero", "guild"), "hero pertenece al gremio")
	_expect(factions.set_member("ally", "guild"), "ally pertenece al gremio")
	_expect(factions.set_member("thug", "bandits"), "thug pertenece a bandidos")
	_expect(not factions.set_member("ghost", "unknown"), "miembro de faccion inexistente rechazado")
	_expect(factions.set_relation("guild", "bandits", -80.0), "relacion entre facciones")
	_expect_eq(factions.get_relation("bandits", "guild"), -80.0, "relacion entre facciones simetrica")
	_expect(not factions.set_relation("guild", "guild", 10.0), "relacion de faccion consigo misma rechazada")
	_expect_eq(factions.relation_between_entities("hero", "stranger"), 0.0, "sin faccion ajena no hay herencia")
	var inherited = NPCRelationsScript.new({"faction_weight": 0.5}, factions)
	inherited.set_affinity("hero", "thug", 60.0)
	_expect_eq(inherited.get_base_affinity("hero", "thug"), 60.0, "afinidad individual intacta")
	_expect_eq(inherited.get_affinity("hero", "thug"), 20.0, "herencia 60 + (-80 * 0.5)")
	inherited.set_affinity("hero", "ally", 40.0)
	_expect_eq(inherited.get_affinity("hero", "ally"), 90.0, "misma faccion suma 100 * 0.5")
	inherited.set_affinity("hero", "stranger", 60.0)
	_expect_eq(inherited.get_affinity("hero", "stranger"), 60.0, "sin dato de faccion no se altera la afinidad")
	inherited.set_faction_weight(0.25)
	_expect_eq(inherited.get_affinity("hero", "thug"), 40.0, "peso de faccion ajustable")
	_expect_eq(inherited.get_affinity("hero", "ally"), 65.0, "peso de faccion ajustable en aliados")
	inherited.set_faction_weight(0.5)
	inherited.set_affinity("hero", "thug", -100.0)
	_expect_eq(inherited.get_affinity("hero", "thug"), -100.0, "afinidad efectiva limitada a -100")

	_case = "actitud con histeresis"
	var attitudes = NPCRelationsScript.new({
		"attitude_border": 25.0,
		"hysteresis": 12.0,
		"faction_weight": 0.0,
	})
	attitudes.set_affinity("player", "npc", 30.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_NEUTRAL, "30 no basta para amistoso (37)")
	attitudes.set_affinity("player", "npc", 40.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_FRIENDLY, "40 pasa a amistoso")
	attitudes.set_affinity("player", "npc", 20.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_FRIENDLY, "20 conserva amistoso (13)")
	attitudes.set_affinity("player", "npc", 10.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_NEUTRAL, "10 vuelve a neutro")
	attitudes.set_affinity("player", "npc", -40.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_HOSTILE, "-40 pasa a hostil")
	attitudes.set_affinity("player", "npc", -20.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_HOSTILE, "-20 conserva hostil (-13)")
	attitudes.set_affinity("player", "npc", -10.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_NEUTRAL, "-10 vuelve a neutro")
	attitudes.set_hysteresis(0.0)
	attitudes.set_affinity("player", "npc", 25.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_FRIENDLY, "sin histeresis 25 ya es amistoso")
	attitudes.set_affinity("player", "npc", -25.0)
	_expect_eq(attitudes.get_attitude("player", "npc"), attitudes.ATTITUDE_HOSTILE, "sin histeresis -25 ya es hostil")

	_case = "serializacion y restauracion exacta"
	var saved_factions = NPCFactionsScript.new()
	saved_factions.register_faction("town", "Pueblo")
	saved_factions.register_faction("outlaws", "Forajidos")
	saved_factions.set_member("player", "town")
	saved_factions.set_member("enemy", "outlaws")
	saved_factions.set_relation("town", "outlaws", -70.0)
	var saved = NPCRelationsScript.new({
		"decay_rate": 3.0,
		"tick_cap": 55.0,
		"faction_weight": 0.4,
		"attitude_border": 30.0,
		"hysteresis": 10.0,
	}, saved_factions)
	saved.set_affinity("player", "enemy", -60.0)
	saved.set_affinity("player", "merchant", 45.0)
	saved.get_attitude("player", "enemy")
	saved.get_attitude("player", "merchant")
	saved.apply_event("player", "enemy", "help")
	var snapshot: Dictionary = saved.to_dict()
	_expect_eq(int(snapshot["version"]), 1, "version del snapshot")
	_expect_eq((snapshot["affinities"] as Array).size(), 2, "afinidades serializadas")
	_expect_eq((snapshot["attitudes"] as Array).size(), 2, "actitudes serializadas")
	_expect_eq((snapshot["tick_usage"] as Array).size(), 1, "presupuesto serializado")
	_expect((snapshot["factions"] as Dictionary).has("factions"), "snapshot de facciones incluido")
	var restored = NPCRelationsScript.new({}, NPCFactionsScript.new())
	_expect(restored.restore(snapshot), "restaurar snapshot")
	_expect_eq(restored.to_dict(), snapshot, "snapshot regenerado identico")
	_expect_eq(restored.get_affinity("player", "enemy"), saved.get_affinity("player", "enemy"), "afinidad efectiva restaurada")
	_expect_eq(restored.get_tick_usage("player"), saved.get_tick_usage("player"), "presupuesto restaurado")
	_expect_eq(restored.factions.get_faction("player"), "town", "faccion restaurada")
	_expect_eq(restored.factions.get_relation("town", "outlaws"), -70.0, "relacion de facciones restaurada")
	var json_text: String = JSON.stringify(snapshot)
	var parsed: Variant = JSON.parse_string(json_text)
	_expect(parsed != null, "JSON del snapshot valido")
	var from_json = NPCRelationsScript.new({}, NPCFactionsScript.new())
	_expect(from_json.restore(parsed), "restaurar desde JSON")
	_expect_eq(from_json.to_dict(), snapshot, "round-trip JSON exacto")

	_case = "datos corruptos"
	var before: Dictionary = restored.to_dict()
	var bad_version: Dictionary = snapshot.duplicate(true)
	bad_version["version"] = 99
	_expect(not restored.restore(bad_version), "version futura rechazada")
	_expect_eq(restored.to_dict(), before, "restore con version invalida no muta")
	var bad_value: Dictionary = snapshot.duplicate(true)
	bad_value["affinities"][0]["value"] = 500.0
	_expect(not restored.restore(bad_value), "afinidad fuera de rango rechazada")
	_expect_eq(restored.to_dict(), before, "restore con valor invalido no muta")
	var bad_type: Dictionary = snapshot.duplicate(true)
	bad_type["decay_rate"] = "3"
	_expect(not restored.restore(bad_type), "campo numerico como texto rechazado")
	_expect_eq(restored.to_dict(), before, "restore con tipo invalido no muta")
	var bad_attitude: Dictionary = snapshot.duplicate(true)
	bad_attitude["attitudes"][0]["attitude"] = "aliado"
	_expect(not restored.restore(bad_attitude), "actitud desconocida rechazada")
	_expect_eq(restored.to_dict(), before, "restore con actitud invalida no muta")
	var bad_member: Dictionary = snapshot.duplicate(true)
	bad_member["factions"]["members"][0]["faction"] = "ghost"
	_expect(not restored.restore(bad_member), "miembro de faccion inexistente rechazado")
	_expect_eq(restored.to_dict(), before, "restore con faccion invalida no muta")
	var bad_container: Dictionary = snapshot.duplicate(true)
	bad_container["affinities"] = {}
	_expect(not restored.restore(bad_container), "contenedor de afinidades invalido rechazado")
	_expect_eq(restored.to_dict(), before, "restore con contenedor invalido no muta")
	var bad_duplicate: Dictionary = snapshot.duplicate(true)
	bad_duplicate["affinities"].append((snapshot["affinities"] as Array)[0].duplicate(true))
	_expect(not restored.restore(bad_duplicate), "par de afinidad duplicado rechazado")
	_expect_eq(restored.to_dict(), before, "restore con duplicado no muta")
	var bad_missing: Dictionary = snapshot.duplicate(true)
	bad_missing.erase("factions")
	_expect(not restored.restore(bad_missing), "snapshot sin facciones rechazado")
	_expect_eq(restored.to_dict(), before, "restore incompleto no muta")
	_expect(not restored.restore("no es un dictionary"), "snapshot no Dictionary rechazado")
	_expect_eq(restored.to_dict(), before, "restore con tipo base invalido no muta")

	_case = "determinismo"
	var det_a: Dictionary = _deterministic_snapshot(["a", "b", "c"])
	var det_b: Dictionary = _deterministic_snapshot(["a", "b", "c"])
	var det_c: Dictionary = _deterministic_snapshot(["c", "a", "b"])
	_expect_eq(det_a, det_b, "misma secuencia produce el mismo snapshot")
	_expect_eq(det_a, det_c, "orden de insercion no altera el snapshot serializado")
	_expect_eq(det_a, _deterministic_snapshot(["a", "b", "c"]), "snapshots repetidos son identicos")
	var det_json: Variant = JSON.parse_string(JSON.stringify(det_a))
	var det_restored = NPCRelationsScript.new({}, NPCFactionsScript.new())
	_expect(det_restored.restore(det_json), "snapshot determinista se restaura")
	_expect_eq(det_restored.to_dict(), det_a, "JSON determinista tras restauracion")

	_case = "adaptador de lectura para NPCBehavior"
	var controller: NPCController = _cold_controller()
	var neutral_rel = NPCRelationsScript.new({"faction_weight": 0.0})
	var neutral_ctx: Dictionary = neutral_rel.behavior_context("player", "guard")
	_expect_eq(str(neutral_ctx["relation_attitude"]), "neutral", "adaptador reporta neutral")
	_expect(not neutral_ctx.has("danger") and not neutral_ctx.has("sociability"), "neutral no inyecta sesgo")
	var neutral_result: Dictionary = NPCBehavior.new(controller, null, {"hysteresis": 0.0}).select(neutral_ctx)
	_expect_eq(str(neutral_result["id"]), "idle", "sin relacion predomina inaccion")
	var hostile_rel = NPCRelationsScript.new({"faction_weight": 0.0})
	hostile_rel.set_affinity("player", "guard", -90.0)
	var hostile_ctx: Dictionary = hostile_rel.behavior_context("player", "guard")
	_expect_eq(str(hostile_ctx["relation_attitude"]), "hostil", "adaptador reporta hostil")
	_expect(hostile_ctx.has("danger"), "hostil inyecta peligro")
	var hostile_result: Dictionary = NPCBehavior.new(controller, null, {"hysteresis": 0.0}).select(hostile_ctx)
	_expect_eq(str(hostile_result["id"]), "flee", "relacion hostil provoca huida")
	var friendly_rel = NPCRelationsScript.new({"faction_weight": 0.0})
	friendly_rel.set_affinity("player", "guard", 90.0)
	var friendly_ctx: Dictionary = friendly_rel.behavior_context("player", "guard")
	_expect_eq(str(friendly_ctx["relation_attitude"]), "amistoso", "adaptador reporta amistoso")
	_expect(friendly_ctx.has("sociability"), "amistoso inyecta sociabilidad")
	var friendly_result: Dictionary = NPCBehavior.new(controller, null, {"hysteresis": 0.0}).select(friendly_ctx)
	_expect_eq(str(friendly_result["id"]), "converse", "relacion amistosa provoca conversacion")
	var merged: Dictionary = friendly_rel.merge_behavior_context({"from": Vector2i(2, 3)}, "player", "guard")
	_expect_eq(merged["from"], Vector2i(2, 3), "merge conserva claves previas")
	_expect(merged.has("relation_attitude"), "merge agrega claves de relacion")
	_expect_eq(str(friendly_rel.get_last_attitude("player", "guard")), "amistoso", "consulta de adaptador conserva histeresis")

	_finish()


func _deterministic_snapshot(order: Array) -> Dictionary:
	var factions = NPCFactionsScript.new()
	for id in ["one", "two"]:
		factions.register_faction(id, id)
	factions.set_relation("one", "two", -30.0)
	var rel = NPCRelationsScript.new({"faction_weight": 0.5}, factions)
	for other in order:
		rel.set_affinity("player", str(other), float(str(other).length() * 10))
		rel.apply_event("player", str(other), "help")
		rel.get_attitude("player", str(other))
	rel.factions.set_member("player", "one")
	for other in order:
		rel.factions.set_member(str(other), "two")
	return rel.to_dict()


func _cold_controller() -> NPCController:
	var personality = NPCPersonality.new({
		"fear": 0.0,
		"sociability": 0.0,
		"curiosity": 0.0,
		"aggressiveness": 0.0,
		"bravery": 1.0,
		"confidence": 1.0,
	})
	return NPCController.new(
		NPCStateMachine.new(),
		personality,
		NPCNeeds.new(),
		NPCMemory.new(),
		NPCRoutine.new([])
	)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])


func _expect_eq(actual, expected, message: String) -> void:
	_expect(actual == expected, "%s (esperado %s, obtenido %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)
