extends SceneTree

var _checks: int = 0
var _failures: Array = []
var _case: String = ""

var HandAnchorScript
var VrGloveScript
var VrHandScript
var VrGrabbableScript
var VrPickupScript
var VrMoveableScript

func _initialize() -> void:
	await process_frame
	
	HandAnchorScript = load("res://core/vr/hand_anchor.gd")
	VrGloveScript = load("res://core/vr/vr_glove.gd")
	VrHandScript = load("res://core/vr/vr_hand.gd")
	VrGrabbableScript = load("res://core/vr/vr_grabbable.gd")
	VrPickupScript = load("res://core/vr/vr_pickup.gd")
	VrMoveableScript = load("res://core/vr/vr_moveable.gd")
	
	await _test_hand_anchor()
	await _test_vr_glove()
	await _test_vr_hand()
	await _test_vr_grabbable()
	await _test_vr_pickup()
	await _test_vr_moveable()
	await _test_physics_collision()
	
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
		_failures.append("[%s] %s" % [_case, message])

func _test_hand_anchor() -> void:
	_case = "HandAnchor: creación y configuración"
	
	var anchor = HandAnchorScript.new()
	anchor.hand_name = "right"
	anchor.anchor_mass = 0.1
	anchor.follow_stiffness = 1200.0
	anchor.follow_damping = 80.0
	root.add_child(anchor)
	await physics_frame
	
	_expect(anchor.get_hand_name() == "right", "nombre de mano correcto")
	_expect(anchor.mass == 0.1, "masa configurada")
	_expect(anchor.continuous_cd == true, "continuous CD habilitado")
	_expect(anchor.sleeping == false, "no duerme")
	
	var target = Transform3D(Basis.IDENTITY, Vector3(1, 2, 3))
	anchor.set_target_transform(target)
	await physics_frame
	await physics_frame
	
	var pos = anchor.global_position
	_expect(pos.distance_to(target.origin) < 0.5, "anchor sigue target (%s vs %s)" % [pos, target.origin])
	
	anchor.queue_free()
	await physics_frame

func _test_vr_glove() -> void:
	_case = "VrGlove: construcción y poses"
	
	var glove = VrGloveScript.new()
	var success = glove.build("right")
	root.add_child(glove)
	await physics_frame
	
	_expect(success == true, "construcción exitosa")
	_expect(glove.get_hand_name() == "right", "mano derecha")
	_expect(glove.get_skeleton() != null, "skeleton creado")
	_expect(glove.visible_mesh_count() > 0, "tiene mallas visibles")
	
	glove.set_pose(0.5, 0.0, "grip")
	await physics_frame
	var curl_index = glove.curl_of("index")
	_expect(curl_index > 0.0, "dedo índice curvado con grip")
	
	glove.set_pose(0.0, 1.0, "grip")
	await physics_frame
	var curl_trigger = glove.curl_of("index")
	_expect(curl_trigger > 0.0, "dedo índice curvado con trigger")
	
	glove.set_visible(false)
	_expect(glove.is_visible() == false, "visible = false")
	glove.set_visible(true)
	_expect(glove.is_visible() == true, "visible = true")
	
	glove.queue_free()
	await physics_frame

func _test_vr_hand() -> void:
	_case = "VrHand: construcción y agarre básico"
	
	var hand = VrHandScript.new()
	hand.hand_name = "left"
	hand.show_visual = true
	root.add_child(hand)
	await physics_frame
	
	_expect(hand.get_hand_name() == "left", "mano izquierda")
	_expect(hand.get_anchor() != null, "anchor creado")
	_expect(hand.get_glove() != null, "guante creado")
	_expect(hand.is_grabbing() == false, "no agarra al inicio")
	
	var target = Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -0.5))
	hand.set_target_transform(target)
	await physics_frame
	await physics_frame
	
	var anchor_transform = hand.get_anchor_transform()
	_expect(anchor_transform.origin.distance_to(target.origin) < 0.3, "anchor sigue target")
	
	hand.queue_free()
	await physics_frame

func _test_vr_grabbable() -> void:
	_case = "VrGrabbable: comportamiento físico"
	
	var grabbable = VrGrabbableScript.new()
	grabbable.grabbable = true
	grabbable.mass = 2.0
	root.add_child(grabbable)
	await physics_frame
	
	_expect(grabbable.is_in_group("vr_grabbable"), "en grupo vr_grabbable")
	_expect(grabbable.mass == 2.0, "masa correcta")
	_expect(grabbable.can_grab(null) == false, "no agarra con mano null")
	
	var mock_hand = {
		"get_hand_name": func(): return "right",
		"get_anchor_transform": func(): return Transform3D.IDENTITY,
		"get_grip_value": func(): return 1.0,
	}
	
	grabbable.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	await physics_frame
	
	_expect(grabbable.is_grabbed() == true, "marcado como agarrado")
	_expect(grabbable.linear_damp == grabbable.grab_linear_damp, "amortiguación de agarre activa")
	
	grabbable.on_released(mock_hand, "right", Vector3(1, 0, 0))
	await physics_frame
	
	_expect(grabbable.is_grabbed() == false, "marcado como soltado")
	_expect(grabbable.linear_damp == grabbable.linear_damp, "amortiguación restaurada")
	
	grabbable.queue_free()
	await physics_frame

