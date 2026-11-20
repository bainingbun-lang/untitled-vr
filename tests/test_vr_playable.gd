extends SceneTree

const Harness = preload("res://tests/vr_sim_harness.gd")
const BuildingScript = preload("res://core/maps/building_generator.gd")
# zombis con postura encorvada miden ~1.5 m dibujados
const CHAR_MIN: float = 1.5

var _checks: int = 0
var _failures: Array = []
var h = null


func _initialize() -> void:
	await process_frame
	h = Harness.new()
	await h.start(self)
	await _test_calibration_and_floor()
	await _test_weapon_in_hand()
	await _test_fire()
	await _test_locomotion()
	await _test_grab()
	await _test_world_scale()
	await _test_menu()
	h.cleanup()
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


func _ground_below(point: Vector3) -> float:
	var space: PhysicsDirectSpaceState3D = h.world.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 5.0, 1)
	var hit: Dictionary = space.intersect_ray(query)
	return float(hit["position"].y) if not hit.is_empty() else 0.0


func _test_calibration_and_floor() -> void:
	print("-- 6) calibracion y suelo")
	_expect(h.rig.is_active(), "rig activo")
	_expect(h.state.onboarding != null, "onboarding presente")
	var head_y: float = h.head_world().y - _ground_below(h.head_world())
	print("altura de la cabeza sobre el suelo: %.2f m" % head_y)
	_expect(head_y >= 1.6 and head_y <= 1.8, "cabeza 1.6-1.8 m sobre el suelo")
	_expect(not h.rig.inputs_suspended, "entrada no suspendida al arrancar")
	_expect(h.rig.xr_origin.current and h.rig.xr_camera.current, "XROrigin y XRCamera son los actuales")
	await h.step(150, true)
	var calibration = h.rig.get_meta("calibration")
	print("ojos calibrados: %.2f (perfil %s)" % [calibration.eye_height(), calibration.last_status])
	_expect(absf(calibration.eye_height() - 1.7) < 0.02, "altura de ojos tomada de la cabeza real")
	await h.step(72 * 9, true)
	_expect(not h.state.onboarding.tutorial_open, "el tutorial se cierra solo y no bloquea la vista")


func _test_weapon_in_hand() -> void:
	print("-- 2) arma en mano")
	var hand = h.rig.right_hand
	print("arma inicial en mano derecha: '%s'" % hand.weapon_id)
	_expect(hand.weapon_id == "pistol", "al iniciar hay una pistola en la mano principal")
	if hand.weapon_id.is_empty() or hand.viewmodel == null:
		return
	var model = hand.viewmodel.model_instance()
	var length: float = Harness.longest(Harness.global_aabb(model))
	print("pistola: %.3f m (objetivo 0.15-0.30)" % length)
	_expect(length >= 0.15 and length <= 0.30, "pistola 0.15-0.30 m")
	var hands_vm = hand.viewmodel.hands_viewmodel()
	_expect(hands_vm == null or not hands_vm.visible, "sin brazos FPS flotando en la mano VR")
	var spawn_hand_pos: Vector3 = h.hand_world("right")
	for pair in [["assault_rifle", 0.7, 1.1], ["submachine_gun", 0.35, 0.6], ["shotgun", 0.7, 1.2], ["sniper_rifle", 0.8, 1.3]]:
		hand.stow()
		h.rig.bag.set_items([pair[0]])
		_expect(hand.try_take(pair[0], true), "se saca " + pair[0])
		await h.step(2)
		var size: float = Harness.longest(Harness.global_aabb(hand.viewmodel.model_instance()))
		print("%s: %.3f m (objetivo %.2f-%.2f)" % [pair[0], size, pair[1], pair[2]])
		_expect(size >= pair[1] and size <= pair[2], "%s en rango" % pair[0])
	hand.stow()
	h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
	hand.try_take("pistol", true)
	for side in ["left", "right"]:
		var model_node = h.rig.hand_models[side]
		var hand_len: float = Harness.longest(Harness.global_aabb(model_node))
		print("mano %s: %.3f m (objetivo 0.15-0.22)" % [side, hand_len])
		_expect(hand_len >= 0.15 and hand_len <= 0.22, "mano %s 0.15-0.22 m" % side)
	_expect(h.hand_world("right") == spawn_hand_pos, "la mano no se mueve sola")


