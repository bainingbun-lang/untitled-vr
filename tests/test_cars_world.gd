extends SceneTree

const GeneratorScript = preload("res://core/maps/map_generator.gd")
const WorldScene = preload("res://scenes/world/game_world.tscn")
const VehicleSpawnerScript = preload("res://core/game/vehicle_spawner.gd")
const VehicleScript = preload("res://core/game/vehicle.gd")
const VrVehicleInputScript = preload("res://core/vr/vr_vehicle_input.gd")
const VrGameModeScript = preload("res://core/vr/vr_game_mode.gd")

var _checks := 0
var _failures: Array = []


func _initialize() -> void:
	await _run()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + str(failure))
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)


func _run() -> void:
	VehicleSpawnerScript.clear()
	var meta: Dictionary = GeneratorScript.generate(9137, {
		"width": 24, "height": 18, "obstacle_density": 0.18, "spawn_count": 4,
	})
	_expect(bool(meta.get("ok", false)), "MapGenerator entrega una meta valida")
	var world = WorldScene.instantiate()
	root.add_child(world)
	await process_frame
	world.setup(meta)
	await process_frame
	for i in range(3):
		await physics_frame

	var cars: Array = world.vehicles()
	_expect(cars.size() >= 3 and cars.size() <= 4, "3-4 coches aparcados en el mundo")
	_expect(world.parked_vehicle_list().size() == cars.size(), "los coches aparcados estan expuestos")
	_expect(int((world.world_report as Dictionary).get("parked_vehicles", 0)) == cars.size(),
		"world_report cuanta los coches aparcados")

	var boxes: Array = []
	var geometry := world.get_node_or_null("WorldGeometry") as Node3D
	if geometry != null:
		for body in geometry.find_children("*", "CollisionObject3D", true, false):
			if str((body as Node).name) == "Ground":
				continue
			var box: AABB = _box_of(body as Node3D)
			if box.size.x > 0.0 and box.size.z > 0.0:
				boxes.append(box)
	for car in cars:
		var point: Vector3 = (car as Node3D).global_position
		var inside_building: bool = false
		for box in boxes:
			var expanded := AABB(box.position - Vector3.ONE, box.size + Vector3.ONE * 2.0)
			if expanded.has_point(Vector3(point.x, box.get_center().y, point.z)):
				inside_building = true
				break
		_expect(not inside_building, "coche aparcado fuera de edificios: %s" % (car as Node).name)
	for i in range(cars.size()):
		for j in range(i + 1, cars.size()):
			var a: Vector3 = (cars[i] as Node3D).global_position
			var b: Vector3 = (cars[j] as Node3D).global_position
			_expect(_planar(a, b) > 2.2, "coches aparcados no se solapan")

	var player = world.actor
	player.gravity = 0.0
	player.velocity = Vector3.ZERO
	var target: Node3D = cars[0] as Node3D
	player.global_position = target.door_position()
	player.interact_pressed.emit()
	_expect(player.get("vehicle") == target, "interact entra en el coche cercano")
	player.interact_pressed.emit()
	_expect(player.get("vehicle") == null, "interact sale del coche")

	_expect(world.spawn_menu != null, "menu de aparicion en pantalla creado")
	_expect(not bool(world.spawn_menu.visible), "menu de aparicion empieza oculto")
	world.open_spawn_menu()
	_expect(bool(world.spawn_menu.visible), "menu de aparicion se abre")
	var before_menu: int = world.vehicles().size()
	world.spawn_menu.emit_signal("spawn_requested", "suv")
	await process_frame
	_expect(world.vehicles().size() == before_menu + 1, "el menu crea un coche delante del jugador")
	_expect(not bool(world.spawn_menu.visible), "el menu se cierra tras aparecer")
	world.close_spawn_menu()

	var old_limit: int = VehicleSpawnerScript.max_alive
	VehicleSpawnerScript.max_alive = 2
	for i in range(3):
		world.spawn_vehicle_in_front("sedan")
	_expect(VehicleSpawnerScript.alive_count() <= 2, "respeta el limite de coches vivos")
	VehicleSpawnerScript.max_alive = old_limit

	var vr_state = VrGameModeScript.State.new()
	vr_state.world = world
	vr_state._setup_vehicle_input()
	_expect(vr_state.vehicle_input != null, "VrGameMode crea VrVehicleInput")
	vr_state.open_vehicle_spawn_menu()
	_expect(vr_state.vehicle_spawn_menu != null \
		and bool(vr_state.vehicle_spawn_menu.get("is_open")), "VR abre menu de aparicion")
	var before_vr: int = world.vehicles().size()
	vr_state.vehicle_spawn_menu.emit_signal(
		"button_pressed", VrVehicleInputScript.SPAWN_PREFIX + "suv")
	await process_frame
	_expect(world.vehicles().size() == before_vr + 1, "el menu VR crea un coche")
	vr_state.vehicle_spawn_menu.call("close_menu")

	var vr_input = VrVehicleInputScript.new()
	var fake_driver := Node3D.new()
	root.add_child(fake_driver)
	var drive_car: Node3D = world.vehicles()[0] as Node3D
	_expect(vr_input.try_enter(drive_car.door_position(), drive_car, fake_driver, true),
		"entrar en VR agarrando la puerta")
	var update_result: Dictionary = vr_input.update(0.016,
		{"left": Transform3D.IDENTITY, "right": Transform3D.IDENTITY},
		{"left": 0.0, "right": 0.0}, {"left": 0.0, "right": 0.0}, 0.0)
	_expect(not update_result.is_empty(), "VrVehicleInput.update devuelve estado de conduccion")
	_expect(vr_input.exit(), "salir en VR")

	_expect(FileAccess.file_exists(VehicleScript.STEERING_WHEEL_MODEL), "modelo de volante descargado")
	_expect(FileAccess.file_exists(VehicleScript.STEERING_WHEEL_MODEL + ".import"),
		"volante importado por Godot")
	_expect(FileAccess.file_exists(VehicleScript.HORN_SOUND), "claxon real descargado")
	_expect(FileAccess.file_exists(VehicleScript.ENGINE_SOUND), "motor real descargado")
	var sample: Node3D = world.vehicles()[0] as Node3D
	_expect(sample.steering_wheel != null \
		and str(sample.steering_wheel.get_meta("model_path", "")) == VehicleScript.STEERING_WHEEL_MODEL,
		"el volante usa el modelo descargado")
	var meshes: Array = sample.steering_wheel.find_children("*", "MeshInstance3D", true, false)
	var torus_left: bool = false
	for mesh in meshes:
		if (mesh as MeshInstance3D).mesh is TorusMesh:
			torus_left = true
	_expect(not torus_left, "no queda volante TorusMesh sintetico")
	_expect(sample.horn_player != null and sample.horn_player.stream is AudioStreamOggVorbis,
		"claxon usa Ogg real")
	_expect(sample.horn_player.stream.get_length() > 0.2, "claxon con duracion real")
	_expect(sample.engine_player != null and sample.engine_player.stream is AudioStreamOggVorbis,
		"motor usa Ogg real")
	_expect(bool(sample.engine_player.stream.loop), "motor en bucle")
	sample.call("set_drive_input", 1.0, 0.0, 0.0)
	for i in range(8):
		await physics_frame
	_expect(sample.engine_player.pitch_scale > 0.73, "pitch del motor sube con las revoluciones")

	var credits := FileAccess.open("res://assets/CREDITS.md", FileAccess.READ)
	var credits_text: String = credits.get_as_text() if credits != null else ""
	if credits != null:
		credits.close()
	_expect(credits_text.contains("steering_wheel.glb") and credits_text.contains("CC BY 3.0"),
		"volante CC-BY acreditado en assets/CREDITS.md")

	vr_state.free()
	VehicleSpawnerScript.clear()


func _box_of(root: Node3D) -> AABB:
	var result := AABB()
	var found := false
	var stack: Array = [{"node": root, "xform": Transform3D.IDENTITY}]
	while not stack.is_empty():
		var entry: Dictionary = stack.pop_back()
		var node: Node = entry["node"]
		var xform: Transform3D = entry["xform"]
		if node is Node3D:
			xform = xform * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var child_box: AABB = xform * (node as MeshInstance3D).mesh.get_aabb()
			result = child_box if not found else result.merge(child_box)
			found = true
		for child in node.get_children():
			stack.append({"node": child, "xform": xform})
	return result


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
