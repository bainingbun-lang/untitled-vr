extends SceneTree

const EventBusScript = preload("res://core/event_bus.gd")

var _failures: Array = []
var _case := ""


func _init() -> void:
	_case = "subscribe y emit"
	_test_subscribe_emit()

	_case = "orden por prioridad"
	_test_priority_order()

	_case = "unsubscribe por id"
	_test_unsubscribe()

	_case = "unsubscribe por owner"
	_test_unsubscribe_owner()

	_case = "nombres invalidos"
	_test_invalid_names()

	_case = "callable invalido"
	_test_invalid_callable()

	_case = "detener propagacion"
	_test_stop_propagation()

	_case = "snapshot durante emit"
	_test_snapshot()

	_case = "handler invalidado antes de invocarse"
	_test_invalidated_handler()

	_case = "emit sin suscriptores"
	_test_emit_without_subscribers()

	_case = "clear"
	_test_clear()

	if _failures.is_empty():
		print("TEST_OK")
		quit(0)
	else:
		print("TEST_FAIL: ", "; ".join(_failures))
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append("%s: %s" % [_case, message])


func _test_subscribe_emit() -> void:
	var bus = EventBusScript.new()
	var received: Array = []
	var handler := func(payload): received.append(payload)

	var subscription_id: int = bus.subscribe("test.evento", handler, "mod.a")
	_expect(subscription_id > 0, "subscribe debe devolver un id > 0, se obtuvo %d" % subscription_id)

	var result: Dictionary = bus.emit("test.evento", {"n": 7})
	_expect(result["ok"], "emit debe ser ok")
	_expect(result["handled"] == 1, "handled debe ser 1, se obtuvo %d" % result["handled"])
	_expect(received.size() == 1, "el handler debe invocarse una vez, se invoco %d" % received.size())
	if received.size() == 1:
		_expect(received[0] is Dictionary, "el payload debe ser Dictionary")
		_expect(received[0].get("n") == 7, "payload incorrecto: %s" % str(received[0]))


func _test_priority_order() -> void:
	var bus = EventBusScript.new()
	var order: Array = []
	var high := func(_payload): order.append("200")
	var low := func(_payload): order.append("50")

	bus.subscribe("test.prio", low, "mod.a", 50)
	bus.subscribe("test.prio", high, "mod.b", 200)
	bus.emit("test.prio")
	_expect(order == ["200", "50"], "orden por prioridad incorrecto: %s" % str(order))

	var tie: Array = []
	var first := func(_payload): tie.append("primero")
	var second := func(_payload): tie.append("segundo")
	bus.subscribe("test.empate", first, "mod.a", 100)
	bus.subscribe("test.empate", second, "mod.b", 100)
	bus.emit("test.empate")
	_expect(tie == ["primero", "segundo"], "empate debe respetar orden de suscripcion: %s" % str(tie))


func _test_unsubscribe() -> void:
	var bus = EventBusScript.new()
	var calls := [0]
	var handler := func(_payload): calls[0] += 1
	var subscription_id: int = bus.subscribe("test.unsub", handler, "mod.a")

	_expect(bus.unsubscribe(subscription_id), "el primer unsubscribe debe devolver true")
	_expect(not bus.unsubscribe(subscription_id), "el segundo unsubscribe debe devolver false")

	var result: Dictionary = bus.emit("test.unsub")
	_expect(calls[0] == 0, "el handler eliminado no debe invocarse")
	_expect(result["handled"] == 0, "handled debe ser 0, se obtuvo %d" % result["handled"])
	_expect(not bus.has_subscribers("test.unsub"), "no debe quedar suscriptor")


func _test_unsubscribe_owner() -> void:
	var bus = EventBusScript.new()
	var handler := func(_payload): pass
	bus.subscribe("test.a1", handler, "mod.a")
	bus.subscribe("test.a2", handler, "mod.a")
	bus.subscribe("test.b1", handler, "mod.b")

	_expect(bus.unsubscribe_owner("mod.a") == 2, "debe eliminar 2 suscripciones de mod.a")
	_expect(not bus.has_subscribers("test.a1"), "test.a1 no debe tener suscriptores")
	_expect(not bus.has_subscribers("test.a2"), "test.a2 no debe tener suscriptores")
	_expect(bus.has_subscribers("test.b1"), "mod.b no debe verse afectado")
	_expect(bus.unsubscribe_owner("mod.a") == 0, "una segunda llamada debe devolver 0")