func _test_fire() -> void:
	print("-- 4) disparo")
	var hand = h.rig.right_hand
	var ws = h.ws
	var info: Dictionary = ws.ammo_info("pistol")
	print("pistola al iniciar: cargador %d/%d, reserva %d, bloqueo '%s', ciclo pendiente %s" % [
		int(info["mag"]), int(info["mag_size"]), int(info["reserve"]), str(info["block_reason"]), str(info["needs_cycle"])])
	_expect(int(info["mag"]) == int(info["mag_size"]) and int(info["mag"]) > 0, "nace cargada")
	_expect(str(info["block_reason"]).is_empty() or str(info["block_reason"]) == "cadencia", "sin bloqueo (recarga/ciclo)")
	_expect(not bool(info["needs_cycle"]) and not hand.manual_reload_active, "bala en recamara, sin recarga manual pendiente")
	h.set_hand_world("right", h.head_world() + Vector3(0.25, -0.45, -0.35))
	await h.step(20, true)
	var before: int = ws.ammo("pistol")
	var shots: Array = []
	hand.fired.connect(func(result: Dictionary) -> void: shots.append(result))
	var haptics: Array = []
	hand.haptic.connect(func(who: String, duration: float, frequency: float, amplitude: float) -> void: haptics.append(who))
	var fx_before: int = h.tree.root.find_children("MuzzleFlash*", "", true, false).size()
	h.input.triggers["right"] = true
	await h.step(2, true)
	h.input.triggers["right"] = 0.0
	await h.step(2, true)
	var steps: Array = []
	for entry in hand.shot_trace:
		steps.append(entry["step"])
	print("disparo con gatillo bool: municion %d -> %d, trace %s, haptica %d eventos" % [before, ws.ammo("pistol"), str(steps), haptics.size()])
	_expect(ws.ammo("pistol") == before - 1, "el gatillo (bool) baja la municion")
	_expect(shots.size() == 1 and bool(hand.last_shot.get("fired", false)), "try_fire dispara")
	for needed in ["ammo", "recoil", "haptic", "muzzle_fx", "sound", "fire"]:
		_expect(steps.has(needed), "paso del disparo: " + needed)
	_expect(haptics.size() > 0, "hay haptica")
	_expect(hand.last_shot.has("recoil") and hand.last_shot.has("direction"), "hay retroceso y direccion")
	var fx_after: int = h.tree.root.find_children("MuzzleFlash*", "", true, false).size()
	print("fogonazos en escena: %d -> %d, hit=%s distancia=%s" % [fx_before, fx_after, str(hand.last_shot.get("hit", "?")), str(hand.last_shot.get("distance", "?"))])
	_expect(fx_after > fx_before or hand.viewmodel.find_child("MuzzleFx", true, false) != null, "fogonazo")
	await h.step(15, true)
	var before_float: int = ws.ammo("pistol")
	h.input.triggers["right"] = 0.8
	await h.step(2, true)
	h.input.triggers["right"] = 0.0
	await h.step(2, true)
	print("disparo con gatillo 0.8: municion %d -> %d" % [before_float, ws.ammo("pistol")])
	_expect(ws.ammo("pistol") == before_float - 1, "el gatillo analogico 0.8 tambien dispara")
	h.input.triggers["right"] = 0.4
	await h.step(2, true)
	h.input.triggers["right"] = 0.0
	_expect(ws.ammo("pistol") == before_float - 1, "gatillo 0.4 no dispara")
	var rifle_ammo: Dictionary = {}
	for id in ["shotgun", "sniper_rifle", "assault_rifle"]:
		hand.stow()
		h.rig.bag.set_items([id])
		hand.try_take(id, true)
		var info2: Dictionary = ws.ammo_info(id)
		_expect(int(info2["mag"]) == int(info2["mag_size"]) and not bool(info2["needs_cycle"]) and ws.fire_block_reason(id).is_empty(),
			"%s nace lista para disparar" % id)
		rifle_ammo[id] = info2["mag"]
	hand.stow()
	h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
	hand.try_take("pistol", true)


