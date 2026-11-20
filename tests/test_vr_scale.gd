extends SceneTree

const RigScript = preload("res://core/vr/vr_rig.gd")
const CharacterScript = preload("res://core/game/character_model.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const BuildingScript = preload("res://core/maps/building_generator.gd")
const GoreScript = preload("res://core/game/gore_fx.gd")

const REAL_LENGTH := {"pistol": 0.20, "submachine_gun": 0.45, "assault_rifle": 0.90, "shotgun": 1.00, "sniper_rifle": 1.10, "bat": 0.85}

var _n := 0
var _fail := 0


func _expect(c: bool, m: String) -> void:
	_n += 1
	if not c:
		_fail += 1
		print("FAIL: " + m)


func _mesh_aabb(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for item in node.find_children("*", "MeshInstance3D", true, false):
		var mi := item as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var box: AABB = mi.global_transform * mi.mesh.get_aabb()
		result = box if not found else result.merge(box)
		found = true
	return result


func _initialize() -> void:
	await process_frame
	await _rig_scale()
	await _npc_scale()
	await _weapon_scale()
	_map_scale()
	await _gore_not_continuous()
	if _fail == 0:
		print("PASS (%d assertions)" % _n)
		quit(0)
	else:
		print("FAIL (%d assertions, %d failures)" % [_n, _fail])
		quit(1)


func _rig_scale() -> void:
	var rig = RigScript.new()
	rig.auto_process = false
	rig.xr_availability_override = func() -> bool: return true
	root.add_child(rig)
	await process_frame
	_expect(rig.xr_origin.world_scale == 1.0 and rig.xr_origin.scale == Vector3.ONE and rig.scale == Vector3.ONE, "origen XR sin escala (world_scale=1)")
	_expect(rig.xr_origin.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "escala global del origen = 1")
	# casco a la altura del suelo (espacio Local): el rig sube a una altura de ojos humana
	rig.xr_camera.position = Vector3(0, 0.02, 0)
	rig.step(2.0)
	_expect(is_equal_approx(rig.xr_camera.global_position.y, rig.default_eye_height), "casco a ras de suelo -> ojos a %.2f m" % rig.xr_camera.global_position.y)
	rig.queue_free()
	var floor_rig = RigScript.new()
	floor_rig.auto_process = false
	floor_rig.xr_availability_override = func() -> bool: return true
	root.add_child(floor_rig)
	await process_frame
	floor_rig.xr_camera.position = Vector3(0, 1.62, 0)
	floor_rig.step(2.0)
	_expect(floor_rig.floor_offset == 0.0 and is_equal_approx(floor_rig.xr_camera.global_position.y, 1.62), "espacio Local Floor: sin correccion")
	floor_rig.queue_free()
	await process_frame


func _npc_scale() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	for skin in ["civil", "enemy", "soldier"]:
		var model = CharacterScript.spawn(holder, skin)
		if model == null or not model.is_loaded():
			_expect(false, "modelo %s carga" % skin)
			continue
		await process_frame
		var box: AABB = _mesh_aabb(model)
		_expect(box.size.y > 1.55 and box.size.y < 1.95, "NPC %s mide %.2f m (1.75 normalizado)" % [skin, box.size.y])
		_expect(absf(model.height() - 1.75 * model.variation_scale()) < 0.05, "%s: normalizacion unica (sin multiplicar)" % skin)
	holder.queue_free()


func _weapon_scale() -> void:
	for id in REAL_LENGTH.keys():
		var hand = preload("res://core/vr/vr_weapon_hand.gd").new()
		hand.weapon_id = id
		hand.auto_process = false
		root.add_child(hand)
		await process_frame
		var holder: Node3D = hand.holder
		_expect(holder != null and holder.global_transform.basis.get_scale().is_equal_approx(Vector3.ONE), "%s: holder sin escala" % id)
		var box: AABB = _mesh_aabb(holder)
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
		var expected: float = REAL_LENGTH[id]
		_expect(longest > expected * 0.75 and longest < expected * 1.3, "%s mide %.2f m (real ~%.2f)" % [id, longest, expected])
		hand.queue_free()
	await process_frame


func _map_scale() -> void:
	_expect(BuildingScript.DOOR_HEIGHT >= 1.9 and BuildingScript.DOOR_HEIGHT <= 2.4, "puerta de %.1f m" % BuildingScript.DOOR_HEIGHT)
	_expect(BuildingScript.WALL_HEIGHT >= 2.4 and BuildingScript.WALL_HEIGHT <= 3.2, "planta de %.1f m" % BuildingScript.WALL_HEIGHT)
	var packed := load("res://assets/models/maps/building/door-rotate-square-a.glb") as PackedScene
	if packed != null:
		var door := packed.instantiate() as Node3D
		root.add_child(door)
		var box: AABB = _mesh_aabb(door)
		_expect(box.size.y > 0.5 and box.size.y < 4.0, "modelo de puerta Kenney a escala metrica (%.2f m)" % box.size.y)
		door.free()
	var car := (load("res://assets/models/vehicles/sedan.glb") as PackedScene).instantiate() as Node3D
	root.add_child(car)
	var car_box: AABB = _mesh_aabb(car)
	_expect(car_box.size.z > 2.0 and car_box.size.z < 5.5 and car_box.size.y < 2.2, "coche de %.1f x %.1f m" % [car_box.size.z, car_box.size.y])
	car.free()


func _gore_not_continuous() -> void:
	GoreScript.set_gore_enabled(true)
	var host := Node3D.new()
	root.add_child(host)
	var before: int = GoreScript.puddle_count()
	GoreScript.blood_hit(host, Vector3(0, 1, 0), Vector3.UP, 30.0)
	var emitters := 0
	var one_shot := 0
	for p in host.find_children("*", "CPUParticles3D", true, false):
		emitters += 1
		if (p as CPUParticles3D).one_shot:
			one_shot += 1
	_expect(emitters >= 1 and emitters == one_shot, "las particulas de sangre son de un solo disparo")
	for i in 120:
		await process_frame
	var still := 0
	for p in host.find_children("*", "CPUParticles3D", true, false):
		if (p as CPUParticles3D).emitting:
			still += 1
	_expect(still == 0, "tras el impacto no hay emision continua")
	_expect(GoreScript.puddle_count() == before, "sin muerte no aparecen charcos")
	GoreScript.set_gore_enabled(null)
	host.queue_free()