func _test_invalid_names() -> void:
	var bus = EventBusScript.new()
	var handler := func(_payload): pass
	for name in ["sinpunto", "Mayus.x", ""]:
		_expect(
			bus.subscribe(name, handler, "mod.a") == -1,
			"subscribe('%s') debe devolver -1" % name
		)
		var result: Dictionary = bus.emit(name)
		_expect(not result["ok"], "emit('%s') debe tener ok=false" % name)
		_expect(result["handled"] == 0, "emit('%s') no debe manejar nada" % name)
		_expect(result["errors"].size() >= 1, "emit('%s') debe incluir un error" % name)


func _test_invalid_callable() -> void:
	var bus = EventBusScript.new()
	_expect(
		bus.subscribe("test.callable", Callable(), "mod.a") == -1,
		"un Callable vacio debe devolver -1"
	)


func _test_stop_propagation() -> void:
	var bus = EventBusScript.new()
	var order: Array = []
	var stopper := func(_payload):
		order.append("stop")
		return true
	var after := func(_payload): order.append("after")

	bus.subscribe("test.stop", stopper, "mod.a", 200)
	bus.subscribe("test.stop", after, "mod.a", 50)
	var result: Dictionary = bus.emit("test.stop")

	_expect(result["stopped"], "stopped debe ser true")
	_expect(result["handled"] == 1, "handled debe ser 1, se obtuvo %d" % result["handled"])
	_expect(order == ["stop"], "los siguientes handlers no deben ejecutarse: %s" % str(order))


func _test_snapshot() -> void:
	var bus = EventBusScript.new()
	var calls := {"first": 0, "second": 0}
	var first_id_ref := [0]
	var second_handler := func(_payload): calls["second"] = calls["second"] + 1
	var first_handler := func(_payload):
		calls["first"] = calls["first"] + 1
		bus.unsubscribe(first_id_ref[0])
		bus.subscribe("test.snapshot", second_handler, "mod.b")
	first_id_ref[0] = bus.subscribe("test.snapshot", first_handler, "mod.a")

	var first_result: Dictionary = bus.emit("test.snapshot")
	_expect(calls["first"] == 1, "el primer handler debe ejecutarse una vez")
	_expect(
		calls["second"] == 0,
		"el handler suscrito durante el emit no debe invocarse en ese emit"
	)
	_expect(
		first_result["handled"] == 1,
		"handled del primer emit debe ser 1, se obtuvo %d" % first_result["handled"]
	)

	var second_result: Dictionary = bus.emit("test.snapshot")
	_expect(
		calls["second"] == 1,
		"el handler suscrito durante el emit debe invocarse en el siguiente emit"
	)
	_expect(
		second_result["handled"] == 1,
		"handled del segundo emit debe ser 1, se obtuvo %d" % second_result["handled"]
	)


func _test_invalidated_handler() -> void:
	var bus = EventBusScript.new()
	var node := Node.new()
	var handler := Callable(node, "get_name")
	var subscription_id: int = bus.subscribe("test.freed", handler, "mod.a")
	_expect(subscription_id > 0, "la suscripcion con un nodo vivo debe ser valida")

	node.free()
	var result: Dictionary = bus.emit("test.freed")
	_expect(result["ok"], "emit debe ser ok aunque el handler sea invalido")
	_expect(result["handled"] == 0, "el handler invalido no debe contarse")
	_expect(result["errors"].size() >= 1, "el handler invalido debe aparecer en errors")


func _test_emit_without_subscribers() -> void:
	var bus = EventBusScript.new()
	var result: Dictionary = bus.emit("test.vacio")
	_expect(result["ok"], "emit sin suscriptores debe ser ok")
	_expect(result["handled"] == 0, "handled debe ser 0, se obtuvo %d" % result["handled"])


func _test_clear() -> void:
	var bus = EventBusScript.new()
	var handler := func(_payload): pass
	bus.subscribe("test.clear", handler, "mod.a")
	bus.subscribe("test.clear2", handler, "mod.b")
	bus.clear()
	_expect(not bus.has_subscribers("test.clear"), "clear debe eliminar las suscripciones")
	_expect(not bus.has_subscribers("test.clear2"), "clear debe eliminar todas las suscripciones")
	var result: Dictionary = bus.emit("test.clear")
	_expect(result["handled"] == 0, "tras clear no debe invocarse nada")