func _test_locomotion() -> void:
	print("-- 1) locomocion")
	var rig = h.rig
	var start: Vector3 = h.origin_pos()
	h.set_head_yaw(0.0)
	h.input.sticks["left"] = Vector2(0, -1)
	await h.step(144, true)
	h.input.sticks["left"] = Vector2.ZERO
	var moved: Vector3 = h.origin_pos() - start
	print("stick adelante 2 s: avanza %.2f m (%s)" % [moved.length(), str(moved)])
	_expect(moved.length() >= 3.0 and moved.length() <= 5.0, "avanza 3-5 m en 2 s")
	_expect(absf(moved.y) < 0.01, "no se hunde ni sube")
	var forward: Vector3 = -rig.xr_camera.global_transform.basis.z
	forward.y = 0.0
	_expect(moved.normalized().dot(forward.normalized()) > 0.95 or moved.length() < 1.0, "va hacia donde mira la cabeza")
	h.set_head_yaw(PI * 0.5)
	var start2: Vector3 = h.origin_pos()
	h.input.sticks["left"] = Vector2(0, -1)
	await h.step(36, true)
	h.input.sticks["left"] = Vector2.ZERO
	var moved2: Vector3 = h.origin_pos() - start2
	var head_forward: Vector3 = -rig.xr_camera.global_transform.basis.z
	print("con la cabeza girada 90: avanza %.2f m, coseno con la mirada %.2f" % [moved2.length(), moved2.normalized().dot(head_forward)])
	_expect(moved2.length() > 0.8 and moved2.normalized().dot(head_forward) > 0.95, "sigue la direccion de la cabeza girada")
	h.set_head_yaw(0.0)
	var yaw_before: float = rig.xr_origin.global_rotation.y
	h.input.sticks["right"] = Vector2(1, 0)
	await h.step(36, true)
	h.input.sticks["right"] = Vector2.ZERO
	var turned: float = rad_to_deg(wrapf(rig.xr_origin.global_rotation.y - yaw_before, -PI, PI))
	print("stick derecho 0.5 s: gira %.1f grados (%s)" % [turned, rig.turn_mode])
	_expect(absf(turned) > 10.0, "el stick derecho gira el rig")
	rig.xr_origin.global_rotation = Vector3.ZERO

	# colision con paredes: se camina hacia la pared mas cercana y no se atraviesa
	var space: PhysicsDirectSpaceState3D = h.world.get_world_3d().direct_space_state
	var best_dir := Vector3.ZERO
	var best_distance: float = 1.0e9
	var origin: Vector3 = h.origin_pos()
	for i in 16:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, TAU * float(i) / 16.0)
		var query := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 0.9, origin + Vector3.UP * 0.9 + dir * 12.0, 1)
		var hit: Dictionary = space.intersect_ray(query)
		if not hit.is_empty() and float(hit["normal"].dot(-dir)) > 0.9:
			var d: float = (Vector3(hit["position"].x, origin.y, hit["position"].z) - origin).dot(-hit["normal"])
			if d < best_distance:
				best_distance = d
				best_dir = -hit["normal"]
	_expect(best_dir != Vector3.ZERO, "hay una pared cerca del jugador")
	if best_dir != Vector3.ZERO:
		best_dir.y = 0.0
		best_dir = best_dir.normalized()
		h.set_head_yaw(atan2(-best_dir.x, -best_dir.z))
		var wall_start: Vector3 = h.origin_pos()
		h.input.sticks["left"] = Vector2(0, -1)
		await h.step(72 * 6, true)
		h.input.sticks["left"] = Vector2.ZERO
		var advanced: float = (h.origin_pos() - wall_start).dot(best_dir)
		print("pared a %.2f m: se avanza %.2f m en 6 s de stick (colision)" % [best_distance, advanced])
		_expect(advanced < best_distance - 0.15, "no atraviesa la pared (se detiene antes de tocarla)")
		_expect(advanced > 0.1 or best_distance < 0.5, "se acerca a la pared")
	h.set_head_yaw(0.0)
	_expect(absf(h.origin_pos().y - start.y) < 0.01, "el suelo no cambia de altura")
	var head_y: float = h.head_world().y - _ground_below(h.head_world())
	_expect(head_y >= 1.6 and head_y <= 1.8, "tras caminar la cabeza sigue 1.6-1.8 m sobre el suelo")


func _hand_empty() -> void:
	for hand in [h.rig.left_hand, h.rig.right_hand]:
		hand.stow()
	h.input.grips["left"] = 0.0
	h.input.grips["right"] = 0.0


