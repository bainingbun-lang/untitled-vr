extends SceneTree

const DistanceGrabScript = preload("res://core/vr/vr_distance_grab.gd")
const GrabScript = preload("res://core/vr/vr_grab.gd")
const HolsterScript = preload("res://core/vr/vr_holsters.gd")
const HandScript = preload("res://core/vr/vr_weapon_hand.gd")
const WsScript = preload("res://core/game/weapon_system.gd")
const DbScript = preload("res://core/game/weapon_db.gd")
const BagScript = preload("res://core/vr/vr_bag.gd")

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

class FakeProvider extends RefCounted:
	var pose: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	var grip_pressed: bool = false
	func get_pose(_hand: String) -> Transform3D:
		return pose
	func is_grip_pressed(_hand: String) -> bool:
		return grip_pressed
	func is_trigger_pressed(_hand: String) -> bool:
		return false

class FakeHolsters extends RefCounted:
	var _slots: Dictionary = {}
	var _head_transform: Transform3D = Transform3D.IDENTITY
	func set_head_pose(xform: Transform3D) -> void:
		_head_transform = xform
	func slot_position(slot: String) -> Vector3:
		var offsets := {
			"hip": Vector3(0.18, -0.40, 0.02),
			"hip2": Vector3(-0.18, -0.40, 0.02),
			"back": Vector3(0.0, 0.08, 0.24),
			"chest": Vector3(0.0, -0.15, -0.16),
			"bag": Vector3(0.26, -0.38, 0.32),
		}
		var eye_height: float = 1.65
		var local := offsets.get(slot, Vector3.ZERO) * eye_height
		return _head_transform.origin + _head_transform.basis * local
	func slot_radius(slot: String) -> float:
		return 0.2
	func nearest_slot(hand_pose: Transform3D, radius_scale: float = 1.0) -> Dictionary:
		var best := ""
		var best_dist: float = 1.0e9
		for slot in ["hip", "hip2", "back", "chest", "bag"]:
			var dist := hand_pose.origin.distance_to(slot_position(slot))
			if dist < best_dist:
				best_dist = dist
				best = slot
		var limit := slot_radius(best) * radius_scale
		return {"slot": best if best_dist <= limit else "", "distance": best_dist, "ok": best_dist <= limit}

class FakeBag extends RefCounted:
	var items_list: Array = []
	var head_forward: Vector3 = Vector3.FORWARD
	var head_position: Vector3 = Vector3(0, 1.7, 0)
	func items() -> Array:
		return items_list
	func held_in(_hand: String) -> String:
		return ""
	func is_open() -> bool:
		return true
	func is_in_bag_zone(_pos: Vector3) -> bool:
		return false
	func bag_center() -> Vector3:
		return Vector3(0, 1.5, 0.3)
	func set_head_transform(_xform: Transform3D) -> void:
		pass
	func open(_pos: Vector3) -> void:
		pass
	func take(_id: String, _hand: String) -> bool:
		return false
	func stow(_hand: String) -> void:
		pass

class FakeWeaponSystem extends Node:
	var calls: int = 0
	func fire(_id: String, _origin: Vector3, _direction: Vector3, _space, _exclude) -> Dictionary:
		calls += 1
		return {"fired": true}

func _initialize() -> void:
	await process_frame
	_test_basic_targeting()
	_test_cone_priority()
	_test_close_grab_priority()
	_test_disabled()
	_test_fly_to_hand()
	_test_weapon_equip()
	_test_prop_grab()
	_test_no_grab_outside_range()
	_test_no_grab_outside_cone()
	if _failures.is_empty():
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			print("FAIL: " + failure)
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("[%s] %s" % [_case, message])

func _finite(value: Vector3) -> bool:
	return not is_nan(value.x) and not is_inf(value.x) and not is_nan(value.y) and not is_inf(value.y) and not is_nan(value.z) and not is_inf(value.z)

func _make_weapon_pickup(weapon_id: String, pos: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	body.name = "WeaponPickup_%s" % weapon_id
	body.add_to_group("weapon_pickup")
	body.set_meta("weapon_id", weapon_id)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.1, 0.1, 0.5)
	shape.shape = box
	body.add_child(shape)
	body.global_position = pos
	root.add_child(body)
	return body

func _make_physics_prop(pos: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	body.name = "PhysicsProp"
	body.add_to_group("physics_props")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.1
	shape.shape = sphere
	body.add_child(shape)
	body.global_position = pos
	root.add_child(body)
	return body

func _make_grabbable_prop(pos: Vector3) -> Node3D:
	var body := RigidBody3D.new()
	body.name = "GrabbableProp"
	body.add_to_group("grabbable")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 0.2, 0.2)
	shape.shape = box
	body.add_child(shape)
	body.global_position = pos
	root.add_child(body)
	return body

func _test_basic_targeting() -> void:
	_case = "targeting basico"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -1.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == weapon, "arma a 1m detectada como objetivo")
	_expect(grab.is_enabled(), "distance grab habilitado por defecto")
	
	weapon.free()
	hand.queue_free()
	grab.cancel()

