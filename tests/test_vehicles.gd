extends SceneTree

const DbScript = preload("res://core/game/vehicle_db.gd")
const SpawnerScript = preload("res://core/game/vehicle_spawner.gd")
const MenuScene = preload("res://scenes/ui/spawn_menu.tscn")
const GoreScript = preload("res://core/game/gore_fx.gd")

class Dummy extends Node3D:
	var hits: Array = []
	var dead := false
	func take_damage(amount: float, _p: Vector3 = Vector3.ZERO, _n: Vector3 = Vector3.UP, _s: Node = null) -> void:
		hits.append(amount)
		dead = amount > 100.0
	func is_dead() -> bool:
		return dead

var _n := 0
var _fail := 0
var _world: Node3D


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _initialize() -> void:
	await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 1, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -0.5, 0)
	_world.add_child(floor_body)
	_db()
	await _spawn_all()
	_errors()
	await _physics()
	await _limit()
	await _enter_exit()
	_damage()
	await _menu()
	SpawnerScript.clear()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _db() -> void:
	var ids: Array = DbScript.list_ids()
	_expect(ids.size() >= 5, "al menos 5 vehiculos")
	var kinds: Array = []
	for id in ids:
		var def: Dictionary = DbScript.get_def(id)
		kinds.append(def["kind"])
		_expect(ResourceLoader.exists(def["model_path"]), "modelo existe: " + str(id))
	for kind in ["turismo", "pickup", "deportivo", "furgoneta", "buggy"]:
		_expect(kinds.has(kind), "tipo " + kind)
	_expect(DbScript.all().has("sedan") and DbScript.all()["sedan"].has("scene_builder"), "contrato de VehicleDb.all")
	var manifest := FileAccess.get_file_as_string("res://assets/models/vehicles/manifest.json")
	var data = JSON.parse_string(manifest)
	_expect(data is Dictionary and (data["vehicles"] as Array).size() >= 5, "manifest.json con los vehiculos")


func _spawn_all() -> void:
	SpawnerScript.max_alive = 20
	var x := 0.0
	for id in DbScript.list_ids():
		var v = SpawnerScript.spawn(id, Transform3D(Basis.IDENTITY, Vector3(x, 2.0, 0)), _world)
		x += 6.0
		_expect(v != null and v.vehicle_id == id, "spawn " + str(id))
		if v == null:
			continue
		var steering := 0
		var meshes := 0
		for w in v.wheels:
			if w.use_as_steering:
				steering += 1
			meshes += w.get_child_count()
		_expect(v.wheels.size() == 4 and steering == 2 and meshes == 4, "%s: 4 ruedas del modelo (2 directrices)" % id)
		_expect(v.headlights.size() == 2 and v.brake_lights.size() == 2 and v.steering_wheel != null, "%s: luces y volante" % id)
		_expect(v.get_node_or_null("Model") != null and v.body_size.z > 1.2, "%s: carroceria del modelo" % id)
	SpawnerScript.clear()
	SpawnerScript.max_alive = 6
	await physics_frame


func _errors() -> void:
	_expect(SpawnerScript.spawn("tanque", Transform3D.IDENTITY, _world) == null and SpawnerScript.last_error.begins_with("vehiculo desconocido"), "id desconocido -> error controlado")
	_expect(SpawnerScript.spawn("sedan", Transform3D.IDENTITY, null) == null, "sin padre -> null")


func _physics() -> void:
	var v = SpawnerScript.spawn("sedan", Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), _world)
	await _frames(100)
	_expect(v.global_position.y > -0.1 and v.global_position.y < 0.4, "cae y se apoya en el suelo: y=%.2f" % v.global_position.y)
	_expect(v.speed() < 0.6, "queda quieto: %.2f" % v.speed())
	var driver := Dummy.new()
	_world.add_child(driver)
	_expect(v.enter(driver), "entrar")
	var start: Vector3 = v.global_position
	v.set_drive_input(1.0, 0.0, 0.0)
	await _frames(150)
	var moved: Vector3 = v.global_position - start
	_expect(moved.length() > 3.0, "acelera y avanza: %.1f m" % moved.length())
	_expect(moved.dot(v.global_transform.basis.z) > 0.0 and moved.z > 0.0, "avanza hacia el frente (+Z del modelo): %s" % str(moved))
	_expect(v.speed() < float(v.def["max_speed"]) + 1.0, "respeta la velocidad maxima")
	var spin_ok := false
	for w in v.wheels:
		if absf(w.get_rpm()) > 1.0:
			spin_ok = true
	_expect(spin_ok, "las ruedas giran")
	v.set_drive_input(1.0, 1.0, 0.0)
	await _frames(40)
	_expect(v.steering < -0.05, "volante a la derecha: %.2f" % v.steering)
	_expect(v.global_position.x < start.x - 0.5, "gira a la derecha (-X al mirar +Z)")
	var fast: float = v.speed()
	v.set_drive_input(0.0, 0.0, 1.0)
	await _frames(120)
	_expect(v.speed() < fast * 0.5, "frena: %.1f -> %.1f" % [fast, v.speed()])
	v.set_drive_input(NAN, 5.0, -3.0)
	await physics_frame
	_expect(is_finite(v.engine_force) and is_finite(v.steering), "entradas invalidas sin NaN")
	v.exit()
	driver.free()
	SpawnerScript.clear()