func _grip_at(hand_name: String, point: Vector3) -> String:
	var hand = h.rig.left_hand if hand_name == "left" else h.rig.right_hand
	h.set_hand_world(hand_name, point)
	return str(hand.weapon_id)


func _test_grab() -> void:
	print("-- 3) agarre")
	h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
	_hand_empty()
	h.rig.xr_origin.global_position = h.world.spawn_point_positions()[0] if not h.world.spawn_point_positions().is_empty() else Vector3.ZERO
	h.set_head_yaw(0.0)
	await h.step(3)
	var hand = h.rig.right_hand
	var head: Vector3 = h.head_world()
	var holsters = hand.holsters
	holsters.set_head_pose(Transform3D(Basis.IDENTITY, head))
	var results: Dictionary = {}
	for slot in ["hip", "back", "chest", "bag"]:
		_hand_empty()
		h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
		var target: Vector3 = holsters.slot_position(slot) + Vector3(0.08, 0.05, 0.08)
		h.set_hand_world("right", target)
		h.input.grips["right"] = 0.0
		await h.step(2)
		_expect(hand.weapon_id.is_empty(), "mano suelta antes del agarre en " + slot)
		h.input.grips["right"] = 1.0
		await h.step(3)
		results[slot] = hand.weapon_id
		print("grip en funda %s (mano a 0.13 m del centro): arma '%s'" % [slot, hand.weapon_id])
		_expect(not hand.weapon_id.is_empty(), "el grip en la funda %s saca un arma" % slot)
		h.input.grips["right"] = 0.0
		h.set_hand_world("right", target + Vector3(0.0, 0.3, -0.5))
		await h.step(3)
		_expect(not hand.weapon_id.is_empty(), "soltar el grip fuera de funda no guarda el arma (%s)" % slot)
	_expect(results["hip"] == "pistol", "cadera = pistola")
	_hand_empty()
	h.rig.bag.set_items(["pistol", "assault_rifle"])
	h.set_hand_world("right", head + Vector3(0.0, 0.4, -0.6))
	h.input.grips["right"] = 1.0
	await h.step(3)
	_expect(hand.weapon_id.is_empty(), "grip lejos de cualquier funda no saca nada")
	h.input.grips["right"] = 0.0
	await h.step(2)
	h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
	# props del mundo
	var props: Array = h.world.props()
	_expect(props.size() > 0, "el mundo tiene props de fisica")
	if props.size() > 0:
		var prop: RigidBody3D = props[0]
		prop.freeze = false
		var home: Vector3 = prop.global_position
		h.set_hand_world("right", home + Vector3(0.1, 0.1, 0.0))
		h.input.grips["right"] = 1.0
		await h.step(3)
		_expect(hand.grab_system != null and hand.grab_system.held_prop() == prop, "grip cerca de un prop lo agarra")
		h.set_hand_world("right", home + Vector3(0.0, 1.2, 0.0))
		await h.step(3)
		print("prop agarrado sigue a la mano: distancia %.3f m" % prop.global_position.distance_to(h.hand_world("right")))
		_expect(prop.global_position.distance_to(h.hand_world("right")) < 0.05, "el prop sigue a la mano")
		h.input.grips["right"] = 0.0
		await h.step(3)
		_expect(hand.grab_system.held_prop() == null, "soltar el grip suelta el prop")
		prop.global_position = home
	h.input.grips["right"] = 0.0
	_hand_empty()
	h.rig.bag.set_items(["pistol", "submachine_gun", "assault_rifle", "shotgun", "sniper_rifle", "bat"])
	hand.try_take("pistol", true)


func _skinned_height(node: Node3D, skip: String = "") -> float:
	return Harness.skinned_aabb(node, skip).size.y


func _office_boxes(office: Node) -> Array:
	var shape: ConcavePolygonShape3D = (office.get_node("OfficeCollision/OfficeCollisionShape") as CollisionShape3D).shape
	var faces: PackedVector3Array = shape.get_faces()
	var boxes: Array = []
	for start in range(0, faces.size(), 36):
		var box := AABB(faces[start], Vector3.ZERO)
		for i in range(start, start + 36):
			box = box.expand(faces[i])
		boxes.append(box)
	return boxes