func _test_cone_priority() -> void:
	_case = "prioridad por cono de 8 grados"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon_center = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -2.0))
	var weapon_edge = _make_weapon_pickup("shotgun", Vector3(0.5, 1.5, -2.0))
	var weapon_outside = _make_weapon_pickup("rifle", Vector3(1.0, 1.5, -2.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == weapon_center, "arma centrada en el rayo tiene prioridad")
	
	weapon_center.free()
	weapon_edge.free()
	weapon_outside.free()
	hand.queue_free()
	grab.cancel()

func _test_close_grab_priority() -> void:
	_case = "prioridad agarre cercano (< 0.25m a funda)"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	var holster_pos := Vector3(0.18 * 1.65, 1.7 - 0.40 * 1.65, 0.02 * 1.65)
	provider.pose = Transform3D(Basis.IDENTITY, holster_pos + Vector3(0.05, 0.0, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -1.0))
	
	var holsters = FakeHolsters.new()
	holsters.set_head_pose(Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)))
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == null, "no hay objetivo a distancia si mano cerca de funda")
	
	weapon.free()
	hand.queue_free()
	grab.cancel()

func _test_disabled() -> void:
	_case = "desactivable por ajuste"
	var grab = DistanceGrabScript.new("right")
	grab.set_enabled(false)
	
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -1.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == null, "no detecta objetivo si desactivado")
	_expect(not grab.is_enabled(), "is_enabled devuelve false")
	
	weapon.free()
	hand.queue_free()
	grab.cancel()

func _test_fly_to_hand() -> void:
	_case = "vuelo a la mano en 0.25-0.35s"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -2.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	hand.distance_grab_enabled = true
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	_expect(grab.get_target() == weapon, "objetivo detectado antes del grip")
	
	provider.grip_pressed = true
	grab.step(0.016, provider.pose, true, holsters, bag, hand)
	_expect(grab.is_flying(), "inicia vuelo al presionar grip")
	
	var start_pos := weapon.global_position
	var flew: bool = false
	for i in range(30):
		grab.step(0.016, provider.pose, true, holsters, bag, hand)
		if weapon.global_position.distance_to(start_pos) > 0.1:
			flew = true
			break
	_expect(flew, "el objeto se mueve hacia la mano")
	
	for i in range(50):
		grab.step(0.016, provider.pose, true, holsters, bag, hand)
		if not grab.is_flying():
			break
	
	_expect(not grab.is_flying(), "vuelo termina")
	_expect(hand.weapon_id == "pistol", "arma equipada en la mano tras vuelo")
	_expect(not is_instance_valid(weapon), "nodo del arma recogida liberado")
	
	hand.queue_free()
	grab.cancel()

func _test_weapon_equip() -> void:
	_case = "reutiliza _equip_weapon_from_pickup"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("assault_rifle", Vector3(0.0, 1.5, -3.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	hand.distance_grab_enabled = true
	hand.use_physical_grab = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	provider.grip_pressed = true
	
	for i in range(80):
		grab.step(0.016, provider.pose, true, holsters, bag, hand)
		if not grab.is_flying():
			break
	
	_expect(hand.weapon_id == "assault_rifle", "arma larga equipada")
	_expect(hand.viewmodel != null, "viewmodel creado")
	
	hand.queue_free()
	grab.cancel()

func _test_prop_grab() -> void:
	_case = "agarre de props fisicos (physics_props/grabbable)"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var prop = _make_physics_prop(Vector3(0.0, 1.5, -1.5))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	hand.distance_grab_enabled = true
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	_expect(grab.get_target() == prop, "prop fisico detectado")
	
	provider.grip_pressed = true
	for i in range(80):
		grab.step(0.016, provider.pose, true, holsters, bag, hand)
		if not grab.is_flying():
			break
	
	_expect(hand.grab_system != null and hand.grab_system.held_prop() == prop, "prop agarrado con VrGrab")
	
	prop.free()
	hand.queue_free()
	grab.cancel()

func _test_no_grab_outside_range() -> void:
	_case = "no agarra fuera de 6m"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(0.0, 1.5, -7.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == null, "arma a 7m no detectada")
	
	provider.grip_pressed = true
	grab.step(0.016, provider.pose, true, holsters, bag, hand)
	_expect(not grab.is_flying(), "no inicia vuelo si fuera de rango")
	
	weapon.free()
	hand.queue_free()
	grab.cancel()

func _test_no_grab_outside_cone() -> void:
	_case = "no agarra fuera del cono de 8 grados"
	var grab = DistanceGrabScript.new("right")
	var provider = FakeProvider.new()
	provider.pose = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 0.0))
	
	var weapon = _make_weapon_pickup("pistol", Vector3(1.0, 1.5, -1.0))
	
	var holsters = FakeHolsters.new()
	var bag = FakeBag.new()
	var hand = HandScript.new()
	hand.hand = "right"
	hand.bag = bag
	hand.input_provider = provider
	hand.auto_process = false
	root.add_child(hand)
	
	grab.step(0.016, provider.pose, false, holsters, bag, hand)
	
	_expect(grab.get_target() == null, "arma a ~30 grados fuera del cono no detectada")
	
	weapon.free()
	hand.queue_free()
	grab.cancel()