func _test_vr_pickup() -> void:
	_case = "VrPickup: ítem recogible"
	
	var pickup = VrPickupScript.new()
	pickup.item_id = "health_potion"
	pickup.item_name = "Poción de vida"
	pickup.current_stack = 3
	pickup.max_stack = 10
	pickup.consume_on_use = true
	pickup.use_on_trigger = true
	root.add_child(pickup)
	await physics_frame
	
	_expect(pickup.item_id == "health_potion", "ID correcto")
	_expect(pickup.current_stack == 3, "stack inicial")
	
	var used_data = null
	pickup.pickup_used.connect(func(data): used_data = data)
	
	var mock_hand = {
		"get_hand_name": func(): return "right",
		"get_trigger_value": func(): return 1.0,
		"get_anchor_transform": func(): return Transform3D.IDENTITY,
		"get_grip_value": func(): return 1.0,
	}
	
	pickup.on_grabbed(mock_hand, "right", Transform3D.IDENTITY)
	await physics_frame
	
	pickup.on_released(mock_hand, "right", Vector3.ZERO)
	await physics_frame
	
	_expect(used_data != null, "emitió señal de uso")
	_expect(used_data["item_id"] == "health_potion", "ID en datos de uso")
	_expect(pickup.current_stack == 2, "stack decrementado tras uso")
	
	pickup.set_stack(0)
	await physics_frame
	_expect(not is_instance_valid(pickup), "destruido al stack 0")
	
	await physics_frame

func _test_vr_moveable() -> void:
	_case = "VrMoveable: objeto movible con dos manos"
	
	var moveable = VrMoveableScript.new()
	moveable.moveable_type = "crate"
	moveable.require_two_hands = true
	moveable.push_resistance = 100.0
	moveable.snap_to_hand = true
	root.add_child(moveable)
	await physics_frame
	
	_expect(moveable.get_state() == "idle", "estado inicial idle")
	_expect(moveable.require_two_hands == true, "requiere dos manos")
	
	var mock_hand1 = {
		"get_hand_name": func(): return "left",
		"get_anchor_transform": func(): return Transform3D(Basis.IDENTITY, Vector3(-0.1, 1.5, -0.5)),
		"get_grip_value": func(): return 1.0,
		"get_trigger_value": func(): return 0.0,
	}
	var mock_hand2 = {
		"get_hand_name": func(): return "right",
		"get_anchor_transform": func(): return Transform3D(Basis.IDENTITY, Vector3(0.1, 1.5, -0.5)),
		"get_grip_value": func(): return 1.0,
		"get_trigger_value": func(): return 0.0,
	}
	
	moveable.on_grabbed(mock_hand1, "left", Transform3D.IDENTITY)
	await physics_frame
	
	_expect(moveable.get_state() == "grabbed", "estado grabbed")
	_expect(moveable.get_primary_hand() == mock_hand1, "mano primaria asignada")
	
	moveable.try_add_secondary_hand(mock_hand2)
	await physics_frame
	
	_expect(moveable.is_grabbed_with_two_hands() == true, "agarre con dos manos")
	_expect(moveable.get_secondary_hand() == mock_hand2, "mano secundaria asignada")
	
	moveable.on_released(mock_hand1, "left", Vector3.ZERO)
	await physics_frame
	
	_expect(moveable.get_primary_hand() == mock_hand2, "mano secundaria pasa a primaria")
	
	moveable.on_released(mock_hand2, "right", Vector3(2, 0, 0))
	await physics_frame
	
	_expect(moveable.get_state() == "thrown", "estado thrown tras soltar")
	
	await physics_frame
	moveable.queue_free()

func _test_physics_collision() -> void:
	_case = "Colisión física: mano no atraviesa paredes"
	
	var wall = StaticBody3D.new()
	var wall_shape = BoxShape3D.new()
	wall_shape.size = Vector3(2, 3, 0.1)
	var wall_collision = CollisionShape3D.new()
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	wall.global_position = Vector3(0, 1.5, -1)
	root.add_child(wall)
	await physics_frame
	
	var hand = VrHandScript.new()
	hand.hand_name = "right"
	hand.show_visual = false
	hand.anchor_mass = 0.1
	hand.follow_stiffness = 2000.0
	root.add_child(hand)
	await physics_frame
	
	var target_behind_wall = Transform3D(Basis.IDENTITY, Vector3(0, 1.5, -1.5))
	hand.set_target_transform(target_behind_wall)
	
	for i in range(30):
		await physics_frame
	
	var hand_pos = hand.get_anchor_transform().origin
	_expect(hand_pos.z > -1.1, "mano detenida por pared (z=%s)" % hand_pos.z)
	
	hand.queue_free()
	wall.queue_free()
	await physics_frame