func _test_world_scale() -> void:
	print("-- 5) escala del mundo (real | objetivo)")
	var world = h.world
	var office: Node = world.find_children("Office_*", "Node3D", true, false)[0]
	var rows: Array = []
	# El renderizador headless no conserva los transforms de los MultiMesh: se miden las cajas de colision reales.
	var boxes: Array = _office_boxes(office)
	var wall_height: float = 0.0
	var desk_heights: Array = []
	for box in boxes:
		wall_height = maxf(wall_height, box.size.y)
		if box.size.y > 0.7 and box.size.y < 0.85 and box.size.x * box.size.z > 0.6:
			desk_heights.append(box.size.y)
	rows.append(["techo oficina (muros)", wall_height, 2.4, 3.2])
	for value in desk_heights:
		rows.append(["escritorio", value, 0.7, 0.81])
	_expect(desk_heights.size() >= 1, "la oficina tiene escritorios")
	var door_path: String = "res://assets/models/maps/furniture/wallDoorwayWide.glb"
	var door_part: Dictionary = BuildingScript.model_parts(door_path)[0]
	var native: AABB = door_part["mesh"].get_aabb()
	var triangles: TriangleMesh = door_part["mesh"].generate_triangle_mesh()
	var up := triangles.intersect_ray(Vector3(native.get_center().x, native.position.y - 0.01, native.get_center().z), Vector3.UP)
	var opening_ratio: float = 1.0 if up.is_empty() else (float(up["position"].y) - native.position.y) / native.size.y
	rows.append(["puerta (vano)", opening_ratio * wall_height, 2.0, 2.2])
	var characters: Array = []
	for node in world.find_children("*", "Node3D", true, false):
		var script_path: String = node.get_script().resource_path.get_file() if node.get_script() != null else ""
		if script_path == "armed_npc.gd" or script_path == "target_dummy.gd":
			characters.append(node)
	for node in characters:
		rows.append([str(node.name), _skinned_height(node, "WeaponMount"), CHAR_MIN, 1.9])
		var mount = node.get_node_or_null("WeaponMount")
		if mount != null and mount.get_child_count() > 0:
			rows.append([str(node.name) + " arma", Harness.longest(Harness.skinned_aabb(mount)), 0.3, 1.2])
	for vehicle in world.vehicles():
		var box: AABB = Harness.local_aabb(vehicle)
		rows.append([str(vehicle.name) + " largo", maxf(box.size.x, box.size.z), 2.9 if "buggy" in str(vehicle.name) else 4.0, 5.2])
	for row in rows:
		var ok: bool = float(row[1]) >= float(row[2]) and float(row[1]) <= float(row[3])
		print("  %-26s real %.2f m | objetivo %.2f-%.2f %s" % [row[0], row[1], row[2], row[3], "OK" if ok else "FUERA"])
		_expect(ok, "escala %s %.2f fuera de %.2f-%.2f" % [row[0], row[1], row[2], row[3]])


func _test_menu() -> void:
	print("-- C) menu y entrada")
	var state = h.state
	var rig = h.rig
	var menu = state.menu
	_expect(not menu.is_open and not rig.inputs_suspended, "al empezar el menu esta cerrado y la entrada libre")
	h.input.buttons["menu"] = true
	await h.step(2)
	h.input.buttons["menu"] = false
	_expect(menu.is_open and rig.inputs_suspended, "boton de menu abre el menu y suspende el rig")
	var ammo: int = h.ws.ammo("pistol")
	h.input.triggers["right"] = 1.0
	await h.step(3)
	h.input.triggers["right"] = 0.0
	_expect(h.ws.ammo("pistol") == ammo, "con el menu abierto el gatillo no dispara")
	menu.call("close_menu")
	await h.step(2)
	_expect(not rig.inputs_suspended, "cerrar el menu libera la entrada")
	var start: Vector3 = h.origin_pos()
	h.input.sticks["left"] = Vector2(0, -1)
	await h.step(36, true)
	h.input.sticks["left"] = Vector2.ZERO
	_expect(h.origin_pos().distance_to(start) > 0.5, "tras cerrar el menu se puede caminar")
	var ammo2: int = h.ws.ammo("pistol")
	await h.step(20, true)
	h.input.triggers["right"] = 1.0
	await h.step(2, true)
	h.input.triggers["right"] = 0.0
	_expect(h.ws.ammo("pistol") == ammo2 - 1, "tras cerrar el menu el gatillo dispara")
