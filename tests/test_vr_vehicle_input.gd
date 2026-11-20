extends SceneTree

const InputScript = preload("res://core/vr/vr_vehicle_input.gd")
const SpawnerScript = preload("res://core/game/vehicle_spawner.gd")
const DbScript = preload("res://core/game/vehicle_db.gd")

var _n := 0
var _fail := 0
var _world: Node3D


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200, 1, 200)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	_world.add_child(floor_body)
	await _drive()
	_math()
	_menu()
	SpawnerScript.clear()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _pose(pos: Vector3, roll: float = 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.FORWARD * -1.0, roll), pos)


func _poses(wheel: Vector3, roll_l: float = 0.0, roll_r: float = 0.0) -> Dictionary:
	return {"left": _pose(wheel + Vector3(-0.15, 0.0, 0.0), roll_l), "right": _pose(wheel + Vector3(0.15, 0.0, 0.0), roll_r)}


func _drive() -> void:
	var v = SpawnerScript.spawn("sedan", Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), _world)
	for i in 60:
		await physics_frame
	var vr = InputScript.new()
	var who := Node3D.new()
	_world.add_child(who)
	var events: Array = []
	vr.entered.connect(func(_v): events.append("in"))
	vr.exited.connect(func(_v): events.append("out"))
	var far: Vector3 = v.global_position + Vector3(10, 1, 0)
	_expect(not vr.can_enter(far, v) and not vr.try_enter(far, v, who), "lejos de la puerta no entra")
	var door: Vector3 = v.door_position()
	_expect(vr.can_enter(door + Vector3(0.1, 0, 0), v), "mano cerca de la puerta")
	_expect(not vr.try_enter(door, v, who, false), "sin agarre/boton no entra")
	_expect(vr.try_enter(door, v, who) and vr.driving and events == ["in"], "entra agarrando la puerta")
	_expect(not vr.try_enter(door, v, who), "no entra dos veces")
	var wheel: Vector3 = v.steering_wheel.global_position
	var grips := {"left": 0.0, "right": 0.0}
	var trig := {"left": 0.0, "right": 0.0}
	var out: Dictionary = vr.update(0.016, _poses(wheel), grips, trig)
	_expect(not bool(vr.hands_on_wheel["left"]) and absf(vr.steer) < 0.001, "sin agarrar no gira")
	grips = {"left": 1.0, "right": 1.0}
	var hapt := [0]
	vr.haptic.connect(func(_h, _d, _a): hapt[0] += 1)
	vr.update(0.016, _poses(wheel), grips, trig)
	_expect(bool(vr.hands_on_wheel["left"]) and bool(vr.hands_on_wheel["right"]) and hapt[0] == 2, "agarra el volante con las dos manos (haptica)")
	var roll := 0.0
	for i in 40:
		roll += 0.02
		vr.update(0.016, _poses(wheel, roll, roll), grips, trig)
	_expect(vr.steer > 0.1 and vr.steer < 0.9, "girar la muñeca gira el volante (suave): %.2f" % vr.steer)
	var before: float = vr.steer
	vr.update(0.016, _poses(wheel, 3.0, 3.0), grips, trig)
	_expect(vr.steer - before < 0.2, "un giro brusco de muñeca se suaviza en un frame")
	for i in 100:
		vr.update(0.016, _poses(wheel, 3.0, 3.0), grips, trig)
	_expect(vr.steer == 1.0 or vr.steer > 0.99, "tope del volante")
	var one := InputScript.new()
	one.vehicle = v
	one.driving = true
	one.update(0.016, _poses(wheel), {"left": 1.0, "right": 0.0}, trig)
	for i in 30:
		one.update(0.016, _poses(wheel, -0.5, 0.0), {"left": 1.0, "right": 0.0}, trig)
	_expect(one.steer < -0.2 and not bool(one.hands_on_wheel["right"]), "una sola mano tambien gira (izquierda)")
	grips = {"left": 0.0, "right": 0.0}
	for i in 120:
		vr.update(0.016, _poses(wheel), grips, trig)
	_expect(absf(vr.steer) < 0.01, "al soltar el volante vuelve al centro")
	vr.update(0.016, _poses(wheel), grips, {"left": 0.0, "right": 1.0})
	_expect(vr.throttle > 0.0 and vr.throttle < 0.2, "el acelerador sube progresivamente")
	var start: Vector3 = v.global_position
	for i in 200:
		vr.update(0.016, _poses(wheel), grips, {"left": 0.0, "right": 1.0}, 0.0)
		await physics_frame
	_expect(v.global_position.distance_to(start) > 3.0, "gatillo derecho acelera el coche")
	_expect(not vr.shift("R"), "no se mete marcha atras en movimiento")
	_expect(not vr.exit(), "no se sale a gran velocidad")
	var fast: float = v.speed()
	for i in 150:
		vr.update(0.016, _poses(wheel), grips, {"left": 1.0, "right": 0.0})
		await physics_frame
	_expect(v.speed() < fast * 0.5 and vr.brake == 1.0, "gatillo izquierdo frena")
	for i in 200:
		vr.update(0.016, _poses(wheel), grips, {"left": 1.0, "right": 0.0})
		await physics_frame
	_expect(v.speed() < 0.5, "queda parado")
	_expect(vr.shift("R") and vr.gear == "R", "marcha atras con el coche parado")
	var back_start: float = v.forward_speed()
	for i in 80:
		vr.update(0.016, _poses(wheel), grips, {"left": 0.0, "right": 1.0})
		await physics_frame
	_expect(v.forward_speed() < back_start - 0.5, "en R el mismo gatillo da marcha atras")
	for i in 200:
		vr.update(0.016, _poses(wheel), grips, {"left": 1.0, "right": 0.0})
		await physics_frame
	_expect(vr.shift("N") and vr.shift("D"), "palanca N y D")
	vr.update(0.016, _poses(wheel), grips, {"left": 1.0, "right": 0.0}, 3.0)
	var vig: float = vr.vignette
	for i in 60:
		vr.update(0.016, _poses(wheel), grips, trig, 3.0)
	_expect(vr.vignette > vig and vr.vignette <= 0.8001, "viñeta al girar rapido")
	for i in 200:
		vr.update(0.016, _poses(wheel), grips, trig, 0.0)
	_expect(vr.vignette < 0.01, "la viñeta se retira")
	var lever_vr = InputScript.new()
	lever_vr.vehicle = v
	lever_vr.driving = true
	var lever_pose: Dictionary = {"left": _pose(v.global_position + Vector3(10, 5, 0)), "right": _pose(lever_vr.lever_position())}
	lever_vr.update(0.016, lever_pose, {"left": 0.0, "right": 1.0}, trig)
	_expect(lever_vr.gear == "R", "agarrar la palanca cambia de marcha")
	vr.update(0.016, _poses(wheel), grips, {"left": 1.0, "right": 0.0})
	for i in 60:
		await physics_frame
	_expect(vr.exit() and not vr.driving and v.driver == null and events == ["in", "out"], "sale con el coche parado")
	_expect(not vr.exit(), "salir sin conducir")
	_expect(vr.update(0.016, _poses(wheel), grips, trig).is_empty(), "fuera del coche no hay control")
	var eye: Vector3 = vr.seat_eye(v)
	_expect(eye.distance_to(v.global_position) < 1.5, "vista desde el asiento")
	who.free()


