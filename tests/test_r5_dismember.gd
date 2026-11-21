extends SceneTree

const CharacterModelScript = preload("res://core/game/character_model.gd")
const GameSessionScript = preload("res://core/game/game_session.gd")
const GoreSystemScript = preload("res://core/game/gore_system.gd")

var _failures: Array = []
var _checks: int = 0
var _case: String = ""
var _root: Node3D = null
var _model: CharacterModel = null


func _initialize() -> void:
	await process_frame
	_root = Node3D.new()
	root.add_child(_root)
	GameSessionScript.gore_enabled = true
	GameSessionScript.gore_level = 2
	
	var results = []
	
	results.append(["desmembramiento: brazo supera umbral y se separa", await test_limb_detaches_on_threshold()])
	results.append(["desmembramiento: muñón existe tras corte", await test_stump_exists()])
	results.append(["desmembramiento: tope de piezas sueltas respetado (max 6)", await test_max_detached_limbs()])
	results.append(["desmembramiento: gore apagado no genera piezas", await test_gore_disabled_no_pieces()])
	results.append(["desmembramiento: PinJoint3D encadena padre e hijo", await test_pin_joints_chain_child_limbs()])
	results.append(["desmembramiento: costo de corte dentro de límite headless", await test_cut_performance()])
	
	for r in results:
		print("%s: %s" % [r[0], "PASS" if r[1] else "FAIL"])
	
	var all_passed = true
	for r in results:
		if not r[1]: 
			all_passed = false
	
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null
	
	if all_passed:
		print("PASS (%d assertions)" % _checks)
		quit(0)
	else:
		print("FAIL (%d/%d assertions fallidas)" % [_failures.size(), _checks])
		for failure in _failures:
			print("FAIL: " + str(failure))
		quit(1)


func test_limb_detaches_on_threshold() -> bool:
	_model = CharacterModelScript.spawn(_root, "civil", 12345)
	await _wait_loaded()
	
	var initial_limbs = _model.get_detached_limbs_count()
	
	var arm_bone = _model.find_bone("arm.r")
	if arm_bone < 0:
		_expect(false, "hueso arm.r no encontrado")
		return false
	
	for i in range(10):
		_model.accumulate_damage("arm.r", 15.0)
		await process_frame
	
	var final_limbs = _model.get_detached_limbs_count()
	_expect(final_limbs > initial_limbs, "miembro se separa al superar umbral: %d -> %d" % [initial_limbs, final_limbs])
	return final_limbs > initial_limbs


func test_stump_exists() -> bool:
	_model.accumulate_damage("leg.l", 200.0)
	await process_frame
	
	var leg_bone = _model.find_bone("leg.l")
	if leg_bone < 0:
		_expect(false, "hueso leg.l no encontrado")
		return false
	
	var stump = _model.get_stump_for_bone("leg.l")
	_expect(stump != null, "muñón existe")
	if stump == null:
		return false
	
	_expect(stump.has_meta("cut_surface"), "muñón tiene meta cut_surface")
	return stump.has_meta("cut_surface")


func test_max_detached_limbs() -> bool:
	var model2 = CharacterModelScript.spawn(_root, "civil", 54321)
	await _wait_loaded_model(model2)
	
	for bone in ["arm.l", "arm.r", "leg.l", "leg.r", "head"]:
		model2.accumulate_damage(bone, 500.0)
		await process_frame
	
	var count = model2.get_detached_limbs_count()
	_expect(count <= 6, "tope de piezas sueltas respetado (max 6): %d" % count)
	return count <= 6


func test_gore_disabled_no_pieces() -> bool:
	GameSessionScript.gore_enabled = false
	
	var model3 = CharacterModelScript.spawn(_root, "soldier", 999)
	await _wait_loaded_model(model3)
	
	model3.accumulate_damage("arm.r", 500.0)
	await process_frame
	
	var count = model3.get_detached_limbs_count()
	_expect(count == 0, "gore apagado no genera piezas: %d" % count)
	
	GameSessionScript.gore_enabled = true
	return count == 0


func test_pin_joints_chain_child_limbs() -> bool:
	GameSessionScript.gore_enabled = true
	GameSessionScript.gore_level = 2
	var host := Node3D.new()
	_root.add_child(host)
	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	host.add_child(skeleton)
	skeleton.add_bone("arm.r")
	skeleton.add_bone("hand.r")
	skeleton.set_bone_parent(1, 0)
	skeleton.set_bone_pose_position(0, Vector3(0.0, 1.0, 0.0))
	skeleton.set_bone_pose_position(1, Vector3(0.0, 0.5, 0.0))
	await process_frame

	var limb := GoreSystemScript._create_detached_limb(host, 0, skeleton, Vector3(0.0, 1.0, 0.0), 0.5, Vector3.RIGHT)
	await process_frame

	_expect(limb != null, "miembro desmembrado creado")
	var joints: Array = limb.get_meta("pin_joints", []) if limb != null else []
	_expect(joints.size() == 1, "un PinJoint3D por hueso hijo: %d" % joints.size())
	if joints.is_empty():
		return false

	var joint = joints[0]
	_expect(joint is PinJoint3D, "joint es PinJoint3D")
	var node_a = joint.get_node_or_null(joint.node_a)
	var node_b = joint.get_node_or_null(joint.node_b)
	_expect(node_a is RigidBody3D, "padre del joint es RigidBody3D")
	_expect(node_b is RigidBody3D, "hijo del joint es RigidBody3D")
	return joints.size() == 1 and joint is PinJoint3D and node_a is RigidBody3D and node_b is RigidBody3D


func test_cut_performance() -> bool:
	var model4 = CharacterModelScript.spawn(_root, "civil", 111)
	await _wait_loaded_model(model4)
	
	var start = Time.get_ticks_msec()
	model4.accumulate_damage("leg.r", 500.0)
	await process_frame
	var elapsed = Time.get_ticks_msec() - start
	
	_expect(elapsed < 60, "costo de corte dentro de límite headless: %d ms" % elapsed)
	return elapsed < 60


func _wait_loaded() -> void:
	while not _model.is_loaded():
		await process_frame


func _wait_loaded_model(model: CharacterModel) -> void:
	while not model.is_loaded():
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [_case, message])