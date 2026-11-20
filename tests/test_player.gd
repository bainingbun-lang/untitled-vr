extends SceneTree

var _fail := 0
var _n := 0


class FakeVehicle extends Node3D:
	var entered_by: Node3D = null
	var exited := false
	var last_input: Vector3 = Vector3(-999.0, -999.0, -999.0)

	func enter(driver: Node3D) -> bool:
		entered_by = driver
		return true

	func exit() -> Node3D:
		exited = true
		return null

	func set_drive_input(throttle: float, steer: float, brake: float) -> void:
		last_input = Vector3(throttle, steer, brake)


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _initialize() -> void:
	await _run()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _run() -> void:
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	_expect(packed != null, "player.tscn carga")
	if packed == null:
		return
	var player = packed.instantiate()
	root.add_child(player)
	await process_frame

	_expect(player.get_node_or_null("Collision") != null, "colision del jugador")
	_expect(player.get_node_or_null("Head/Camera") != null, "camara en la cabeza")
	_expect((player.get_node("Head") as Node3D).position.y > 1.0, "camara a altura de ojos")
	_expect(player.health > 0.0, "vida inicial")
	_expect(player.inventory != null, "inventario inicial")
	_expect(player.has_method("move_action") and player.has_method("look_action") and player.has_method("jump_action"), "acciones expuestas para VR")

	var floor_body := StaticBody3D.new()
	floor_body.name = "TestFloor"
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 1.0, 60.0)
	var col := CollisionShape3D.new()
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)
	player.global_position = Vector3(0.0, 3.0, 0.0)
	for i in range(60):
		await physics_frame
	_expect(player.is_on_floor(), "cae y se apoya en el suelo")
	_expect(absf(player.global_position.y) < 0.2, "apoya a la altura del suelo")

	var controls_packed := load("res://scenes/ui/touch_controls.tscn") as PackedScene
	_expect(controls_packed != null, "touch_controls.tscn carga")
	if controls_packed == null:
		return
	var controls = controls_packed.instantiate()
	root.add_child(controls)
	await process_frame
	_expect(controls.layout != null, "TouchControls inicializa el layout configurable")

	var seen := [0, 0, 0, 0, 0, 0, 0, 0]
	controls.move.connect(func(_v): seen[0] += 1)
	controls.look.connect(func(_d): seen[1] += 1)
	controls.jump_pressed.connect(func(): seen[2] += 1)
	controls.fire_pressed.connect(func(): seen[3] += 1)
	controls.fire_released.connect(func(): seen[4] += 1)
	controls.interact_pressed.connect(func(): seen[5] += 1)
	controls.menu_pressed.connect(func(): seen[6] += 1)
	controls.hotbar_select.connect(func(_i): seen[7] += 1)
	var hotbar_index := [-1]
	controls.hotbar_select.connect(func(i): hotbar_index[0] = i)
	controls.move.emit(Vector2(1.0, 0.0))
	controls.look.emit(Vector2(0.1, 0.0))
	controls.jump_pressed.emit()
	controls.fire_pressed.emit()
	controls.fire_released.emit()
	controls.interact_pressed.emit()
	controls.menu_pressed.emit()
	controls.hotbar_select.emit(2)
	_expect(seen == [1, 1, 1, 1, 1, 1, 1, 1], "todas las señales de TouchControls")
	_expect(hotbar_index[0] == 2, "hotbar_select envia indice")
	var reload_calls := [0]
	controls.reload_pressed.connect(func(): reload_calls[0] += 1)
	controls.get_node("ReloadButton").pressed.emit()
	_expect(reload_calls[0] == 1, "senal reload_pressed del boton de recargar")

	controls.size = Vector2(1000.0, 800.0)
	await process_frame
	var fire_control := controls.get_node("FireButton") as Control
	_expect(fire_control.position.x > controls.size.x * 0.5, "disparo en el lado derecho del layout diestro")
	_expect(is_equal_approx(controls.move_deadzone, controls.layout.move_deadzone), "zona muerta tomada del layout")
	var last_move := [Vector2.ZERO]
	var last_look := [Vector2.ZERO]
	var look_calls := [0]
	controls.move.connect(func(v): last_move[0] = v)
	controls.look.connect(func(d): last_look[0] = d; look_calls[0] += 1)
	controls.inject_touch_down(1, Vector2(100.0, 700.0))
	controls.inject_touch_move(1, Vector2(220.0, 700.0))
	_expect(last_move[0].x > 0.8, "joystick sigue el dedo por indice")
	controls.inject_touch_down(2, Vector2(800.0, 300.0))
	controls.inject_touch_move(2, Vector2(830.0, 300.0))
	_expect(look_calls[0] == 1, "zona de mirar usa otro dedo")
	_expect(last_look[0].x > 0.0, "look delta con sensibilidad")
	controls.inject_touch_move(1, Vector2(106.0, 700.0))
	_expect(last_move[0] == Vector2.ZERO, "zona muerta del joystick")
	controls.inject_touch_up(1)
	controls.inject_touch_up(2)

	player.set_touch_controls(controls)
	var start_x: float = player.global_position.x
	controls.move.emit(Vector2(1.0, 0.0))
	for i in range(20):
		await physics_frame
	_expect(player.global_position.x > start_x + 0.5, "input simulado desplaza al jugador")
	controls.move.emit(Vector2.ZERO)
	var y_before: float = player.global_position.y
	controls.jump_pressed.emit()
	await physics_frame
	_expect(player.velocity.y > 0.0, "salto aplica velocidad vertical")
	await physics_frame
	_expect(player.global_position.y > y_before, "salto eleva al jugador")

	var died_calls := [0]
	player.died.connect(func(): died_calls[0] += 1)
	player.take_damage(200.0)
	_expect(player.health <= 0.0, "dano letal deja la vida en cero")
	_expect(died_calls[0] == 1, "senal died emitida")
	player.take_damage(10.0)
	_expect(died_calls[0] == 1, "died no se repite")
	player.respawn(Vector3(1.0, 0.0, 1.0))
	_expect(player.health == player.max_health, "respawn restaura la vida")
	_expect(player.global_position.distance_to(Vector3(1.0, 0.0, 1.0)) < 0.1, "respawn recoloca al jugador")

	var changed := [""]
	player.weapon_changed.connect(func(id): changed[0] = id)
	player.inventory = null
	_expect(player.equip("pistol"), "equip funciona sin inventario previo")
	_expect(changed[0] == "pistol", "weapon_changed notifica el arma")
	player.fire()
	_expect(true, "fire sin WeaponSystem no falla")

	var pi := [0]
	var pm := [0]
	player.interact_pressed.connect(func(): pi[0] += 1)
	player.menu_pressed.connect(func(): pm[0] += 1)
	player.interact_action()
	player.menu_action()
	_expect(pi[0] == 1 and pm[0] == 1, "acciones VR de interactuar y menu")

	var fake := FakeVehicle.new()
	root.add_child(fake)
	player.enter_vehicle(fake)
	_expect(fake.entered_by == player, "enter_vehicle llama enter")
	_expect(player.vehicle == fake, "referencia al vehiculo")
	player.set_drive_input(1.0, -0.5, 0.0)
	await physics_frame
	_expect(fake.last_input == Vector3(1.0, -0.5, 0.0), "reenvia set_drive_input")
	player.exit_vehicle()
	_expect(fake.exited, "exit_vehicle llama exit")
	_expect(player.vehicle == null, "vehiculo liberado")