func _math() -> void:
	var yaw := 0.0
	for i in 10:
		yaw = InputScript.limit_view_yaw(yaw, PI, 0.016)
	_expect(absf(yaw) < 0.3, "la vista no gira de golpe: %.2f" % yaw)
	_expect(is_equal_approx(InputScript.limit_view_yaw(0.0, 0.01, 1.0), 0.01), "pequeños giros pasan directos")
	_expect(is_equal_approx(InputScript.limit_view_yaw(3.0, -3.0, 1.0), -3.0) or absf(InputScript.limit_view_yaw(3.0, -3.0, 1.0)) > 2.5, "da la vuelta por el camino corto")
	_expect(is_zero_approx(InputScript.wrap_angle(TAU)), "wrap_angle")
	var wheel := Transform3D.IDENTITY
	_expect(absf(InputScript.wrist_roll(_pose(Vector3.ZERO, 0.5), wheel) - 0.5) < 0.001, "roll de muñeca medido")
	var vr = InputScript.new()
	vr.update(1.0e9, {}, {}, {}, 1.0e9)
	_expect(true, "update sin conducir no falla")


func _menu() -> void:
	var vr = InputScript.new()
	var menu = vr.build_spawn_menu(_world)
	var got: Array = []
	vr.spawn_requested.connect(func(id): got.append(id))
	_expect(menu.buttons.size() == DbScript.list_ids().size(), "VrMenu con un boton por vehiculo")
	_expect(InputScript.vehicle_id_from_button("spawn:sedan") == "sedan" and InputScript.vehicle_id_from_button("play") == "", "ids de boton")
	menu.open_in_front(Vector3(0, 1.6, 0), Vector3.FORWARD)
	var pressed: Array = []
	for id in DbScript.list_ids():
		var found := ""
		for xi in range(-45, 46):
			for yi in range(-25, 26):
				var target := Vector3(xi * 0.01, 1.6 + yi * 0.01, -1.4)
				var hit: Dictionary = menu.pointer_hit(Vector3(0, 1.6, 0), target - Vector3(0, 1.6, 0))
				if str(hit.get("button_id", "")) == "spawn:" + str(id):
					found = menu.try_press(Vector3(0, 1.6, 0), target - Vector3(0, 1.6, 0), true)
					break
			if not found.is_empty():
				break
		pressed.append(found)
	_expect(got == DbScript.list_ids(), "apuntar y pulsar cada boton emite spawn_requested: %s" % str(got))