func _limit() -> void:
	SpawnerScript.max_alive = 6
	var first = SpawnerScript.spawn("sedan", Transform3D(Basis.IDENTITY, Vector3(50, 1.5, 0)), _world)
	var guard := Dummy.new()
	_world.add_child(guard)
	var second = SpawnerScript.spawn("van", Transform3D(Basis.IDENTITY, Vector3(56, 1.5, 0)), _world)
	second.enter(guard)
	for i in 7:
		SpawnerScript.spawn("buggy", Transform3D(Basis.IDENTITY, Vector3(60 + i * 5, 1.5, 0)), _world)
	await physics_frame
	await physics_frame
	_expect(SpawnerScript.alive_count() == 6, "limite de vivos: %d" % SpawnerScript.alive_count())
	_expect(not is_instance_valid(first) or first.is_queued_for_deletion() or not first.is_inside_tree(), "el mas antiguo se elimina")
	_expect(is_instance_valid(second) and second.is_inside_tree(), "el vehiculo con conductor no se elimina")
	SpawnerScript.clear()
	guard.free()


func _enter_exit() -> void:
	var v = SpawnerScript.spawn("pickup", Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -40)), _world)
	var a := Dummy.new()
	var b := Dummy.new()
	_world.add_child(a)
	_world.add_child(b)
	a.global_position = v.global_position + Vector3(-3, 0, 0)
	var events: Array = []
	v.entered.connect(func(d): events.append("in"))
	v.exited.connect(func(d): events.append("out"))
	_expect(v.enter(a) and not v.enter(b), "un solo conductor")
	await _frames(40)
	_expect(a.global_position.distance_to(v.to_global(v.SEAT) - Vector3(0, 0, 0)) < 1.5, "el conductor se anima hasta el asiento")
	_expect(v.exit() == a and v.driver == null and events == ["in", "out"], "salir devuelve al conductor")
	_expect(a.global_position.distance_to(v.global_position) > 1.0, "sale junto al coche")
	_expect(v.exit() == null, "salir sin conductor")
	v.honk()
	_expect(v.horn_player.stream != null and v.horn_player.stream.get_length() > 0.2, "claxon con sonido")
	_expect(v.toggle_headlights() and v.headlights[0].visible and not v.toggle_headlights(), "faros")
	SpawnerScript.clear()
	a.free()
	b.free()


func _damage() -> void:
	var v = SpawnerScript.spawn("sedan", Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 80)), _world)
	var damaged: Array = []
	var dead := [0]
	v.damaged.connect(func(a, h): damaged.append(a))
	v.destroyed.connect(func(): dead[0] += 1)
	var soft: Dictionary = v.register_impact(2.0, Vector3.ZERO, Vector3.UP, null)
	_expect(float(soft["crash_damage"]) == 0.0 and v.health == v.max_health, "golpe suave sin daño")
	var hard: Dictionary = v.register_impact(15.0, Vector3.ZERO, Vector3.UP, null)
	_expect(float(hard["crash_damage"]) > 50.0 and v.health < v.max_health and damaged.size() == 1, "choque fuerte daña")
	v.register_impact(40.0, Vector3.ZERO, Vector3.UP, null)
	_expect(v.is_dead() and dead[0] == 1, "destruido")
	v.register_impact(40.0, Vector3.ZERO, Vector3.UP, null)
	_expect(dead[0] == 1, "destruido una sola vez")
	var target := Dummy.new()
	_world.add_child(target)
	v.linear_velocity = Vector3(0, 0, -10)
	GoreScript.set_gore_enabled(true)
	var before: int = GoreScript.active_count()
	var run: Dictionary = v.register_impact(1.0, Vector3(0, 1, 80), Vector3.UP, target)
	_expect(bool(run["run_over"]) and target.hits.size() == 1 and target.hits[0] > 30.0, "atropello daña al objetivo")
	_expect(GoreScript.active_count() > before, "atropello con gore activo deja sangre")
	GoreScript.set_gore_enabled(false)
	before = GoreScript.active_count()
	v.register_impact(1.0, Vector3(0, 1, 80), Vector3.UP, target)
	_expect(GoreScript.active_count() == before, "sin gore no hay sangre")
	GoreScript.set_gore_enabled(null)
	v.linear_velocity = Vector3.ZERO
	var slow: Dictionary = v.register_impact(0.5, Vector3.ZERO, Vector3.UP, target)
	_expect(not bool(slow["run_over"]), "a baja velocidad no atropella")
	target.free()
	SpawnerScript.clear()


func _menu() -> void:
	var menu = MenuScene.instantiate()
	root.add_child(menu)
	await process_frame
	var got: Array = []
	menu.spawn_requested.connect(func(id): got.append(id))
	_expect(menu.buttons.size() == DbScript.list_ids().size(), "un boton por vehiculo")
	for id in DbScript.list_ids():
		menu.buttons[id].pressed.emit()
	_expect(got == DbScript.list_ids(), "SpawnMenu emite el id correcto")
	_expect(menu.buttons["sedan"].custom_minimum_size.y >= 90.0, "botones grandes para tactil")
	menu.free()
